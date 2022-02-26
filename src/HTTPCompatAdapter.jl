"""
    HTTPCompatAdapter <: ProtocolAdapter

An adapter that works for HTTP API v1.x.
"""
mutable struct HTTPCompatAdapter <: AbstractHTTPAdapter
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
    @assert resp[:code] == 0

    put!(adp.output_channel, resp)
    loop_body(adp, qq, poll_interval, fetch_count, response_type_compat, SESSION_KEY_IN_BODY)
end


response_type_compat(msg) = response_type(msg)


function send(adp::HTTPCompatAdapter, cmd::AbstractCommand; session_key_position::SessionKeyPosition = SESSION_KEY_IN_BODY)
    send(adp, cmd, response_type_compat; session_key_position)
end
