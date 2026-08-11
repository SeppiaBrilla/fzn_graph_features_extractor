module GraphType

struct Edge
    label::Symbol
end

struct Node
    label::String
    type::Symbol
    value::String
    id::UInt64
end

const EDGE_0 = Symbol(0)
const EDGE_1 = Symbol(1)
const EDGE_2 = Symbol(2)

const HASH_EDGE_0 = hash(EDGE_0)
const HASH_EDGE_1 = hash(EDGE_1)
const HASH_EDGE_2 = hash(EDGE_2)

@inline function fast_edge_hash(edge_type::Symbol)::UInt64
    if edge_type === EDGE_0
        return HASH_EDGE_0
    elseif edge_type === EDGE_1
        return HASH_EDGE_1
    elseif edge_type === EDGE_2
        return HASH_EDGE_2
    else
        return hash(edge_type)
    end
end
@inline fast_edge_hash(edge_type::String)::UInt64 = fast_edge_hash(Symbol(edge_type))

struct Graph
    nodes::Vector{Node}
    edges::Vector{Tuple{UInt64,UInt64,Symbol}}
    edge_set::Set{UInt128}
    node_dict::Dict{UInt64,Node}
    node_idx::Dict{UInt64,Int}
    in_adj::Vector{Vector{Tuple{Int,UInt64}}}
end

# Outer constructor for empty Graph
Graph() = Graph(
    Node[],
    Tuple{UInt64,UInt64,Symbol}[],
    Set{UInt128}(),
    Dict{UInt64,Node}(),
    Dict{UInt64,Int}(),
    Vector{Tuple{Int,UInt64}}[]
)

function add_node(graph::Graph, node::Node)::Graph
    if !haskey(graph.node_dict, node.id)
        push!(graph.nodes, node)
        idx = length(graph.nodes)
        graph.node_dict[node.id] = node
        graph.node_idx[node.id] = idx
        push!(graph.in_adj, Tuple{Int,UInt64}[])
    end
    return graph
end

function add_edge(graph::Graph, _from::UInt64, _to::UInt64, e::Edge)::Graph
    key = (UInt128(_from) << 64) | UInt128(_to)
    if !(key in graph.edge_set)
        push!(graph.edge_set, key)
        push!(graph.edges, (_from, _to, e.label))
        if haskey(graph.node_idx, _to) && haskey(graph.node_idx, _from)
            to_i = graph.node_idx[_to]
            from_i = graph.node_idx[_from]
            push!(graph.in_adj[to_i], (from_i, fast_edge_hash(e.label)))
        end
    end
    return graph
end

export Graph, Node, Edge, add_node, add_edge, fast_edge_hash, EDGE_0, EDGE_1, EDGE_2

end
