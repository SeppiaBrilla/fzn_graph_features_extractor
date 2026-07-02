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
    edges::IdDict{Tuple{UInt64,UInt64},Edge}
    edge_from::IdDict{UInt64,Vector{Tuple{UInt64,Edge}}}
    edge_to::IdDict{UInt64,Vector{Tuple{UInt64,Edge}}}
    node_dict::IdDict{UInt64,Node}
end

# Outer constructor for empty Graph
Graph() = Graph(
    Node[],
    IdDict{Tuple{Int,Int},Edge}(),
    IdDict{UInt64,Vector{Tuple{Node,Edge}}}(),
    IdDict{UInt64,Vector{Tuple{Node,Edge}}}(),
    IdDict{UInt64,Node}()
)

function add_node(graph::Graph, node::Node)::Graph
    if haskey(graph.node_dict, node.id)
        return graph
    end
    push!(graph.nodes, node)
    graph.node_dict[node.id] = node
    return graph
end

function add_edge(graph::Graph, _from::UInt64, _to::UInt64, e::Edge)::Graph
    if !haskey(graph.node_dict, _from)
        throw(error("node from not present"))
    elseif !haskey(graph.node_dict, _to)
        throw(error("node to not present"))
    end
    if haskey(graph.edges, (_from, _to))
        return graph
    end
    graph.edges[(_from, _to)] = e
    if !haskey(graph.edge_to, _to)
        graph.edge_to[_to] = []
    end
    if !haskey(graph.edge_from, _from)
        graph.edge_from[_from] = []
    end
    push!(graph.edge_to[_to], (_from, e))
    push!(graph.edge_from[_from], (_to, e))
    return graph

end
export Graph, Node, Edge, add_node, add_edge

end
