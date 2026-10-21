//! `.graph` file deserializer, port of `GraphLoader.jl`.

use std::collections::HashMap;
use std::io::BufRead;

use flatzinc_to_graph::graph::types::{Edge, EdgeLabel, Graph, Node};
use flatzinc_to_graph::julia_hash::jl_hash_str;

use crate::helper::{is_global, GLOBAL_NODES};

/// Load a `.graph` file. Mirrors the Julia loader including its handling of
/// global nodes (relabeling to `name + counter`) and parameter nodes
/// (re-typed to `par_node`).
pub fn load_graph(filepath: &str) -> std::io::Result<Graph> {
    let mut graph = Graph::new();
    let file = std::fs::File::open(filepath)?;
    let mut reader = std::io::BufReader::new(file);

    let mut header = String::new();
    reader.read_line(&mut header)?;

    if !header.starts_with("##") {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "Invalid header",
        ));
    }
    // header: "## n. nodes - n. edges"
    let pos = header
        .find(" - ")
        .ok_or_else(|| std::io::Error::new(std::io::ErrorKind::InvalidData, "Invalid header"))?;
    let _n_nodes: usize = header[2..pos].trim().parse().unwrap_or(0);
    let _n_edges: usize = header[pos + 3..].trim().parse().unwrap_or(0);

    let mut nodes_section = false;
    let mut edges_section = false;
    let mut globals_count = 0u64;

    let mut line_no = 0usize;
    loop {
        let mut line = String::new();
        if reader.read_line(&mut line)? == 0 {
            break;
        }
        line_no += 1;
        let _ = line_no;
        let line = line.trim();
        if line == "nodes:" {
            nodes_section = true;
            edges_section = false;
            continue;
        } else if line == "edges:" {
            edges_section = true;
            nodes_section = false;
            continue;
        }
        if line.is_empty() {
            continue;
        }

        if nodes_section {
            // Format: "idx: label -- type [-- var_type [-- dom]]
            let Some(colon) = line.find(':') else { continue };
            let idx_str = &line[..colon];
            let rest = line[colon + 1..].trim_start();
            let Ok(idx) = idx_str.trim().parse::<u64>() else {
                continue;
            };

            let Some(sep1) = rest.find(" -- ") else { continue };
            let label = &rest[..sep1];

            let start_node_type = sep1 + 4;
            let (node_type, next_pos) = match rest[start_node_type..].find(" -- ") {
                Some(rel) => {
                    let end = start_node_type + rel;
                    (&rest[start_node_type..end], Some(end + 4))
                }
                None => (&rest[start_node_type..], None),
            };

            let mut var_type = "None";
            let mut var_dom_size: i64 = 0;
            if let Some(start_var_type) = next_pos {
                match rest[start_var_type..].find(" -- ") {
                    None => var_type = &rest[start_var_type..],
                    Some(rel) => {
                        let end = start_var_type + rel;
                        var_type = &rest[start_var_type..end];
                        let dom_str = &rest[end + 4..];
                        if let Ok(d) = dom_str.trim().parse::<i64>() {
                            var_dom_size = d;
                        }
                    }
                }
            }

            let node = match node_type {
                "literal_node" | "var_node" => Node::with_var(label, node_type, idx, var_type, var_dom_size),
                "parameter_node" | "par_node" => Node::with_var(label, "par_node", idx, var_type, var_dom_size),
                t if is_global(t) => {
                    let global_name = t.trim_end_matches("_node");
                    let new_label = format!("{}{}", global_name, globals_count);
                    globals_count += 1;
                    Node::with_var(new_label, t, idx, var_type, var_dom_size)
                }
                t => Node::with_var(label, t, idx, var_type, var_dom_size),
            };
            graph.add_node(node);
        } else if edges_section {
            // Format: "idx: node1--node2--label"
            let Some(colon) = line.find(':') else { continue };
            let rest = line[colon + 1..].trim();
            let Some(sep1) = rest.find("--") else { continue };
            let Ok(n1) = rest[..sep1].parse::<u64>() else { continue };
            let after = &rest[sep1 + 2..];
            let Some(sep2) = after.find("--") else { continue };
            let Ok(n2) = after[..sep2].parse::<u64>() else { continue };
            let label_str = &after[sep2 + 2..];
            // stop at a further "--" if present (Julia: findnext("--", ...))
            let label = match label_str.find("--") {
                Some(rel) => &label_str[..rel],
                None => label_str,
            };
            graph.add_edge(n1, n2, &Edge::new(EdgeLabel::new(label)));
        }
    }

    Ok(graph)
}

#[allow(unused)]
fn _unused(_: &HashMap<String, Node>, _: &str, _: &str) {
    let _ = jl_hash_str("");
    let _ = GLOBAL_NODES;
}
