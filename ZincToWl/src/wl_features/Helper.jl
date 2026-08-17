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

function extract_extra_info(g)::Dict{String,Any}
    n_nodes = length(g.nodes)
    if n_nodes == 0
        return Dict{String,Any}(
            "globals_pairs" => Dict(),
            "cpv" => 0.0, "cpp" => 0.0, "n_nodes" => 0,
            "d_ratio_int_vars" => 0.0, "d_ratio_bool_vars" => 0.0,
            "o_deg_cons" => 0.0, "o_deg_std" => 0.0, "o_dom_deg" => 0.0,
            "v_ent_deg_vars" => 0.0, "v_sum_domdeg_vars" => 0.0
        )
    end

    out_degrees = Dict{UInt64,Int}()
    pairs = Dict{Tuple{Symbol,Symbol},Int}()
    
    obj_var_id = UInt64(0)

    for (from_id, to_id, _) in g.edges
        out_degrees[from_id] = get(out_degrees, from_id, 0) + 1

        to_node = g.node_dict[to_id]
        if is_cut_node(to_node.type)
            from_node = g.node_dict[from_id]
            pair = (typer(from_node.type), to_node.type)
            pairs[pair] = get(pairs, pair, 0) + 1
        end
        
        if g.node_dict[from_id].type === :maximise_node || g.node_dict[from_id].type === :minimise_node
            obj_var_id = to_id
        end
    end

    in_degrees = Dict{UInt64,Int}()
    for (from_id, to_id, _) in g.edges
        in_degrees[to_id] = get(in_degrees, to_id, 0) + 1
    end
    n_constraints = 0
    for node in g.nodes
        if get(in_degrees, node.id, 0) > 0 && get(out_degrees, node.id, 0) == 0
            n_constraints += 1
        end
    end

    constraints_per_variable = 0
    constraints_per_par = 0
    n_var = 0
    n_par = 0
    
    int_vars = 0
    bool_vars = 0
    
    var_degrees = Int[]
    
    v_sum_domdeg_vars = 0.0
    obj_deg = 0.0
    obj_dom = 0.0

    for node in g.nodes
        t = typer(node.type)
        if node.type === :var_node
            deg = get(out_degrees, node.id, 0)
            constraints_per_variable += deg
            n_var += 1
            push!(var_degrees, deg)
            
            parts = split(node.value, " -- ")
            dom_size = 1.0
            if length(parts) >= 4
                dom_type = parts[3]
                if dom_type == "int"
                    int_vars += 1
                elseif dom_type == "bool"
                    bool_vars += 1
                end
                dom_size_parsed = tryparse(Float64, parts[4])
                if !isnothing(dom_size_parsed)
                    dom_size = dom_size_parsed
                end
            end
            
            v_sum_domdeg_vars += dom_size / max(1.0, float(deg))
            
            if node.id == obj_var_id
                obj_deg = float(deg)
                obj_dom = float(dom_size)
            end
            
        elseif t === :literal_node
            constraints_per_par += get(out_degrees, node.id, 0)
            n_par += 1
        end
    end

    cpv = n_var > 0 ? constraints_per_variable / n_var : 0.0
    cpp = n_par > 0 ? constraints_per_par / n_par : 0.0
    
    d_ratio_int_vars = n_var > 0 ? int_vars / n_var : 0.0
    d_ratio_bool_vars = n_var > 0 ? bool_vars / n_var : 0.0
    
    v_ent_deg_vars = 0.0
    if n_var > 0
        freq = Dict{Int,Int}()
        for d in var_degrees
            freq[d] = get(freq, d, 0) + 1
        end
        for (d, count) in freq
            p = count / n_var
            v_ent_deg_vars -= p * log(p)
        end
    end
    
    mean_deg = n_var > 0 ? sum(var_degrees) / n_var : 0.0
    var_deg = n_var > 1 ? sum((d - mean_deg)^2 for d in var_degrees) / (n_var - 1) : 0.0
    std_deg = sqrt(var_deg)
    
    o_deg_std = 0.0
    if obj_var_id != 0 && std_deg > 0
        o_deg_std = (obj_deg - mean_deg) / std_deg
    end
    
    o_deg_cons = 0.0
    if obj_var_id != 0 && n_constraints > 0
        o_deg_cons = obj_deg / n_constraints
    end
    
    o_dom_deg = 0.0
    if obj_var_id != 0 && obj_deg > 0
        o_dom_deg = obj_dom / obj_deg
    end

    return Dict{String,Any}(
        "globals_pairs" => pairs,
        "cpv" => cpv,
        "cpp" => cpp,
        "n_nodes" => n_nodes,
        "d_ratio_int_vars" => d_ratio_int_vars,
        "d_ratio_bool_vars" => d_ratio_bool_vars,
        "o_deg_cons" => o_deg_cons,
        "o_deg_std" => o_deg_std,
        "o_dom_deg" => o_dom_deg,
        "v_ent_deg_vars" => v_ent_deg_vars,
        "v_sum_domdeg_vars" => v_sum_domdeg_vars
    )
end

export typer, is_global, is_cut_node, GLOBAL_NODES, load_colors, save_colors, tailored_hash, HASH_EDGE_0, HASH_EDGE_1, HASH_EDGE_2, fast_edge_hash, extract_extra_info

end