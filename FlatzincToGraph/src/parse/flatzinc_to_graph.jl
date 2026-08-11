module FlatzincToGraphParser

include("graph/types.jl")
include("helper.jl")
include("variables.jl")
include("parameters.jl")
include("graph/helper.jl")
include("solve.jl")
include("constraint.jl")

using .Helper
using .Variables
using .Parameters
using .Solve
using .GraphType
using .Constraints
using .GraphHelper

function flatzinc_to_graph(file_name::String, num_cores::Int=1)::Graph
    GraphHelper.reset_counter()
    variables = Dict{String,Variable}()
    parameters = Dict{String,Parameter}()
    graph = Graph()

    constraint_lines = String[]
    solve_line = Ref{Union{String,Nothing}}(nothing)

    open(file_name) do f
        for line in eachline(f)
            if isempty(line)
                continue
            end

            # Fast check for comments/predicates/constraints/vars/solve
            first_char = line[1]
            if first_char == '%'
                continue
            elseif startswith(line, "constraint")
                push!(constraint_lines, line)
            elseif startswith(line, "var ")
                var = parse_variable(line)
                if !isnothing(var)
                    variables[var.name] = var
                    id = hash(var.name)
                    add_node(graph, Node(var.name, :var_node, "$id: $(var.name) -- var_node -- $(var.type) -- $(var.domain_size)", id))
                end
            elseif startswith(line, "solve")
                solve_line[] = line
            elseif startswith(line, "predicate")
                continue
            else
                # It must be a parameter declaration
                par = parse_parameter(line, variables)
                if !isnothing(par)
                    parameters[par.name] = par
                end
            end
        end
    end

    # Pre-size the graph dicts
    sizehint!(graph.nodes, length(variables) + length(constraint_lines))
    sizehint!(graph.node_dict, length(variables) + length(constraint_lines))
    sizehint!(graph.edges, length(constraint_lines) * 2)
    sizehint!(graph.edge_set, length(constraint_lines) * 2)

    num_constraints = length(constraint_lines)

    if num_cores <= 1 || num_constraints < 1000
        # Sequential parsing
        task_local_storage(:task_prefix, UInt64(0))
        task_local_storage(:task_counter, 0)
        for line in constraint_lines
            parse_constraint(line, parameters, variables, graph)
        end
    else
        # Parallel parsing
        actual_cores = min(num_cores, Threads.nthreads())
        if actual_cores <= 1
            # Fall back to sequential if only 1 thread is available in Julia
            task_local_storage(:task_prefix, UInt64(0))
            task_local_storage(:task_counter, 0)
            for line in constraint_lines
                parse_constraint(line, parameters, variables, graph)
            end
        else
            chunk_size = div(num_constraints + actual_cores - 1, actual_cores)
            tasks = []
            local_graphs = [Graph() for _ in 1:actual_cores]

            for c in 1:actual_cores
                start_idx = (c - 1) * chunk_size + 1
                end_idx = min(c * chunk_size, num_constraints)

                if start_idx <= end_idx
                    t = Threads.@spawn begin
                        # Initialize unique counter prefix and counter for this task
                        task_local_storage(:task_prefix, UInt64(c) * 1_000_000_000)
                        task_local_storage(:task_counter, 0)

                        lg = local_graphs[c]
                        # Pre-size local collections
                        local_len = end_idx - start_idx + 1
                        sizehint!(lg.nodes, local_len)
                        sizehint!(lg.node_dict, local_len)
                        sizehint!(lg.edges, local_len * 2)
                        sizehint!(lg.edge_set, local_len * 2)

                        for i in start_idx:end_idx
                            parse_constraint(constraint_lines[i], parameters, variables, lg)
                        end
                    end
                    push!(tasks, t)
                end
            end

            # Wait for all tasks to complete
            for t in tasks
                wait(t)
            end

            # Merge local graphs into main graph
            for lg in local_graphs
                for node in lg.nodes
                    add_node(graph, node)
                end
                for (f, t_id, label) in lg.edges
                    add_edge(graph, f, t_id, Edge(label))
                end
            end
        end
    end

    # Process solve line at the end
    if !isnothing(solve_line[])
        solve = parse_solve(solve_line[], variables)
        if !isnothing(solve)
            if solve.type == "maximize"
                label = "Maximise($(solve.objectiveVar.name))"
                id = hash(label)
                add_node(graph, Node(label, :maximise_node, "$id: $(label) -- maximise_node", id))
                add_edge(graph, id, hash(solve.objectiveVar.name), Edge(EDGE_0))
            elseif solve.type == "minimize"
                label = "Minimise($(solve.objectiveVar.name))"
                id = hash(label)
                add_node(graph, Node(label, :minimise_node, "$id: $(label) -- minimise_node", id))
                add_edge(graph, id, hash(solve.objectiveVar.name), Edge(EDGE_0))
            end
        end
    end

    return graph
end

function write_graph(graph::Graph, filepath::AbstractString)
    open(filepath, "w") do file
        @assert iswritable(file) "file $filepath is not writable"

        write(file, "##$(length(graph.nodes)) - $(length(graph.edges))\n")

        write(file, "nodes:\n")

        for node in graph.nodes
            write(file, node.value)
            write(file, '\n')
        end

        write(file, "edges:\n")

        for (idx, (n1, n2, label)) in enumerate(graph.edges)
            zero_based_idx = idx - 1
            # Write directly to stream avoiding interpolation string allocations
            print(file, zero_based_idx, ": ", n1, "--", n2, "--", label, '\n')
        end
    end
end

export flatzinc_to_graph, write_graph

end
