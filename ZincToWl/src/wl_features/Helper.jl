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

const CUT_NODES = union(GLOBAL_NODES, Set{Symbol}([
    :multi_and_node, :multi_or_node, :multi_xor_node,
    :maximise_node, :minimise_node, :satisfy_node
]))

@inline function is_global(node_type::Symbol)::Bool
    return in(node_type, GLOBAL_NODES)
end

@inline function is_cut_node(node_type::Symbol)::Bool
    return in(node_type, CUT_NODES)
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

function extract_extra_info(g, num_cores::Int=1)::Dict{String,Any}
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

    n_threads = min(num_cores, Threads.nthreads())
    n_edges = length(g.edges)

    obj_var_id = UInt64(0)
    for node in g.nodes
        if node.type === :maximise_node || node.type === :minimise_node
            for (f_id, t_id, _) in g.edges
                if f_id == node.id
                    obj_var_id = t_id
                    break
                end
            end
            break
        end
    end

    out_degrees_t = [Dict{UInt64,Int}() for _ in 1:n_threads]
    in_degrees_t = [Dict{UInt64,Int}() for _ in 1:n_threads]
    pairs_t = [Dict{Tuple{Symbol,Symbol},Int}() for _ in 1:n_threads]

    tasks_edges = Task[]
    chunk_size_edges = ceil(Int, n_edges / n_threads)

    for t in 1:n_threads
        start_idx = (t - 1) * chunk_size_edges + 1
        end_idx = min(t * chunk_size_edges, n_edges)
        if start_idx > n_edges
            break
        end

        push!(tasks_edges, Threads.@spawn begin
            out_deg = out_degrees_t[t]
            in_deg = in_degrees_t[t]
            p = pairs_t[t]

            for i in start_idx:end_idx
                from_id, to_id, _ = g.edges[i]

                out_deg[from_id] = get(out_deg, from_id, 0) + 1
                in_deg[to_id] = get(in_deg, to_id, 0) + 1

                to_node = g.node_dict[to_id]
                to_type = to_node.type

                if is_cut_node(to_type)
                    from_node = g.node_dict[from_id]
                    pair = (typer(from_node.type), to_type)
                    p[pair] = get(p, pair, 0) + 1
                end
            end
        end)
    end

    for task in tasks_edges
        wait(task)
    end

    out_degrees = Dict{UInt64,Int}()
    in_degrees = Dict{UInt64,Int}()
    pairs = Dict{Tuple{Symbol,Symbol},Int}()

    for t in 1:n_threads
        for (k, v) in out_degrees_t[t]
            out_degrees[k] = get(out_degrees, k, 0) + v
        end
        for (k, v) in in_degrees_t[t]
            in_degrees[k] = get(in_degrees, k, 0) + v
        end
        for (k, v) in pairs_t[t]
            pairs[k] = get(pairs, k, 0) + v
        end
    end

    chunk_size_nodes = ceil(Int, n_nodes / n_threads)
    tasks_nodes = Task[]

    for t in 1:n_threads
        start_idx = (t - 1) * chunk_size_nodes + 1
        end_idx = min(t * chunk_size_nodes, n_nodes)
        if start_idx > n_nodes
            break
        end

        push!(tasks_nodes, Threads.@spawn begin
            n_constraints_t = 0
            constraints_per_variable_t = 0
            constraints_per_par_t = 0
            n_var_t = 0
            n_par_t = 0
            int_vars_t = 0
            bool_vars_t = 0

            freq_t = Dict{Int,Int}()
            v_sum_domdeg_vars_t = 0.0
            obj_deg_t = 0.0
            obj_dom_t = 0.0

            for i in start_idx:end_idx
                node = g.nodes[i]

                t_node = typer(node.type)
                if node.type === :var_node
                    out_d = get(out_degrees, node.id, 0)
                    constraints_per_variable_t += out_d
                    n_var_t += 1

                    freq_t[out_d] = get(freq_t, out_d, 0) + 1

                    if node.var_type === :int
                        int_vars_t += 1
                    elseif node.var_type === :bool
                        bool_vars_t += 1
                    end

                    if out_d > 0
                        v_sum_domdeg_vars_t += node.var_dom_size / float(out_d)
                    end

                    if node.id == obj_var_id
                        obj_deg_t = float(out_d)
                        obj_dom_t = float(node.var_dom_size)
                    end

                elseif t_node === :literal_node
                    out_d = get(out_degrees, node.id, 0)
                    constraints_per_par_t += out_d
                    n_par_t += 1
                end

                if get(in_degrees, node.id, 0) > 0 && get(out_degrees, node.id, 0) == 0
                    n_constraints_t += 1
                end
            end

            return (n_constraints_t, constraints_per_variable_t, constraints_per_par_t, n_var_t, n_par_t, int_vars_t, bool_vars_t, freq_t, v_sum_domdeg_vars_t, obj_deg_t, obj_dom_t)
        end)
    end

    n_constraints = 0
    constraints_per_variable = 0
    constraints_per_par = 0
    n_var = 0
    n_par = 0
    int_vars = 0
    bool_vars = 0
    freq = Dict{Int,Int}()
    v_sum_domdeg_vars = 0.0
    obj_deg = 0.0
    obj_dom = 0.0

    for task in tasks_nodes
        res = fetch(task)
        n_constraints += res[1]
        constraints_per_variable += res[2]
        constraints_per_par += res[3]
        n_var += res[4]
        n_par += res[5]
        int_vars += res[6]
        bool_vars += res[7]

        for (d, count) in res[8]
            freq[d] = get(freq, d, 0) + count
        end

        v_sum_domdeg_vars += res[9]

        if res[10] > 0.0
            obj_deg = res[10]
        end
        if res[11] > 0.0
            obj_dom = res[11]
        end
    end

    cpv = n_var > 0 ? constraints_per_variable / n_var : 0.0
    cpp = n_par > 0 ? constraints_per_par / n_par : 0.0

    d_ratio_int_vars = n_var > 0 ? int_vars / n_var : 0.0
    d_ratio_bool_vars = n_var > 0 ? bool_vars / n_var : 0.0

    v_ent_deg_vars = 0.0
    if n_var > 0
        for (_, count) in freq
            p = count / n_var
            v_ent_deg_vars -= p * log2(p)
        end
    end

    mean_deg = n_var > 0 ? constraints_per_variable / n_var : 0.0
    var_deg = 0.0
    if n_var > 0
        for (d, count) in freq
            var_deg += count * (d - mean_deg)^2
        end
        var_deg /= n_var
    end
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