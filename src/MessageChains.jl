module MessageChains
using ..StructTypes
import ..Optional, ..FriendId, ..GroupOrFriendId, ..GroupId, ..TimeStamp, ..DurationSeconds
import ..MessageId, ..EventId, ..DeviceKind

abstract type MessageElement end

const MessageChain = Vector{MessageElement}

Base.@kwdef struct Source <: MessageElement
    id::MessageId
    time::TimeStamp
end

Base.@kwdef struct Quote <: MessageElement
    id::MessageId
    groupId::GroupId # 0 for friend messages
    senderId::FriendId
    targetId::GroupOrFriendId # original receiver
    origin::MessageChain
end

Base.@kwdef struct At <: MessageElement
    target::FriendId
    display::String
end

Base.@kwdef struct AtAll <: MessageElement end

Base.@kwdef struct Face <: MessageElement
    faceId::Optional{Int} = nothing
    name::Optional{String} = nothing
end

Base.@kwdef struct Plain <: MessageElement
    text::String
end

abstract type ResourceElement <: MessageElement end

StructTypes.omitempties(::Type{<:ResourceElement}) = true

Base.@kwdef struct Image <: ResourceElement
    imageId::Optional{String} = nothing
    url::Optional{String} = nothing
    path::Optional{String} = nothing
    base64::Optional{String} = nothing
end

Base.@kwdef struct FlashImage <: ResourceElement
    imageId::Optional{String} = nothing
    url::Optional{String} = nothing
    path::Optional{String} = nothing
    base64::Optional{String} = nothing
end

Base.@kwdef struct Voice <: ResourceElement
    voiceId::Optional{String} = nothing
    url::Optional{String} = nothing
    path::Optional{String} = nothing
    base64::Optional{String} = nothing
end

Base.@kwdef struct Xml <: MessageElement
    xml::String
end

Base.@kwdef struct Json <: MessageElement
    json::String
end

Base.@kwdef struct App <: MessageElement
    content::String
end

Base.@kwdef struct Poke <: MessageElement
    name::String
end

Base.@kwdef struct Dice <: MessageElement
    value::Int
end

Base.@kwdef struct MusicShare <: MessageElement
    kind::String
    title::String
    summary::String
    jumpUrl::String
    pictureUrl::String
    musicUrl::String
    brief::String
end

Base.@kwdef struct MessageNode
    senderId::FriendId
    time::TimeStamp
    senderName::String
    messageChain::MessageChain
    messageId::Optional{MessageId}
end
StructTypes.StructType(::Type{MessageNode}) = StructTypes.Struct()

Base.@kwdef struct Forward <: MessageElement
    nodeList::Vector{MessageNode}
end

Base.@kwdef struct File <: MessageElement
    id::String
    name::String
    size::Int
end

Base.@kwdef struct MiraiCode <: MessageElement
    code::String
end

const message_element_types = (; Source, Quote, At, AtAll, Face,
    Plain, Image, FlashImage, Voice, Xml, Json, Poke, Dice,
    MusicShare, Forward, File, MiraiCode)

StructTypes.StructType(::Type{MessageElement}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{MessageElement}) = :type
StructTypes.subtypes(::Type{MessageElement}) = message_element_types

# So that `type` field is also included in serialization
StructTypes.StructType(::Type{<:MessageElement}) = StructTypes.DictType()

function StructTypes.construct(T::Type{<:MessageElement}, x::Dict)
    # Force T to be StructTypes.Struct to reuse the infrastructure of StructTypes
    StructTypes.constructfrom(StructTypes.Struct(), T, x)
end

@generated function StructTypes.keyvaluepairs(x::MessageElement)
    fields = (:($f = x.$f) for f in fieldnames(x))
    quote
        pairs((type = $(Meta.quot(x.name.name)), $(fields...)))
    end
end

export MessageChain

for n in keys(message_element_types)
    @eval export $n
end

end
