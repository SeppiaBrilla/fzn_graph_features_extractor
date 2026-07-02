module Constraints

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

function is_constraint_line(line::String)
    return startswith(line, "constraint")
end

function to_val(val::String, vars::IdDict{String,Variable}, parameters::IdDict{String,Parameter})
    key = intern(val)
    if haskey(vars, key)
        return vars[key]
    end
    if haskey(parameters, key)
        return parameters[key]
    end
    return val
end


function decompose_parameters(components::AbstractString, vars::IdDict{String,Variable}, parameters::IdDict{String,Parameter})::Vector{Union{Any,Vector{Any}}}
    constraint_parameters::Vector{Union{Any,Vector{Any}}} = []
    components = replace(components, " " => "")
    while length(components) > 0
        if components[1] == '[' #it is an array
            array_end = only(findfirst("]", components))
            param = components[2:array_end-1]
            if param != ""
                push!(constraint_parameters, [to_val(String(val), vars, parameters) for val in split(param, ",")])
            else
                push!(constraint_parameters, [])
            end
            components = components[array_end+2:end]
        elseif components[1] == '{'
            set_end = only(findfirst('}', components))
            param = components[1:set_end]
            push!(constraint_parameters, String(param))
            components = components[set_end+2:end]
        else
            param_end = length(components)
            if occursin(",", components)
                param_end = only(findfirst(",", components)) - 1
            end
            param = components[1:param_end]
            push!(constraint_parameters, to_val(String(param), vars, parameters))
            components = components[param_end+2:end]
        end
    end
    return constraint_parameters
end

