abstract type AbstractCommand end

module CommandMethods
@enum CommandMethod begin
    GET
    POST
    UPLOAD
end
end
const CommandMethod = CommandMethods.CommandMethod

command(cmd::AbstractCommand) = typeof(cmd).name.name
subcommand(::AbstractCommand) = nothing

Base.@kwdef struct RESTful{T}
    code::Int
    msg::String
    data::T
end

StructTypes.@Struct struct VersionResponse
    version::VersionNumber
end

struct about <: AbstractCommand end
method(::about) = CommandMethods.GET
response_type(::about) = RESTful{VersionResponse}

struct messageFromId <: AbstractCommand
    id::Int
end
method(::messageFromId) = CommandMethods.GET
response_type(::messageFromId) = RESTful{MessageChain}

abstract type AbstractListCommand <: AbstractCommand end
method(::AbstractListCommand) = CommandMethods.GET

Base.@kwdef struct friendList <: AbstractListCommand end
response_type(::friendList) = RESTful{Vector{Friend}}

Base.@kwdef struct groupList <: AbstractListCommand end
response_type(::groupList) = RESTful{Vector{Group}}

Base.@kwdef struct memberList <: AbstractListCommand end
response_type(::memberList) = RESTful{Vector{Member}}

module Sexes
@enum Sex begin
    UNKNOWN
    MALE
    FEMALE
end
end
const Sex = Sexes.Sex

StructTypes.@Struct struct Profile <: AbstractCommand
    nickname::String
    email::String
    age::Int
    level::Int
    sign::String
    sex::Sex
end

abstract type AbstractGetProfileCommand <: AbstractCommand end
method(::AbstractGetProfileCommand) = CommandMethods.GET
response_type(::AbstractGetProfileCommand) = Profile

Base.@kwdef struct botProfile <: AbstractGetProfileCommand end

Base.@kwdef struct friendProfile <: AbstractGetProfileCommand
    target::FriendId
end

Base.@kwdef struct memberProfile <: AbstractGetProfileCommand
    target::GroupId   # group id
    memberId::FriendId # member qq
end

StructTypes.@Struct struct MessageIdResponse
    code::Int
    msg::String
    messageId::MessageId
end

abstract type AbstractMessagingCommand <: AbstractCommand end
method(::AbstractMessagingCommand) = CommandMethods.POST
response_type(::AbstractMessagingCommand) = MessageIdResponse

Base.@kwdef struct sendFriendMessage <: AbstractMessagingCommand
    target::Optional{FriendId} = nothing
    qq::Optional{FriendId} = nothing # Choose one between target and qq
    quoteId::Optional{MessageId} = nothing
    messageChain::MessageChain
end

Base.@kwdef struct sendGroupMessage <: AbstractMessagingCommand
    target::Optional{GroupId} = nothing
    group::Optional{GroupId} = nothing # Choose one between target and group
    quoteId::Optional{MessageId} = nothing
    messageChain::MessageChain
end

Base.@kwdef struct sendTempMessage <: AbstractMessagingCommand
    qq::FriendId
    group::GroupId
    quoteId::Optional{MessageId} = nothing
    messageChain::MessageChain
end

Base.@kwdef struct sendNudge <: AbstractMessagingCommand
    target::FriendId  # target qq
    subject::GroupOrFriendId # group or friend id
    kind::NudgeKind
end
response_type(::sendNudge) = RESTful{Nothing}

Base.@kwdef struct recall <: AbstractMessagingCommand
    target::MessageId
end
response_type(::recall) = RESTful{Nothing}

abstract type AbstractFileCommand <: AbstractCommand end
method(::AbstractFileCommand) = CommandMethods.POST

StructTypes.@Struct struct DownloadInfo
    sha1::String
    md5::String
    downloadTimes::Int
    uploaderId::FriendId
    uploadTime::TimeStamp
    lastModifyTime::TimeStamp
    url::String
end

StructTypes.@Struct struct FileInfo
    name::String
    id::Optional{String} # Empty for root
    path::String
    parent::Optional{FileInfo}
    contact::Union{Group,Friend}
    isFile::Bool
    isDirectory::Bool
    size::Int
    downloadInfo::Optional{DownloadInfo}
end

