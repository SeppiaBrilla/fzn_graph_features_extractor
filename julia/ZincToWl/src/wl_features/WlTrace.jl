module WlTrace

using FlatzincToGraph.GraphType
using ..Helper

export TraceState, ColorInfo, trace!, TRACE_METHODS

const TRACE_METHODS = ("wl", "wl-n", "wl-e", "wl-ne", "wl-nc", "wl-nec")

"""
    ColorInfo

Aggregated information about a single WL color (a `UInt64` hash) observed
while tracing a corpus of graphs in training mode.

Fields:
- `h`            : the color hash itself
- `kind`         : `:type` (hash of a node type), `:neutral` (the all-zero initial
                   color of untyped WL), `:cut` (hash of a cut-node signature),
                   `:refined` (produced by a refinement step) or `:unknown`
                   (seed color never observed during the replay)
- `sig`          : human readable origin for root colors (`""` for refined ones)
- `self_parent`  : for refined colors, the node's own color before refinement
- `nbs`          : for refined colors, the sorted multiset of neighbor entries as
                   `(mixed value, neighbor color, labels, multiplicity)`. The mixed
                   value is what actually enters the hash: the neighbor color
                   itself for `wl`/`wl-n`/`wl-nc`, or `hash(neighbor color, edge
                   hash)` for edge-aware methods. `labels` is the `/`-joined set
                   of edge labels of the aggregated neighbors.
- `first_file`   : 1-based index of the file where the color was first seen
- `first_level`  : 0-based level where the color was first seen (0 = initialization)
- `hist`         : occurrences per level, aggregated over the whole corpus
- `g_init`       : number of graphs where the color occurs at initialization
- `g_final`      : number of graphs where the color occurs at the final level
- `per_graph`    : `(file index => final level count)` entries
"""
mutable struct ColorInfo
    h::UInt64
    kind::Symbol
    sig::String
    self_parent::UInt64
    nbs::Vector{Tuple{UInt64,UInt64,String,Int}}
    first_file::Int
    first_level::Int
    hist::Vector{Int}
    g_init::Int
    g_final::Int
    per_graph::Vector{Pair{Int,Int}}
end

function ColorInfo(h::UInt64, kind::Symbol, sig::String, first_file::Int, first_level::Int, n_levels::Int)
    return ColorInfo(h, kind, sig, UInt64(0), Tuple{UInt64,UInt64,String,Int}[],
        first_file, first_level, zeros(Int, n_levels), 0, 0, Pair{Int,Int}[])
end

"""
    TraceState(method, iterations)

Accumulator for a corpus replay. Pass it (together with a file index) to
[`trace!`] for every graph of the corpus, always in the same order.
"""
mutable struct TraceState
    method::String
    iterations::Int
    colors::Dict{UInt64,ColorInfo}
    order::Vector{UInt64}
end

function TraceState(method::String, iterations::Int)
    method in TRACE_METHODS || error("unsupported method \"$method\"; expected one of $TRACE_METHODS")
    iterations >= 0 || error("iterations must be >= 0")
    return TraceState(method, iterations, Dict{UInt64,ColorInfo}(), UInt64[])
end

# Distinct (typer(from type), cut type) pairs for edges entering cut nodes.
# Mirrors the construction in WlNodeCut/WlNodeEdgeCut: for every cut node type,
# the sorted list of distinct neighbor types it is connected from.
function _globals_from_types(g::Graph)::Dict{Symbol,Vector{Symbol}}
    pairs = Set{Tuple{Symbol,Symbol}}()
    for (from_id, to_id, _) in g.edges
        to_node = get(g.node_dict, to_id, nothing)
        to_node === nothing && continue
        if is_cut_node(to_node.type)
            from_node = get(g.node_dict, from_id, nothing)
            from_node === nothing && continue
            push!(pairs, (typer(from_node.type), to_node.type))
        end
    end
    gft = Dict{Symbol,Vector{Symbol}}()
    for (ft, gt) in pairs
        push!(get!(() -> Symbol[], gft, gt), ft)
    end
    for v in values(gft)
        sort!(v)
    end
    return gft
end

# Adjacency list with, for each neighbor, the edge hash actually used by the WL
# kernels (taken from g.in_adj, the same source of truth used by the original
# implementations) plus the original edge label for display purposes.
function _adjacency(g::Graph, cut_mode::Bool)
    n = length(g.nodes)
    labels = Dict{Pair{Int,Int},String}()
    for (from_id, to_id, label) in g.edges
        fi = get(g.node_idx, from_id, 0)
        ti = get(g.node_idx, to_id, 0)
        (fi > 0 && ti > 0) || continue
        key = fi => ti
        if !haskey(labels, key)
            labels[key] = String(label)
        end
    end
    adj = [Tuple{Int,UInt64,String}[] for _ in 1:n]
    for to_i in 1:n
        if cut_mode && is_cut_node(g.nodes[to_i].type)
            continue
        end
        for (from_i, h_edge) in g.in_adj[to_i]
            if cut_mode && is_cut_node(g.nodes[from_i].type)
                continue
            end
            push!(adj[to_i], (from_i, h_edge, get(labels, from_i => to_i, "")))
        end
    end
    return adj
