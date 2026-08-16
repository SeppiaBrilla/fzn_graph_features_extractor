module Helper

using Serialization

function typer(t::Symbol)::Symbol
    if t in (:int, :float, :bool, :par_node, :parameter_node)
        return :literal_node
    end
    return t
end
typer(t::String)::Symbol = typer(Symbol(t))

const GLOBAL_NODES = Set{Symbol}([
    :cumulatives_node, :int_element_node, :int_lin_eq_imp_node, :array_int_maximum_node,
    :schedule_unary_node, :int_le_imp_node, :global_cardinality_node, :global_cardinality_low_up_node,
    :maximum_arg_int_offset_node, :circuit_node, :count_eq_reif_node, :set_in_imp_node,
    :count_eq_node, :global_cardinality_low_up_closed_node, :bool_xor_imp_node, :nooverlap_node,
    :regular_node, :all_different_node, :eq_imp_node, :all_equal_node, :bool_element_node,
    :array_int_minimum_node, :bool_clause_reif_node, :int_element2d_node, :bin_packing_load_node,
    :table_int_node, :precede_node, :array_int_lq_node, :int_lin_le_imp_node, :int_lin_ne_imp_node,
    :increasing_int_node, :inverse_offsets_node, :nvalue_node, :int_ne_imp_node, :increasing_bool_node,
    :member_int_node, :table_int_imp_node, :at_least_node, :at_most_node, :int_pow_node,
    :global_cardinality_closed_node, :lin_sum_node
])

function is_global(node_type::Symbol)::Bool
    return node_type in GLOBAL_NODES
end
is_global(node_type::String)::Bool = is_global(Symbol(node_type))

@inline function is_cut_node(node_type::Symbol)::Bool
    if is_global(node_type)
        return true
    end
    s = string(node_type)
    return startswith(s, "lin_") || startswith(s, "multi_")
end
is_cut_node(node_type::String)::Bool = is_cut_node(Symbol(node_type))

const HASH_EDGE_0 = hash(Symbol(0))
const HASH_EDGE_1 = hash(Symbol(1))
const HASH_EDGE_2 = hash(Symbol(2))

@inline function fast_edge_hash(edge_type::Symbol)::UInt64
    if edge_type === Symbol(0)
        return HASH_EDGE_0
    elseif edge_type === Symbol(1)
        return HASH_EDGE_1
    elseif edge_type === Symbol(2)
        return HASH_EDGE_2
    else
        return hash(edge_type)
    end
end
@inline fast_edge_hash(edge_type::String)::UInt64 = fast_edge_hash(Symbol(edge_type))

@inline function tailored_hash(self_color::UInt64, sorted_neibs::AbstractVector{UInt64})::UInt64
    h = self_color
    for c in sorted_neibs
        h = hash(c, h)
    end
    return h
end


function load_colors(file_path::String)::Dict{UInt64,UInt64}
    if isfile(file_path)
        obj = deserialize(file_path)
        if obj isa Dict{UInt64,UInt64}
            return obj
        elseif obj isa Dict
            d = Dict{UInt64,UInt64}()
            for (k, v) in obj
                h_k = k isa UInt64 ? k : hash(k)
                d[h_k] = UInt64(v)
            end
            return d
        end
    end
    return Dict{UInt64,UInt64}()
end

function save_colors(file_path::String, colors::Dict{UInt64,UInt64})::Nothing
    serialize(file_path, colors)
end

export typer, is_global, is_cut_node, GLOBAL_NODES, load_colors, save_colors, tailored_hash, HASH_EDGE_0, HASH_EDGE_1, HASH_EDGE_2, fast_edge_hash

end