Base.@kwdef struct file_list <: AbstractFileCommand
    id::String # folder id
    path::Optional{String} = nothing # folder name
    target::Optional{GroupOrFriendId} = nothing
    group::Optional{GroupId} = nothing
    qq::Optional{FriendId} = nothing
    withDownloadInfo::Bool = false
    offset::Optional{Int} = 1 # page number
    size::Optional{Int} = 10  # page size
end
response_type(::file_list) = RESTful{Vector{FileInfo}}
method(::file_list) = CommandMethods.GET

Base.@kwdef struct file_info <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{GroupOrFriendId} = nothing
    group::Optional{GroupId} = nothing
    qq::Optional{FriendId} = nothing
    withDownloadInfo::Bool = false
end
response_type(::file_info) = RESTful{FileInfo}
method(::file_info) = CommandMethods.GET

Base.@kwdef struct file_mkdir <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{GroupOrFriendId} = nothing
    group::Optional{GroupId} = nothing
    qq::Optional{FriendId} = nothing
    directoryName::String
end
response_type(::file_mkdir) = RESTful{FileInfo}

Base.@kwdef struct file_delete <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{GroupOrFriendId} = nothing
    group::Optional{GroupId} = nothing
    qq::Optional{FriendId} = nothing
end
response_type(::file_delete) = RESTful{Nothing}

Base.@kwdef struct file_move <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{GroupOrFriendId} = nothing
    group::Optional{GroupId} = nothing
    qq::Optional{FriendId} = nothing
    moveTo::Optional{String} # destination folder id
    moveToPath::Optional{String}
end
response_type(::file_move) = RESTful{Nothing}

Base.@kwdef struct file_rename <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{GroupOrFriendId} = nothing
    group::Optional{GroupId} = nothing
    qq::Optional{FriendId} = nothing
    renameTo::String
end
response_type(::file_rename) = RESTful{Nothing}

abstract type AbstractUploadCommand <: AbstractCommand end
method(::AbstractUploadCommand) = CommandMethods.UPLOAD

module UploadTypes
@enum UploadType begin
    FRIEND
    GROUP
    TEMP
end
end
const UploadType = UploadTypes.UploadType

Base.string(x::UploadType) = x == UploadTypes.FRIEND ? "friend" : x == UploadTypes.GROUP ? "group" : "temp"

StructTypes.@Struct struct ImageIdResponse
    imageId::String
    url::String
end

Base.@kwdef struct uploadImage <: AbstractUploadCommand
    type::UploadType
    img::Any
end
response_type(::uploadImage) = ImageIdResponse

StructTypes.@Struct struct VoiceIdResponse
    voiceId::String
    url::String
end

Base.@kwdef struct uploadVoice <: AbstractUploadCommand
    type::UploadType
    voice::Any
end
response_type(::uploadVoice) = VoiceIdResponse

Base.@kwdef struct file_upload <: AbstractUploadCommand
    type::UploadType
    target::GroupOrFriendId
    path::String
    file::Any # What ever that can be used by HTTP.Form
end
response_type(::file_upload) = RESTful{FileInfo}


Base.@kwdef struct deleteFriend <: AbstractCommand
    target::FriendId
end
method(::deleteFriend) = CommandMethods.POST
response_type(::deleteFriend) = RESTful{Nothing}


abstract type AbstractGroupManagementCommand <: AbstractCommand end
method(::AbstractGroupManagementCommand) = CommandMethods.POST
response_type(::AbstractGroupManagementCommand) = RESTful{Nothing}

Base.@kwdef struct mute <: AbstractGroupManagementCommand
    target::GroupId
    memberId::FriendId
    time::TimeStamp # seconds
end

Base.@kwdef struct unmute <: AbstractGroupManagementCommand
    target::GroupId
    memberId::FriendId
end

Base.@kwdef struct kick <: AbstractGroupManagementCommand
    target::GroupId
    memberId::FriendId
    msg::Optional{String} = nothing
end

Base.@kwdef struct quit <: AbstractGroupManagementCommand
    target::GroupId
end

Base.@kwdef struct muteAll <: AbstractGroupManagementCommand
    target::GroupId
end

Base.@kwdef struct unmuteAll <: AbstractGroupManagementCommand
    target::GroupId
end

Base.@kwdef struct setEssence <: AbstractGroupManagementCommand
    target::MessageId
end

