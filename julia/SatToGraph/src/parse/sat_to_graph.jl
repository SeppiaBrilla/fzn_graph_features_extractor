module SatToGraphParser

include("terms.jl")
include("clauses.jl")
include("graph/add_to_graph.jl")

using FlatzincToGraph
using FlatzincToGraph.GraphType

using .SatTerms
using .SatClause
using .AddToGraph

export sat_to_graph, write_graph

"""
    open_cnf_file(f, filepath)

Opens `filepath` which can be uncompressed or `.xz` compressed (streaming via `xz -dc`).
"""
function open_cnf_file(f::Function, filepath::AbstractString)
    if endswith(filepath, ".xz")
        open(`xz -dc $filepath`, "r") do io
            f(io)
        end
    else
        open(filepath, "r") do io
            f(io)
        end
    end
end

"""
    sat_to_graph(filepath::String, num_cores::Int=1)::Graph

Main parsing entrypoint for SAT CNF (.cnf, .cnf.xz) files.
"""
function sat_to_graph(filepath::String, num_cores::Int=1)::Graph
    graph = Graph()
    variables = Dict{Int64,Node}()
    clauses = Clause[]

    num_vars = 0
    num_clauses = 0

    open_cnf_file(filepath) do io
        curr_tokens = String[]
        for raw_line in eachline(io)
            line = strip(raw_line)
            if isempty(line) || startswith(line, "c") || startswith(line, "%") || startswith(line, "=")
                continue
            end

            if startswith(line, "p cnf")
                parts = split(line)
                if length(parts) >= 4
                    num_vars = tryparse(Int, parts[3]) === nothing ? 0 : parse(Int, parts[3])
                    num_clauses = tryparse(Int, parts[4]) === nothing ? 0 : parse(Int, parts[4])
                end
                continue
            end

            # Standard CNF line: space separated integers terminated by 0
            # Clauses may span multiple lines
            tokens = split(line)
            for tok in tokens
                if tok == "0"
                    c = parse_clause(curr_tokens)
                    if !isnothing(c)
                        push!(clauses, c)
                    end
                    empty!(curr_tokens)
                else
                    push!(curr_tokens, String(tok))
                end
            end
        end
        # Flush any trailing non-zero terminated clause if present
        if !isempty(curr_tokens)
            c = parse_clause(curr_tokens)
            if !isnothing(c)
                push!(clauses, c)
            end
        end
    end

    # Pre-size graph
    n_clauses = max(length(clauses), num_clauses)
    n_vars = max(length(variables), num_vars)
    sizehint!(graph.nodes, n_vars + n_clauses * 3)
    sizehint!(graph.node_dict, n_vars + n_clauses * 3)
    sizehint!(graph.edges, n_clauses * 6)
    sizehint!(graph.edge_set, n_clauses * 6)

    # Add clauses to graph
    for clause in clauses
        add_clause_to_graph!(graph, clause, variables)
    end

    return graph
end

# Re-export write_graph from FlatzincToGraph
const write_graph = FlatzincToGraph.write_graph

end
