"""
    HTTPCompatAdapter <: ProtocolAdapter

An adapter that works for HTTP API v1.x.
"""
mutable struct HTTPCompatAdapter <: HTTPAdapterBase
    server::String
    output_channel::OutputChannel
    sessionKey::String
    closed::Bool
end


HTTPCompatAdapter() = HTTPCompatAdapter("", OutputChannel(DEFAULT_BUFFER_SIZE), "", false)


function loop(adp::HTTPCompatAdapter, server, qq, authKey; poll_interval = 1, fetch_count = 8)
    adp.server = server
    # Verify
    resp = post_restful("http://$server/auth", (), (; authKey))
    adp.sessionKey = resp[:session]
    # Bind
    resp = post_restful("http://$server/verify", (), (; adp.sessionKey, qq))
    resp[:code] == 0 || throw(AdapterConectionFailed(resp[:code], resp[:msg]))

    put!(adp.output_channel, resp)
    loop_body(adp, qq, poll_interval, fetch_count, Commands.response_type_compat, SESSION_KEY_IN_BODY)
end


Commands.response_type_compat(msg) = Commands.response_type(msg)


function send(adp::HTTPCompatAdapter, cmd::Commands.AbstractCommand; kwarg...)
    send(adp, cmd, Commands.response_type_compat; kwarg..., session_key_position = SESSION_KEY_IN_BODY)
end


is_adapter_compatibile(::HTTPCompatAdapter, version) = version.major == 1
