module Parameters

using ..Helper
using ..Variables
using Parsers

struct Type
    type::String
    is_var::Bool
end

struct ParType
    type::Type
    is_array::Bool
end

struct Parameter{T}
    name::String
    type::ParType
    value::T
end

Parameter(name::AbstractString, type::ParType, value::T) where T = Parameter{T}(String(name), type, value)

function Base.show(io::IO, p::Parameter)
    print(io, "Parameter(", p.name, ", type: ", p.type, ", value: ", p.value, ")")
end

function Base.show(io::IO, pt::ParType)
    print(io, pt.is_array ? "Array of " : "", pt.type)
end

function Base.show(io::IO, t::Type)
    print(io, t.is_var ? "var " : "", t.type)
end

function is_parameter(line::AbstractString)::Bool
    if !occursin(":", line)
        return false
    end
    if !occursin("=", line)
        return false
    end
    type_separator = findfirst(":", line)
    type_part = SubString(line, 1, first(type_separator)-1)
    if startswith(type_part, "var")
        return false
    end
    for t in ALL_TYPES
        if startswith(line, t)
            return true
        end
    end
    return occursin("..", type_part)
end

function bounded_type(par_type_str::AbstractString)::Union{Nothing,String}
    if occursin("..", par_type_str)
        return occursin(".", replace(par_type_str, ".." => "")) ? "float" : "int"
    end
    if startswith(par_type_str, '{') && endswith(par_type_str, '}')
        return occursin(".", par_type_str) ? "float" : "int"
    end
    return nothing
end

function parse_type(par_type_str::AbstractString)::Union{Nothing,ParType}
    if par_type_str == "bool" || par_type_str == "int" || par_type_str == "float" || par_type_str == "set of int"
        return ParType(Type(String(par_type_str), false), false)
    end
    if startswith(par_type_str, "array")
        of_idx = findfirst("of", par_type_str)
        if isnothing(of_idx)
            return nothing
        end
        array_value_type = strip(SubString(par_type_str, first(of_idx)+2, length(par_type_str)))
        is_var = startswith(array_value_type, "var ")
        type_name = is_var ? strip(SubString(array_value_type, 5, length(array_value_type))) : array_value_type
        return ParType(Type(String(type_name), is_var), true)
    end
    bound = bounded_type(par_type_str)
    if isnothing(bound)
        return nothing
    end
    return ParType(Type(bound, false), false)
end

function parse_par_value(par_value_str::AbstractString, par_type::ParType, vars::Dict{String,Variable})
    val_str = strip(par_value_str)
    if endswith(val_str, ';')
        val_str = strip(SubString(val_str, 1, length(val_str)-1))
    end
    if par_type.is_array
        if startswith(val_str, '[') && endswith(val_str, ']')
            val_str = SubString(val_str, 2, length(val_str)-1)
        end
        element_str = SubString{String}[]
        if occursin("{", val_str) || occursin("[", val_str)
            i = 1
            len = length(val_str)
            while i <= len
                while i <= len && (val_str[i] == ' ' || val_str[i] == ',')
                    i = nextind(val_str, i)
                end
                if i > len
                    break
                end
                end_idx = len
                if val_str[i] == '{'
                    matching_idx = findnext('}', val_str, i + 1)
                    if !isnothing(matching_idx)
                        end_idx = matching_idx
                    end
                elseif val_str[i] == '['
                    matching_idx = findnext(']', val_str, i + 1)
                    if !isnothing(matching_idx)
                        end_idx = matching_idx
                    end
                else
                    comma_idx = findnext(',', val_str, i)
                    if !isnothing(comma_idx)
                        end_idx = comma_idx - 1
                    end
                end
                push!(element_str, SubString(val_str, i, end_idx))
                i = nextind(val_str, end_idx) + 1
            end
        else
            for x in eachsplit(val_str, ',')
                push!(element_str, strip(x))
            end
        end
        elements = Any[]
        if !par_type.type.is_var
            t_name = par_type.type.type
            p_type = ParType(Type(t_name, false), false)
            elements = [Parameter(String(e), p_type, String(e)) for e in element_str]
        else
            for element in element_str
                if is_literal(element)
                    push!(elements, String(element))
                else
                    push!(elements, vars[element])
                end
            end
        end
        return elements
    else
        if !par_type.type.is_var
            return String(val_str)
        else
            return vars[val_str]
        end
    end
end

function parse_parameter(line::String, vars::Dict{String,Variable})::Union{Nothing,Parameter}
    type_separator_idx = findfirst(':', line)
    if isnothing(type_separator_idx)
        return nothing
    end
    value_separator_idx = findfirst('=', line)
    if isnothing(value_separator_idx)
        return nothing
    end
    
    par_type = parse_type(SubString(line, 1, type_separator_idx-1))
    if isnothing(par_type)
        return nothing
    end
    
    start_idx = type_separator_idx + 1
    end_pos = value_separator_idx
    colon_colon_idx = findnext("::", line, start_idx)
    if !isnothing(colon_colon_idx) && first(colon_colon_idx) < end_pos
        end_pos = first(colon_colon_idx)
    end
    name = strip(SubString(line, start_idx, end_pos-1))
    
    value = parse_par_value(strip(SubString(line, value_separator_idx+1, length(line))), par_type, vars)
    return Parameter(String(name), par_type, value)
end

export is_parameter, parse_parameter, Parameter, ParType, Type

end
