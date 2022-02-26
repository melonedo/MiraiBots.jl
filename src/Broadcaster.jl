
"""
    Broadcaster

A broadcaster that calls all of the registered functions.

- `register`: add a function to the list of functions to be called.
- `broadcast`: call `f(adapter, msg_or_event)` for all of registered functions if `applicable`.
- `launch`: launch the adapter and start broadcasting messages.
"""
struct Broadcaster{Adapter<:ProtocolAdapter}
    adapter::Adapter
    methods::Vector{Any}
end
Broadcaster(adp::ProtocolAdapter) = Broadcaster(adp, [])

function register(f, b::Broadcaster)
    push!(b.methods, f)
end

struct ShutDownBroadcaster <: Exception end

"""
    broadcast(b::Broadcast, msg)

Call `f(adapter, msg_or_event)` for all of registered functions if `applicable`, return if `ShutDownBroadcaster` is thrown from any of the callback functions.
"""
function broadcast(b::Broadcaster, msg)
    args = b.adapter, msg
    for f in b.methods
        applicable(f, args...) || continue
        try
            f(args...)
        catch e
            if e isa ShutDownBroadcaster
                return false
            else
                @error "Error occurred executing broadcaster callbacks" exception = (e, catch_backtrace())
            end
        end
    end
    return true
end


function launch(b::Broadcaster, server, qq, key; check_version = true, kwargs...)
    @sync begin
        @async with_catch_backtrace(get_output_channel(b.adapter)) do
            MiraiBots.loop(b.adapter, server, qq, key; kwargs...)
        end
        check_version && @assert check_adapter_compatibility(b)
        receive_or_throw(b.adapter)
        @info "Adapter is connected to mirai."
        handle_message(b, Events.ProtocolAdapterConnected())
        for msg in get_output_channel(b.adapter)
            handle_message(b, msg)
        end
    end
end


function handle_message(bot, msg)
    if msg isa MiraiBots.ExceptionAndBacktrace
        @error "Error occurred in adapter" exception = (msg.exception, msg.backtrace)
    else
        broadcast(bot, msg) || close(bot.adapter)
    end
end


function check_adapter_compatibility(b)
    resp = send(b.adapter, Commands.about())
    is_adapter_compatibile(b.adapter, resp.data.version)
end

is_adapter_compatibile(::ProtocolAdapter, version) = version.major == 2
