module GraphLoader

using FlatzincToGraph

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

is_global(node_type::SubString{String}) = node_type in GLOBAL_NODES

function load_graph(filepath::String)::Graph
    graph = Graph()

    open(filepath, "r") do file
        nodes_section = false
        edges_section = false
        nodes = Dict{UInt64,Node}()
        globals_count = 0

        for line in eachline(file)
            line = strip(line)
            if line == "nodes:"
                nodes_section = true
                edges_section = false
                continue
            elseif line == "edges:"
                edges_section = true
                nodes_section = false
                continue
            end
            if isempty(line)
                continue
            end

            if nodes_section
                # Format: "idx: label -- type -- extra..."
                parts = split(line, ": ", limit=2)
                if length(parts) < 2
                    continue
                end
                idx_str = parts[1]
                idx = parse(UInt64, idx_str)
                components = split(parts[2], " -- ")
                label = components[1]
                node_type = components[2]

                if node_type == "literal_node" || node_type == "var_node"
                    node = Node(label, node_type, line, idx)
                elseif node_type == "parameter_node" || node_type == "par_node"
                    node = Node(label, "par_node", line, idx)
                elseif is_global(node_type)
                    global_name = replace(node_type, "_node" => "")
                    node = Node(global_name * string(globals_count), node_type, line, idx)
                    globals_count += 1
                else
                    node = Node(label, node_type, line, idx)
                end

                add_node(graph, node)
                nodes[idx] = node
            elseif edges_section
                # Format: "idx: node1--node2--label"
                parts = split(line, ": ", limit=2)
                if length(parts) < 2
                    continue
                end
                edge_components = split(parts[2], "--")
                if length(edge_components) >= 3
                    n1 = parse(UInt64, edge_components[1])
                    n2 = parse(UInt64, edge_components[2])
                    edge_label = edge_components[3]
                    add_edge(graph, n1, n2, Edge(edge_label))
                end
            end
        end
    end

    return graph
end

export load_graph
end