module Variables

using ..Helper
using Parsers

struct Variable
    type::String
    name::String
    domain_size::Int
end

function Base.show(io::IO, v::Variable)
    print(io, "Var(", v.type, " ", v.name, " (dom size: ", v.domain_size, "))")
end

function is_var(line::AbstractString)::Bool
    return startswith(line, "var")
end

function parse_domain(domain::AbstractString)::Union{Nothing,Tuple{String,Int}}
    bound = is_bounded_number_set(domain)
    if !isnothing(bound)
        return "int", bound
    end
    if domain == "bool"
        return "bool", 2
    elseif domain == "int"
        return "int", 1000000
    elseif domain == "float"
        return "float", 1000000
    elseif startswith(domain, "set of")
        rest = strip(SubString(domain, 7, length(domain)))
        if rest == "int"
            return "set of int", 1000000
        else
            dot_idx = findfirst("..", rest)
            if !isnothing(dot_idx)
                idx = first(dot_idx)
                lb = Parsers.parse(Int, SubString(rest, 1, idx-1))
                ub = Parsers.parse(Int, SubString(rest, idx+2, length(rest)))
                return "set of int", (ub - lb + 1)
            elseif startswith(rest, '{') && endswith(rest, '}')
                commas = 0
                for char in rest
                    if char == ','
                        commas += 1
                    end
                end
                return "set of int", commas + 1
            end
        end
    end
    return nothing
end

function parse_variable(line::AbstractString)::Union{Variable,Nothing}
    domain_separator = findfirst(':', line)
    if isnothing(domain_separator)
        return nothing
    end
    domain_str = strip(SubString(line, 5, only(domain_separator)-1))
    dom_res = parse_domain(domain_str)
    if isnothing(dom_res)
        return nothing
    end
    domain_type, size = dom_res
    
    start_idx = domain_separator + 1
    end_idx = length(line)
    
    colon_colon_idx = findnext("::", line, start_idx)
    eq_idx = findnext('=', line, start_idx)
    semi_idx = findnext(';', line, start_idx)
    
    end_pos = end_idx
    if !isnothing(colon_colon_idx)
        end_pos = min(end_pos, first(colon_colon_idx))
    end
    if !isnothing(eq_idx)
        end_pos = min(end_pos, eq_idx)
    end
    if !isnothing(semi_idx)
        end_pos = min(end_pos, semi_idx)
    end
    
    name = strip(SubString(line, start_idx, end_pos-1))
    return Variable(domain_type, String(name), size)
end

export is_var, parse_variable, Variable

end
