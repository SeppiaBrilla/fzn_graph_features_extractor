module WlNodeCut
using FlatzincToGraph.GraphType
using ..Helper

function wl_node_cut_directed_last(g::GraphType.Graph, colors::Dict{String,UInt64}, iterations::Int, training::Bool)::Tuple{Vector{UInt64},Dict{String,Any}}
    n_nodes = length(g.nodes)
    node_idx = Dict{UInt64,Int}(node.id => idx for (idx, node) in enumerate(g.nodes))

    # 1. Initial Node Colors based on typer(node.type)
    for node in g.nodes
        t_type = typer(node.type)
        if !haskey(colors, t_type)
            colors[t_type] = hash(t_type)
        end
    end
    node_colors = [colors[typer(node.type)] for node in g.nodes]

    # Precalculate in-edges and out-degrees for efficiency
    out_degrees = Dict{UInt64,Int}()
    in_edges = Dict{UInt64,Vector{UInt64}}()
    for (from_id, to_id, _) in g.edges
        out_degrees[from_id] = get(out_degrees, from_id, 0) + 1
        if !haskey(in_edges, to_id)
            in_edges[to_id] = UInt64[]
        end
        push!(in_edges[to_id], from_id)
    end

    # 2. WL Propagation Loop
    for _ in 1:iterations
        neib_colors = [UInt64[] for _ in 1:n_nodes]

        for (from_id, to_id, _) in g.edges
            to_node = g.node_dict[to_id]
            if is_global(to_node.type) || startswith(to_node.type, "lin_") || startswith(to_node.type, "multi_")
                continue
            end
            from_i = node_idx[from_id]
            to_i = node_idx[to_id]
            push!(neib_colors[to_i], node_colors[from_i])
        end

        updated_colors = Vector{String}(undef, n_nodes)
        for i in 1:n_nodes
            updated_colors[i] = string(node_colors[i], ",", join(sort!(neib_colors[i]), ","))
        end

        if training
            for uc in unique(updated_colors)
                if !haskey(colors, uc)
                    colors[uc] = hash(uc)
                end
            end
        end

        node_colors = [get(colors, uc, node_colors[i]) for (i, uc) in enumerate(updated_colors)]
    end

    # 3. Extra feature extraction & global pairs calculation
    constraints_per_variable = 0
    constraints_per_par = 0
    n_var = 0
    n_par = 0
    pairs = Dict{Tuple{String,String},Int}()

    for node in g.nodes
        t = typer(node.type)
        if node.type == "var_node"
            constraints_per_variable += get(out_degrees, node.id, 0)
            n_var += 1
        elseif t == "literal_node"
            constraints_per_par += get(out_degrees, node.id, 0)
            n_par += 1
        elseif is_global(node.type) || startswith(node.type, "lin_") || startswith(node.type, "multi_")
            incoming = get(in_edges, node.id, UInt64[])
            for from_id in incoming
                from_node = g.node_dict[from_id]
                pair = (typer(from_node.type), node.type)
                pairs[pair] = get(pairs, pair, 0) + 1
            end
        end
    end

    # 4. Global node color recalculation
    globals_set = sort(unique([p[2] for p in keys(pairs)]))
    for g_type in globals_set
        matching_from_types = sort([p[1] for (p, count) in pairs if p[2] == g_type])
        color_str = g_type * "," * join(matching_from_types, ",")
        h_g = hash(g_type)

        if training && !haskey(colors, color_str)
            colors[color_str] = hash(color_str)
        end
        if haskey(colors, color_str)
            target_color = colors[color_str]
            for i in 1:n_nodes
                if node_colors[i] == h_g
                    node_colors[i] = target_color
                end
            end
        end
    end

    extra_info = Dict{String,Any}(
        "globals_pairs" => pairs,
        "cpv" => n_var > 0 ? constraints_per_variable / n_var : 0.0,
        "cpp" => n_par > 0 ? constraints_per_par / n_par : 0.0,
        "n_nodes" => n_nodes
    )

    return node_colors, extra_info
end

export wl_node_cut_directed_last

end