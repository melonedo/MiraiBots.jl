module MiraiBots

using HTTP, JSON3, StructTypes


"""
    ProtocolAdapter

Adapter for different protocols that Mirai HTTP API provides.

- `loop`: start sending and receiving. The function blocks, so you would like to call it as `@async loop(...)`.
- `send`: post a message, wait and return the result. Because the adapter need to be initialized, do not send until the first message is received.
- `receive`: wait and retrieve a message. The first message is always session info.
- `get_output_channel`: alternative to `receive`, you can manipulate the underlying channel directly.
- `close`: attempt to shutdown the adapter.
"""
abstract type ProtocolAdapter end

get_output_channel(adp::ProtocolAdapter) = adp.output_channel
receive(adp::ProtocolAdapter) = take!(get_output_channel(adp))

const sync_id_counter = Ref(0)
get_sync_id() = string(sync_id_counter[] += 1)

@enum CommandMethod begin
    GET
    POST
    UPLOAD
end

struct Command
    command::Symbol
    subCommand::Union{Nothing,Symbol}
    content::Any
    method::CommandMethod
end

struct WebSocketCommand
    syncId::String
    command::Symbol
    subCommand::Union{Nothing,Symbol}
    content::Any
end

Command(cmd, content, method) = Command(cmd, nothing, content, method)
WebSocketCommand(cmd::Command) = WebSocketCommand(get_sync_id(), cmd.command, cmd.subCommand, cmd.content)
# WebSocketCommand(cmd::Command) = WebSocketCommand(get_sync_id(), cmd)

# Base.propertynames(cmd::WebSocketCommand) = (:syncId, propertynames(cmd.cmd))
# Base.getproperty(cmd::WebSocketCommand, f::Symbol) = hasfield(typeof(cmd), f) ? getfield(cmd, f) : getfield(cmd.cmd, f)

StructTypes.StructType(::Type{WebSocketCommand}) = StructTypes.Struct()
StructTypes.omitempties(::Type{WebSocketCommand}) = (:subCommand, :content)


const OutputChannel = Channel{JSON3.Object}
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
        @sync begin
            @async while !eof(ws)
                try
                    bytes = readavailable(ws)
                    isempty(bytes) && eof(ws) && break
                    @debug "Received data: $(String(copy(bytes)))"
                    data = JSON3.read(bytes)::JSON3.Object
                    dispatch(adp, data[:syncId], data[:data])
                catch e
                    @error "Error receiving data" exception = (e, catch_backtrace())
                end
            end
            @async for cmd in adp.input_channel
                try
                    @debug "Command: $cmd"
                    str = JSON3.write(cmd)
                    @debug "Sending command: $str"
                    write(ws, str)
                catch e
                    @error "Error sending command" exception = (e, catch_backtrace())
                end
            end
        end
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

function send(adp::WebSocketAdapter, cmd::Command)
    cmd = WebSocketCommand(cmd)
    ret_ch = OutputChannel(0) do ch
        with_entry(adp.output_dict, cmd.syncId, ch) do
            put!(adp.input_channel, cmd)
            wait(ch)
        end
    end
    take!(ret_ch)
end

function dispatch(adp::WebSocketAdapter, syncId, data)
    ch = get(adp.output_dict, syncId, nothing)
    if isnothing(ch)
        put!(adp.output_channel, data)
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

function loop(adp::HTTPAdapter, server, qq, verifyKey; poll_interval = 2, fetch_count = 8)
    adp.server = server
    # Verify
    resp = post_restful("http://$server/verify", (), (; verifyKey))
    adp.sessionKey = resp[:session]
    # Bind
    resp = post_restful("http://$server/bind", (), (; adp.sessionKey, qq))

    put!(adp.output_channel, resp)
    while !adp.closed
        cmd = Command(:fetchMessage, nothing, (; count = fetch_count), GET)
        data = send(adp, cmd)
        for msg in data[:data]
            put!(adp.output_channel, msg)
        end
        @debug "Received data: $data"
        sleep(poll_interval)
    end
end

command_to_path(cmd::Command) = replace(String(cmd.command), '_' => '/')


function send(adp::HTTPAdapter, cmd::Command)
    url = "http://$(adp.server)/$(command_to_path(cmd))"
    headers = ["sessionKey" => adp.sessionKey]
    if cmd.method == GET
        get_restful(url, headers, cmd.content)
    elseif cmd.method == POST
        post_restful(url, headers, cmd.content)
    elseif cmd.method == UPLOAD
        r = HTTP.post(url, headers, HTTP.Form(cmd.content))
        JSON3.read(r)
    end
end


function Base.close(adp::HTTPAdapter)
    adp.closed = true
end


function post_restful(url, headers, data)
    body = JSON3.write(data)
    json_header = "Content-Type" => "application/json"
    headers = [json_header, headers...]
    r = HTTP.post(url, headers, body)
    data = JSON3.read(r.body)
    data[:code] == 0 || @debug data
    @assert data[:code] == 0
    return data
end

function get_restful(url, headers, query)
    r = HTTP.get(url, headers; query)
    data = JSON3.read(r.body)
    data[:code] == 0 || @debug data
    @assert data[:code] == 0
    return data
end

end
