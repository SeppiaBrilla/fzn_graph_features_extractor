module ZincToWl

using ArgParse: check_type
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

function parse_commandline(args::Vector{String})
    s = ArgParseSettings(
        description="ZincToWl: Convert FlatZinc models to Weisfeiler-Lehman graph representations."
    )

    @add_arg_table! s begin
        "input_file"
        help = "Path to input FlatZinc (.fzn) or graph (.graph) file."
        required = false
        "--num-cores", "-c"
        help = "Number of cores for parallel processing."
        arg_type = Int
        default = 1
        "--wl-iterations", "-k"
        help = "Number of Weisfeiler-Lehman iterations."
        arg_type = Int
        default = 1
        "--method", "-m"
        help = "Weisfeiler-Lehman method."
        arg_type = String
        default = "wl-nc"
        range_tester = x -> x in ["wl", "wl-n", "wl-e", "wl-ne", "wl-nc", "wl-nec", "wl-u", "wl-un", "wl-ue", "wl-une", "wl-unc", "wl-unec", "wl-a", "wl-an", "wl-ae", "wl-ane", "wl-anc", "wl-anec"]
        "--colors"
        help = "Path to the colors dict. Creates the file if it doesn't exist."
        arg_type = String
        default = "colors.bin"
        "--training", "-t"
        help = "whether it is training or testing (training mode add unseen colors to the colors dict)."
        arg_type = Bool
        default = false
        "--check-colors"
        help = "Prints all the colors of a color file to stdout. It is ignored if a .fzn or .graph file is passed."
        arg_type = String
        required = false
    end

    return parse_args(args, s)
end
function format_colors(colors_arr::Vector{UInt64}, colors::Dict{UInt64,UInt64})::String
    counts = Dict{UInt64,Int}()
    for c in colors_arr
        counts[c] = get(counts, c, 0) + 1
    end

    io = IOBuffer()
    (color), remaining_pairs = Iterators.peel(values(colors))
    print(io, "{\n\t\"$color\":$(get(counts, color, 0))")
    for color in remaining_pairs
        print(io, ",\n\t\"", color, "\":", get(counts, color, 0))
    end
    return String(take!(io))
end

function main(args::Vector{String}=copy(ARGS))
    parsed_args = parse_commandline(args)
    check_colors = parsed_args["check-colors"]
    input_file = parsed_args["input_file"]
    if !isnothing(check_colors) && (isnothing(input_file) || isempty(input_file))
        colors = Helper.load_colors(check_colors)
        is_first = true
        for col in values(colors)
            if is_first
                print(col)
                is_first = false
            else
                print(",$col")
            end
        end
        return
    end

    if isnothing(input_file) || isempty(input_file)
        error("input_file is required unless starting a server or checking colors with --check-colors")
    end
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
    extra_info = Helper.extract_extra_info(g)

    if method == "wl"
        node_colors = wl_directed_last(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-n"
        node_colors = wl_node_directed_last(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-e"
        node_colors = wl_edge_directed_last(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-ne"
        node_colors = wl_node_edge_directed_last(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-nc"
        node_colors = wl_node_cut_directed_last(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-nec"
        node_colors = wl_node_edge_cut_directed_last(g, colors, wl_iterations, training, num_cores)

    elseif method == "wl-a"
        println(stderr, "WARNING: all_levels graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_directed_all_levels(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-an"
        println(stderr, "WARNING: all_levels graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_node_directed_all_levels(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-ae"
        println(stderr, "WARNING: all_levels graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_edge_directed_all_levels(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-ane"
        println(stderr, "WARNING: all_levels graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_node_edge_directed_all_levels(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-anc"
        println(stderr, "WARNING: all_levels graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_node_cut_directed_all_colors(g, colors, wl_iterations, training, num_cores)
    elseif method == "wl-anec"
        println(stderr, "WARNING: all_levels graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_node_edge_cut_directed_all_levels(g, colors, wl_iterations, training, num_cores)

    elseif method == "wl-u"
        println(stderr, "WARNING: undirected graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_undirected_last(g, colors, wl_iterations, training)
    elseif method == "wl-un"
        println(stderr, "WARNING: undirected graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_node_undirected_last(g, colors, wl_iterations, training)
    elseif method == "wl-ue"
        println(stderr, "WARNING: undirected graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_edge_undirected_last(g, colors, wl_iterations, training)
    elseif method == "wl-une"
        println(stderr, "WARNING: undirected graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_node_edge_undirected_last(g, colors, wl_iterations, training)
    elseif method == "wl-unc"
        println(stderr, "WARNING: undirected graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_node_cut_undirected_last(g, colors, wl_iterations, training)
    elseif method == "wl-unec"
        println(stderr, "WARNING: undirected graphs are not recommended to use and are kept for testing purposes only")
        node_colors = wl_node_edge_cut_undirected_last(g, colors, wl_iterations, training)

    end

    print("\n$(format_colors(node_colors, colors))")
    print(",\n\t\"n_nodes\":$(extra_info["n_nodes"])")
    print(",\n\t\"cpv\":$(extra_info["cpv"])")
    print(",\n\t\"cpp\":$(extra_info["cpp"])")
    print(",\n\t\"d_ratio_int_vars\":$(extra_info["d_ratio_int_vars"])")
    print(",\n\t\"d_ratio_bool_vars\":$(extra_info["d_ratio_bool_vars"])")
    print(",\n\t\"o_deg_cons\":$(extra_info["o_deg_cons"])")
    print(",\n\t\"o_deg_std\":$(extra_info["o_deg_std"])")
    print(",\n\t\"o_dom_deg\":$(extra_info["o_dom_deg"])")
    print(",\n\t\"v_ent_deg_vars\":$(extra_info["v_ent_deg_vars"])")
    print(",\n\t\"v_sum_domdeg_vars\":$(extra_info["v_sum_domdeg_vars"])")
    if method == "wl-nc" || method == "wl-nec"
        for (p, v) in extra_info["globals_pairs"]
            print(",\n\t\"($(p[1]), $(p[2]))\":$(v)")
        end
    end
    print("\n}")
    if training
        Helper.save_colors(colors_path, colors)
    end
end

using Sockets

function start_server(socket_path::String)
    rm(socket_path, force=true)
    server = listen(socket_path)
    println("Server listening on $socket_path")
    while true
        conn = accept(server)
        @async begin
            try
                line = readline(conn)
                args_parsed = String.(split(line, '\0'))
                filter!(x -> !isempty(x), args_parsed)

                original_stdout = stdout
                original_stderr = stderr
                redirect_stdout(conn)
                redirect_stderr(conn)

                try
                    main(args_parsed)
                catch e
                    println(stderr, "ERROR: $e")
                    Base.showerror(stderr, e, catch_backtrace())
                finally
                    redirect_stdout(original_stdout)
                    redirect_stderr(original_stderr)
                    close(conn)
                end
            catch e
                println(stderr, "Connection error: $e")
            end
        end
    end
end

function julia_main()::Cint
    try
        if length(ARGS) >= 2 && ARGS[1] == "--server"
            start_server(ARGS[2])
        else
            main()
        end
    catch e
        Base.showerror(stderr, e, catch_backtrace())
        return 1
    end
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) >= 2 && ARGS[1] == "--server"
        start_server(ARGS[2])
    else
        main()
    end
end


end # module ZincToWl
