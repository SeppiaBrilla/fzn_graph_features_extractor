module Helper

using Parsers

const ALL_TYPES = ["bool", "int", "float", "set of int", "array"]

function is_bounded_number_set(type_str::AbstractString)::Union{Nothing,Int}
    if startswith(type_str, "set of")
        return nothing
    end
    dot_idx = findfirst("..", type_str)
    if !isnothing(dot_idx)
        idx = first(dot_idx)
        lb = Parsers.parse(Int, SubString(type_str, 1, idx-1))
        ub = Parsers.parse(Int, SubString(type_str, idx+2, length(type_str)))
        return ub - lb + 1
    elseif startswith(type_str, '{') && endswith(type_str, '}')
        commas = 0
        for char in type_str
            if char == ','
                commas += 1
            end
        end
        return commas + 1
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
        return SubString(line, 1, first(comment_sign)-1)
    end
end

function is_set(value::AbstractString)::Bool
    len = length(value)
    if len == 0
        return false
    end
    if startswith(value, "{") && endswith(value, "}")
        return true
    end
    dot_idx = findfirst("..", value)
    if !isnothing(dot_idx)
        idx = first(dot_idx)
        return !isnothing(tryparse(Int32, SubString(value, 1, idx-1))) && !isnothing(tryparse(Int32, SubString(value, idx+2, len)))
    end
    return false
end

function is_literal(value::AbstractString)::Bool
    if value == "true" || value == "false"
        return true
    end
    c = first(value)
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
        return false
    end
    return true
end

function get_type(value::AbstractString)
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

export is_bounded_number_set, remove_comments, ALL_TYPES, is_literal, get_type

end
