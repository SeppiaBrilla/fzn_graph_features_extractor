module FlatzincToGraph

include("parse/flatzinc_to_graph.jl")

using .FlatzincToGraphParser

function run_program(ARGS)
    if length(ARGS) == 0
        println("no argument passed. pass a model")
        return
    end
    file_in = ARGS[1]
    file_out = ARGS[2]
    graph = flatzinc_to_graph(file_in)
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
