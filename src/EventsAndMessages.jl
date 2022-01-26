

abstract type EventOrMessage end

abstract type AbstractEvent <: EventOrMessage end

abstract type AbstractMessage <: EventOrMessage end


struct Friend
    id::Int
    nickname::String
    remark::String
end

@enum Permission begin
    OWNER
    ADMINISTRATOR
    MEMBER
end

struct Group
    id::Int
    name::String
    permission::Permission
end

struct Member
    id::Int
    memberName::String
    specialTitle::String
    permission::Permission
    joinTimestamp::Int
    lastSpeakTimestamp::Int
    muteTimeRemaining::Int
    group::Group
end

struct Platform
    id::Int
    platform::String
end


struct FriendMessage <: AbstractMessage
    sender::Friend
    messageChain::MessageChain
end

struct GroupMessage <: AbstractMessage
    sender::Member
    messageChain::MessageChain
end

struct TempMessage <: AbstractMessage
    sender::Member
    messageChain::MessageChain
end

struct StrangerMessage <: AbstractMessage
    sender::Friend
    messageChain::MessageChain
end

struct OtherClientMessage <: AbstractMessage
    sender::Platform
    messageChain::MessageChain
end

struct BotOnlineEvent <: AbstractEvent
    qq::Int
end

struct BotOfflineEventActive <: AbstractEvent
    qq::Int
end

struct BotOfflineEventForce <: AbstractEvent
    qq::Int
end

struct BotOfflineEventDropped <: AbstractEvent
    qq::Int
end

struct BotReloginEvent <: AbstractEvent
    qq::Int
end

struct FriendInputStatusChangedEvent <: AbstractEvent
    friend::Friend
    inputting::Bool
end

struct FriendNickChangedEvent <: AbstractEvent
    friend::Friend
    from::String
    to::String
end

struct BotGroupPermissionChangeEvent <: AbstractEvent
    origin::Permission
    current::Permission
    group::Group
end

struct BotMuteEvent <: AbstractEvent
    durationSeconds::Int
    operator::Member
end

struct BotUnmuteEvent <: AbstractEvent
    oprerator::Member
end

struct BotJoinGroupEvent <: AbstractEvent
    group::Group
    invitor::Union{Nothing,Member}
end

struct BotLeaveEventActive <: AbstractEvent
    group::Group
end

struct BotLeaveEventKick <: AbstractEvent
    group::Group
    operator::Member
end

struct GroupRecallEvent <: AbstractEvent
    authorId::Int
    messageId::Int
    time::Int
    group::Group
    operator::Member
end

struct FriendRecallEvent <: AbstractEvent
    authoerId::Int
    messageId::Int
    time::Int
    operator::Int
end

@enum NudgeKind begin
    GROUP
    FRIEND
    STRANGER
end

function StructTypes.construct(::Type{NudgeKind}, s::String; kw...)
    s == "Group" && return GROUP
    s == "Friend" && return FRIEND
    s == "Stranger" && return STRANGER
    error("Unknown subject kind")
end

Base.string(x::NudgeKind) = x == GROUP ? "Group" : "Friend"


struct Subject
    id::Int
    kind::NudgeKind
end

struct NudgeEvent <: AbstractEvent
    fromId::Int
    subject::Subject
    action::String
    suffix::String
    target::Int
end

# TO BE CONTINUED...

const message_types = (; FriendMessage, GroupMessage, OtherClientMessage, StrangerMessage, TempMessage)

const event_types = (; BotGroupPermissionChangeEvent, BotJoinGroupEvent, BotLeaveEventActive, BotLeaveEventKick,
    BotMuteEvent, BotOfflineEventActive, BotOfflineEventDropped, BotOfflineEventForce,
    BotOnlineEvent, BotReloginEvent, BotUnmuteEvent, FriendInputStatusChangedEvent,
    FriendNickChangedEvent, FriendRecallEvent, GroupRecallEvent, NudgeEvent)

StructTypes.StructType(::Type{<:EventOrMessage}) = StructTypes.Struct()
StructTypes.StructType(::Type{EventOrMessage}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{EventOrMessage}) = :type
StructTypes.subtypes(::Type{EventOrMessage}) = (; event_types..., message_types...)

StructTypes.StructType(::Type{<:Union{Friend,Group,Member,Subject}}) = StructTypes.Struct()