end

@inline function _init_color(node::Node, gft::Dict{Symbol,Vector{Symbol}}, method::String)
    if method == "wl" || method == "wl-e"
        return UInt64(0), :neutral, "neutral (0)"
    elseif method == "wl-n" || method == "wl-ne"
        t = typer(node.type)
        return hash(t), :type, string(t)
    else # cut methods: wl-nc, wl-nec
        if is_cut_node(node.type)
            matching = get(gft, node.type, Symbol[])
            sig = string(node.type) * "," * join(matching, ",")
            return hash(sig), :cut, sig
        end
        t = typer(node.type)
        return hash(t), :type, string(t)
    end
end

function _record_init!(st::TraceState, h::UInt64, kind::Symbol, sig::String, file_idx::Int)
    haskey(st.colors, h) && return
    st.colors[h] = ColorInfo(h, kind, sig, file_idx, 0, st.iterations + 1)
    push!(st.order, h)
end

# Aggregate the sorted neighbor entries into the compact multiset that will be
# serialized: group by identical mixed value, join the distinct edge labels.
function _record_refined!(st::TraceState, h_key::UInt64, self_color::UInt64,
    entries::Vector{Tuple{UInt64,UInt64,String}}, file_idx::Int, level::Int)

    nbs = Tuple{UInt64,UInt64,String,Int}[]
    i = 1
    while i <= length(entries)
        j = i
        labels = Set{String}()
        while j <= length(entries) && entries[j][1] == entries[i][1]
            if !isempty(entries[j][3])
                push!(labels, entries[j][3])
            end
            j += 1
        end
        push!(nbs, (entries[i][1], entries[i][2], join(sort(collect(labels)), "/"), j - i))
        i = j
    end

    info = ColorInfo(h_key, :refined, "", file_idx, level, st.iterations + 1)
    info.self_parent = self_color
    info.nbs = nbs
    st.colors[h_key] = info
    push!(st.order, h_key)
end

"""
    trace!(st::TraceState, g::Graph, file_idx::Int) -> Vector{Vector{UInt64}}

Runs the selected WL method on `g` exactly like the training-mode kernels of
ZincToWl, recording every newly discovered color (with its derivation) into `st`
and counting occurrences per level. Returns the colors of every node at every
level (`levels[level][node]`, level 1 being the initialization).
"""
function trace!(st::TraceState, g::Graph, file_idx::Int)::Vector{Vector{UInt64}}
    m = st.method
    k = st.iterations
    n = length(g.nodes)

    if n == 0
        return [UInt64[] for _ in 1:(k + 1)]
    end

    cut_mode = (m == "wl-nc" || m == "wl-nec")
    use_edges = (m == "wl-e" || m == "wl-ne" || m == "wl-nec")

    gft = cut_mode ? _globals_from_types(g) : Dict{Symbol,Vector{Symbol}}()
    adj = _adjacency(g, cut_mode)

    # --- initialization (level 0) ---
    curr = Vector{UInt64}(undef, n)
    init_set = Set{UInt64}()
    for i in 1:n
        h, kind, sig = _init_color(g.nodes[i], gft, m)
        curr[i] = h
        _record_init!(st, h, kind, sig, file_idx)
        push!(init_set, h)
    end
    for h in init_set
        st.colors[h].g_init += 1
    end
    for i in 1:n
        st.colors[curr[i]].hist[1] += 1
    end

    levels = [copy(curr)]

    # --- refinement iterations ---
    max_deg = maximum(length(a) for a in adj; init=0)
    buf = Vector{UInt64}(undef, max_deg)
    entries = Tuple{UInt64,UInt64,String}[]

    for it in 1:k
        nxt = Vector{UInt64}(undef, n)
        for i in 1:n
            if cut_mode && is_cut_node(g.nodes[i].type)
                nxt[i] = curr[i]
                continue
            end
            a = adj[i]
            empty!(entries)
            sizehint!(entries, length(a))
            for (kk, (from_i, h_edge, label)) in enumerate(a)
                mixed = use_edges ? hash(curr[from_i], h_edge) : curr[from_i]
                push!(entries, (mixed, curr[from_i], label))
            end
            # the original kernels hash the sorted multiset of mixed values
            sort!(entries, by = e -> e[1])
            for kk in 1:length(a)
                buf[kk] = entries[kk][1]
            end
            h_key = tailored_hash(curr[i], view(buf, 1:length(a)))
            nxt[i] = h_key
            if !haskey(st.colors, h_key)
                _record_refined!(st, h_key, curr[i], entries, file_idx, it)
            end
        end
        curr = nxt
        push!(levels, copy(curr))
        for i in 1:n
            st.colors[curr[i]].hist[it + 1] += 1
        end
    end

    # --- final level per-graph counts ---
    final_counts = Dict{UInt64,Int}()
    for c in curr
        final_counts[c] = get(final_counts, c, 0) + 1
    end
    for (h, cnt) in final_counts
        info = st.colors[h]
        info.g_final += 1
        push!(info.per_graph, file_idx => cnt)
    end

    return levels
end

end # module
