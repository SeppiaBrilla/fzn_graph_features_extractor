module WlNodeEdgeCut

using FlatzincToGraph.GraphType
using ..Helper

@inline function filter_non_cut_node!(i::Int, g_nodes, in_adj, non_cut_in_adj)
    if !is_cut_node(g_nodes[i].type)
        for (from_i, h_edge) in in_adj[i]
            if !is_cut_node(g_nodes[from_i].type)
                push!(non_cut_in_adj[i], (from_i, h_edge))
            end
        end
    end
end

@inline function init_node_color!(i::Int,
    g_nodes::Vector{Node},
    globals_from_types::Dict{Symbol,Vector{Symbol}},
    curr_colors::Vector{UInt64},
    colors::Dict{UInt64,UInt64},
    colors_lock::ReentrantLock,
    training::Bool)

    node = g_nodes[i]
    if is_cut_node(node.type)
        g_type = node.type
        matching_from_types = get(globals_from_types, g_type, Symbol[])
        color_str = string(g_type) * "," * join(matching_from_types, ",")
        h_color = hash(color_str)
        if training
            if !haskey(colors, h_color)
                lock(colors_lock) do
                    colors[h_color] = h_color
                end
            end
            curr_colors[i] = h_color
        else
            curr_colors[i] = get(colors, h_color, hash(g_type))
        end
    else
        t = typer(node.type)
        h_type = hash(t)
        if training
            if !haskey(colors, h_type)
                lock(colors_lock) do
                    colors[h_type] = h_type
                end
            end
            curr_colors[i] = h_type
        else
            curr_colors[i] = get(colors, h_type, h_type)
        end
    end
end

@inline function process_node!(i::Int,
    g_nodes::Vector{Node},
    non_cut_in_adj::Vector{Vector{Tuple{Int,UInt64}}},
    curr_colors::Vector{UInt64},
    next_colors::Vector{UInt64},
    colors::Dict{UInt64,UInt64},
    colors_lock::ReentrantLock,
    training::Bool,
    buffer::Vector{UInt64})

    node = g_nodes[i]
    if is_cut_node(node.type)
        next_colors[i] = curr_colors[i]
        return
    end

    adj_list = non_cut_in_adj[i]
    neib_buf = view(buffer, 1:length(adj_list))
    for (k, (from_i, h_edge)) in enumerate(adj_list)
        neib_buf[k] = hash(curr_colors[from_i], h_edge)
    end
    sort!(neib_buf)

    h_key = tailored_hash(curr_colors[i], neib_buf)

    if training
        if !haskey(colors, h_key)
            lock(colors_lock) do
                colors[h_key] = h_key
            end
        end
        next_colors[i] = h_key
    else
        next_colors[i] = get(colors, h_key, curr_colors[i])
    end
end

function wl_node_edge_cut_directed_last(g::GraphType.Graph, colors::Dict{UInt64,UInt64}, iterations::Int, training::Bool, num_cores::Int=1)::Vector{UInt64}
    n_nodes = length(g.nodes)
    if n_nodes == 0
        return UInt64[]
    end

    use_parallel = n_nodes >= 1000 && num_cores > 1 && Threads.maxthreadid() > 1
    colors_lock = ReentrantLock()


    out_degrees = Dict{UInt64,Int}()
    pairs = Dict{Tuple{Symbol,Symbol},Int}()

    for (from_id, to_id, _) in g.edges
        out_degrees[from_id] = get(out_degrees, from_id, 0) + 1

        to_node = g.node_dict[to_id]
        if is_cut_node(to_node.type)
            from_node = g.node_dict[from_id]
            pair = (typer(from_node.type), to_node.type)
            pairs[pair] = get(pairs, pair, 0) + 1
        end
    end

    # 1. Parallel non-cut adjacency pre-filtering
    non_cut_in_adj = [Tuple{Int,UInt64}[] for _ in 1:n_nodes]


    if use_parallel
        Threads.@threads :static for i in 1:n_nodes
            filter_non_cut_node!(i, g.nodes, g.in_adj, non_cut_in_adj)
        end
    else
        for i in 1:n_nodes
            filter_non_cut_node!(i, g.nodes, g.in_adj, non_cut_in_adj)
        end
    end

    max_degree = maximum(length(adj_list) for adj_list in non_cut_in_adj; init=0)
    buffer = [Vector{UInt64}(undef, max_degree) for _ in 1:Threads.maxthreadid()]

    # 2. Statistics calculation
    constraints_per_variable = 0
    constraints_per_par = 0
    n_var = 0
    n_par = 0
    for node in g.nodes
        t = typer(node.type)
        if node.type === :var_node
            constraints_per_variable += get(out_degrees, node.id, 0)
            n_var += 1
        elseif t === :literal_node
            constraints_per_par += get(out_degrees, node.id, 0)
            n_par += 1
        end
    end

    globals_from_types = Dict{Symbol,Vector{Symbol}}()
    for (pair, _) in pairs
        g_type = pair[2]
        if !haskey(globals_from_types, g_type)
            globals_from_types[g_type] = Symbol[]
        end
        push!(globals_from_types[g_type], pair[1])
    end
    for (g_type, v) in globals_from_types
        sort!(v)
    end

    # 3. Parallel initial color assignment
    curr_colors = Vector{UInt64}(undef, n_nodes)
    if use_parallel
        Threads.@threads :static for i in 1:n_nodes
            init_node_color!(i, g.nodes, globals_from_types, curr_colors, colors, colors_lock, training)
        end
    else
        for i in 1:n_nodes
            init_node_color!(i, g.nodes, globals_from_types, curr_colors, colors, colors_lock, training)
        end
    end

    # 4. Main WL iterations loop
    next_colors = Vector{UInt64}(undef, n_nodes)

    for _ in 1:iterations
        if use_parallel
            Threads.@threads :static for i in 1:n_nodes
                process_node!(i, g.nodes, non_cut_in_adj, curr_colors, next_colors, colors, colors_lock, training, buffer[Threads.threadid()])
            end
        else
            for i in 1:n_nodes
                process_node!(i, g.nodes, non_cut_in_adj, curr_colors, next_colors, colors, colors_lock, training, buffer[1])
            end
        end
        curr_colors, next_colors = next_colors, curr_colors
    end

    return curr_colors
end

export wl_node_edge_cut_directed_last

end