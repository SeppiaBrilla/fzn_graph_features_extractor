//! `.graph` file serialization, byte-identical to the Julia `write_graph`.
//!
//! Format:
//! ```text
//! ##<n_nodes> - <n_edges>
//! nodes:
//! <id>: <label> -- <type>                          (plain nodes)
//! <id>: <label> -- var_node -- <var_type> -- <dom> (var nodes)
//! <id>: <label> -- literal_node -- <var_type> -- <label> (literal nodes)
//! edges:
//! <idx>: <from>--<to>--<label>
//! ```

use crate::graph::types::Graph;
use crate::interner::{
    TypeId, T_BOOL, T_FLOAT, T_INT, T_PARAMETER_NODE, T_PAR_NODE, T_SETOFINT, T_VAR_NODE,
};

pub fn write_graph(graph: &Graph, filepath: &str) -> std::io::Result<()> {
    use std::io::Write;
    let mut file = std::fs::File::create(filepath)?;

    writeln!(file, "##{} - {}", graph.nodes.len(), graph.edges.len())?;
    writeln!(file, "nodes:")?;

    for node in &graph.nodes {
        match node.node_type {
            T_VAR_NODE => writeln!(
                file,
                "{}: {} -- var_node -- {} -- {}",
                node.id, node.label, node.var_type.as_str(), node.var_dom_size
            )?,
            T_PARAMETER_NODE => writeln!(
                file,
                "{}: {} -- parameter_node -- {} -- {}",
                node.id, node.label, node.var_type.as_str(), node.var_dom_size
            )?,
            t if is_literal_type(t) => writeln!(
                file,
                "{}: {} -- literal_node -- {} -- {}",
                node.id, node.label, node.var_type.as_str(), node.label
            )?,
            _ => writeln!(
                file,
                "{}: {} -- {}",
                node.id, node.label, node.node_type.as_str()
            )?,
        }
    }

    writeln!(file, "edges:")?;

    for (idx, (n1, n2, label)) in graph.edges.iter().enumerate() {
        writeln!(file, "{}: {}--{}--{}", idx, n1, n2, label.as_str())?;
    }

    Ok(())
}

/// The Julia writer emits `literal_node` lines for node types
/// `int | float | bool | SetOfInt` (the *node* type, not var_type).
#[inline]
fn is_literal_type(t: TypeId) -> bool {
    t == T_INT || t == T_FLOAT || t == T_BOOL || t == T_SETOFINT
}

/// Re-exported for the graph loader and other readers: does this node type
/// serialize as a `literal_node` line?
pub fn serializes_as_literal(t: TypeId) -> bool {
    is_literal_type(t)
}

/// `parameter_node` / `par_node` normalize to `par_node` on load in the
/// Julia GraphLoader; the writer always writes `parameter_node`.
#[allow(dead_code)]
pub fn is_parameter(t: TypeId) -> bool {
    t == T_PARAMETER_NODE || t == T_PAR_NODE
}
