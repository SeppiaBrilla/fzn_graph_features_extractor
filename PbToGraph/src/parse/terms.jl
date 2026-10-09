module PbTerms

struct Variable
    name::String
    is_negative::Bool
end

const Parameter = Int64

struct Term
    variables::Vector{Variable}
    coefficient::Parameter
end

function parse_term(tokens::AbstractVector{<:AbstractString})::Vector{Term}
    end_tokens = length(tokens)
    if end_tokens > 0 && tokens[end_tokens] == ";"
        end_tokens -= 1
    end
    terms = Term[]
    sizehint!(terms, div(end_tokens + 1, 2))
    vars = Variable[]
    coeff::Union{Parameter,Nothing} = nothing

    i = 1
    while i <= end_tokens
        t = tokens[i]
        # Check if token is a coefficient (starts with '+' or '-' or is a digit)
        if (t[1] == '+' || t[1] == '-' || isdigit(t[1])) && (length(t) == 1 || isdigit(t[2]))
            parsed_coeff = tryparse(Int64, t)
            if !isnothing(parsed_coeff)
                if !isnothing(coeff)
                    push!(terms, Term(copy(vars), coeff))
                    empty!(vars)
                end
                coeff = parsed_coeff
                i += 1
                continue
            end
        end

        # Otherwise it's a variable literal
        if startswith(t, "~")
            push!(vars, Variable(String(t[2:end]), true))
        else
            push!(vars, Variable(String(t), false))
        end
        i += 1
    end

    if !isnothing(coeff)
        push!(terms, Term(copy(vars), coeff))
    end

    return terms
end

function parse_term(term_line::AbstractString)::Vector{Term}
    tokens = split(strip(term_line))
    return parse_term(tokens)
end

export Variable, Parameter, Term, parse_term

end
