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
    type_part = line[1:first(type_separator)-1]
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
    if par_type_str in ("bool", "int", "float", "set of int")
        return ParType(Type(par_type_str, false), false)
    end
    if startswith(par_type_str, "array")
        components = split(par_type_str, "of")
        array_value_type = strip(join(components[2:end], "of"))
        type = Type(String(replace(array_value_type, "var " => "")), occursin("var", array_value_type))
        return ParType(type, true)
    end
    bound = bounded_type(par_type_str)
    if isnothing(bound)
        return nothing
    end
    return ParType(Type(bound, false), false)
end

function parse_par_value(par_value_str::AbstractString, par_type::ParType, vars::IdDict{String,Variable})
    val_str = strip(par_value_str)
    if endswith(val_str, ';')
        val_str = strip(val_str[1:end-1])
    end
    if par_type.is_array
        if startswith(val_str, '[') && endswith(val_str, ']')
            val_str = val_str[2:end-1]
        end
        element_str = String[]
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
                push!(element_str, String(val_str[i:end_idx]))
                i = nextind(val_str, end_idx) + 1
            end
        else
            element_str = [String(strip(x)) for x in split(val_str, ",")]
        end
        elements = Any[]
        if !par_type.type.is_var
            if par_type.type.type == "int"
                elements = [Parameter(e, ParType(Type("int", false), false), e) for e in element_str]
            elseif par_type.type.type == "bool"
                elements = [Parameter(e, ParType(Type("bool", false), false), e) for e in element_str]
            elseif par_type.type.type == "set of int"
                elements = [Parameter(e, ParType(Type("set of int", false), false), e) for e in element_str]
            elseif par_type.type.type == "float"
                elements = [Parameter(e, ParType(Type("float", false), false), e) for e in element_str]
            end
        else
            for element in element_str
                if is_literal(element)
                    push!(elements, element)
                else
                    push!(elements, vars[intern(element)])
                end
            end
        end
        return elements
    else
        if !par_type.type.is_var
            return String(val_str)
        else
            return vars[intern(val_str)]
        end
    end
end

function parse_parameter(line::String, vars::IdDict{String,Variable})::Union{Nothing,Parameter}
    type_separator_idx = only(findfirst(":", line))
    value_separator_idx = only(findfirst("=", line))
    par_type = parse_type(line[1:type_separator_idx-1])
    if isnothing(par_type)
        return nothing
    end
    name = replace(line[type_separator_idx+1:value_separator_idx-1], " " => "")
    if occursin("::", name)
        name = String(split(name, "::")[1])
    end
    name = intern(name)
    value = parse_par_value(strip(line[value_separator_idx+1:end]), par_type, vars)
    return Parameter(name, par_type, value)
end

export is_parameter, parse_parameter, Parameter, ParType, Type

end
