module Events
using ..StructTypes, ..Messages
import ..Optional, ..FriendId, ..GroupOrFriendId, ..GroupId, ..TimeStamp, ..DurationSeconds
import ..MessageId, ..EventId, ..DeviceKind, ..MessageChains.MessageChain, ..EventOrMessage
import ..Messages.SelfOrMember

abstract type AbstractEvent <: EventOrMessage end

abstract type BotLoginEvent <: AbstractEvent end

struct BotOnlineEvent <: BotLoginEvent
    qq::FriendId
end

abstract type BotLogoutEvent <: AbstractEvent end

struct BotOfflineEventActive <: BotLogoutEvent
    qq::FriendId
end

struct BotOfflineEventForce <: BotLogoutEvent
    qq::FriendId
end

struct BotOfflineEventDropped <: BotLogoutEvent
    qq::FriendId
end

struct BotReloginEvent <: BotLoginEvent
    qq::FriendId
end

abstract type FriendStatusEvent <: AbstractEvent end

struct FriendInputStatusChangedEvent <: FriendStatusEvent
    friend::Friend
    inputting::Bool
end

struct FriendNickChangedEvent <: FriendStatusEvent
    friend::Friend
    from::String
    to::String
end


abstract type RecallEvent <: AbstractEvent end

struct GroupRecallEvent <: RecallEvent
    authorId::FriendId
    messageId::MessageId
    time::TimeStamp
    group::Group
    operator::SelfOrMember
end

struct FriendRecallEvent <: RecallEvent
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
import .NudgeKinds.NudgeKind

function StructTypes.construct(::Type{NudgeKind}, s::String; kw...)
    s == "Group" && return NudgeKinds.GROUP
    s == "Friend" && return NudgeKinds.FRIEND
    s == "Stranger" && return NudgeKinds.STRANGER
    error("Unknown subject kind")
end

Base.string(x::NudgeKind) = x == NudgeKinds.GROUP ? "Group" : "Friend"


StructTypes.@Struct struct Subject
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

abstract type GroupEvent <: AbstractEvent end

abstract type GroupStatusChangeEvent <: GroupEvent end

struct GroupNameChangeEvent <: GroupStatusChangeEvent
    origin::String  # original name
    current::String # current name
    group::Group
    operator::SelfOrMember
end

struct GroupEntranceAnnouncementChangeEvent <: GroupStatusChangeEvent
    origin::String
    current::String
    group::Group
    operator::SelfOrMember
end

struct GroupMuteAllEvent <: GroupStatusChangeEvent
    origin::Bool
    current::Bool
    group::Group
    operator::SelfOrMember
end

struct GroupAllowAnonymousChatEvent <: GroupStatusChangeEvent
    origin::Bool
    current::Bool
    group::Group
    operator::SelfOrMember
end

struct GroupAllowConfessTalkEvent <: GroupStatusChangeEvent
    origin::Bool
    current::Bool
    group::Group
    isByBot::Bool
end

struct GroupAllowMemberInviteEvent <: GroupStatusChangeEvent
    origin::Bool
    current::Bool
    group::Group
    operator::SelfOrMember
end

abstract type MemberEvent <: GroupEvent end

struct MemberJoinEvent <: MemberEvent
    member::Member
    invitor::SelfOrMember
end

struct BotJoinGroupEvent <: MemberEvent
    group::Group
    invitor::Union{Nothing,Member}
end

abstract type MemberLeaveEvent <: MemberEvent end

abstract type OtherMemberLeaveEvent <: MemberLeaveEvent end

struct MemberLeaveEventKick <: OtherMemberLeaveEvent
    member::Member
    operator::SelfOrMember
end

# If bot is leaving, see BotLeaveEvent
struct MemberLeaveEventQuit <: OtherMemberLeaveEvent
    member::Member
end

abstract type BotLeaveEvent <: MemberLeaveEvent end

struct BotLeaveEventActive <: BotLeaveEvent
    group::Group
end

struct BotLeaveEventKick <: BotLeaveEvent
    group::Group
    operator::Member
end

abstract type MemberStatusChangeEvent <: MemberEvent end

