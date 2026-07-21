module Solve

using ..Variables
using ..Helper

function is_solve(line::AbstractString)::Bool
    startswith(line, "solve")
end

struct SolveType
    type::String
    objectiveVar::Union{Variable, Nothing}
end

function Base.show(io::IO, s::SolveType)
    print(io, "Solve(", s.type, ", ", s.objectiveVar, ")")
end

function parse_solve(line::AbstractString, vars::Dict{String, Variable})::SolveType
    if occursin("satisfy", line)
        return SolveType("SAT", nothing)
    elseif occursin("minimize", line)
        var_name = strip(replace(split(line, "minimize")[end], ";" => ""))
        return SolveType("minimize", vars[var_name])
    elseif occursin("maximize", line)
        var_name = strip(replace(split(line, "maximize")[end], ";" => ""))
        return SolveType("maximize", vars[var_name])
    end
end

export is_solve, SolveType, parse_solve

end
