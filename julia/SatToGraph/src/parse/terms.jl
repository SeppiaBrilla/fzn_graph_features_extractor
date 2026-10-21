module SatTerms

struct Literal
    var_id::Int64
    is_negative::Bool
end

function parse_literals(tokens::AbstractVector{<:AbstractString})::Vector{Literal}
    lits = Literal[]
    sizehint!(lits, length(tokens))
    for t in tokens
        val = tryparse(Int64, t)
        if !isnothing(val) && val != 0
            push!(lits, Literal(abs(val), val < 0))
        end
    end
    return lits
end

export Literal, parse_literals

end
