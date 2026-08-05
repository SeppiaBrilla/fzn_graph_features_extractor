module Helper

using Serialization

function typer(t::String)::String
    if t in ("int", "float", "bool", "par_node", "parameter_node")
        return "literal_node"
    end
    return t
end

const GLOBAL_NODES = Set([
    "cumulatives_node", "int_element_node", "int_lin_eq_imp_node", "array_int_maximum_node",
    "schedule_unary_node", "int_le_imp_node", "global_cardinality_node", "global_cardinality_low_up_node",
    "maximum_arg_int_offset_node", "circuit_node", "count_eq_reif_node", "set_in_imp_node",
    "count_eq_node", "global_cardinality_low_up_closed_node", "bool_xor_imp_node", "nooverlap_node",
    "regular_node", "all_different_node", "eq_imp_node", "all_equal_node", "bool_element_node",
    "array_int_minimum_node", "bool_clause_reif_node", "int_element2d_node", "bin_packing_load_node",
    "table_int_node", "precede_node", "array_int_lq_node", "int_lin_le_imp_node", "int_lin_ne_imp_node",
    "increasing_int_node", "inverse_offsets_node", "nvalue_node", "int_ne_imp_node", "increasing_bool_node",
    "member_int_node", "table_int_imp_node", "at_least_node", "at_most_node", "int_pow_node",
    "global_cardinality_closed_node", "lin_sum_node"
])

function is_global(node_type::String)::Bool
    return node_type in GLOBAL_NODES
end

function load_colors(file_path::String)::Dict{String,UInt64}
    if isfile(file_path)
        return deserialize(file_path)::Dict{String,UInt64}
    else
        return Dict{String,UInt64}()
    end
end

function save_colors(file_path::String, colors::Dict{String,UInt64})::Nothing
    serialize(file_path, colors)
end

export typer, is_global, GLOBAL_NODES, load_colors, save_colors

end