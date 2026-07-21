module Constraints

using Base: normalize_depots_for_relocation
include("graph/decompose_int.jl")
include("graph/decompose_bool.jl")
include("graph/decompose_set.jl")
include("graph/decompose_global.jl")

using ..Parameters
using ..Variables
using ..GraphType
using ..Helper
using .DecomposeIntConstraints
using .DecomposeBoolConstraints
using .DecomposeSetConstraints
using .DecomposeGlobalConstraints
using ..GraphHelper

function is_constraint_line(line::String)
    return startswith(line, "constraint")
end

function to_val(val::AbstractString, vars::Dict{String,Variable}, parameters::Dict{String,Parameter}, graph::Graph, normalize::Bool)::Union{Node,Vector{Node}}
    var = get(vars, val, nothing)
    if !isnothing(var)
        return get_node_for_val(graph, var)
    end
    param = get(parameters, val, nothing)
    if !isnothing(param)
        if param.type.is_array && normalize
            return [get_node_for_val(graph, p) for p in normalize_list(param)]
        end
        return get_node_for_val(graph, param)
    end
    id = hash(val)
    node = get(graph.node_dict, id, nothing)
    if !isnothing(node)
        return node
    end
    val_str = String(val)
    return get_node_for_val(graph, val_str, Helper.get_type(val_str))
end

function decompose_parameters(components::AbstractString, vars::Dict{String,Variable}, parameters::Dict{String,Parameter}, graph::Graph, normalize::Bool)::Vector{Union{Vector{Node},Node}}
    constraint_parameters = Union{Vector{Node},Node}[]
    
    len = lastindex(components)
    i = 1
    
    @inline function skip_whitespace(idx)
        while idx <= len && (components[idx] == ' ' || components[idx] == '\t' || components[idx] == '\n' || components[idx] == '\r')
            idx = nextind(components, idx)
        end
        return idx
    end

    i = skip_whitespace(i)
    while i <= len
        if components[i] == '['
            array_start = i + 1
            close_idx = findnext(']', components, array_start)
            if isnothing(close_idx)
                break
            end
            
            # Non-allocating parsing of array content
            arr_nodes = Node[]
            p = array_start
            p_end = close_idx - 1
            while p <= p_end
                while p <= p_end && (components[p] == ' ' || components[p] == '\t' || components[p] == '\n' || components[p] == '\r')
                    p = nextind(components, p)
                end
                if p > p_end
                    break
                end
                
                next_comma = findnext(',', components, p)
                val_end = (isnothing(next_comma) || next_comma > p_end) ? p_end : next_comma - 1
                
                # strip trailing whitespace
                v_end = val_end
                while v_end >= p && (components[v_end] == ' ' || components[v_end] == '\t' || components[v_end] == '\n' || components[v_end] == '\r')
                    v_end = prevind(components, v_end)
                end
                
                if p <= v_end
                    val_sub = SubString(components, p, v_end)
                    push!(arr_nodes, to_val(val_sub, vars, parameters, graph, false))
                end
                
                p = isnothing(next_comma) ? p_end + 1 : next_comma + 1
            end
            push!(constraint_parameters, arr_nodes)
            
            i = close_idx + 1
            i = skip_whitespace(i)
            if i <= len && components[i] == ','
                i = nextind(components, i)
                i = skip_whitespace(i)
            end
            
        elseif components[i] == '{'
            close_idx = findnext('}', components, i + 1)
            if isnothing(close_idx)
                break
            end
            set_sub = SubString(components, i, close_idx)
            push!(constraint_parameters, get_node_for_val(graph, String(set_sub), "set of int"))
            
            i = close_idx + 1
            i = skip_whitespace(i)
            if i <= len && components[i] == ','
                i = nextind(components, i)
                i = skip_whitespace(i)
            end
            
        else
            comma_idx = findnext(',', components, i)
            val_end = (isnothing(comma_idx) || comma_idx > len) ? len : comma_idx - 1
            
            v_start = i
            while v_start <= val_end && (components[v_start] == ' ' || components[v_start] == '\t' || components[v_start] == '\n' || components[v_start] == '\r')
                v_start = nextind(components, v_start)
            end
            v_end = val_end
            while v_end >= v_start && (components[v_end] == ' ' || components[v_end] == '\t' || components[v_end] == '\n' || components[v_end] == '\r')
                v_end = prevind(components, v_end)
            end
            
            if v_start <= v_end
                val_sub = SubString(components, v_start, v_end)
                push!(constraint_parameters, to_val(val_sub, vars, parameters, graph, normalize))
            end
            
            i = isnothing(comma_idx) ? len + 1 : comma_idx + 1
            i = skip_whitespace(i)
        end
    end
    
    return constraint_parameters
