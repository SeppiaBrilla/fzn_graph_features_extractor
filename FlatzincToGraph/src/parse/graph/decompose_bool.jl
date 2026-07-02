module DecomposeBoolConstraints

using ...GraphType
using ...Parameters
using ...Variables
using ...Helper
using ...GraphHelper

function decompose_array_bool_and(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    r = args[2]

    as_list = normalize_list(_as)
    as_nodes = [get_node_for_val(graph, a, "bool") for a in as_list]
    r_node = get_node_for_val(graph, r, "bool")

    and_label = join([_n.label for _n in as_nodes], "/\\ ")
    and_hash = hash(and_label)
    and_node = Node(and_label, "multi_and_node", build_generic_value(and_hash, and_label, "multi_and_node"), and_hash)
    add_node(graph, and_node)

    for _n in as_nodes
        add_edge(graph, _n.id, and_node.id, Edge("0"))
    end

    iff_label = "$(r_node.label) <-> $(and_node.label)"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)
    add_node(graph, iff_node)

    add_edge(graph, and_node.id, iff_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_array_bool_element(args::Vector{Any}, graph::Graph)::Graph
    b = args[1]
    _as = args[2]
    c = args[3]

    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "bool")
    _as_node = get_node_for_val(graph, _as, "bool")

    index_label = "$(_as_node.label)[$(b_node.label)]"
    index_node = Node(index_label, "index_node", build_generic_value(hash(index_label), index_label, "index_node"), hash(index_label))
    equality_label = "$(index_node.label) = $(b_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)

    add_node(graph, index_node)
    add_node(graph, equality_node)

    add_edge(graph, _as_node.id, index_node.id, Edge("0"))
    add_edge(graph, b_node.id, index_node.id, Edge("1"))
    add_edge(graph, index_node.id, equality_node.id, Edge("0"))
    add_edge(graph, c_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_array_bool_xor(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]

    as_list = normalize_list(_as)
    as_nodes = [get_node_for_val(graph, a, "bool") for a in as_list]

    xor_label = join([_n.label for _n in as_nodes], "xor ")
    xor_hash = hash(xor_label)
    xor_node = Node(xor_label, "multi_xor_node", build_generic_value(xor_hash, xor_label, "multi_xor_node"), xor_hash)
    add_node(graph, xor_node)

    for _n in as_nodes
        add_edge(graph, _n.id, xor_node.id, Edge("0"))
    end

    return graph
end

function decompose_array_var_bool_element(args::Vector{Any}, graph::Graph)::Graph
    b = args[1]
    _as = args[2]
    c = args[3]

    if _as isa Parameter
        _as_node = get_node_for_val(graph, _as, "bool")
    elseif _as isa Vector{Any} || _as isa Vector{String}
        _as_node = list_to_node(graph, _as, "bool")
    else
        error("Unknown as type: $(typeof(_as))")
    end

    b_node = get_node_for_val(graph, b, "int")
    c_node = get_node_for_val(graph, c, "bool")

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
    add_edge(graph, index_node.id, equality_node.id, Edge("0"))
    add_edge(graph, c_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_bool2int(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    one = get_node_for_val(graph, "1", "int")
    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "int")

    equality_label = "$(b_node.label) = 1"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)
    iff_label = "$(a_node.label) <-> $(equality_node.label)"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)

    add_node(graph, equality_node)
    add_node(graph, iff_node)

    add_edge(graph, one.id, equality_node.id, Edge("0"))
    add_edge(graph, b_node.id, equality_node.id, Edge("0"))
    add_edge(graph, a_node.id, iff_node.id, Edge("0"))
    add_edge(graph, equality_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_bool_and(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")
    r_node = get_node_for_val(graph, r, "bool")

    and_label = "$(a_node.label) /\\ $(b_node.label)"
    and_hash = hash(and_label)
    and_node = Node(and_label, "and_node", build_generic_value(and_hash, and_label, "and_node"), and_hash)
    iff_label = "$(r_node.label) /\\ $(and_node.label)"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)

    add_node(graph, and_node)
    add_node(graph, iff_node)

    add_edge(graph, a_node.id, and_node.id, Edge("0"))
    add_edge(graph, b_node.id, and_node.id, Edge("0"))
    add_edge(graph, and_node.id, iff_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_bool_clause(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    _bs = args[2]

    as_list = normalize_list(_as)
    bs_list = normalize_list(_bs)

    a_nodes = Node[]
    for a in as_list
        push!(a_nodes, get_node_for_val(graph, a, "bool"))
    end

    not_b_nodes = Node[]
    for b in bs_list
        # println("not! " * bs_list)
        b_node = get_node_for_val(graph, b, "bool")
        not_label = "not $(b_node.label)"
        not_hash = hash(not_label)
        not_b = Node(not_label, "not_node", build_generic_value(not_hash, not_label, "not_node"), not_hash)
        add_node(graph, not_b)
        add_edge(graph, b_node.id, not_b.id, Edge("0"))
        push!(not_b_nodes, not_b)
    end

    a_or = nothing
    if length(a_nodes) > 0
        a_or_label = join([_n.label for _n in a_nodes], " \\\\/ ")
        a_or_hash = hash(a_or_label)
        a_or = Node(a_or_label, "multi_or_node", build_generic_value(a_or_hash, a_or_label, "multi_or_node"), a_or_hash)
        add_node(graph, a_or)
        for _n in a_nodes
            add_edge(graph, _n.id, a_or.id, Edge("0"))
        end
    end

    b_or = nothing
    if length(not_b_nodes) > 0
        b_or_label = join([_n.label for _n in not_b_nodes], " \\\\/ ")
        b_or_hash = hash(b_or_label)
        b_or = Node(b_or_label, "multi_or_node", build_generic_value(b_or_hash, b_or_label, "multi_or_node"), b_or_hash)
        add_node(graph, b_or)
        for _n in not_b_nodes
            add_edge(graph, _n.id, b_or.id, Edge("0"))
        end
    end

    if !isnothing(a_or) && !isnothing(b_or)
        a_or_not_b_label = "$(a_or.label) \\\\/ $(b_or.label)"
        a_or_not_b_hash = hash(a_or_not_b_label)
        a_or_not_b = Node(a_or_not_b_label, "or_node", build_generic_value(a_or_not_b_hash, a_or_not_b_label, "or_node"), a_or_not_b_hash)
        add_node(graph, a_or_not_b)
        add_edge(graph, a_or.id, a_or_not_b.id, Edge("0"))
        add_edge(graph, b_or.id, a_or_not_b.id, Edge("0"))
    end

    return graph
end

function decompose_bool_eq(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")

    equality_label = "$(a_node.label) = $(b_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)

    add_node(graph, equality_node)

    add_edge(graph, a_node.id, equality_node.id, Edge("0"))
    add_edge(graph, b_node.id, equality_node.id, Edge("0"))

    return graph
end

function decompose_bool_eq_reif(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")
    r_node = get_node_for_val(graph, r, "bool")

    equality_label = "$(a_node.label) = $(b_node.label)"
    equality_hash = hash(equality_label)
    equality_node = Node(equality_label, "equality_node", build_generic_value(equality_hash, equality_label, "equality_node"), equality_hash)
    iff_label = "$(r_node.label) <-> ($(equality_node.label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)

    add_node(graph, equality_node)
    add_node(graph, iff_node)

    add_edge(graph, a_node.id, equality_node.id, Edge("0"))
    add_edge(graph, b_node.id, equality_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, equality_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_bool_le(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")

    leq_label = "$(a_node.label) <= $(b_node.label)"
    leq_hash = hash(leq_label)
    leq_node = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)

    add_node(graph, leq_node)

    add_edge(graph, a_node.id, leq_node.id, Edge("0"))
    add_edge(graph, b_node.id, leq_node.id, Edge("0"))

    return graph
end

function decompose_bool_le_reif(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")
    r_node = get_node_for_val(graph, r, "bool")

    leq_label = "$(a_node.label) <= $(b_node.label)"
    leq_hash = hash(leq_label)
    leq_node = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    iff_label = "$(r_node.label) <-> ($(leq_node.label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)

    add_node(graph, leq_node)
    add_node(graph, iff_node)

    add_edge(graph, a_node.id, leq_node.id, Edge("0"))
    add_edge(graph, b_node.id, leq_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, leq_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_bool_lin_eq(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    bs = args[2]
    c = args[3]

    as_list = normalize_list(_as)
    bs_list = normalize_list(bs)

    a_nodes = [get_node_for_val(graph, a, "int") for a in as_list]
    b_nodes = [get_node_for_val(graph, b, "bool") for b in bs_list]
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

function decompose_bool_lin_le(args::Vector{Any}, graph::Graph)::Graph
    _as = args[1]
    bs = args[2]
    c = args[3]

    as_list = normalize_list(_as)
    bs_list = normalize_list(bs)

    a_nodes = [get_node_for_val(graph, a, "int") for a in as_list]
    b_nodes = [get_node_for_val(graph, b, "bool") for b in bs_list]
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

    leq_label = "$(sum_node.id)<=$(_c.id)"
    leq_hash = hash(leq_label)
    leq = Node(leq_label, "leq_node", build_generic_value(leq_hash, leq_label, "leq_node"), leq_hash)
    add_node(graph, leq)
    add_edge(graph, _c.id, leq.id, Edge("0"))
    add_edge(graph, sum_node.id, leq.id, Edge("0"))

    return graph
end

function decompose_bool_lt(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")

    le_label = "$(a_node.label) < $(b_node.label)"
    le_hash = hash(le_label)
    le_node = Node(le_label, "le_node", build_generic_value(le_hash, le_label, "le_node"), le_hash)

    add_node(graph, le_node)

    add_edge(graph, a_node.id, le_node.id, Edge("0"))
    add_edge(graph, b_node.id, le_node.id, Edge("0"))

    return graph
end

function decompose_bool_lt_reif(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")
    r_node = get_node_for_val(graph, r, "bool")

    le_label = "$(a_node.label) < $(b_node.label)"
    le_hash = hash(le_label)
    le_node = Node(le_label, "le_node", build_generic_value(le_hash, le_label, "le_node"), le_hash)
    iff_label = "$(r_node.label) <-> ($(le_node.label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)

    add_node(graph, le_node)
    add_node(graph, iff_node)

    add_edge(graph, a_node.id, le_node.id, Edge("0"))
    add_edge(graph, b_node.id, le_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, le_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_bool_not(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")

    inequality_label = "$(a_node.label) != $(b_node.label)"
    inequality_hash = hash(inequality_label)
    inequality_node = Node(inequality_label, "inequality_node", build_generic_value(inequality_hash, inequality_label, "inequality_node"), inequality_hash)

    add_node(graph, inequality_node)

    add_edge(graph, a_node.id, inequality_node.id, Edge("0"))
    add_edge(graph, b_node.id, inequality_node.id, Edge("0"))

    return graph
end

function decompose_bool_or(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")
    r_node = get_node_for_val(graph, r, "bool")

    or_label = "$(a_node.label) \\/ $(b_node.label)"
    or_hash = hash(or_label)
    or_node = Node(or_label, "or_node", build_generic_value(or_hash, or_label, "or_node"), or_hash)
    iff_label = "$(r_node.label) <-> ($(or_node.label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)

    add_node(graph, or_node)
    add_node(graph, iff_node)

    add_edge(graph, a_node.id, or_node.id, Edge("0"))
    add_edge(graph, b_node.id, or_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, or_node.id, iff_node.id, Edge("0"))

    return graph
end

function decompose_bool_xor(args::Vector{Any}, graph::Graph)::Graph
    a = args[1]
    b = args[2]
    r = args[3]

    a_node = get_node_for_val(graph, a, "bool")
    b_node = get_node_for_val(graph, b, "bool")
    r_node = get_node_for_val(graph, r, "bool")

    xor_label = "$(a_node.label) xor $(b_node.label)"
    xor_hash = hash(xor_label)
    xor_node = Node(xor_label, "xor_node", build_generic_value(xor_hash, xor_label, "xor_node"), xor_hash)
    iff_label = "$(r_node.label) <-> ($(xor_node.label))"
    iff_hash = hash(iff_label)
    iff_node = Node(iff_label, "iff_node", build_generic_value(iff_hash, iff_label, "iff_node"), iff_hash)

    add_node(graph, xor_node)
    add_node(graph, iff_node)

    add_edge(graph, a_node.id, xor_node.id, Edge("0"))
    add_edge(graph, b_node.id, xor_node.id, Edge("0"))
    add_edge(graph, r_node.id, iff_node.id, Edge("0"))
    add_edge(graph, xor_node.id, iff_node.id, Edge("0"))

    return graph
end

export decompose_array_bool_and, decompose_array_bool_element, decompose_array_bool_xor,
    decompose_array_var_bool_element, decompose_bool2int, decompose_bool_and,
    decompose_bool_clause, decompose_bool_eq, decompose_bool_eq_reif,
    decompose_bool_le, decompose_bool_le_reif, decompose_bool_lin_eq,
    decompose_bool_lin_le, decompose_bool_lt, decompose_bool_lt_reif,
    decompose_bool_not, decompose_bool_or, decompose_bool_xor

end
