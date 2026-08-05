module NodeEdgeWl

using FlatzincToGraph.GraphType
using ..Helper

function wl_node_edge_directed_last(g::GraphType.Graph, colors::Dict{String,UInt64}, iterations::Int, training::Bool)::Vector{UInt64}
    node_idx = Dict{UInt64,Int}(node.id => idx for (idx, node) in enumerate(g.nodes))
    n_nodes = length(g.nodes)

    for node in g.nodes
        t_type = typer(node.type)
        if !haskey(colors, t_type)
            colors[t_type] = hash(t_type)
        end
    end
    node_colors = [colors[typer(node.type)] for node in g.nodes]

    for _ in 1:iterations
        neib_colors = [String[] for _ in 1:n_nodes]

        for (from_id, to_id, edge_type) in g.edges
            from_i = node_idx[from_id]
            to_i = node_idx[to_id]
            push!(neib_colors[to_i], string(node_colors[from_i]) * "-" * edge_type)
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

    return node_colors
end

export wl_node_edge_directed_last

end
