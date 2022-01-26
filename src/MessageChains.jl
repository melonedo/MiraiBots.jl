abstract type MessageElement end

const MessageChain = Vector{MessageElement}

Base.@kwdef struct Source <: MessageElement
    id::Int
    time::Int
end

Base.@kwdef struct Quote <: MessageElement
    id::Int
    groupId::Int
    senderId::Int
    targetId::Int
    origin::MessageChain
end

Base.@kwdef struct At <: MessageElement
    target::Int
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
    senderId::Int
    time::Int
    senderName::String
    messageChain::MessageChain
    messageId::Int
end

Base.@kwdef struct ForwardMessage <: MessageElement
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

const message_element_types = (; Source, Quote, At, AtAll, Face, Plain, Image,
    FlashImage, Voice, Xml, Json, Poke, Dice, MusicShare,
    ForwardMessage, File, MiraiCode)

StructTypes.StructType(::Type{<:MessageElement}) = StructTypes.Struct()
StructTypes.StructType(::Type{MessageElement}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{MessageElement}) = :type
StructTypes.subtypes(::Type{MessageElement}) = message_element_types
StructTypes.omitempties(::Type{<:ResourceElement}) = (:imageId, :voiceId, :url, :path, :base64)
