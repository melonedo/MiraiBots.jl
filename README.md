# MiraiBots

[mirai-api-http](https://github.com/project-mirai/mirai-api-http)的Julia接口，通过[HTTP](https://github.com/JuliaWeb/HTTP.jl)监听，并利用[JSON3](https://github.com/quinnj/JSON3.jl)实现序列化，将消息对应到结构体。

## Broadcaster示例

```julia
using MiraiBots
broadcaster = MiraiBots.Broadcaster(MiraiBots.HTTPAdapter())
# 匿名函数
MiraiBots.register(broadcaster) do bot, msg::MiraiBots.FriendMessage
    chain = msg.messageChain
    MiraiBots.send(bot, MiraiBots.sendFriendMessage(target = msg.sender.id, quoteId = chain[1].id, messageChain = chain[2:end])) |> println
    throw(MiraiBots.ShutDownBroadcaster())
end
# 命名函数
register(f) = MiraiBots.register(f, broadcaster)
function logger(bot, msg)
    @info "$(now()): $msg"
end |> register
# 启动
MiraiBots.launch(broadcaster, server, qq, key)
```

## 不用Broadcaster示例

```julia
using MiraiBots
# 或 bot = MiraiBots.WebSocketAdapter()
bot = MiraiBots.HTTPAdapter()
@sync begin
    @async MiraiBots.loop(bot, server, qq, key)
    # 需等待首条消息才算连接到HTTP API
    MiraiBots.receive(bot)

    @async for msg in MiraiBots.get_output_channel(bot)
        if msg isa MiraiBots.ExceptionAndBacktrace
            @error "Error occurred in adapter" exception = (msg.exception, msg.backtrace)
        elseif msg isa MiraiBots.FriendMessage
            chain = msg.messageChain
            MiraiBots.send(bot, MiraiBots.sendFriendMessage(target = msg.sender.id, quoteId = chain[1].id, messageChain = chain[2:end])) |> println
        elseif msg isa MiraiBots.NewFriendRequestEvent
            MiraiBots.send(bot, MiraiBots.resp_newFriendRequestEvent(eventId = msg.eventId, fromId = msg.fromId, groupId = msg.groupId, operate = MiraiBots.NewFriendOperations.REFUSE, message = "sorry~"))
        else
            @show msg
        end
    end

    sleep(10)
    close(bot)
end
```
