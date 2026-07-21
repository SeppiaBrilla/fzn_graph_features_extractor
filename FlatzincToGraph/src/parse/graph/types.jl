module GraphType

struct Edge
    label::String
end

struct Node
    label::String
    type::String
    value::String
    id::UInt64
end

struct Graph
    nodes::Vector{Node}
    edges::Vector{Tuple{UInt64,UInt64,String}}
    edge_set::Set{UInt128}
    node_dict::Dict{UInt64,Node}
end

# Outer constructor for empty Graph
Graph() = Graph(
    Node[],
    Tuple{UInt64,UInt64,String}[],
    Set{UInt128}(),
    Dict{UInt64,Node}()
)

function add_node(graph::Graph, node::Node)::Graph
    if !haskey(graph.node_dict, node.id)
        push!(graph.nodes, node)
        graph.node_dict[node.id] = node
    end
    return graph
end

function add_edge(graph::Graph, _from::UInt64, _to::UInt64, e::Edge)::Graph
    key = (UInt128(_from) << 64) | UInt128(_to)
    if !(key in graph.edge_set)
        push!(graph.edge_set, key)
        push!(graph.edges, (_from, _to, e.label))
    end
    return graph
end

export Graph, Node, Edge, add_node, add_edge

end