Base.@kwdef struct memberAdmin <: AbstractGroupManagementCommand
    target::GroupId
    memberId::FriendId
    assign::Bool
end

Base.@kwdef struct GroupConfig
    name::Optional{String} = nothing # Group name
    announcement::Optional{String} = nothing
    confessTalk::Optional{Bool} = nothing
    allowMemberInvite::Optional{Bool} = nothing
    autoApprove::Optional{Bool} = nothing
    anonymousChat::Optional{Bool} = nothing
end
StructTypes.StructType(::Type{GroupConfig}) = StructTypes.Struct()

Base.@kwdef struct getGroupConfig <: AbstractGroupManagementCommand
    target::GroupId
end
command(::getGroupConfig) = :groupConfig
subcommand(::getGroupConfig) = :get
method(::getGroupConfig) = CommandMethods.GET
response_type(::getGroupConfig) = GroupConfig

Base.@kwdef struct updateGroupConfig <: AbstractGroupManagementCommand
    target::GroupId
    config::GroupConfig
end
command(::updateGroupConfig) = :groupConfig
subcommand(::updateGroupConfig) = :update
method(::updateGroupConfig) = CommandMethods.POST
response_type(::updateGroupConfig) = RESTful{Nothing}

Base.@kwdef struct getMemberInfo <: AbstractGroupManagementCommand
    target::GroupId
    memberId::FriendId
end
command(::getMemberInfo) = :memberInfo
subcommand(::getMemberInfo) = :get
method(::getMemberInfo) = CommandMethods.GET
response_type(::getMemberInfo) = Member

Base.@kwdef struct updateMemberInfo <: AbstractGroupManagementCommand
    target::GroupId
    memberId::FriendId
end
command(::updateMemberInfo) = :memberInfo
subcommand(::updateMemberInfo) = :update
method(::updateMemberInfo) = CommandMethods.POST
response_type(::updateMemberInfo) = RESTful{Nothing}

abstract type AbstractRequestCommand <: AbstractCommand end
method(::AbstractRequestCommand) = CommandMethods.POST
response_type(::AbstractRequestCommand) = RESTful{Nothing}

module NewFriendOperations
const ACCEPT = 0
const REFUSE = 1
const REFUSE_AND_BLACKLIST = 2
end

Base.@kwdef struct resp_newFriendRequestEvent <: AbstractRequestCommand
    eventId::EventId
    fromId::FriendId
    groupId::GroupId # 0 if not from a group
    operate::Int
    message::String
end

module MemberJoinOperations
const ACCEPT = 0
const REFUSE = 1
const IGNORE = 2
const REFUSE_AND_BLACKLIST = 3
const IGNORE_AND_BLACKLIST = 4
end

Base.@kwdef struct resp_memberJoinRequestEvent <: AbstractRequestCommand
    eventId::EventId
    fromId::FriendId
    groupId::GroupId
    operate::Int
    message::String
end

module BotInviteJoinGroupOperations
const ACCEPT = 0
const REFUSE = 1
end

Base.@kwdef struct resp_botInvitedJoinGroupRequestEvent <: AbstractRequestCommand
    eventId::EventId
    fromId::FriendId
    groupId::GroupId
    operate::Int
    message::String
end


abstract type AbstractGetMessageCommand <: AbstractCommand end
method(::AbstractGetMessageCommand) = CommandMethods.GET
response_type(::AbstractGetMessageCommand) = RESTful{Vector{EventOrMessage}}

struct fetchMessage <: AbstractGetMessageCommand
    count::Int
end

struct fetchLatestMessage <: AbstractGetMessageCommand
    count::Int
end

struct peekMessage <: AbstractGetMessageCommand
    count::Int
end

struct peekLatestMessage <: AbstractGetMessageCommand
    count::Int
end

struct countMessage <: AbstractGetMessageCommand end
response_type(::countMessage) = RESTful{Int}


StructTypes.StructType(::Type{<:AbstractCommand}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:RESTful}) = StructTypes.Struct()
StructTypes.names(::Type{<:AbstractMessagingCommand}) = ((:quoteId, :quote),)
StructTypes.omitempties(::Type{<:AbstractMessagingCommand}) = (:target, :qq, :group, :quoteId)
StructTypes.omitempties(::Type{<:AbstractFileCommand}) = (:path, :target, :qq, :group, :offset, :size)
