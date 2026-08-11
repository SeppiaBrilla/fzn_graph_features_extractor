module DecomposeGlobalConstraints

using ...GraphType
using ...Parameters
using ...Variables
using ...Helper
using ...GraphHelper

function decompose_generic_global(args::Vector{Union{Vector{Node},Node}}, graph::Graph, label_prefix::String, type::Symbol)::Graph
    global_label = label_prefix * string(GraphHelper.get_next_global_id())
    global_hash = hash(global_label)
    global_node = Node(global_label, type, build_generic_value(global_hash, global_label, type), global_hash)
    add_node(graph, global_node)

    edge_obj = Edge(EDGE_2)
    for arg in args
        if arg isa Vector{Node}
            for node in arg
                add_node(graph, node)
                add_edge(graph, node.id, global_node.id, edge_obj)
            end
        else
            add_node(graph, arg)
            add_edge(graph, arg.id, global_node.id, edge_obj)
        end
    end

    return graph
end

# Decompose wrappers for each global constraint
decompose_global_cumulatives(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "cumulatives", :cumulatives_node)
decompose_global_int_element(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "int_element", :int_element_node)
decompose_global_int_lin_eq_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "int_lin_eq_imp", :int_lin_eq_imp_node)
decompose_global_array_int_maximum(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "array_int_maximum", :array_int_maximum_node)
decompose_global_schedule_unary(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "schedule_unary", :schedule_unary_node)
decompose_global_int_le_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "int_le_imp", :int_le_imp_node)
decompose_global_global_cardinality(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "global_cardinality", :global_cardinality_node)
decompose_global_cardinality_low_up(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "global_cardinality_low_up", :global_cardinality_low_up_node)
decompose_global_maximum_arg_int_offset(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "maximum_arg_int_offset", :maximum_arg_int_offset_node)
decompose_global_circuit(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "circuit", :circuit_node)
decompose_global_count_eq_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "count_eq_reif", :count_eq_reif_node)
decompose_global_set_in_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "set_in_imp", :set_in_imp_node)
decompose_global_fzn_count_eq(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "count_eq", :count_eq_node)
decompose_global_fzn_global_cardinality_low_up_closed(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "global_cardinality_low_up_closed", :global_cardinality_low_up_closed_node)
decompose_global_bool_xor_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "bool_xor_imp", :bool_xor_imp_node)
decompose_global_nooverlap(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "nooverlap", :nooverlap_node)
decompose_global_regular(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "regular", :regular_node)
decompose_global_all_different_int(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "all_different_int", :all_different_node)
decompose_global_int_eq_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "int_eq_imp", :eq_imp_node)
decompose_global_all_equal(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "all_equal", :all_equal_node)
decompose_global_bool_element(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "bool_element", :bool_element_node)
decompose_global_array_int_minimum(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "array_int_minimum", :array_int_minimum_node)
decompose_global_bool_clause_reif(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "bool_clause_reif", :bool_clause_reif_node)
decompose_global_int_element_2d(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "int_element2d", :int_element2d_node)
decompose_global_bin_packing_load(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "bin_packing_load", :bin_packing_load_node)
decompose_global_table_int(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "table_int", :table_int_node)
decompose_global_precede(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "precede", :precede_node)
decompose_global_array_int_lq(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "array_int_lq", :array_int_lq_node)
decompose_global_int_lin_le_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "int_lin_le_imp", :int_lin_le_imp_node)
decompose_global_int_lin_ne_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "int_lin_ne_imp", :int_lin_ne_imp_node)
decompose_global_increasing_int(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "increasing_int", :increasing_int_node)
decompose_global_inverse_offsets(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "inverse_offsets", :inverse_offsets_node)
decompose_global_nvalue(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "nvalue", :nvalue_node)
decompose_global_int_ne_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "int_ne_imp", :int_ne_imp_node)
decompose_global_table_int_imp(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "table_int_imp", :table_int_imp_node)
decompose_global_fzn_member_int(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "fzn_member_int", :member_int_node)
decompose_global_global_cardinality_closed(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "global_cardinality_closed", :global_cardinality_closed_node)
decompose_global_gecode_int_pow(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "gecode_int_pow", :int_pow_node)
decompose_fzn_at_most_int(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "fzn_at_most_int", :at_most_node)
decompose_global_fzn_at_least_int(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "fzn_at_least_int", :at_least_node)
decompose_global_fzn_increasing_bool(args::Vector{Union{Vector{Node},Node}}, graph::Graph) = decompose_generic_global(args, graph, "fzn_increasing_bool", :increasing_bool_node)

export decompose_global_cumulatives, decompose_global_int_element, decompose_global_int_lin_eq_imp,
    decompose_global_array_int_maximum, decompose_global_schedule_unary, decompose_global_int_le_imp,
    decompose_global_global_cardinality, decompose_global_cardinality_low_up, decompose_global_maximum_arg_int_offset,
    decompose_global_circuit, decompose_global_count_eq_reif, decompose_global_set_in_imp,
    decompose_global_fzn_count_eq, decompose_global_fzn_global_cardinality_low_up_closed, decompose_global_bool_xor_imp,
    decompose_global_nooverlap, decompose_global_regular, decompose_global_all_different_int,
    decompose_global_int_eq_imp, decompose_global_all_equal, decompose_global_bool_element,
    decompose_global_array_int_minimum, decompose_global_bool_clause_reif, decompose_global_int_element_2d,
    decompose_global_bin_packing_load, decompose_global_table_int, decompose_global_precede,
    decompose_global_array_int_lq, decompose_global_int_lin_le_imp, decompose_global_int_lin_ne_imp,
    decompose_global_increasing_int, decompose_global_inverse_offsets, decompose_global_nvalue,
    decompose_global_int_ne_imp, decompose_global_table_int_imp, decompose_global_fzn_member_int,
    decompose_global_global_cardinality_closed, decompose_global_gecode_int_pow, decompose_fzn_at_most_int,
    decompose_global_fzn_at_least_int, decompose_global_fzn_increasing_bool

end
