module ZincToWl

using FlatzincToGraph
using ArgParse

include("wl_features/Helper.jl")
using .Helper

include("GraphLoader.jl")
include("wl_features/StandardWl.jl")
include("wl_features/NodeWl.jl")
include("wl_features/EdgeWl.jl")
include("wl_features/NodeEdgeWl.jl")
include("wl_features/WlNodeCut.jl")
include("wl_features/WlNodeEdgeCut.jl")

using .GraphLoader
using .StandardWl
using .NodeWl
using .EdgeWl
using .NodeEdgeWl
using .WlNodeCut
using .WlNodeEdgeCut
using .Helper

function parse_commandline()
    s = ArgParseSettings(
        description="ZincToWl: Convert FlatZinc models to Weisfeiler-Lehman graph representations."
    )

    @add_arg_table! s begin
        "input_file"
        help = "Path to input FlatZinc (.fzn) or graph (.graph) file"
        required = true
        "--num-cores", "-c"
        help = "Number of cores for parallel processing"
        arg_type = Int
        default = 1
        "--wl-iterations", "-k"
        help = "Number of Weisfeiler-Lehman iterations"
        arg_type = Int
        default = 1
        "--method", "-m"
        help = "Weisfeiler-Lehman method"
        arg_type = String
        default = "wl-nc"
        range_tester = x -> x in ["wl", "wl-n", "wl-e", "wl-ne", "wl-nc", "wl-nec"]
        "--colors"
        help = "Path to the colors dict. Creates the file if it doesn't exist."
        arg_type = String
        default = "colors.bin"
        "--training", "-t"
        help = "whether it is training or testing (training mode add unseen colors to the colors dict)"
        arg_type = Bool
        default = false
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    input_file = parsed_args["input_file"]
    num_cores = parsed_args["num-cores"]
    wl_iterations = parsed_args["wl-iterations"]
    method = parsed_args["method"]
    colors_path = parsed_args["colors"]
    training = parsed_args["training"]

    if endswith(input_file, ".fzn")
        g = FlatzincToGraph.flatzinc_to_graph(input_file, num_cores)
    elseif endswith(input_file, ".graph")
        g = load_graph(input_file)
    else
        error("Unknown file type: $input_file")
    end
    colors = Helper.load_colors(colors_path)
    if method == "wl"
        node_colors = wl_directed_last(g, colors, wl_iterations, training, num_cores)
        println("\n$(join(node_colors, ","))\n")
    elseif method == "wl-n"
        node_colors = wl_node_directed_last(g, colors, wl_iterations, training, num_cores)
        println("\n$(join(node_colors, ","))\n")
    elseif method == "wl-e"
        node_colors = wl_edge_directed_last(g, colors, wl_iterations, training, num_cores)
        println("\n$(join(node_colors, ","))\n")
    elseif method == "wl-ne"
        node_colors = wl_node_edge_directed_last(g, colors, wl_iterations, training, num_cores)
        println("\n$(join(node_colors, ","))\n")
    elseif method == "wl-nc"
        node_colors, extra_info = wl_node_cut_directed_last(g, colors, wl_iterations, training, num_cores)
        println("\n$(join(node_colors, ","))")
        println("==========")
        println("n_nodes: $(extra_info["n_nodes"])")
        println("cpv: $(extra_info["cpv"])")
        println("cpp: $(extra_info["cpp"])")
        println("----------")
        for (p, v) in extra_info["globals_pairs"]
            println("($(p[1]), $(p[2])): $(v)")
        end
    elseif method == "wl-nec"
        node_colors, extra_info = wl_node_edge_cut_directed_last(g, colors, wl_iterations, training, num_cores)
        println("\n$(join(node_colors, ","))")
        println("==========")
        println("n_nodes: $(extra_info["n_nodes"])")
        println("cpv: $(extra_info["cpv"])")
        println("cpp: $(extra_info["cpp"])")
        println("----------")
        for (p, v) in extra_info["globals_pairs"]
            println("($(p[1]), $(p[2])): $(v)")
        end
    end
    if training
        Helper.save_colors(colors_path, colors)
    end
end

function julia_main()::Cint
    try
        main()
    catch e
        Base.showerror(stderr, e, catch_backtrace())
        return 1
    end
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end # module ZincToWl
