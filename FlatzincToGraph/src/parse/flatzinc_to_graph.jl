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

function flatzinc_to_graph(file_name::String)::Graph
    variables = IdDict{String,Variable}([])
    parameters = IdDict{String,Parameter}([])
    graph = Graph()
    open(file_name) do f
        for line in readlines(f)
            if is_var(line)
                var = parse_variable(line)
                if !isnothing(var)
                    variables[var.name] = var
                    id = hash(var.name)
                    add_node(graph, Node(var.name, "var_node", "$id: $(var.name) -- var_node -- $(var.type) -- $(var.domain_size)", id))
                end
            elseif is_parameter(line)
                par = parse_parameter(line, variables)
                if !isnothing(par)
                    parameters[par.name] = par
                end
            elseif is_solve(line)
                solve = parse_solve(line, variables)
                if solve.type == "maximize"
                    label = "Maximise($(solve.objectiveVar.name))"
                    id = hash(label)
                    add_node(graph, Node(label, "maximise_node", "$id: $(label) -- maximise_node", id))
                    add_edge(graph, id, hash(solve.objectiveVar.name), Edge("0"))
                elseif solve.type == "minimize"
                    label = "Minimise($(solve.objectiveVar.name))"
                    id = hash(label)
                    add_node(graph, Node(label, "minimise_node", "$id: $(label) -- minimise_node", id))
                    add_edge(graph, id, hash(solve.objectiveVar.name), Edge("0"))
                end
            elseif is_constraint_line(line)
                parse_constraint(line, parameters, variables, graph)
            end
        end
    end
    return graph
end

function write_graph(graph::Graph, filepath::AbstractString)
    open(filepath, "w") do file
        @assert iswritable(file) "file $file is not writable"

        write(file, "nodes:\n")

        for node in graph.nodes
            write(file, node.value * "\n")
        end

        write(file, "edges:\n")

        for (idx, ((n1, n2), l)) in enumerate(graph.edges)
            zero_based_idx = idx - 1
            try
                write(file, "$(zero_based_idx): $(n1)--$(n2)--$(l.label)\n")
            catch e
                println("n1 ", n1, " ", n1._type)
                println("n2 ", n2, " ", n2._type)
                rethrow(e)
            end
        end
    end
end

export flatzinc_to_graph, write_graph

end
