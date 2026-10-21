module AddToGraph

using FlatzincToGraph
using FlatzincToGraph.GraphType
using ..SatTerms
using ..SatClause

function get_or_create_var(graph::Graph, var_id::Int64, variables::Dict{Int64,Node})::Node
    node = get(variables, var_id, nothing)
    if !isnothing(node)
        return node
    end
    var_name = "x$(var_id)"
    h_id = hash(var_name)
    var_node = Node(var_name, :var_node, h_id, :bool, 2)
    add_node(graph, var_node)
    variables[var_id] = var_node
    return var_node
end

function get_not_node(graph::Graph, base_var::Node)::Node
    not_label = "not $(base_var.label)"
    not_hash = hash(not_label)
    not_node = get(graph.node_dict, not_hash, nothing)
    if isnothing(not_node)
        not_node = Node(not_label, :not_node, not_hash)
        add_node(graph, not_node)
        add_edge(graph, base_var.id, not_node.id, Edge(EDGE_0))
    end
    return not_node
end

"""
    add_clause_to_graph!(graph, clause, variables)

Decomposes a CNF clause (pos_lits \\/ neg_lits) identically to FlatZinc's decompose_bool_clause:
  - If pos_lits exist: creates multi_or_node for pos_lits
  - If neg_lits exist: creates not_node for each neg_lit, and multi_or_node for not_nodes
  - If both exist: creates or_node combining pos_or and neg_or
"""
function add_clause_to_graph!(graph::Graph, clause::Clause, variables::Dict{Int64,Node})
    pos_nodes = Node[get_or_create_var(graph, lit.var_id, variables) for lit in clause.pos_lits]
    neg_nodes = Node[get_not_node(graph, get_or_create_var(graph, lit.var_id, variables)) for lit in clause.neg_lits]

    a_or = nothing
    if length(pos_nodes) > 0
        a_or_label = join([_n.label for _n in pos_nodes], " \\\\/ ")
        a_or_hash = hash(a_or_label)
        a_or = get(graph.node_dict, a_or_hash, nothing)
        if isnothing(a_or)
            a_or = Node(a_or_label, :multi_or_node, a_or_hash)
            add_node(graph, a_or)
            for _n in pos_nodes
                add_edge(graph, _n.id, a_or.id, Edge(EDGE_0))
            end
        end
    end

    b_or = nothing
    if length(neg_nodes) > 0
        b_or_label = join([_n.label for _n in neg_nodes], " \\\\/ ")
        b_or_hash = hash(b_or_label)
        b_or = get(graph.node_dict, b_or_hash, nothing)
        if isnothing(b_or)
            b_or = Node(b_or_label, :multi_or_node, b_or_hash)
            add_node(graph, b_or)
            for _n in neg_nodes
                add_edge(graph, _n.id, b_or.id, Edge(EDGE_0))
            end
        end
    end

    if !isnothing(a_or) && !isnothing(b_or)
        a_or_not_b_label = "$(a_or.label) \\\\/ $(b_or.label)"
        a_or_not_b_hash = hash(a_or_not_b_label)
        a_or_not_b = get(graph.node_dict, a_or_not_b_hash, nothing)
        if isnothing(a_or_not_b)
            a_or_not_b = Node(a_or_not_b_label, :or_node, a_or_not_b_hash)
            add_node(graph, a_or_not_b)
            add_edge(graph, a_or.id, a_or_not_b.id, Edge(EDGE_0))
            add_edge(graph, b_or.id, a_or_not_b.id, Edge(EDGE_0))
        end
    end
end

export add_clause_to_graph!

end
