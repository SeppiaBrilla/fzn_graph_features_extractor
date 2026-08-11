module EdgeWl

using FlatzincToGraph.GraphType
using ..Helper

@inline function process_node!(i::Int, in_adj::Vector{Vector{Tuple{Int,UInt64}}}, curr_colors::Vector{UInt64}, next_colors::Vector{UInt64}, colors::Dict{UInt64,UInt64}, colors_lock::ReentrantLock, training::Bool, buffer::Vector{UInt64})
    adj_list = in_adj[i]
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

function wl_edge_directed_last(g::GraphType.Graph, colors::Dict{UInt64,UInt64}, iterations::Int, training::Bool, num_cores::Int=1)::Vector{UInt64}
    n_nodes = length(g.nodes)
    if n_nodes == 0
        return UInt64[]
    end

    in_adj = g.in_adj
    curr_colors = zeros(UInt64, n_nodes)
    next_colors = Vector{UInt64}(undef, n_nodes)
    colors_lock = ReentrantLock()

    use_parallel = n_nodes >= 1000 && num_cores > 1 && Threads.nthreads() > 1

    max_degree = maximum(length(adj_list) for adj_list in in_adj; init=0)
    buffer = [Vector{UInt64}(undef, max_degree) for _ in 1:Threads.nthreads()]

    for _ in 1:iterations
        if use_parallel
            Threads.@threads for i in 1:n_nodes
                process_node!(i, in_adj, curr_colors, next_colors, colors, colors_lock, training, buffer[Threads.threadid()])
            end
        else
            for i in 1:n_nodes
                process_node!(i, in_adj, curr_colors, next_colors, colors, colors_lock, training, buffer[1])
            end
        end
        curr_colors, next_colors = next_colors, curr_colors
    end

    return curr_colors
end

export wl_edge_directed_last

end
