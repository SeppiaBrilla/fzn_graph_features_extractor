module SatClause

using ..SatTerms

struct Clause
    pos_lits::Vector{Literal}
    neg_lits::Vector{Literal}
end

function parse_clause(tokens::AbstractVector{<:AbstractString})::Union{Nothing,Clause}
    lits = parse_literals(tokens)
    if isempty(lits)
        return nothing
    end
    pos = Literal[]
    neg = Literal[]
    for lit in lits
        if lit.is_negative
            push!(neg, lit)
        else
            push!(pos, lit)
        end
    end
    return Clause(pos, neg)
end

function parse_clause(line::AbstractString)::Union{Nothing,Clause}
    tokens = split(strip(line))
    return parse_clause(tokens)
end

export Clause, parse_clause

end
