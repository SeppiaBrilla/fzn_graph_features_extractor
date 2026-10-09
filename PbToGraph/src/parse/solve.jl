module PbSolve

using ..PbTerms

struct SolveType
    type::Symbol
    objectiveVars::Union{Vector{Term},Nothing}
end

function Base.show(io::IO, s::SolveType)
    print(io, "Solve(", s.type, ", ", s.objectiveVars, ")")
end

function parse_solve(line::AbstractString)::SolveType
    t_type = startswith(line, "min:") ? :min : :max
    term_body = strip(line[5:end])
    terms = parse_term(term_body)
    return SolveType(t_type, terms)
end

function is_solve(line::AbstractString)::Bool
    return startswith(line, "min:") || startswith(line, "max:")
end

export is_solve, parse_solve, SolveType

end
