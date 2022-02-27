using Test
using MiraiBots, MiraiBots.Messages, MiraiBots.Events, MiraiBots.MessageChains, MiraiBots.Commands
using MiraiBots: send, Commands
using Dates
using JSON3

(; qq, key, server, image_url) = open(JSON3.read, "config.json")

# ENV["JULIA_DEBUG"] = MiraiBots

@testset "No Broadcaster" begin
    using MiraiBots, MiraiBots.Messages, MiraiBots.Events, MiraiBots.MessageChains
    using MiraiBots: Commands, send
    bot = MiraiBots.WebSocketAdapter()
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
                    messageChain = chain[2:end]))
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
end


@testset "Broadcaster" begin
    broadcaster = MiraiBots.Broadcaster(MiraiBots.HTTPAdapter())
    # 匿名函数
    MiraiBots.register(broadcaster) do bot, msg::FriendMessage
        chain = msg.messageChain
        send(bot, Commands.sendFriendMessage(target = msg.sender.id, quoteId = chain[1].id, messageChain = chain[2:end]))
        throw(MiraiBots.ShutdownBroadcaster())
    end
    # 命名函数
    register(f) = MiraiBots.register(f, broadcaster)
    function logger(_, msg)
        @info "$(now()): $msg"
    end |> register

    function respond_image(bot, msg::NudgeEvent)
        if msg.subject.kind == Commands.NudgeKinds.FRIEND
            @info 1
            send(bot, Commands.sendFriendMessage(
                target = msg.subject.id,
                messageChain = [Image(url = image_url)]
            ))
        end
    end |> register
    # 启动
    MiraiBots.launch(broadcaster, server, qq, key)
end
