module MiraiBots

using HTTP, JSON3, StructTypes

const Optional{T} = Union{T,Nothing}

# TODO: really make them different
const FriendId = Int
const GroupId = Int
const GroupOrFriendId = Union{FriendId,GroupId}
const MessageId = Int
const TimeStamp = Int
const DurationSeconds = Int
const EventId = Int
const DeviceKind = Int

include("MessageChains.jl")
include("EventsAndMessages.jl")
include("Commands.jl")

"""
    ProtocolAdapter

Adapter for different protocols that Mirai HTTP API provides.

- `loop`: start sending and receiving. The function blocks, so you would like to call it as `@async loop(...)`.
- `send`: post a message, wait and return the result. Because the adapter need to be initialized, do not send until the first message is received.
- `receive`: wait and retrieve a message (serialized when possible) or exception. The first message is always session info.
- `get_output_channel`: alternative to `receive`, you can manipulate the underlying channel directly.
- `close`: attempt to shutdown the adapter.
"""
abstract type ProtocolAdapter end

get_output_channel(adp::ProtocolAdapter) = adp.output_channel
receive(adp::ProtocolAdapter) = take!(get_output_channel(adp))

const sync_id_counter = Ref(0)
get_sync_id() = string(sync_id_counter[] += 1)


"A command object suitable for both adapters."
struct GeneralCommand
    command::Symbol
    subCommand::Optional{Symbol}
    content::Any
    method::CommandMethod
end

function make_command(cmd::AbstractCommand)
    GeneralCommand(command(cmd), subcommand(cmd), cmd, method(cmd))
end

struct WebSocketCommand
    syncId::String
    command::Symbol
    subCommand::Optional{Symbol}
    content::Any
end

WebSocketCommand(syncId, cmd::GeneralCommand) = WebSocketCommand(syncId, cmd.command, cmd.subCommand, cmd.content)

StructTypes.StructType(::Type{WebSocketCommand}) = StructTypes.Struct()
StructTypes.omitempties(::Type{WebSocketCommand}) = (:subCommand, :content)

const ExceptionAndBacktrace = Pair{Exception, Union{Base.return_types(catch_backtrace, ())...}}
const OutputChannel = Channel{Union{JSON3.Object, EventOrMessage, ExceptionAndBacktrace}}
const DEFAULT_BUFFER_SIZE = 16

mutable struct WebSocketAdapter <: ProtocolAdapter
    reservedSyncId::String
    input_channel::Channel{WebSocketCommand}
    output_channel::OutputChannel
    output_dict::Dict{String,OutputChannel}
    socket::HTTP.WebSockets.WebSocket
    function WebSocketAdapter(reservedSyncId = "-1")
        new(reservedSyncId, Channel{WebSocketCommand}(DEFAULT_BUFFER_SIZE), OutputChannel(DEFAULT_BUFFER_SIZE), Dict{String,OutputChannel}())
    end
end


function loop(adp::WebSocketAdapter, server, qq, verifyKey)
    url = "ws://$server/message?verifyKey=$verifyKey&qq=$qq"
    HTTP.WebSockets.open(url) do ws
        adp.socket = ws
        hello = JSON3.read(readavailable(ws))
        @assert hasproperty(hello, :data)
        put!(adp.output_channel, hello.data)
        @sync begin
            @async begin
                while !eof(ws)
                    try
                        bytes = readavailable(ws)
                        isempty(bytes) && eof(ws) && break
                        @debug "Received data: $(String(copy(bytes)))"
                        data = JSON3.read(bytes)::JSON3.Object
                        dispatch(adp, data[:syncId], data[:data])
                    catch e
                        put!(adp.output_channel, e => catch_backtrace())
                    end
                end
                # to close all pending tasks
                close(adp.output_channel)
                foreach(close, values(adp.output_dict))
                @info "WebSocket adapter receiver quitted"
            end
            @async begin
                for cmd in adp.input_channel
                    try
                        @debug "Command: $cmd"
                        str = JSON3.write(cmd)
                        @debug "Sending command: $str"
                        write(ws, str)
                    catch e
                        put!(adp.output_channel, e => catch_backtrace())
                    end
                end
                @info "WebSocket adapter sender quitted"
            end
        end
        @info "WebSocket adapter quitted"
    end
end

function with_entry(f, dict::AbstractDict, key, value)
    dict[key] = value
    try
        f()
    finally
        delete!(dict, key)
    end
end

