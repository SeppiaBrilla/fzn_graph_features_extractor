module FlatzincToGraph

include("parse/flatzinc_to_graph.jl")

using .FlatzincToGraphParser
using .FlatzincToGraphParser.GraphType

export FlatzincToGraphParser, GraphType, Graph, Node, Edge, add_node, add_edge, flatzinc_to_graph, write_graph

function run_program(ARGS)
    if length(ARGS) < 2
        println("usage: FlatzincToGraph <input_file> <output_file> [num_cores]")
        return
    end
    file_in = ARGS[1]
    file_out = ARGS[2]
    num_cores = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 1
    graph = flatzinc_to_graph(file_in, num_cores)
    write_graph(graph, file_out)
end

function julia_main()::Cint
    try
        run_program(ARGS)
    catch e
        Base.showerror(stderr, e, catch_backtrace())
        return 1
    end
    return 0
end

end
# =====================================================================
# 3. Entry point for Script Execution (e.g., `julia src/FlatzincToGraph.jl`)
# =====================================================================
# This block only runs if the file is executed directly as a script.
# It is skipped during package loading or compilation.
if abspath(PROGRAM_FILE) == @__FILE__
    # Call the main function with command-line arguments and exit with the correct code
    FlatzincToGraph.run_program(ARGS)
end
