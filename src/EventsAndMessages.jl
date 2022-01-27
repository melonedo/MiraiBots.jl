

abstract type EventOrMessage end

abstract type AbstractEvent <: EventOrMessage end

abstract type AbstractMessage <: EventOrMessage end


struct Friend
    id::FriendId
    nickname::String
    remark::String
end

module Permissions
@enum Permission begin
    OWNER
    ADMINISTRATOR
    MEMBER
end
end
const Permission = Permissions.Permission

struct Group
    id::GroupId
    name::String
    permission::Permission
end

struct Member
    id::FriendId
    memberName::String
    specialTitle::String
    permission::Permission
    joinTimestamp::TimeStamp
    lastSpeakTimestamp::TimeStamp
    muteTimeRemaining::DurationSeconds
    group::Group
end

struct Platform
    id::Int # What is this?
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
    qq::FriendId
end

struct BotOfflineEventActive <: AbstractEvent
    qq::FriendId
end

struct BotOfflineEventForce <: AbstractEvent
    qq::FriendId
end

struct BotOfflineEventDropped <: AbstractEvent
    qq::FriendId
end

struct BotReloginEvent <: AbstractEvent
    qq::FriendId
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
    durationSeconds::DurationSeconds
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
    authorId::FriendId
    messageId::MessageId
    time::TimeStamp
    group::Group
    operator::Member
end

struct FriendRecallEvent <: AbstractEvent
    authorId::FriendId
    messageId::MessageId
    time::TimeStamp
    operator::FriendId
end

module NudgeKinds
@enum NudgeKind begin
    GROUP
    FRIEND
    STRANGER
end
end
const NudgeKind = NudgeKinds.NudgeKind

function StructTypes.construct(::Type{NudgeKind}, s::String; kw...)
    s == "Group" && return NudgeKinds.GROUP
    s == "Friend" && return NudgeKinds.FRIEND
    s == "Stranger" && return NudgeKinds.STRANGER
    error("Unknown subject kind")
end

Base.string(x::NudgeKind) = x == NudgeKinds.GROUP ? "Group" : "Friend"


struct Subject
    id::GroupOrFriendId
    kind::NudgeKind
end

struct NudgeEvent <: AbstractEvent
    fromId::FriendId
    subject::Subject
    action::String
    suffix::String
    target::FriendId
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