function send(adp::WebSocketAdapter, cmd::GeneralCommand)
    wscmd = WebSocketCommand(get_sync_id(), cmd)
    ret_ch = OutputChannel(0) do ch
        with_entry(adp.output_dict, wscmd.syncId, ch) do
            put!(adp.input_channel, wscmd)
            wait(ch)
        end
    end
    take!(ret_ch)
end

function dispatch(adp::WebSocketAdapter, syncId, data)
    ch = get(adp.output_dict, syncId, nothing)
    if isnothing(ch)
        msg = try_convert(EventOrMessage, data)
        @debug msg
        put!(adp.output_channel, msg)
    else
        put!(ch, data)
    end
end

function Base.close(adp::WebSocketAdapter)
    close(adp.input_channel)
    close(adp.socket)
end

mutable struct HTTPAdapter <: ProtocolAdapter
    server::String
    output_channel::OutputChannel
    sessionKey::String
    closed::Bool
end

HTTPAdapter() = HTTPAdapter("", OutputChannel(DEFAULT_BUFFER_SIZE), "", false)

function loop(adp::HTTPAdapter, server, qq, verifyKey; poll_interval = 1, fetch_count = 8)
    adp.server = server
    # Verify
    resp = post_restful("http://$server/verify", (), (; verifyKey))
    adp.sessionKey = resp[:session]
    # Bind
    resp = post_restful("http://$server/bind", (), (; adp.sessionKey, qq))

    put!(adp.output_channel, resp)
    cmd = fetchLatestMessage(fetch_count)
    while !adp.closed
        data = nothing
        try
            data = send(adp, cmd)::response_type(cmd)
            for msg in data.data
                put!(adp.output_channel, msg)
            end
        catch e
            if isnothing(data)
                put!(adp.output_channel, e => catch_backtrace())
            else
                put!(adp.output_channel, dat)
            end
        end
        sleep(poll_interval)
    end
    close(adp.output_channel)
    resp = post_restful("http://$server/release", (), (; adp.sessionKey, qq))
    @info "HTTP adapter quitted"
end

command_to_path(cmd::GeneralCommand) = replace(string(cmd.command), '_' => '/')


function send(adp::HTTPAdapter, cmd::GeneralCommand)
    url = "http://$(adp.server)/$(command_to_path(cmd))"
    headers = ["sessionKey" => adp.sessionKey]
    resp = if cmd.method == CommandMethods.GET
        get_restful(url, headers, cmd.content)
    elseif cmd.method == CommandMethods.POST
        post_restful(url, headers, cmd.content)
    elseif cmd.method == CommandMethods.UPLOAD
        upload(url, headers, cmd.content)
    end
    resp
end


function Base.close(adp::HTTPAdapter)
    adp.closed = true
end


function post_restful(url, headers, data)
    body = JSON3.write(data)
    json_header = "Content-Type" => "application/json"
    headers = [json_header, headers...]
    @debug "body=$body"
    r = HTTP.post(url, headers, body)
    data = JSON3.read(r.body)
    @debug "response: $(String(r.body))"
    return data
end

function get_restful(url, headers, query)
    query = StructTypes.constructfrom(Dict, query)
    map!(string, values(query))
    @debug "query = $query"
    r = HTTP.get(url, headers; query)
    data = JSON3.read(r.body)
    @debug "response: $(String(r.body))"
    return data
end

function upload(url, headers, form)
    form = StructTypes.constructfrom(Dict, form)
    map!(values(form)) do v
        v isa Union{Integer,Enum} ? string(v) : v
    end
    form = HTTP.Form(form)
    @debug "form = $form"
    r = HTTP.post(url, headers, form)
    ret = JSON3.read(r.body)
    @debug "response: $(String(r.body))"
    ret
end


function try_convert(T, x)
    try
        StructTypes.constructfrom(T, x)
    catch e
        @debug "Error deserializing data" exception = (e, catch_backtrace())
        x
    end
end

struct RESTfulRequestFailed <: Exception
    cmd::AbstractCommand
    code::Int
    msg::String
end

function send(adp::ProtocolAdapter, cmd::AbstractCommand)
    # Otherwise we are flooded by them
    cmd isa AbstractGetMessageCommand || @info "Sending $cmd"
    resp = send(adp, make_command(cmd))
    ret = try_convert(response_type(cmd), resp)
    if response_type(cmd) <: RESTful && hasproperty(ret, :code) && ret.code != 0
        msg = hasproperty(ret, :msg) ? ret.msg : ""
        throw(RESTfulRequestFailed(cmd, ret.code, msg))
    else
        ret
    end
end

end
