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

include("Broadcaster.jl")

get_output_channel(adp::ProtocolAdapter) = adp.output_channel
receive(adp::ProtocolAdapter) = take!(get_output_channel(adp))

const sync_id_counter = Ref(0)
get_sync_id() = string(sync_id_counter[] += 1)


"A command object suitable for both adapters."
struct GeneralCommand{T}
    command::Symbol
    subCommand::Optional{Symbol}
    content::T
    method::CommandMethod
end

function make_command(cmd::AbstractCommand)
    GeneralCommand(command(cmd), subcommand(cmd), cmd, method(cmd))
end


struct ExceptionAndBacktrace
    exception::Exception
    backtrace::Union{Base.return_types(catch_backtrace, ())...}
end

const OutputChannel = Channel{Union{JSON3.Object,EventOrMessage,ExceptionAndBacktrace}}
const DEFAULT_BUFFER_SIZE = 16

include("WebSocketAdapter.jl")
include("AbstractHTTPAdapter.jl")
include("HTTPAdapter.jl")
include("HTTPCompatAdapter.jl")

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

function send(adp::ProtocolAdapter, cmd::AbstractCommand, response_type_func = response_type; session_key_position::SessionKeyPosition = SESSION_KEY_IN_HEADERS)
    # Otherwise we are flooded by them
    cmd isa AbstractGetMessageCommand || @info "Sending $cmd"
    resp = send(adp, make_command(cmd); session_key_position)
    ret = try_convert(response_type_func(cmd), resp)
    if response_type_func(cmd) <: RESTful && hasproperty(ret, :code) && ret.code != 0
        msg = hasproperty(ret, :msg) ? ret.msg : ""
        throw(RESTfulRequestFailed(cmd, ret.code, msg))
    else
        ret
    end
end

end
