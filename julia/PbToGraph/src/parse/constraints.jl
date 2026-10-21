module PbConstraint

using ..PbTerms

struct Constraint
    weight::Union{Nothing,Int64}
    is_weighted::Bool
    terms::Vector{Term}
    type::Symbol
    rhs::Int64
end

function parse_constraint(line::AbstractString)::Constraint
    weight::Union{Nothing,Int64} = nothing
    start_idx = 1
    if startswith(line, "[")
        weight_end = findfirst(']', line)
        weight = parse(Int64, strip(line[2:weight_end - 1]))
        start_idx = weight_end + 1
    end

    comment_idx = findfirst("/*", line)
    clean_line = if !isnothing(comment_idx)
        strip(line[start_idx:first(comment_idx) - 1])
    else
        strip(line[start_idx:end])
    end

    tokens = split(clean_line)
    op_idx = findfirst(t -> t in (">=", "<=", "="), tokens)
    if isnothing(op_idx) || op_idx >= length(tokens)
        error("Invalid constraint format: $line")
    end

    op_str = tokens[op_idx]
    rhs_str = tokens[op_idx + 1]
    if endswith(rhs_str, ";")
        rhs_str = rhs_str[1:end-1]
    end
    rhs = parse(Int64, rhs_str)

    terms = parse_term(tokens[1:op_idx - 1])

    if op_str == ">="
        # Invert to <= matching FlatZinc decomposition: sum(-coeff * term) <= -rhs
        inverted_terms = [Term(t.variables, -1 * t.coefficient) for t in terms]
        return Constraint(weight, !isnothing(weight), inverted_terms, :leq_node, -1 * rhs)
    elseif op_str == "<="
        return Constraint(weight, !isnothing(weight), terms, :leq_node, rhs)
    else
        return Constraint(weight, !isnothing(weight), terms, :eq_node, rhs)
    end
end

export Constraint, parse_constraint

end
