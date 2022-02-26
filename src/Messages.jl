module Messages
using ..StructTypes
import ..Optional, ..FriendId, ..GroupOrFriendId, ..GroupId, ..TimeStamp, ..DurationSeconds
import ..MessageId, ..EventId, ..DeviceKind, ..MessageChains.MessageChain, ..EventOrMessage

abstract type AbstractMessage <: EventOrMessage end

StructTypes.@Struct struct Friend
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
import .Permissions.Permission

StructTypes.@Struct struct Group
    id::GroupId
    name::String
    permission::Permission
end

StructTypes.@Struct struct Member
    id::FriendId
    memberName::String
    specialTitle::Optional{String}
    permission::Permission
    joinTimestamp::Optional{TimeStamp}
    lastSpeakTimestamp::Optional{TimeStamp}
    muteTimeRemaining::Optional{DurationSeconds}
    group::Group
end

"`nothing` if operated by self, otherwise the operator"
const SelfOrMember = Optional{Member}

StructTypes.@Struct struct Platform
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

const message_types = (; FriendMessage, GroupMessage, OtherClientMessage, StrangerMessage, TempMessage)

for n in keys(message_types)
    @eval export $n
end

export Friend, Group, Member, Platform, Subject, Permissions, Permission

end
