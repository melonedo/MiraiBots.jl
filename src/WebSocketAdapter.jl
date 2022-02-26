struct WebSocketCommand
    syncId::String
    command::Symbol
    subCommand::Optional{Symbol}
    content::Any
end

WebSocketCommand(syncId, cmd::GeneralCommand) = WebSocketCommand(syncId, cmd.command, cmd.subCommand, cmd.content)

StructTypes.StructType(::Type{WebSocketCommand}) = StructTypes.Struct()
StructTypes.omitempties(::Type{WebSocketCommand}) = (:subCommand, :content)

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
                    with_catch_backtrace(adp.output_channel) do
                        bytes = readavailable(ws)
                        isempty(bytes) && eof(ws) && return
                        @debug "Received data: $(String(copy(bytes)))"
                        data = JSON3.read(bytes)::JSON3.Object
                        dispatch(adp, data[:syncId], data[:data])
                    end
                end
                # to close all pending tasks
                close(adp.output_channel)
                foreach(close, values(adp.output_dict))
                @info "WebSocket adapter receiver quitted"
            end
            @async begin
                for cmd in adp.input_channel
                    with_catch_backtrace(adp.output_channel) do
                        @debug "Command: $cmd"
                        str = JSON3.write(cmd)
                        @debug "Sending command: $str"
                        write(ws, str)
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

function send(adp::WebSocketAdapter, cmd::GeneralCommand; session_key_position)
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
