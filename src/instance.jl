struct InstanceFormatError <: Exception
    source::String
    line::Int
    msg::String
end

function Base.showerror(io::IO, e::InstanceFormatError)
    print(io, "InstanceFormatError: ", e.source, ":", e.line, ": ", e.msg)
end
