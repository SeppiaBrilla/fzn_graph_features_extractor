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
    # println(domain)
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
    elseif !isnothing(findfirst("set of", domain))
        if !isnothing(findfirst("int", domain))
            return "set of int", 1000000
        elseif !isnothing(findfirst("..", domain))
            lb, ub = (Parsers.parse(Int, v) for v in split(replace(domain, "set of" => ""), ".."))
            return "set of int", (ub - lb + 1)
        else
            set_str = strip(replace(domain, "set of" => ""))
            if startswith(set_str, '{') && endswith(set_str, '}')
                set_str = set_str[2:end-1]
            end
            size = length(split(set_str, ","))
            return "set of int", size
        end
    end
    return nothing
end

function parse_variable(line::AbstractString)::Union{Variable,Nothing}
    if !is_var(line)
        return nothing
    end
    domain_separator = findfirst(":", line)
    if isnothing(domain_separator)
        return nothing
    end
    domain_str = strip(line[5:only(domain_separator)-1])
    dom_res = parse_domain(domain_str)
    if isnothing(dom_res)
        return nothing
    end
    domain_type, size = dom_res
    end_separator = ";"
    if !isnothing(findfirst("::", line))
        end_separator = "::"
    elseif !isnothing(findfirst("=", line))
        end_separator = "="
    end
    end_idx = findfirst(end_separator, line)
    if isnothing(end_idx)
        return nothing
    end
    name = intern(replace(line[only(domain_separator)+1:first(end_idx)-1], " " => ""))
    return Variable(domain_type, name, size)
end

export is_var, parse_variable, Variable

end
