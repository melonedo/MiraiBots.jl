mutable struct HTTPAdapter <: HTTPAdapterBase
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
    @assert resp[:code] == 0

    put!(adp.output_channel, resp)
    loop_body(adp, qq, poll_interval, fetch_count, Commands.response_type, SESSION_KEY_IN_HEADERS)
end
