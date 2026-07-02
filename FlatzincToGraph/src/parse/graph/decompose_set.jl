module DecomposeSetConstraints

using ...GraphType
using ...Parameters
using ...Variables
using ...Helper
using ...GraphHelper

function decompose_array_set_element(args::Vector{Any}, graph::Graph)::Graph
    b = args[1]
    _as = args[2]
    c = args[3]

    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "set of int")
    _as_node = get_node_for_val(graph, _as, "set of int")

    index_label = "$(_as_node.label)[$(b_node.label)]"
    index_hash = hash(index_label)
    index_node = Node(index_label, "index_node", build_generic_value(index_hash, index_label, "index_node"), index_hash)
    add_node(graph, index_node)

    eq_label = "$(index_node.label) = $(c_node.label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, _as_node.id, index_node.id, Edge("0"))
    add_edge(graph, b_node.id, index_node.id, Edge("1"))
    add_edge(graph, b_node.id, index_node.id, Edge("0"))
    add_edge(graph, index_node.id, equality_node.id, Edge("0"))
    add_edge(graph, c_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_array_var_set_element(args::Vector{Any}, graph::Graph)::Graph
    return decompose_array_set_element(args, graph)
end

function decompose_set_card(args::Vector{Any}, graph::Graph)::Graph
    s = args[1]
    x = args[2]

    s_node = get_node_for_val(graph, s, "set of int")
    x_node = get_node_for_val(graph, x, "int")

    card_label = "|$(s_node.label)|"
    card_hash = hash(card_label)
    card_node = Node(card_label, "card_node", build_generic_value(card_hash, card_label, "card_node"), card_hash)
    add_node(graph, card_node)

    eq_label = "$(x_node.label) = $(card_node.label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, s_node.id, card_node.id, Edge("0"))
    add_edge(graph, card_node.id, equality_node.id, Edge("0"))
    add_edge(graph, x_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_set_diff(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "set of int")

    diff_label = "$(x_node.label) \\ $(y_node.label)"
    diff_hash = hash(diff_label)
    diff_node = Node(diff_label, "diff_node", build_generic_value(diff_hash, diff_label, "diff_node"), diff_hash)
    add_node(graph, diff_node)

    eq_label = "$(r_node.label) = $(diff_label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, x_node.id, diff_node.id, Edge("0"))
    add_edge(graph, y_node.id, diff_node.id, Edge("1"))
    add_edge(graph, diff_node.id, equality_node.id, Edge("0"))
    add_edge(graph, r_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_set_eq(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")

    eq_label = "$(x_node.label) = $(y_node.label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, x_node.id, equality_node.id, Edge("0"))
    add_edge(graph, y_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_set_eq_reif(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "bool")

    eq_label = "$(x_node.label) = $(y_node.label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    iff_label = "$(r_node.label) <-> ($(eq_label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)
    add_node(graph, iff_node)

    add_edge(graph, x_node.id, equality_node.id, Edge("0"))
    add_edge(graph, y_node.id, equality_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, equality_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_set_in_reif(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    s = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "int")
    s_node = get_node_for_val(graph, s, "set of int")
    r_node = get_node_for_val(graph, r, "bool")

    in_label = "$(x_node.label) in $(s_node.label)"
    in_hash = hash(in_label)
    in_node = Node(in_label, "in_node", build_generic_value(in_hash, in_label, "in_node"), in_hash)
    add_node(graph, in_node)

    iff_label = "$(r_node.label) <-> ($(in_label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)
    add_node(graph, iff_node)

    add_edge(graph, x_node.id, in_node.id, Edge("0"))
    add_edge(graph, s_node.id, in_node.id, Edge("1"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, in_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_set_intersect(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "set of int")

    intersect_label = "$(x_node.label) /\\ $(y_node.label)"
    intersect_hash = hash(intersect_label)
    intersect_node = Node(intersect_label, "intersect_node", build_generic_value(intersect_hash, intersect_label, "intersect_node"), intersect_hash)
    add_node(graph, intersect_node)

    eq_label = "$(r_node.label) = $(intersect_label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, x_node.id, intersect_node.id, Edge("0"))
    add_edge(graph, y_node.id, intersect_node.id, Edge("1"))
    add_edge(graph, intersect_node.id, equality_node.id, Edge("0"))
    add_edge(graph, r_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_set_le(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")

    leq_label = "$(x_node.label) <= $(y_node.label)"
    leq_hash = hash(leq_label)
    leq_node = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    add_node(graph, leq_node)

    add_edge(graph, x_node.id, leq_node.id, Edge("0"))
    add_edge(graph, y_node.id, leq_node.id, Edge("1"))

    return graph
end

function decompose_set_le_reif(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "bool")

    leq_label = "$(x_node.label) <= $(y_node.label)"
    leq_hash = hash(leq_label)
    leq_node = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    add_node(graph, leq_node)

    iff_label = "$(r_node.label) <-> ($(leq_label))"
    iff_node = Node(iff_label, "iff_node", build_generic_value(hash(iff_label), iff_label, "iff_node"), hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x_node.id, leq_node.id, Edge("0"))
    add_edge(graph, y_node.id, leq_node.id, Edge("1"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, leq_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_set_lt(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")

    le_label = "$(x_node.label) < $(y_node.label)"
    le_hash = hash(le_label)
    le_node = Node(le_label, "le_node", build_generic_value(le_hash, le_label, "le_node"), le_hash)
    add_node(graph, le_node)

    add_edge(graph, x_node.id, le_node.id, Edge("0"))
    add_edge(graph, y_node.id, le_node.id, Edge("1"))

    return graph
end

function decompose_set_lt_reif(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "bool")

    leq_label = "$(x_node.label) <= $(y_node.label)"
    leq_node = Node(leq_label, "le_node", build_generic_value(hash(leq_label), leq_label, "le_node"), hash(leq_label))
    add_node(graph, leq_node)

    iff_label = "$(r_node.label) <-> ($(leq_label))"
    iff_node = Node(iff_label, "iff_node", build_generic_value(hash(iff_label), iff_label, "iff_node"), hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x_node.id, leq_node.id, Edge("0"))
    add_edge(graph, y_node.id, leq_node.id, Edge("1"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, leq_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_set_ne(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")

    ineq_label = "$(x_node.label) != $(y_node.label)"
    inequality_node = Node(ineq_label, "inequality_node", build_generic_value(hash(ineq_label), ineq_label, "inequality_node"), hash(ineq_label))
    add_node(graph, inequality_node)

    add_edge(graph, x_node.id, inequality_node.id, Edge("0"))
    add_edge(graph, y_node.id, inequality_node.id, Edge("0"))

    return graph
end

function decompose_set_ne_reif(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "bool")

    ineq_label = "$(x_node.label) != $(y_node.label)"
    inequality_node = Node(ineq_label, "inequality_node", build_generic_value(hash(ineq_label), ineq_label, "inequality_node"), hash(ineq_label))
    add_node(graph, inequality_node)

    iff_label = "$(r_node.label) <-> ($(ineq_label))"
    iff_node = Node(iff_label, "iff_node", iff_label, hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x_node.id, inequality_node.id, Edge("0"))
    add_edge(graph, y_node.id, inequality_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, inequality_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_set_subset(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")

    subset_label = "$(x_node.label) \\subset $(y_node.label)"
    subset_node = Node(subset_label, "subset_node", subset_label, hash(subset_label))
    add_node(graph, subset_node)

    add_edge(graph, x_node.id, subset_node.id, Edge("0"))
    add_edge(graph, y_node.id, subset_node.id, Edge("0"))

    return graph
end

function decompose_set_subset_reif(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "bool")

    subset_label = "$(x_node.label) \\subset $(y_node.label)"
    subset_node = Node(subset_label, "subset_node", subset_label, hash(subset_label))
    add_node(graph, subset_node)

    iff_label = "$(r_node.label) <-> ($(subset_label))"
    iff_node = Node(iff_label, "iff_node", iff_label, hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x_node.id, subset_node.id, Edge("0"))
    add_edge(graph, y_node.id, subset_node.id, Edge("1"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, subset_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_set_superset(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")

    subset_label = "$(y_node.label) \\subset $(x_node.label)"
    subset_node = Node(subset_label, "subset_node", subset_label, hash(subset_label))
    add_node(graph, subset_node)

    add_edge(graph, x_node.id, subset_node.id, Edge("0"))
    add_edge(graph, y_node.id, subset_node.id, Edge("0"))

    return graph
end

function decompose_set_superset_reif(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "bool")

    subset_label = "$(y_node.label) \\subset $(x_node.label)"
    subset_node = Node(subset_label, "subset_node", subset_label, hash(subset_label))
    add_node(graph, subset_node)

    iff_label = "$(r_node.label) <-> ($(subset_label))"
    iff_node = Node(iff_label, "iff_node", iff_label, hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x_node.id, subset_node.id, Edge("0"))
    add_edge(graph, y_node.id, subset_node.id, Edge("1"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, subset_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_set_symdiff(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "set of int")

    symdiff_label = "$(x_node.label) symdiff $(y_node.label)"
    symdiff_node = Node(symdiff_label, "symdiff_node", build_generic_value(hash(symdiff_label), symdiff_label, "symdiff_node"), hash(symdiff_label))
    add_node(graph, symdiff_node)

    eq_label = "$(r_node.label) = $(symdiff_label)"
    equality_node = Node(eq_label, "equality_node", build_generic_value(hash(eq_label), eq_label, "equality_node"), hash(eq_label))
    add_node(graph, equality_node)

    add_edge(graph, x_node.id, symdiff_node.id, Edge("0"))
    add_edge(graph, y_node.id, symdiff_node.id, Edge("1"))
    add_edge(graph, symdiff_node.id, equality_node.id, Edge("0"))
    add_edge(graph, r_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_set_union(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    x_node = get_node_for_val(graph, x, "set of int")
    y_node = get_node_for_val(graph, y, "set of int")
    r_node = get_node_for_val(graph, r, "set of int")

    union_label = "$(x_node.label) union $(y_node.label)"
    union_node = Node(union_label, "union_node", build_generic_value(hash(union_label), union_label, "union_node"), hash(union_label))
    add_node(graph, union_node)

    eq_label = "$(r_node.label) = $(union_label)"
    equality_node = Node(eq_label, "equality_node", build_generic_value(hash(eq_label), eq_label, "equality_node"), hash(eq_label))
    add_node(graph, equality_node)

    add_edge(graph, x_node.id, union_node.id, Edge("0"))
    add_edge(graph, y_node.id, union_node.id, Edge("0"))
    add_edge(graph, union_node.id, equality_node.id, Edge("0"))
    add_edge(graph, r_node.id, equality_node.id, Edge("0"))

    return graph
end

export decompose_array_set_element, decompose_array_var_set_element, decompose_set_card,
       decompose_set_diff, decompose_set_eq, decompose_set_eq_reif, decompose_set_in_reif,
       decompose_set_intersect, decompose_set_le, decompose_set_le_reif, decompose_set_lt,
       decompose_set_lt_reif, decompose_set_ne, decompose_set_ne_reif, decompose_set_subset,
       decompose_set_subset_reif, decompose_set_superset, decompose_set_superset_reif,
       decompose_set_symdiff, decompose_set_union

end
