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
    target::Int
end

Base.@kwdef struct memberProfile <: AbstractGetProfileCommand
    target::Int   # group id
    memberId::Int # member qq
end

StructTypes.@Struct struct MessageIdResponse
    code::Int
    msg::String
    messageId::Int
end

abstract type AbstractMessagingCommand <: AbstractCommand end
method(::AbstractMessagingCommand) = CommandMethods.POST
response_type(::AbstractMessagingCommand) = MessageIdResponse

Base.@kwdef struct sendFriendMessage <: AbstractMessagingCommand
    target::Optional{Int} = nothing
    qq::Optional{Int} = nothing # Choose one between target and qq
    quoteId::Optional{Int} = nothing
    messageChain::MessageChain
end

Base.@kwdef struct sendGroupMessage <: AbstractMessagingCommand
    target::Optional{Int} = nothing
    group::Optional{Int} = nothing # Choose one between target and group
    quoteId::Optional{Int} = nothing
    messageChain::MessageChain
end

Base.@kwdef struct sendTempMessage <: AbstractMessagingCommand
    qq::Int
    group::Int
    quoteId::Optional{Int} = nothing
    messageChain::MessageChain
end

Base.@kwdef struct sendNudge <: AbstractMessagingCommand
    target::Int  # target qq
    subject::Int # group or friend id
    kind::NudgeKind
end
response_type(::sendNudge) = RESTful{Nothing}

Base.@kwdef struct recall <: AbstractMessagingCommand
    target::Int
end
response_type(::recall) = RESTful{Nothing}

abstract type AbstractFileCommand <: AbstractCommand end
method(::AbstractFileCommand) = CommandMethods.POST

StructTypes.@Struct struct DownloadInfo
    sha1::String
    md5::String
    downloadTimes::Int
    uploaderId::Int
    uploadTime::Int
    lastModifyTime::Int
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
    target::Optional{Int} = nothing
    group::Optional{Int} = nothing
    qq::Optional{Int} = nothing
    withDownloadInfo::Bool = false
    offset::Optional{Int} = 1 # page number
    size::Optional{Int} = 10  # page size
end
response_type(::file_list) = RESTful{Vector{FileInfo}}
method(::file_list) = CommandMethods.GET

Base.@kwdef struct file_info <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{Int} = nothing
    group::Optional{Int} = nothing
    qq::Optional{Int} = nothing
    withDownloadInfo::Bool = false
end
response_type(::file_info) = RESTful{FileInfo}
method(::file_info) = CommandMethods.GET

Base.@kwdef struct file_mkdir <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{Int} = nothing
    group::Optional{Int} = nothing
    qq::Optional{Int} = nothing
    directoryName::String
end
response_type(::file_mkdir) = RESTful{FileInfo}

Base.@kwdef struct file_delete <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{Int} = nothing
    group::Optional{Int} = nothing
    qq::Optional{Int} = nothing
end
response_type(::file_delete) = RESTful{Nothing}

Base.@kwdef struct file_move <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{Int} = nothing
    group::Optional{Int} = nothing
    qq::Optional{Int} = nothing
    moveTo::Optional{String} # destination folder id
    moveToPath::Optional{String}
end
response_type(::file_move) = RESTful{Nothing}

Base.@kwdef struct file_rename <: AbstractFileCommand
    id::String
    path::Optional{String} = nothing
    target::Optional{Int} = nothing
    group::Optional{Int} = nothing
    qq::Optional{Int} = nothing
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
    target::Int
    path::String
    file::Any # What ever that can be used by HTTP.Form
end
response_type(::file_upload) = RESTful{FileInfo}


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

# TO BE CONTINUED...


StructTypes.StructType(::Type{<:AbstractCommand}) = StructTypes.Struct()
StructTypes.StructType(::Type{<:RESTful}) = StructTypes.Struct()
StructTypes.names(::Type{<:AbstractMessagingCommand}) = ((:quoteId, :quote),)
StructTypes.omitempties(::Type{<:AbstractMessagingCommand}) = (:target, :qq, :group, :quoteId)
StructTypes.omitempties(::Type{<:AbstractFileCommand}) = (:path, :target, :qq, :group, :offset, :size)