struct MemberCardChangeEvent <: MemberStatusChangeEvent
    origin::String
    current::String
    group::Group
    member::Member
end

struct MemberSpecialTitleChangeEvent <: MemberStatusChangeEvent
    origin::String
    current::String
    group::Group
    member::Member
end

struct MemberPermissionChangeEvent <: MemberStatusChangeEvent
    origin::Permission
    current::Permission
    group::Group
    member::Member
end

struct BotGroupPermissionChangeEvent <: MemberStatusChangeEvent
    origin::Permission
    current::Permission
    group::Group
end

struct MemberMuteEvent <: MemberStatusChangeEvent
    durationSeconds::DurationSeconds
    member::Member
    operator::SelfOrMember
end

struct MemberUnmuteEvent <: MemberStatusChangeEvent
    member::Member
    operator::SelfOrMember
end

struct BotMuteEvent <: MemberStatusChangeEvent
    durationSeconds::DurationSeconds
    operator::Member
end

struct BotUnmuteEvent <: MemberStatusChangeEvent
    oprerator::Member
end

module Actions
@enum Action achieve lose
end
import .Actions.Action

struct MemberHonorChangeEvent <: MemberStatusChangeEvent
    member::Member
    action::Action
    honor::String
end

abstract type RequestEvent <: AbstractEvent end

struct NewFriendRequestEvent <: RequestEvent
    eventId::EventId
    fromId::FriendId
    groupId::GroupId
    nick::String
    message::String
end

struct MemberJoinRequestEvent <: RequestEvent
    eventId::EventId
    fromId::FriendId # applyer
    groupId::GroupId
    groupName::String
    nick::String
    message::String
end

struct BotInvitedJoinGroupRequestEvent <: RequestEvent
    eventId::EventId
    fromId::FriendId # invitor
    groupId::GroupId
    groupName::String
    nick::String
    message::String
end

abstract type OtherClientEvent <: AbstractEvent end

struct OtherClientOnlineEvent <: OtherClientEvent
    client::Platform
    kind::Optional{DeviceKind}
end

struct OtherClientOfflineEvent <: OtherClientEvent
    client::Platform
end

struct CommandExecutedEvent <: AbstractEvent
    eventId::Optional{Int}   # Inconsistent documentation here
    name::String
    friend::Optional{Friend} # Nothing if sent from console
    member::Optional{Member} # Nothing if sent from console
    args::MessageChain
end

"""
    ProtocolAdapterConnected

This event is broadcasted by the `Broadcaster` when the protocol adapter is fully launched.
"""
struct ProtocolAdapterConnected <: AbstractEvent end


const event_types = (; BotOnlineEvent, BotReloginEvent, BotOfflineEventActive, BotOfflineEventDropped,
    BotOfflineEventForce, CommandExecutedEvent, FriendInputStatusChangedEvent, FriendNickChangedEvent,
    BotMuteEvent, BotUnmuteEvent, GroupAllowAnonymousChatEvent, GroupAllowConfessTalkEvent,
    GroupAllowMemberInviteEvent, GroupEntranceAnnouncementChangeEvent, GroupMuteAllEvent,
    GroupNameChangeEvent, BotJoinGroupEvent, MemberJoinEvent, BotLeaveEventActive, BotLeaveEventKick,
    MemberLeaveEventKick, MemberLeaveEventQuit, BotGroupPermissionChangeEvent, MemberCardChangeEvent,
    MemberHonorChangeEvent, MemberMuteEvent, MemberPermissionChangeEvent, MemberSpecialTitleChangeEvent,
    MemberUnmuteEvent, NudgeEvent, OtherClientOfflineEvent, OtherClientOnlineEvent, FriendRecallEvent,
    GroupRecallEvent, BotInvitedJoinGroupRequestEvent, MemberJoinRequestEvent, NewFriendRequestEvent,
    FriendMessage, GroupMessage, OtherClientMessage, StrangerMessage, TempMessage)


for n in keys(event_types)
    @eval export $n
end

export NudgeKinds, NudgeKind, Actions, Action

end