end

const CONSTRAINT_HANDLERS = Dict{String, Function}(
    "int_lin_eq" => decompose_int_lin_eq,
    "int_lin_eq_reif" => decompose_int_lin_eq_reif,
    "int_lin_le" => decompose_int_lin_le,
    "int_lin_le_reif" => decompose_int_lin_le_reif,
    "array_int_element" => decompose_array_int_element,
    "array_var_int_element" => decompose_array_var_int_element,
    "int_div" => decompose_int_div,
    "int_abs" => decompose_int_abs,
    "int_eq" => decompose_int_eq,
    "int_eq_reif" => decompose_int_eq_reif,
    "int_le" => decompose_int_le,
    "int_le_reif" => decompose_int_le_reif,
    "int_lin_ne" => decompose_int_lin_ne,
    "int_lin_ne_reif" => decompose_int_lin_ne_reif,
    "int_lt" => decompose_int_lt,
    "int_lt_reif" => decompose_int_lt_reif,
    "int_max" => decompose_int_max,
    "int_min" => decompose_int_min,
    "int_times" => decompose_int_times,
    "set_in" => decompose_set_in,
    "int_mod" => decompose_int_mod,
    "int_ne" => decompose_int_ne,
    "int_ne_reif" => decompose_int_ne_reif,
    "int_plus" => decompose_int_plus,
    "int_pow" => decompose_int_pow,
    "bool_clause" => decompose_bool_clause,
    "array_bool_element" => decompose_array_bool_element,
    "array_bool_and" => decompose_array_bool_and,
    "array_bool_xor" => decompose_array_bool_xor,
    "bool2int" => decompose_bool2int,
    "array_var_bool_element" => decompose_array_var_bool_element,
    "bool_and" => decompose_bool_and,
    "bool_eq" => decompose_bool_eq,
    "bool_eq_reif" => decompose_bool_eq_reif,
    "bool_le" => decompose_bool_le,
    "bool_le_reif" => decompose_bool_le_reif,
    "bool_lin_le" => decompose_bool_lin_le,
    "bool_lin_eq" => decompose_bool_lin_eq,
    "bool_lt" => decompose_bool_lt,
    "bool_lt_reif" => decompose_bool_lt_reif,
    "bool_not" => decompose_bool_not,
    "bool_xor" => decompose_bool_xor,
    "bool_or" => decompose_bool_or,
    "set_le" => decompose_set_le,
    "set_le_reif" => decompose_set_le_reif,
    "set_lt" => decompose_set_lt,
    "set_lt_reif" => decompose_set_lt_reif,
    "array_set_element" => decompose_array_set_element,
    "array_var_set_element" => decompose_array_var_set_element,
    "set_card" => decompose_set_card,
    "set_diff" => decompose_set_diff,
    "set_eq" => decompose_set_eq,
    "set_eq_reif" => decompose_set_eq_reif,
    "set_in_reif" => decompose_set_in_reif,
    "set_intersect" => decompose_set_intersect,
    "set_superset" => decompose_set_superset,
    "set_superset_reif" => decompose_set_superset_reif,
    "set_ne" => decompose_set_ne,
    "set_ne_reif" => decompose_set_ne_reif,
    "set_subset" => decompose_set_subset,
    "set_subset_reif" => decompose_set_subset_reif,
    "set_symdiff" => decompose_set_symdiff,
    "set_union" => decompose_set_union,
    "gecode_cumulatives" => decompose_global_cumulatives,
    "gecode_int_element" => decompose_global_int_element,
    "int_lin_eq_imp" => decompose_global_int_lin_eq_imp,
    "array_int_maximum" => decompose_global_array_int_maximum,
    "gecode_schedule_unary" => decompose_global_schedule_unary,
    "int_le_imp" => decompose_global_int_le_imp,
    "gecode_global_cardinality" => decompose_global_global_cardinality,
    "fzn_global_cardinality_low_up" => decompose_global_cardinality_low_up,
    "gecode_maximum_arg_int_offset" => decompose_global_maximum_arg_int_offset,
    "gecode_circuit" => decompose_global_circuit,
    "fzn_count_eq_reif" => decompose_global_count_eq_reif,
    "set_in_imp" => decompose_global_set_in_imp,
    "fzn_count_eq" => decompose_global_fzn_count_eq,
    "fzn_global_cardinality_low_up_closed" => decompose_global_fzn_global_cardinality_low_up_closed,
    "bool_xor_imp" => decompose_global_bool_xor_imp,
    "gecode_nooverlap" => decompose_global_nooverlap,
    "gecode_regular" => decompose_global_regular,
    "fzn_all_different_int" => decompose_global_all_different_int,
    "int_eq_imp" => decompose_global_int_eq_imp,
    "fzn_all_equal_int" => decompose_global_all_equal,
    "gecode_bool_element" => decompose_global_bool_element,
    "array_int_minimum" => decompose_global_array_int_minimum,
    "bool_clause_reif" => decompose_global_bool_clause_reif,
    "gecode_int_element2d" => decompose_global_int_element_2d,
    "gecode_bin_packing_load" => decompose_global_bin_packing_load,
    "gecode_table_int" => decompose_global_table_int,
    "gecode_precede" => decompose_global_precede,
    "array_int_lq" => decompose_global_array_int_lq,
    "int_lin_le_imp" => decompose_global_int_lin_le_imp,
    "int_lin_ne_imp" => decompose_global_int_lin_ne_imp,
    "fzn_increasing_int" => decompose_global_increasing_int,
    "inverse_offsets" => decompose_global_inverse_offsets,
    "fzn_nvalue" => decompose_global_nvalue,
    "int_ne_imp" => decompose_global_int_ne_imp,
    "gecode_table_int_imp" => decompose_global_table_int_imp,
    "fzn_member_int" => decompose_global_fzn_member_int,
    "gecode_global_cardinality_closed" => decompose_global_global_cardinality_closed,
    "gecode_int_pow" => decompose_global_gecode_int_pow,
    "fzn_at_most_int" => decompose_fzn_at_most_int,
    "fzn_at_least_int" => decompose_global_fzn_at_least_int,
    "fzn_increasing_bool" => decompose_global_fzn_increasing_bool
)

