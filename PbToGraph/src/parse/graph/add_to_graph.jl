module AddToGraph

using FlatzincToGraph
using FlatzincToGraph.GraphType
using ..PbTerms
using ..PbConstraint
using ..PbSolve

function get_or_create_var(graph::Graph, var_name::String, variables::Dict{String,Node})::Node
    node = get(variables, var_name, nothing)
    if !isnothing(node)
        return node
    end
    id = hash(var_name)
    var_node = Node(var_name, :var_node, id, :bool, 2)
    add_node(graph, var_node)
    variables[var_name] = var_node
    return var_node
end

function get_literal_node(graph::Graph, lit::Variable, variables::Dict{String,Node})::Node
    if lit.is_negative
        base_var = get_or_create_var(graph, lit.name, variables)
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
    return get_or_create_var(graph, lit.name, variables)
end

function get_term_node(graph::Graph, term::Term, variables::Dict{String,Node})::Node
    coeff_str = string(term.coefficient)
    coeff_id = hash(coeff_str)
    coeff_node = get(graph.node_dict, coeff_id, nothing)
    if isnothing(coeff_node)
        coeff_node = Node(coeff_str, :int, coeff_id, :int, 0)
        add_node(graph, coeff_node)
    end

    if isempty(term.variables)
        return coeff_node
    end

    # First, form the product of the literals
    lit_nodes = [get_literal_node(graph, var, variables) for var in term.variables]
    current_prod_node = lit_nodes[1]

    for j in 2:length(lit_nodes)
        next_lit = lit_nodes[j]
        mul_l_label = "$(current_prod_node.id) * $(next_lit.id)"
        mul_l_hash = hash(mul_l_label)
        mul_l_node = get(graph.node_dict, mul_l_hash, nothing)
        if isnothing(mul_l_node)
            mul_l_node = Node(mul_l_label, :mult_node, mul_l_hash)
            add_node(graph, mul_l_node)
            add_edge(graph, current_prod_node.id, mul_l_node.id, Edge(EDGE_0))
            add_edge(graph, next_lit.id, mul_l_node.id, Edge(EDGE_0))
        end
        current_prod_node = mul_l_node
    end

    # Now multiply by coefficient
    mul_label = "$(coeff_node.id) * $(current_prod_node.id)"
    mul_hash = hash(mul_label)
    mul_node = get(graph.node_dict, mul_hash, nothing)
    if isnothing(mul_node)
        mul_node = Node(mul_label, :mult_node, mul_hash)
        add_node(graph, mul_node)
        add_edge(graph, coeff_node.id, mul_node.id, Edge(EDGE_0))
        add_edge(graph, current_prod_node.id, mul_node.id, Edge(EDGE_0))
    end
    return mul_node
end

function add_constraint_to_graph!(graph::Graph, constr::Constraint, variables::Dict{String,Node})
    sum_nodes = Node[get_term_node(graph, t, variables) for t in constr.terms]

    sum_label = "sum(" * join(["$(n.id)" for n in sum_nodes], ", ") * ")"
    sum_hash = hash(sum_label)
    sum_node = get(graph.node_dict, sum_hash, nothing)
    if isnothing(sum_node)
        sum_node = Node(sum_label, :lin_sum_node, sum_hash)
        add_node(graph, sum_node)
        for n in sum_nodes
            add_edge(graph, n.id, sum_node.id, Edge(EDGE_0))
        end
    end

    rhs_str = string(constr.rhs)
    rhs_id = hash(rhs_str)
    rhs_node = get(graph.node_dict, rhs_id, nothing)
    if isnothing(rhs_node)
        rhs_node = Node(rhs_str, :int, rhs_id, :int, 0)
        add_node(graph, rhs_node)
    end

    if constr.type === :leq_node
        leq_label = "$(sum_node.id)<=$(rhs_node.id)"
        leq_hash = hash(leq_label)
        leq = get(graph.node_dict, leq_hash, nothing)
        if isnothing(leq)
            leq = Node(leq_label, :leq_node, leq_hash)
            add_node(graph, leq)
            add_edge(graph, sum_node.id, leq.id, Edge(EDGE_0))
            add_edge(graph, rhs_node.id, leq.id, Edge(EDGE_1))
        end
        top_node = leq
    else
        eq_label = "$(sum_node.id)=$(rhs_node.id)"
        eq_hash = hash(eq_label)
        eq = get(graph.node_dict, eq_hash, nothing)
        if isnothing(eq)
            eq = Node(eq_label, :equality_node, eq_hash)
            add_node(graph, eq)
            add_edge(graph, sum_node.id, eq.id, Edge(EDGE_0))
            add_edge(graph, rhs_node.id, eq.id, Edge(EDGE_0))
        end
        top_node = eq
    end

    if constr.is_weighted && !isnothing(constr.weight)
        weight_str = string(constr.weight)
        weight_id = hash(weight_str)
        weight_node = get(graph.node_dict, weight_id, nothing)
        if isnothing(weight_node)
            weight_node = Node(weight_str, :int, weight_id, :int, 0)
            add_node(graph, weight_node)
        end

        soft_label = "soft($(top_node.id), $(weight_node.id))"
        soft_hash = hash(soft_label)
        soft_node = Node(soft_label, :soft_node, soft_hash)
        add_node(graph, soft_node)
        add_edge(graph, top_node.id, soft_node.id, Edge(EDGE_0))
        add_edge(graph, weight_node.id, soft_node.id, Edge(EDGE_1))
    end
end

function add_solve_to_graph!(graph::Graph, solve::Union{Nothing,SolveType}, variables::Dict{String,Node})
    if isnothing(solve) || isnothing(solve.objectiveVars) || isempty(solve.objectiveVars)
        return
    end

    term_nodes = Node[get_term_node(graph, t, variables) for t in solve.objectiveVars]
    sum_label = "sum(" * join(["$(n.id)" for n in term_nodes], ", ") * ")"
    sum_hash = hash(sum_label)
    sum_node = get(graph.node_dict, sum_hash, nothing)
    if isnothing(sum_node)
        sum_node = Node(sum_label, :lin_sum_node, sum_hash)
        add_node(graph, sum_node)
        for n in term_nodes
            add_edge(graph, n.id, sum_node.id, Edge(EDGE_0))
        end
    end

    obj_name = "obj"
    obj_id = hash(obj_name)
    obj_node = get(graph.node_dict, obj_id, nothing)
    if isnothing(obj_node)
        obj_node = Node(obj_name, :var_node, obj_id, :int, 0)
        add_node(graph, obj_node)
    end

    eq_label = "$(sum_node.id)=$(obj_node.id)"
    eq_hash = hash(eq_label)
    eq_node = get(graph.node_dict, eq_hash, nothing)
    if isnothing(eq_node)
        eq_node = Node(eq_label, :equality_node, eq_hash)
        add_node(graph, eq_node)
        add_edge(graph, sum_node.id, eq_node.id, Edge(EDGE_0))
        add_edge(graph, obj_node.id, eq_node.id, Edge(EDGE_0))
    end

    if solve.type === :min
        min_label = "Minimise(obj)"
        min_id = hash(min_label)
        add_node(graph, Node(min_label, :minimise_node, min_id))
        add_edge(graph, min_id, obj_node.id, Edge(EDGE_0))
    else
        max_label = "Maximise(obj)"
        max_id = hash(max_label)
        add_node(graph, Node(max_label, :maximise_node, max_id))
        add_edge(graph, max_id, obj_node.id, Edge(EDGE_0))
    end
end

export add_constraint_to_graph!, add_solve_to_graph!

end
