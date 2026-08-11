module DecomposeSetConstraints

using ...GraphType
using ...Parameters
using ...Variables
using ...Helper
using ...GraphHelper

function decompose_array_set_element(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    b = args[1]
    _as = args[2]
    c = args[3]


    index_label = "$(_as.label)[$(b.label)]"
    index_hash = hash(index_label)
    index_node = Node(index_label, :index_node, build_generic_value(index_hash, index_label, "index_node"), index_hash)
    add_node(graph, index_node)

    eq_label = "$(index_node.label) = $(c.label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, :equality_node, build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, _as.id, index_node.id, Edge(EDGE_0))
    add_edge(graph, b.id, index_node.id, Edge(EDGE_1))
    add_edge(graph, b.id, index_node.id, Edge(EDGE_0))
    add_edge(graph, index_node.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, c.id, equality_node.id, Edge(EDGE_0))

    return graph
end

function decompose_array_var_set_element(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    return decompose_array_set_element(args, graph)
end

function decompose_set_card(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    s = args[1]
    x = args[2]

    card_label = "|$(s.label)|"
    card_hash = hash(card_label)
    card_node = Node(card_label, :card_node, build_generic_value(card_hash, card_label, "card_node"), card_hash)
    add_node(graph, card_node)

    eq_label = "$(x.label) = $(card_node.label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, :equality_node, build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, s.id, card_node.id, Edge(EDGE_0))
    add_edge(graph, card_node.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, x.id, equality_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_diff(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    diff_label = "$(x.label) \\ $(y.label)"
    diff_hash = hash(diff_label)
    diff_node = Node(diff_label, :diff_node, build_generic_value(diff_hash, diff_label, "diff_node"), diff_hash)
    add_node(graph, diff_node)

    eq_label = "$(r.label) = $(diff_label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, :equality_node, build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, x.id, diff_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, diff_node.id, Edge(EDGE_1))
    add_edge(graph, diff_node.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, r.id, equality_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_eq(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    eq_label = "$(x.label) = $(y.label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, :equality_node, build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, x.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, equality_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_eq_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    eq_label = "$(x.label) = $(y.label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, :equality_node, build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    iff_label = "$(r.label) <-> ($(eq_label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, :iff_node, build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)
    add_node(graph, iff_node)

    add_edge(graph, x.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, r.id, iff_node.id, Edge(EDGE_0))
    add_edge(graph, equality_node.id, iff_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_in_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    s = args[2]
    r = args[3]

    in_label = "$(x.label) in $(s.label)"
    in_hash = hash(in_label)
    in_node = Node(in_label, :in_node, build_generic_value(in_hash, in_label, "in_node"), in_hash)
    add_node(graph, in_node)

    iff_label = "$(r.label) <-> ($(in_label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, :iff_node, build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)
    add_node(graph, iff_node)

    add_edge(graph, x.id, in_node.id, Edge(EDGE_0))
    add_edge(graph, s.id, in_node.id, Edge(EDGE_1))
    add_edge(graph, r.id, iff_node.id, Edge(EDGE_0))
    add_edge(graph, in_node.id, iff_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_intersect(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    intersect_label = "$(x.label) /\\ $(y.label)"
    intersect_hash = hash(intersect_label)
    intersect_node = Node(intersect_label, :intersect_node, build_generic_value(intersect_hash, intersect_label, "intersect_node"), intersect_hash)
    add_node(graph, intersect_node)

    eq_label = "$(r.label) = $(intersect_label)"
    eq_hash = hash(eq_label)
    equality_node = Node(eq_label, :equality_node, build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, equality_node)

    add_edge(graph, x.id, intersect_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, intersect_node.id, Edge(EDGE_1))
    add_edge(graph, intersect_node.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, r.id, equality_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_le(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    leq_label = "$(x.label) <= $(y.label)"
    leq_hash = hash(leq_label)
    leq_node = Node(leq_label, :leq_node, build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    add_node(graph, leq_node)

    add_edge(graph, x.id, leq_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, leq_node.id, Edge(EDGE_1))

    return graph
end

function decompose_set_le_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    leq_label = "$(x.label) <= $(y.label)"
    leq_hash = hash(leq_label)
    leq_node = Node(leq_label, :leq_node, build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    add_node(graph, leq_node)

    iff_label = "$(r.label) <-> ($(leq_label))"
    iff_node = Node(iff_label, :iff_node, build_generic_value(hash(iff_label), iff_label, "iff_node"), hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x.id, leq_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, leq_node.id, Edge(EDGE_1))
    add_edge(graph, r.id, iff_node.id, Edge(EDGE_0))
    add_edge(graph, leq_node.id, iff_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_lt(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    le_label = "$(x.label) < $(y.label)"
    le_hash = hash(le_label)
    le_node = Node(le_label, :le_node, build_generic_value(le_hash, le_label, "le_node"), le_hash)
    add_node(graph, le_node)

    add_edge(graph, x.id, le_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, le_node.id, Edge(EDGE_1))

    return graph
end

function decompose_set_lt_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    leq_label = "$(x.label) <= $(y.label)"
    leq_node = Node(leq_label, :le_node, build_generic_value(hash(leq_label), leq_label, "le_node"), hash(leq_label))
    add_node(graph, leq_node)

    iff_label = "$(r.label) <-> ($(leq_label))"
    iff_node = Node(iff_label, :iff_node, build_generic_value(hash(iff_label), iff_label, "iff_node"), hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x.id, leq_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, leq_node.id, Edge(EDGE_1))
    add_edge(graph, r.id, iff_node.id, Edge(EDGE_0))
    add_edge(graph, leq_node.id, iff_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_ne(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    ineq_label = "$(x.label) != $(y.label)"
    inequality_node = Node(ineq_label, :inequality_node, build_generic_value(hash(ineq_label), ineq_label, "inequality_node"), hash(ineq_label))
    add_node(graph, inequality_node)

    add_edge(graph, x.id, inequality_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, inequality_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_ne_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]


    ineq_label = "$(x.label) != $(y.label)"
    inequality_node = Node(ineq_label, :inequality_node, build_generic_value(hash(ineq_label), ineq_label, "inequality_node"), hash(ineq_label))
    add_node(graph, inequality_node)

    iff_label = "$(r.label) <-> ($(ineq_label))"
    iff_node = Node(iff_label, :iff_node, iff_label, hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x.id, inequality_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, inequality_node.id, Edge(EDGE_0))
    add_edge(graph, r.id, iff_node.id, Edge(EDGE_0))
    add_edge(graph, inequality_node.id, iff_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_subset(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    subset_label = "$(x.label) \\subset $(y.label)"
    subset_node = Node(subset_label, :subset_node, subset_label, hash(subset_label))
    add_node(graph, subset_node)

    add_edge(graph, x.id, subset_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, subset_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_subset_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    subset_label = "$(x.label) \\subset $(y.label)"
    subset_node = Node(subset_label, :subset_node, subset_label, hash(subset_label))
    add_node(graph, subset_node)

    iff_label = "$(r.label) <-> ($(subset_label))"
    iff_node = Node(iff_label, :iff_node, iff_label, hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x.id, subset_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, subset_node.id, Edge(EDGE_1))
    add_edge(graph, r.id, iff_node.id, Edge(EDGE_0))
    add_edge(graph, subset_node.id, iff_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_superset(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]

    subset_label = "$(y.label) \\subset $(x.label)"
    subset_node = Node(subset_label, :subset_node, subset_label, hash(subset_label))
    add_node(graph, subset_node)

    add_edge(graph, x.id, subset_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, subset_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_superset_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    subset_label = "$(y.label) \\subset $(x.label)"
    subset_node = Node(subset_label, :subset_node, subset_label, hash(subset_label))
    add_node(graph, subset_node)

    iff_label = "$(r.label) <-> ($(subset_label))"
    iff_node = Node(iff_label, :iff_node, iff_label, hash(iff_label))
    add_node(graph, iff_node)

    add_edge(graph, x.id, subset_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, subset_node.id, Edge(EDGE_1))
    add_edge(graph, r.id, iff_node.id, Edge(EDGE_0))
    add_edge(graph, subset_node.id, iff_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_symdiff(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    symdiff_label = "$(x.label) symdiff $(y.label)"
    symdiff_node = Node(symdiff_label, :symdiff_node, build_generic_value(hash(symdiff_label), symdiff_label, "symdiff_node"), hash(symdiff_label))
    add_node(graph, symdiff_node)

    eq_label = "$(r.label) = $(symdiff_label)"
    equality_node = Node(eq_label, :equality_node, build_generic_value(hash(eq_label), eq_label, "equality_node"), hash(eq_label))
    add_node(graph, equality_node)

    add_edge(graph, x.id, symdiff_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, symdiff_node.id, Edge(EDGE_1))
    add_edge(graph, symdiff_node.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, r.id, equality_node.id, Edge(EDGE_0))

    return graph
end

function decompose_set_union(args::Vector{Union{Vector{Node},Node}}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    r = args[3]

    union_label = "$(x.label) union $(y.label)"
    union_node = Node(union_label, :union_node, build_generic_value(hash(union_label), union_label, "union_node"), hash(union_label))
    add_node(graph, union_node)

    eq_label = "$(r.label) = $(union_label)"
    equality_node = Node(eq_label, :equality_node, build_generic_value(hash(eq_label), eq_label, "equality_node"), hash(eq_label))
    add_node(graph, equality_node)

    add_edge(graph, x.id, union_node.id, Edge(EDGE_0))
    add_edge(graph, y.id, union_node.id, Edge(EDGE_0))
    add_edge(graph, union_node.id, equality_node.id, Edge(EDGE_0))
    add_edge(graph, r.id, equality_node.id, Edge(EDGE_0))

    return graph
end

export decompose_array_set_element, decompose_array_var_set_element, decompose_set_card,
    decompose_set_diff, decompose_set_eq, decompose_set_eq_reif, decompose_set_in_reif,
    decompose_set_intersect, decompose_set_le, decompose_set_le_reif, decompose_set_lt,
    decompose_set_lt_reif, decompose_set_ne, decompose_set_ne_reif, decompose_set_subset,
    decompose_set_subset_reif, decompose_set_superset, decompose_set_superset_reif,
    decompose_set_symdiff, decompose_set_union

end
