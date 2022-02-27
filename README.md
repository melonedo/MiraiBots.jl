# MiraiBots

[mirai-api-http](https://github.com/project-mirai/mirai-api-http)的Julia接口，通过[HTTP](https://github.com/JuliaWeb/HTTP.jl)监听，并利用[JSON3](https://github.com/quinnj/JSON3.jl)实现序列化，将消息对应到结构体。

支持mirai-api-http v2的HTTP和WebSocket接口，分别对应`HTTPAdapter`和`WebSocketAdapter`。同时`HTTPCompatAdapter`支持mirai-api-http v1的HTTP接口。

## 设计

### 顶层API

顶层的API收发普通的Julia结构体，接口是`register(callbck, broadcaster)`和`send(adapter, command)`。各种类型的结构体（命令、消息、事件等）及各部分的含义参考[mirai-api-http的WebsocketAdapter接口](https://github.com/project-mirai/mirai-api-http/blob/v2.4.0/docs/adapter/WebsocketAdapter.md)。

- `register(callback, broadcaster::Broadcaster)`: 在广播器中记录一个回调函数，这个函数会在mirai收到对应类型的参数时调用，给出的参数是用于`send`的接口适配器以及对应的事件或消息。
- `send(adapter::ProtocolAdapter, command::Commands.AbstractCommand)`：通过接口适配器（`ProtocolAdapter`）向mirai发送一条命令，并将收到的回复转换为对应的Julia类型。

### 底层API

发送消息时，`send(adapter, command::Commands.AbstractCommand)`给命令补上各接口适配器都通用的请求信息，构造`GeneralCommand`。`GeneralCommand`被传给`send(adapter, command::GeneralCommand)`，根据不同的接口适配器的要求，将根据对应的信息将命令序列化为JSON、表单或query string。序列化后的消息将通过接口适配器要求的方法传输到mirai。

接口适配器在发送消息的回复直接以`JSON3.Object`形式返回。`send(adapter, command::Commands.AbstractCommand)`收到JSON对象后反序列化。反序列化的类型由命令决定，用`response_type`（或`response_type_compat`）计算。

HTTP协议的接口适配器发送的过程比较简单，只需要根据数据的类型选择正确的方法发送到mirai即可。而WebSocket接口是异步回复的，但我们希望`send`是同步的，因此发送比较复杂。WebSocket的协议的回复消息中包含一个`syncId`成员用于指示回复的对象。因此在发送时会将每条命令的`syncId`的值存入一个字典中，以便在收到回复时做出对应的操作。本库在发送时构造一个`Channel`用于接收回复，并等待这个`Channel`被填充。接口适配器会在收到回复时根据`syncId`向对应的`Channel`发送回复，`send`收到这个回复后才会返回。

## 示例

### 广播器示例

```julia
using MiraiBots, MiraiBots.Messages, MiraiBots.Events, MiraiBots.MessageChains
using MiraiBots: Commands, send
broadcaster = MiraiBots.Broadcaster(MiraiBots.HTTPAdapter())
# 匿名函数
MiraiBots.register(broadcaster) do bot, msg::FriendMessage
    chain = msg.messageChain
    send(bot, Commands.sendFriendMessage(
        target = msg.sender.id, quoteId = chain[1].id, 
        messageChain = chain[2:end])) |> println
    throw(MiraiBots.ShutdownBroadcaster())
end
# 命名函数
register(f) = MiraiBots.register(f, broadcaster)
function logger(bot, msg)
    @info "$(now()): $msg"
end |> register
# 启动
MiraiBots.launch(broadcaster, server, qq, key)
```

### 不用广播器示例

```julia
using MiraiBots, MiraiBots.Messages, MiraiBots.Events, MiraiBots.MessageChains
using MiraiBots: Commands, send
bot = MiraiBots.HTTPAdapter()
@sync begin
    @async MiraiBots.loop(bot, server, qq, key)
    # 需等待首条消息才算连接到HTTP API
    MiraiBots.receive_or_throw(bot)

    @async for msg in MiraiBots.get_output_channel(bot)
        if msg isa MiraiBots.ExceptionAndBacktrace
            @error "Error occurred in adapter" exception = (msg.exception, msg.backtrace)
        elseif msg isa FriendMessage
            chain = msg.messageChain
            send(bot, Commands.sendFriendMessage(
                target = msg.sender.id, quoteId = chain[1].id, 
                messageChain = chain[2:end])) |> println
        elseif msg isa NewFriendRequestEvent
            send(bot, Commands.resp_newFriendRequestEvent(
                eventId = msg.eventId, fromId = msg.fromId, groupId = msg.groupId, 
                operate = Commands.NewFriendOperations.REFUSE, message = "sorry~"))
        else
            @show msg
        end
    end

    sleep(10)
    close(bot)
end
```
