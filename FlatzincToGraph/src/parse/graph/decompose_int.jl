module DecomposeIntConstraints

using ...GraphType
using ...Parameters
using ...Variables
using ...Helper
using ...GraphHelper

function decompose_int_lin_le(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    bs = args[2]
    c = args[3]

    as_list = normalize_list(_as)
    bs_list = normalize_list(bs)

    a_nodes = [get_node_for_val(graph, a, "int") for a in as_list]
    b_nodes = [get_node_for_val(graph, b, "int") for b in bs_list]
    _c = get_node_for_val(graph, c, "int")

    n = length(a_nodes)
    sum_nodes = Node[]
    for i in 1:n
        a = a_nodes[i]
        b = b_nodes[i]
        mul_label = "$(a.id) * $(b.id)"
        mul_hash = hash(mul_label)
        mul_node = Node(mul_label, "mult_node", build_generic_value(mul_hash, "$(a.label)*$(b.label)", "mult_node"), mul_hash)
        push!(sum_nodes, mul_node)
        add_node(graph, mul_node)
        add_edge(graph, a.id, mul_node.id, Edge("0"))
        add_edge(graph, b.id, mul_node.id, Edge("0"))
    end

    sum_label = "sum(" * join(["$(n.id)" for n in sum_nodes], ", ") * ")"
    sum_hash = hash(sum_label)
    sum_node = Node(sum_label, "lin_sum_node", build_generic_value(sum_hash, sum_label, "lin_sum_node"), sum_hash)
    add_node(graph, sum_node)
    for n in sum_nodes
        add_edge(graph, n.id, sum_node.id, Edge("0"))
    end

    leq_label = "$(sum_node.id)<=$(_c.id)"
    leq_hash = hash(leq_label)
    leq = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    add_node(graph, leq)
    add_edge(graph, _c.id, leq.id, Edge("1"))
    add_edge(graph, sum_node.id, leq.id, Edge("0"))

    return graph
end

function decompose_int_lin_le_reif(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    bs = args[2]
    c = args[3]
    r = args[4]

    as_list = normalize_list(_as)
    bs_list = normalize_list(bs)

    a_nodes = [get_node_for_val(graph, a, "int") for a in as_list]
    b_nodes = [get_node_for_val(graph, b, "int") for b in bs_list]
    _c = get_node_for_val(graph, c, "int")
    r_node = get_node_for_val(graph, r, "bool")

    n = length(a_nodes)
    sum_nodes = Node[]
    for i in 1:n
        a = a_nodes[i]
        b = b_nodes[i]
        mul_label = "$(a.id) * $(b.id)"
        mul_hash = hash(mul_label)
        mul_node = Node(mul_label, "mult_node", build_generic_value(mul_hash, "($(a.label), $(b.label))", "mult_node"), mul_hash)
        push!(sum_nodes, mul_node)
        add_node(graph, mul_node)
        add_edge(graph, a.id, mul_node.id, Edge("0"))
        add_edge(graph, b.id, mul_node.id, Edge("0"))
    end

    sum_label = "sum(" * join(["$(n.id)" for n in sum_nodes], ", ") * ")"
    sum_hash = hash(sum_label)
    sum_node = Node(sum_label, "lin_sum_node", build_generic_value(sum_hash, sum_label, "lin_sum_node"), sum_hash)
    add_node(graph, sum_node)
    for n in sum_nodes
        add_edge(graph, n.id, sum_node.id, Edge("0"))
    end

    leq_label = "$(sum_node.id)<=$(_c.id)"
    leq_hash = hash(leq_label)
    leq = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    add_node(graph, leq)
    add_edge(graph, _c.id, leq.id, Edge("1"))
    add_edge(graph, sum_node.id, leq.id, Edge("0"))

    iff_label = "$(r_node.id)<->$(leq.id)"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)
    add_node(graph, iff_node)
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, leq.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_int_lin_eq(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    bs = args[2]
    c = args[3]

    as_list = normalize_list(_as)
    bs_list = normalize_list(bs)

    a_nodes = [get_node_for_val(graph, a, "int") for a in as_list]
    b_nodes = [get_node_for_val(graph, b, "int") for b in bs_list]
    _c = get_node_for_val(graph, c, "int")

    n = length(a_nodes)
    sum_nodes = Node[]
    for i in 1:n
        a = a_nodes[i]
        b = b_nodes[i]
        mul_label = "$(a.id) * $(b.id)"
        mul_hash = hash(mul_label)
        mul_node = Node(mul_label, "mult_node", build_generic_value(mul_hash, "($(a.label), $(b.label))", "mult_node"), mul_hash)
        push!(sum_nodes, mul_node)
        add_node(graph, mul_node)
        add_edge(graph, a.id, mul_node.id, Edge("0"))
        add_edge(graph, b.id, mul_node.id, Edge("0"))
    end

    sum_label = "sum(" * join(["$(n.id)" for n in sum_nodes], ",") * ")"
    sum_hash = hash(sum_label)
    sum_node = Node(sum_label, "lin_sum_node", build_generic_value(sum_hash, sum_label, "lin_sum_node"), sum_hash)
    add_node(graph, sum_node)
    for n in sum_nodes
        add_edge(graph, n.id, sum_node.id, Edge("0"))
    end

    eq_label = "$(sum_node.id)=$(_c.id)"
    eq_hash = hash(eq_label)
    eq = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, eq)
    add_edge(graph, _c.id, eq.id, Edge("0"))
    add_edge(graph, sum_node.id, eq.id, Edge("0"))

    return graph
end

function decompose_int_lin_eq_reif(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    bs = args[2]
    c = args[3]
    r = args[4]

    as_list = normalize_list(_as)
    bs_list = normalize_list(bs)

    a_nodes = [get_node_for_val(graph, a, "int") for a in as_list]
    b_nodes = [get_node_for_val(graph, b, "int") for b in bs_list]
    _c = get_node_for_val(graph, c, "int")
    r_node = get_node_for_val(graph, r, "bool")

    n = length(a_nodes)
    sum_nodes = Node[]
    for i in 1:n
        a = a_nodes[i]
        b = b_nodes[i]
        mul_label = "$(a.id) * $(b.id)"
        mul_hash = hash(mul_label)
        mul_node = Node(mul_label, "mult_node", build_generic_value(mul_hash, "($(a.label), $(b.label))", "mult_node"), mul_hash)
        push!(sum_nodes, mul_node)
        add_node(graph, mul_node)
        add_edge(graph, a.id, mul_node.id, Edge("0"))
        add_edge(graph, b.id, mul_node.id, Edge("0"))
    end

    sum_label = "sum(" * join(["$(n.id)" for n in sum_nodes], ",") * ")"
    sum_hash = hash(sum_label)
    sum_node = Node(sum_label, "lin_sum_node", build_generic_value(sum_hash, sum_label, "lin_sum_node"), sum_hash)
    add_node(graph, sum_node)
    for n in sum_nodes
        add_edge(graph, n.id, sum_node.id, Edge("0"))
    end

    eq_label = "$(sum_node.id)=$(_c.id)"
    eq_hash = hash(eq_label)
    eq = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)
    add_node(graph, eq)
    add_edge(graph, _c.id, eq.id, Edge("0"))
    add_edge(graph, sum_node.id, eq.id, Edge("0"))

    iff_label = "$(r_node.id)<->$(eq.id)"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)
    add_node(graph, iff_node)
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, eq.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_array_int_element(args::Vector{Any}, graph::Graph)::Graph
    b = args[1]
    _as = args[2]
    c = args[3]

    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "int")
    _as_node = get_node_for_val(graph, _as, "int")

    index_label = "$(_as_node.label)[$(b_node.label)]"
    index_hash = hash(index_label)
    index_node = Node(index_label, "index_node", build_generic_value(index_hash, index_label, "index_node"), index_hash)
    equality_label = "$(index_node.label) = $(b_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)

    add_node(graph, index_node)
    add_node(graph, equality_node)

    add_edge(graph, _as_node.id, index_node.id, Edge("0"))
    add_edge(graph, b_node.id, index_node.id, Edge("1"))
    add_edge(graph, b_node.id, index_node.id, Edge("0"))
    add_edge(graph, index_node.id, equality_node.id, Edge("0"))
    add_edge(graph, c_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_array_var_int_element(args::Vector{Any}, graph::Graph)::Graph
    b = args[1]
    _as = args[2]
    c = args[3]

    if _as isa Parameter
        _as_node = get_node_for_val(graph, _as, "int")
    elseif _as isa Vector{Any} || _as isa Vector{String}
        _as_node = list_to_node(graph, _as, "int")
    else
        error("Unknown as type: $(typeof(_as))")
    end

    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "int")

    index_label = "$(_as_node.label)[$(b_node.label)]"
    index_hash = hash(index_label)
    index_node = Node(index_label, "index_node", build_generic_value(index_hash, index_label, "index_node"), index_hash)
    equality_label = "$(index_node.label) = $(b_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)

    add_node(graph, index_node)
    add_node(graph, equality_node)

    add_edge(graph, _as_node.id, index_node.id, Edge("0"))
    add_edge(graph, b_node.id, index_node.id, Edge("1"))
    add_edge(graph, b_node.id, index_node.id, Edge("0"))
    add_edge(graph, index_node.id, equality_node.id, Edge("0"))
    add_edge(graph, c_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_int_abs(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")

    abs_label = "abs($(a_node.label))"
    abs_hash = hash(abs_label)
    abs_node = Node(abs_label, "abs_node", build_generic_value(abs_hash, abs_label, "abs_node"), abs_hash)
    equality_label = "$(abs_node.label) = $(b_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)

    add_node(graph, abs_node)
    add_node(graph, equality_node)

    add_edge(graph, a_node.id, abs_node.id, Edge("0"))
    add_edge(graph, abs_node.id, equality_node.id, Edge("0"))
    add_edge(graph, b_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_int_div(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    c = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "int")

    division_label = "$(a_node.label)/$(b_node.label)"
    division_hash = hash(division_label)
    division_node = Node(division_label, "division_node", build_generic_value(division_hash, division_label, "division_node"), division_hash)
    equality_label = "$(division_node.label) = $(c_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)

    add_node(graph, division_node)
    add_node(graph, equality_node)

    add_edge(graph, a_node.id, division_node.id, Edge("0"))
    add_edge(graph, b_node.id, division_node.id, Edge("1"))
    add_edge(graph, division_node.id, equality_node.id, Edge("0"))
    add_edge(graph, c_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_int_eq(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")

    equality_label = "$(a_node.label) = $(b_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)

    add_node(graph, equality_node)

    add_edge(graph, a_node.id, equality_node.id, Edge("0"))
    add_edge(graph, b_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_int_eq_reif(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    r_node = get_node_for_val(graph, r, "bool")

    equality_label = "$(a_node.label) = $(b_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)
    iif_label = "$(r_node.label) <-> $(equality_node.label)"
    iif_hash = hash(iif_label)
    iif_node = Node(iif_label, "iff_node", build_generic_value(iif_hash, iif_label, "iff_node"), iif_hash)

    add_node(graph, equality_node)
    add_node(graph, iif_node)

    add_edge(graph, a_node.id, equality_node.id, Edge("0"))
    add_edge(graph, b_node.id, equality_node.id, Edge("0"))
    add_edge(graph, r_node.id, iif_node.id, Edge("0"))
    add_edge(graph, equality_node.id, iif_node.id, Edge("0"))

    return graph
end

function decompose_int_le(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")

    leq_label = "$(a_node.label) < $(b_node.label)"
    leq_hash = hash(leq_label)
    leq_node = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)

    add_node(graph, leq_node)

    add_edge(graph, a_node.id, leq_node.id, Edge("0"))
    add_edge(graph, b_node.id, leq_node.id, Edge("0"))

    return graph
end

function decompose_int_le_reif(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    r_node = get_node_for_val(graph, r, "bool")

    leq_label = "$(a_node.label) < $(b_node.label)"
    leq_hash = hash(leq_label)
    leq_node = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    iif_label = "$(r_node.label) <-> $(leq_node.label)"
    iif_hash = hash(iif_label)
    iif_node = Node(iif_label, "iff_node", build_generic_value(iif_hash, iif_label, "iff_node"), iif_hash)

    add_node(graph, leq_node)
    add_node(graph, iif_node)

    add_edge(graph, a_node.id, leq_node.id, Edge("0"))
    add_edge(graph, b_node.id, leq_node.id, Edge("0"))
    add_edge(graph, r_node.id, iif_node.id, Edge("0"))
    add_edge(graph, leq_node.id, iif_node.id, Edge("0"))

    return graph
end

function decompose_int_lin_ne(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    bs = args[2]
    c = args[3]

    as_list = normalize_list(_as)
    bs_list = normalize_list(bs)

    a_nodes = [get_node_for_val(graph, a, "int") for a in as_list]
    b_nodes = [get_node_for_val(graph, b, "int") for b in bs_list]
    _c = get_node_for_val(graph, c, "int")

    n = length(a_nodes)
    sum_nodes = Node[]
    for i in 1:n
        a = a_nodes[i]
        b = b_nodes[i]
        mul_label = "$(a.id) * $(b.id)"
        mul_hash = hash(mul_label)
        mul_node = Node(mul_label, "mult_node", build_generic_value(mul_hash, "($(a.label), $(b.label))", "mult_node"), mul_hash)
        push!(sum_nodes, mul_node)
        add_node(graph, mul_node)
        add_edge(graph, a.id, mul_node.id, Edge("0"))
        add_edge(graph, b.id, mul_node.id, Edge("0"))
    end

    sum_label = "sum(" * join(["$(n.id)" for n in sum_nodes], ",") * ")"
    sum_hash = hash(sum_label)
    sum_node = Node(sum_label, "lin_sum_node", build_generic_value(sum_hash, sum_label, "lin_sum_node"), sum_hash)
    add_node(graph, sum_node)
    for n in sum_nodes
        add_edge(graph, n.id, sum_node.id, Edge("0"))
    end

    neq_label = "$(sum_node.id)=$(_c.id)"
    neq_hash = hash(neq_label)
    neq = Node(neq_label, "inequality_node", build_generic_value(neq_hash, neq_label, "inequality_node"), neq_hash)
    add_node(graph, neq)
    add_edge(graph, _c.id, neq.id, Edge("0"))
    add_edge(graph, sum_node.id, neq.id, Edge("0"))

    return graph
end

function decompose_int_lin_ne_reif(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    bs = args[2]
    c = args[3]
    r = args[4]

    as_list = normalize_list(_as)
    bs_list = normalize_list(bs)

    a_nodes = [get_node_for_val(graph, a, "int") for a in as_list]
    b_nodes = [get_node_for_val(graph, b, "int") for b in bs_list]
    _c = get_node_for_val(graph, c, "int")
    r_node = get_node_for_val(graph, r, "bool")

    n = length(a_nodes)
    sum_nodes = Node[]
    for i in 1:n
        a = a_nodes[i]
        b = b_nodes[i]
        mul_label = "$(a.id) * $(b.id)"
        mul_hash = hash(mul_label)
        mul_node = Node(mul_label, "mult_node", build_generic_value(mul_hash, "($(a.label), $(b.label))", "mult_node"), mul_hash)
        push!(sum_nodes, mul_node)
        add_node(graph, mul_node)
        add_edge(graph, a.id, mul_node.id, Edge("0"))
        add_edge(graph, b.id, mul_node.id, Edge("0"))
    end

    sum_label = "sum(" * join(["$(n.id)" for n in sum_nodes], ",") * ")"
    sum_hash = hash(sum_label)
    sum_node = Node(sum_label, "lin_sum_node", build_generic_value(sum_hash, sum_label, "lin_sum_node"), sum_hash)
    add_node(graph, sum_node)
    for n in sum_nodes
        add_edge(graph, n.id, sum_node.id, Edge("0"))
    end

    neq_label = "$(sum_node.id)!=$(_c.id)"
    neq_hash = hash(neq_label)
    neq = Node(neq_label, "inequality_node", build_generic_value(neq_hash, neq_label, "inequality_node"), neq_hash)
    add_node(graph, neq)
    add_edge(graph, _c.id, neq.id, Edge("0"))
    add_edge(graph, sum_node.id, neq.id, Edge("0"))

    iff_label = "$(r_node.id)<->$(neq.id)"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)
    add_node(graph, iff_node)
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, neq.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_int_lt(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")

    le_label = "$(a_node.label) < $(b_node.label)"
    le_hash = hash(le_label)
    le_node = Node(le_label, "le_node", build_generic_value(le_hash, le_label, "le_node"), le_hash)

    add_node(graph, le_node)

    add_edge(graph, a_node.id, le_node.id, Edge("0"))
    add_edge(graph, b_node.id, le_node.id, Edge("0"))

    return graph
end

function decompose_int_lt_reif(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    r_node = get_node_for_val(graph, r, "bool")

    le_label = "$(a_node.label) < $(b_node.label)"
    le_hash = hash(le_label)
    le_node = Node(le_label, "le_node", build_generic_value(le_hash, le_label, "le_node"), le_hash)
    iif_label = "$(r_node.label) <-> $(le_node.label)"
    iif_hash = hash(iif_label)
    iif_node = Node(iif_label, "iff_node", build_generic_value(iif_hash, iif_label, "iff_node"), iif_hash)

    add_node(graph, le_node)
    add_node(graph, iif_node)

    add_edge(graph, a_node.id, le_node.id, Edge("0"))
    add_edge(graph, b_node.id, le_node.id, Edge("0"))
    add_edge(graph, r_node.id, iif_node.id, Edge("0"))
    add_edge(graph, le_node.id, iif_node.id, Edge("0"))

    return graph
end

function decompose_int_max(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    c = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "int")

    max_label = "max($(a_node.label), $(b_node.label))"
    max_hash = hash(max_label)
    max_node = Node(max_label, "max_node", build_generic_value(max_hash, max_label, "max_node"), max_hash)
    eq_label = "$(max_node.label) = $(c_node.label)"
    eq_hash = hash(eq_label)
    eq_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)

    add_node(graph, max_node)
    add_node(graph, eq_node)

    add_edge(graph, a_node.id, max_node.id, Edge("0"))
    add_edge(graph, b_node.id, max_node.id, Edge("0"))
    add_edge(graph, max_node.id, eq_node.id, Edge("0"))
    add_edge(graph, c_node.id, eq_node.id, Edge("0"))

    return graph
end

function decompose_int_min(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    c = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "int")

    min_label = "min($(a_node.label), $(b_node.label))"
    min_hash = hash(min_label)
    min_node = Node(min_label, "min_node", build_generic_value(min_hash, min_label, "min_node"), min_hash)
    eq_label = "$(min_node.label) = $(c_node.label)"
    eq_hash = hash(eq_label)
    eq_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)

    add_node(graph, min_node)
    add_node(graph, eq_node)

    add_edge(graph, a_node.id, min_node.id, Edge("0"))
    add_edge(graph, b_node.id, min_node.id, Edge("0"))
    add_edge(graph, min_node.id, eq_node.id, Edge("0"))
    add_edge(graph, c_node.id, eq_node.id, Edge("0"))

    return graph
end

function decompose_int_mod(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    c = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "int")

    mod_label = "$(a_node.label) % $(b_node.label)"
    mod_hash = hash(mod_label)
    mod_node = Node(mod_label, "modulo_node", build_generic_value(mod_hash, mod_label, "modulo_node"), mod_hash)
    eq_label = "$(mod_node.label) = $(c_node.label)"
    eq_hash = hash(eq_label)
    eq_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)

    add_node(graph, mod_node)
    add_node(graph, eq_node)

    add_edge(graph, a_node.id, mod_node.id, Edge("0"))
    add_edge(graph, b_node.id, mod_node.id, Edge("0"))
    add_edge(graph, mod_node.id, eq_node.id, Edge("0"))
    add_edge(graph, c_node.id, eq_node.id, Edge("0"))

    return graph
end

function decompose_int_ne(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")

    neq_label = "$(a_node.label) != $(b_node.label)"
    neq_hash = hash(neq_label)
    neq_node = Node(neq_label, "inequality_node", build_generic_value(neq_hash, neq_label, "inequality_node"), neq_hash)

    add_node(graph, neq_node)

    add_edge(graph, a_node.id, neq_node.id, Edge("0"))
    add_edge(graph, b_node.id, neq_node.id, Edge("0"))

    return graph
end

function decompose_int_ne_reif(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    r_node = get_node_for_val(graph, r, "bool")

    neq_label = "$(a_node.label) != $(b_node.label)"
    neq_hash = hash(neq_label)
    neq_node = Node(neq_label, "inequality_node", build_generic_value(neq_hash, neq_label, "inequality_node"), neq_hash)
    iif_label = "$(r_node.label) <-> $(neq_node.label)"
    iif_hash = hash(iif_label)
    iif_node = Node(iif_label, "iff_node", build_generic_value(iif_hash, iif_label, "iff_node"), iif_hash)

    add_node(graph, neq_node)
    add_node(graph, iif_node)

    add_edge(graph, a_node.id, neq_node.id, Edge("0"))
    add_edge(graph, b_node.id, neq_node.id, Edge("0"))
    add_edge(graph, neq_node.id, iif_node.id, Edge("0"))
    add_edge(graph, r_node.id, iif_node.id, Edge("0"))

    return graph
end

function decompose_int_plus(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    c = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "int")

    sum_label = "$(a_node.label) + $(b_node.label)"
    sum_hash = hash(sum_label)
    sum_node = Node(sum_label, "sum_node", build_generic_value(sum_hash, sum_label, "sum_node"), sum_hash)
    eq_label = "$(sum_node.label) = $(c_node.label)"
    eq_hash = hash(eq_label)
    eq_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)

    add_node(graph, sum_node)
    add_node(graph, eq_node)

    add_edge(graph, a_node.id, sum_node.id, Edge("0"))
    add_edge(graph, b_node.id, sum_node.id, Edge("0"))
    add_edge(graph, sum_node.id, eq_node.id, Edge("0"))
    add_edge(graph, c_node.id, eq_node.id, Edge("0"))

    return graph
end

function decompose_int_pow(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    y = args[2]
    z = args[3]

    x_node = get_node_for_val(graph, x, "int")
    y_node = get_node_for_val(graph, y, "int")
    z_node = get_node_for_val(graph, z, "int")

    pow_label = "$(x_node.label)^$(y_node.label)"
    pow_hash = hash(pow_label)
    pow_node = Node(pow_label, "pow_node", build_generic_value(pow_hash, pow_label, "pow_node"), pow_hash)
    eq_label = "$(pow_node.label) = $(z_node.label)"
    eq_hash = hash(eq_label)
    eq_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)

    add_node(graph, pow_node)
    add_node(graph, eq_node)

    add_edge(graph, x_node.id, pow_node.id, Edge("0"))
    add_edge(graph, y_node.id, pow_node.id, Edge("1"))
    add_edge(graph, pow_node.id, eq_node.id, Edge("0"))
    add_edge(graph, z_node.id, eq_node.id, Edge("0"))

    return graph
end

function decompose_int_times(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    c = args[3]

    a_node = get_node_for_val(graph, a, "int")
    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "int")

    mul_label = "$(a_node.label) * $(b_node.label)"
    mul_hash = hash(mul_label)
    mul_node = Node(mul_label, "mult_node", build_generic_value(mul_hash, mul_label, "mult_node"), mul_hash)
    eq_label = "$(mul_node.label) = $(c_node.label)"
    eq_hash = hash(eq_label)
    eq_node = Node(eq_label, "equality_node", build_generic_value(eq_hash, eq_label, "equality_node"), eq_hash)

    add_node(graph, mul_node)
    add_node(graph, eq_node)

    add_edge(graph, a_node.id, mul_node.id, Edge("0"))
    add_edge(graph, b_node.id, mul_node.id, Edge("0"))
    add_edge(graph, mul_node.id, eq_node.id, Edge("0"))
    add_edge(graph, c_node.id, eq_node.id, Edge("0"))

    return graph
end

function decompose_set_in(args::Vector{Any}, graph::Graph)::Graph
    x = args[1]
    s = args[2]

    x_node = get_node_for_val(graph, x, "int")
    s_node = get_node_for_val(graph, s, "set of int")

    in_label = "$(x_node.label) in $(s_node.label)"
    in_hash = hash(in_label)
    in_node = Node(in_label, "in_node", build_generic_value(in_hash, in_label, "in_node"), in_hash)

    add_node(graph, in_node)

    add_edge(graph, x_node.id, in_node.id, Edge("0"))
    add_edge(graph, s_node.id, in_node.id, Edge("1"))

    return graph
end

export decompose_int_lin_le, decompose_int_lin_le_reif, decompose_int_lin_eq, decompose_int_lin_eq_reif,
    decompose_array_int_element, decompose_array_var_int_element, decompose_int_abs, decompose_int_div,
    decompose_int_eq, decompose_int_eq_reif, decompose_int_le, decompose_int_le_reif,
    decompose_int_lin_ne, decompose_int_lin_ne_reif, decompose_int_lt, decompose_int_lt_reif,
    decompose_int_max, decompose_int_min, decompose_int_mod, decompose_int_ne, decompose_int_ne_reif,
    decompose_int_plus, decompose_int_pow, decompose_int_times, decompose_set_in

end
