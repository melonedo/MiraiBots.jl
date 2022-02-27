abstract type HTTPAdapterBase <: ProtocolAdapter end


function loop_body(adp::HTTPAdapterBase, qq, poll_interval, fetch_count, response_type_func, session_key_position)
    cmd = Commands.fetchLatestMessage(fetch_count)
    while !adp.closed
        data = nothing
        try
            data = send(adp, cmd; session_key_position, log=false)::response_type_func(cmd)
            for msg in data.data
                put!(adp.output_channel, msg)
            end
        catch e
            if isnothing(data)
                put!(adp.output_channel, ExceptionAndBacktrace(e, catch_backtrace()))
            else
                put!(adp.output_channel, dat)
            end
        end
        sleep(poll_interval)
    end
    close(adp.output_channel)
    resp = post_restful("http://$(adp.server)/release", (), (; adp.sessionKey, qq))
    @info "HTTP adapter quitted"
end


struct EmbedSessionKey{T}
    sessionKey::String
    data::T
end

StructTypes.StructType(::Type{<:EmbedSessionKey}) = StructTypes.DictType()

@generated function StructTypes.keyvaluepairs(x::EmbedSessionKey{T}) where T
    fields = (:(x.data.$f) for f in fieldnames(T))
    quote
        pairs((; x.sessionKey, $(fields...)))
    end
end


@enum SessionKeyPosition begin
    SESSION_KEY_IN_HEADERS
    SESSION_KEY_IN_BODY
end


command_to_path(cmd::GeneralCommand) = replace(string(cmd.command), '_' => '/')

function send(adp::HTTPAdapterBase, cmd::GeneralCommand; session_key_position::SessionKeyPosition)
    url = "http://$(adp.server)/$(command_to_path(cmd))"
    if session_key_position == SESSION_KEY_IN_HEADERS
        headers = ["sessionKey" => adp.sessionKey]
    else
        headers = []
    end
    if session_key_position == SESSION_KEY_IN_BODY
        body = EmbedSessionKey(adp.sessionKey, cmd.content)
    else
        body = cmd.content
    end
    resp = if cmd.method == Commands.CommandMethods.GET
        get_restful(url, headers, body)
    elseif cmd.method == Commands.CommandMethods.POST
        post_restful(url, headers, body)
    elseif cmd.method == Commands.CommandMethods.UPLOAD
        upload(url, headers, body)
    end
    resp
end


function Base.close(adp::HTTPAdapterBase)
    adp.closed = true
end


function post_restful(url, headers, data)
    body = JSON3.write(data)
    json_header = "Content-Type" => "application/json"
    headers = [json_header, headers...]
    @debug "body = $body"
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