function parse_constraint(line::String, parameters::IdDict{String,Parameter}, vars::IdDict{String,Variable}, graph::Graph)::Graph
    line = strip(line[12:end])
    open_idx, close_idx = only(findfirst("(", line)), only(findfirst(")", line))
    identifier = line[1:open_idx-1]
    components_str = line[open_idx+1:close_idx-1]
    components = decompose_parameters(components_str, vars, parameters)

    #integer decompose
    if identifier == "int_lin_eq"
        return decompose_int_lin_eq(components, graph)
    elseif identifier == "int_lin_eq_reif"
        return decompose_int_lin_eq_reif(components, graph)
    elseif identifier == "int_lin_le"
        return decompose_int_lin_le(components, graph)
    elseif identifier == "int_lin_le_reif"
        return decompose_int_lin_le_reif(components, graph)
    elseif identifier == "array_int_element"
        return decompose_array_int_element(components, graph)
    elseif identifier == "array_var_int_element"
        return decompose_array_var_int_element(components, graph)
    elseif identifier == "int_div"
        return decompose_int_div(components, graph)
    elseif identifier == "int_abs"
        return decompose_int_abs(components, graph)
    elseif identifier == "int_eq"
        return decompose_int_eq(components, graph)
    elseif identifier == "int_eq_reif"
        return decompose_int_eq_reif(components, graph)
    elseif identifier == "int_le"
        return decompose_int_le(components, graph)
    elseif identifier == "int_le_reif"
        return decompose_int_le_reif(components, graph)
    elseif identifier == "int_lin_ne"
        return decompose_int_lin_ne(components, graph)
    elseif identifier == "int_lin_ne_reif"
        return decompose_int_lin_ne_reif(components, graph)
    elseif identifier == "int_lt"
        return decompose_int_lt(components, graph)
    elseif identifier == "int_lt_reif"
        return decompose_int_lt_reif(components, graph)
    elseif identifier == "int_max"
        return decompose_int_max(components, graph)
    elseif identifier == "int_min"
        return decompose_int_min(components, graph)
    elseif identifier == "int_times"
        return decompose_int_times(components, graph)
    elseif identifier == "set_in"
        return decompose_set_in(components, graph)
    elseif identifier == "int_mod"
        return decompose_int_mod(components, graph)
    elseif identifier == "int_ne"
        return decompose_int_ne(components, graph)
    elseif identifier == "int_ne_reif"
        return decompose_int_ne_reif(components, graph)
    elseif identifier == "int_plus"
        return decompose_int_plus(components, graph)
    elseif identifier == "int_pow"
        return decompose_int_pow(components, graph)

        #bool decompose
    elseif identifier == "bool_clause"
        return decompose_bool_clause(components, graph)
    elseif identifier == "array_bool_element"
        return decompose_array_bool_element(components, graph)
    elseif identifier == "array_bool_and"
        return decompose_array_bool_and(components, graph)
    elseif identifier == "array_bool_xor"
        return decompose_array_bool_xor(components, graph)
    elseif identifier == "bool2int"
        return decompose_bool2int(components, graph)
    elseif identifier == "array_var_bool_element"
        return decompose_array_var_bool_element(components, graph)
    elseif identifier == "bool_and"
        return decompose_bool_and(components, graph)
    elseif identifier == "bool_eq"
        return decompose_bool_eq(components, graph)
    elseif identifier == "bool_eq_reif"
        return decompose_bool_eq_reif(components, graph)
    elseif identifier == "bool_le"
        return decompose_bool_le(components, graph)
    elseif identifier == "bool_le_reif"
        return decompose_bool_le_reif(components, graph)
    elseif identifier == "bool_lin_le"
        return decompose_bool_lin_le(components, graph)
    elseif identifier == "bool_lin_eq"
        return decompose_bool_lin_eq(components, graph)
    elseif identifier == "bool_lt"
        return decompose_bool_lt(components, graph)
    elseif identifier == "bool_lt_reif"
        return decompose_bool_lt_reif(components, graph)
    elseif identifier == "bool_not"
        return decompose_bool_not(components, graph)
    elseif identifier == "bool_xor"
        return decompose_bool_xor(components, graph)
    elseif identifier == "bool_or"
        return decompose_bool_or(components, graph)

        #decompose set
    elseif identifier == "set_le"
        return decompose_set_le(components, graph)
    elseif identifier == "set_le_reif"
        return decompose_set_le_reif(components, graph)
    elseif identifier == "set_lt"
        return decompose_set_lt(components, graph)
    elseif identifier == "set_lt_reif"
        return decompose_set_lt_reif(components, graph)
    elseif identifier == "array_set_element"
        return decompose_array_set_element(components, graph)
    elseif identifier == "array_var_set_element"
        return decompose_array_var_set_element(components, graph)
    elseif identifier == "set_card"
        return decompose_set_card(components, graph)
    elseif identifier == "set_diff"
        return decompose_set_diff(components, graph)
    elseif identifier == "set_eq"
        return decompose_set_eq(components, graph)
    elseif identifier == "set_eq_reif"
        return decompose_set_eq_reif(components, graph)
    elseif identifier == "set_in_reif"
        return decompose_set_in_reif(components, graph)
    elseif identifier == "set_intersect"
        return decompose_set_intersect(components, graph)
    elseif identifier == "set_superset"
        return decompose_set_superset(components, graph)
    elseif identifier == "set_superset_reif"
        return decompose_set_superset_reif(components, graph)
    elseif identifier == "set_ne"
        return decompose_set_ne(components, graph)
    elseif identifier == "set_ne_reif"
        return decompose_set_ne_reif(components, graph)
    elseif identifier == "set_subset"
        return decompose_set_subset(components, graph)
    elseif identifier == "set_subset_reif"
        return decompose_set_subset_reif(components, graph)
    elseif identifier == "set_symdiff"
        return decompose_set_symdiff(components, graph)
    elseif identifier == "set_union"
        return decompose_set_union(components, graph)

        #decompose globals
    elseif identifier == "gecode_cumulatives"
        return decompose_global_cumulatives(components, graph)
    elseif identifier == "gecode_int_element"
        return decompose_global_int_element(components, graph)
    elseif identifier == "int_lin_eq_imp"
        return decompose_global_int_lin_eq_imp(components, graph)
    elseif identifier == "array_int_maximum"
        return decompose_global_array_int_maximum(components, graph)
    elseif identifier == "gecode_schedule_unary"
        return decompose_global_schedule_unary(components, graph)
    elseif identifier == "int_le_imp"
        return decompose_global_int_le_imp(components, graph)
    elseif identifier == "gecode_global_cardinality"
        return decompose_global_global_cardinality(components, graph)
    elseif identifier == "fzn_global_cardinality_low_up"
        return decompose_global_cardinality_low_up(components, graph)
    elseif identifier == "gecode_maximum_arg_int_offset"
        return decompose_global_maximum_arg_int_offset(components, graph)
    elseif identifier == "gecode_circuit"
        return decompose_global_circuit(components, graph)
    elseif identifier == "fzn_count_eq_reif"
        return decompose_global_count_eq_reif(components, graph)
    elseif identifier == "set_in_imp"
        return decompose_global_set_in_imp(components, graph)
    elseif identifier == "fzn_count_eq"
        return decompose_global_fzn_count_eq(components, graph)
    elseif identifier == "fzn_global_cardinality_low_up_closed"
        return decompose_global_fzn_global_cardinality_low_up_closed(components, graph)
    elseif identifier == "bool_xor_imp"
        return decompose_global_bool_xor_imp(components, graph)
    elseif identifier == "gecode_nooverlap"
        return decompose_global_nooverlap(components, graph)
    elseif identifier == "gecode_regular"
        return decompose_global_regular(components, graph)
    elseif identifier == "fzn_all_different_int"
        return decompose_global_all_different_int(components, graph)
    elseif identifier == "int_eq_imp"
        return decompose_global_int_eq_imp(components, graph)
    elseif identifier == "fzn_all_equal_int"
        return decompose_global_all_equal(components, graph)
    elseif identifier == "gecode_bool_element"
        return decompose_global_bool_element(components, graph)
    elseif identifier == "array_int_minimum"
        return decompose_global_array_int_minimum(components, graph)
    elseif identifier == "bool_clause_reif"
        return decompose_global_bool_clause_reif(components, graph)
    elseif identifier == "gecode_int_element2d"
        return decompose_global_int_element_2d(components, graph)
    elseif identifier == "gecode_bin_packing_load"
        return decompose_global_bin_packing_load(components, graph)
    elseif identifier == "gecode_table_int"
        return decompose_global_table_int(components, graph)
    elseif identifier == "gecode_precede"
        return decompose_global_precede(components, graph)
    elseif identifier == "array_int_lq"
        return decompose_global_array_int_lq(components, graph)
    elseif identifier == "int_lin_le_imp"
        return decompose_global_int_lin_le_imp(components, graph)
    elseif identifier == "int_lin_ne_imp"
        return decompose_global_int_lin_ne_imp(components, graph)
    elseif identifier == "fzn_increasing_int"
        return decompose_global_increasing_int(components, graph)
    elseif identifier == "inverse_offsets"
        return decompose_global_inverse_offsets(components, graph)
    elseif identifier == "fzn_nvalue"
        return decompose_global_nvalue(components, graph)
    elseif identifier == "int_ne_imp"
        return decompose_global_int_ne_imp(components, graph)
    elseif identifier == "gecode_table_int_imp"
        return decompose_global_table_int_imp(components, graph)
    elseif identifier == "fzn_member_int"
        return decompose_global_fzn_member_int(components, graph)
    elseif identifier == "gecode_global_cardinality_closed"
        return decompose_global_global_cardinality_closed(components, graph)
    elseif identifier == "gecode_int_pow"
        return decompose_global_gecode_int_pow(components, graph)
    elseif identifier == "fzn_at_most_int"
        return decompose_fzn_at_most_int(components, graph)
    elseif identifier == "fzn_at_least_int"
        return decompose_global_fzn_at_least_int(components, graph)
    elseif identifier == "fzn_increasing_bool"
        return decompose_global_fzn_increasing_bool(components, graph)
    end
    return graph
end

export is_constraint_line, parse_constraint

end
