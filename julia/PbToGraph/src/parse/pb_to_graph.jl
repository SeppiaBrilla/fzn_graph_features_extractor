module PbToGraphParser

include("terms.jl")
include("constraints.jl")
include("solve.jl")
include("graph/add_to_graph.jl")

using FlatzincToGraph
using FlatzincToGraph.GraphType

using .PbTerms
using .PbConstraint
using .PbSolve
using .AddToGraph

export pb_to_graph, write_graph

"""
    open_pb_file(f, filepath)

Opens `filepath` which can be uncompressed or `.xz` compressed (streaming via `xz -dc`).
"""
function open_pb_file(f::Function, filepath::AbstractString)
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
    pb_to_graph(filepath::String, num_cores::Int=1)::Graph

Main parsing entrypoint for Pseudo-Boolean (.opb, .wbo, .xz) files.
"""
function pb_to_graph(filepath::String, num_cores::Int=1)::Graph
    graph = Graph()
    solve_item::Union{Nothing,SolveType} = nothing
    constraints = Constraint[]
    variables = Dict{String,Node}()

    open_pb_file(filepath) do io
        for raw_line in eachline(io)
            line = strip(raw_line)
            if isempty(line) || startswith(line, "*")
                continue
            end
            if startswith(line, "soft:")
                continue
            end

            if is_solve(line)
                solve_item = parse_solve(line)
            else
                push!(constraints, parse_constraint(line))
            end
        end
    end

    # Pre-size graph
    sizehint!(graph.nodes, length(constraints) * 4)
    sizehint!(graph.node_dict, length(constraints) * 4)
    sizehint!(graph.edges, length(constraints) * 8)
    sizehint!(graph.edge_set, length(constraints) * 8)

    # Add constraints to graph
    for constr in constraints
        add_constraint_to_graph!(graph, constr, variables)
    end

    # Add objective to graph if present
    if !isnothing(solve_item)
        add_solve_to_graph!(graph, solve_item, variables)
    end

    return graph
end

# Re-export write_graph from FlatzincToGraph
const write_graph = FlatzincToGraph.write_graph

end