function parse_constraint(line::String, parameters::Dict{String,Parameter}, vars::Dict{String,Variable}, graph::Graph)::Graph
    open_idx = findnext('(', line, 12)
    if isnothing(open_idx)
        return graph
    end
    
    id_start = 12
    id_end = open_idx - 1
    while id_start <= id_end && (line[id_start] == ' ' || line[id_start] == '\t')
        id_start = nextind(line, id_start)
    end
    while id_end >= id_start && (line[id_end] == ' ' || line[id_end] == '\t')
        id_end = prevind(line, id_end)
    end
    if id_start > id_end
        return graph
    end
    identifier = String(SubString(line, id_start, id_end))
    
    # Find matching closing parenthesis
    close_idx = -1
    nest_level = 0
    for idx in open_idx:length(line)
        c = line[idx]
        if c == '('
            nest_level += 1
        elseif c == ')'
            nest_level -= 1
            if nest_level == 0
                close_idx = idx
                break
            end
        end
    end
    
    if close_idx == -1
        return graph
    end
    
    components_str = SubString(line, open_idx+1, close_idx-1)
    
    normalize = !occursin("element", identifier)
    normalize = startswith(identifier, "gecode") ? true : normalize
    components = decompose_parameters(components_str, vars, parameters, graph, normalize)
    
    handler = get(CONSTRAINT_HANDLERS, identifier, nothing)
    if !isnothing(handler)
        return handler(components, graph)
    end
    return graph
end

export is_constraint_line, parse_constraint

end
