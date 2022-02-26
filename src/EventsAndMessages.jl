abstract type EventOrMessage end

include("Messages.jl")
include("Events.jl")

StructTypes.StructType(::Type{<:EventOrMessage}) = StructTypes.Struct()
StructTypes.StructType(::Type{EventOrMessage}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{EventOrMessage}) = :type
StructTypes.subtypes(::Type{EventOrMessage}) = (; Events.event_types..., Messages.message_types...)
