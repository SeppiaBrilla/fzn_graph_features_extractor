module Helper

using Parsers

ALL_TYPES = ["bool", "int", "float", "set of int", "array"]

function is_bounded_number_set(type_str::AbstractString)::Union{Nothing,Int}
    # st = startswith("set of", type_str)
    # println("bounded to parse $type_str ($st)")
    if startswith(type_str, "set of")
        # println("nothing!")
        return nothing
    end
    if !isnothing(findfirst("..", type_str))
        lb, ub = (Parsers.parse(Int, v) for v in split(type_str, ".."))
        return ub - lb + 1
    elseif startswith(type_str, '{') && endswith(type_str, '}')
        return length(split(type_str[2:end-1], ","))
    end
    return nothing
end

function remove_comments(line::AbstractString)::AbstractString
    comment_sign = findfirst("%", line)
    if isnothing(comment_sign)
        return line
    elseif first(comment_sign) == 1
        return ""
    else
        return line[1:first(comment_sign)-1]
    end
end

function is_set(value::String)::Bool
    if length(value) == 0
        return false
    end
    if startswith(value, "{") && endswith(value, "}")
        return true
    end
    if occursin("..", value)
        els = split(value, "..")
        if length(els) != 2
            return false
        end
        return !isnothing(tryparse(Int32, els[1])) && !isnothing(tryparse(Int32, els[2]))
    end
    return false
end

function is_literal(value::String)::Bool
    return (value == "true" || value == "false") ||
           is_set(value) ||
           !isnothing(tryparse(Float32, value))
end

function get_type(value::String)
    if value == "true" || value == "false"
        return "bool"
    elseif is_set(value)
        return "set of int"
    elseif !isnothing(tryparse(Float32, value))
        return "float"
    else
        return "int"
    end
end

const STRING_POOL = Dict{String,String}()
function intern(s::AbstractString)::String
    get!(STRING_POOL, s, s)
end

export is_bounded_number_set, remove_comments, ALL_TYPES, is_literal, get_type, intern

end
