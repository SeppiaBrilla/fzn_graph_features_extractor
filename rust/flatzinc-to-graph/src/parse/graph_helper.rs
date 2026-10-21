//! Graph construction helpers, port of `parse/graph/helper.jl`.
//!
//! The critical semantic: `get_node_for_val` — nodes are looked up/created by
//! id = hash(label), and a lookup can *return an existing node of a different
//! declared type* (first-registered wins). This drives dedup of literal nodes
//! across constraints, so it must match Julia exactly.

use crate::graph::types::{Graph, Node};
use crate::julia_hash::jl_hash_str;
use std::cell::Cell;

use super::parameters::{ParElement, Parameter};
use super::variables::Variable;

thread_local! {
    /// Task-local counter for unique node names (Julia `task_local_storage`).
    static COUNTER: Cell<u64> = const { Cell::new(0) };
    static PREFIX: Cell<u64> = const { Cell::new(0) };
}

pub fn reset_counter() {
    COUNTER.with(|c| c.set(0));
    PREFIX.with(|p| p.set(0));
}

pub fn set_task_prefix(prefix: u64) {
    COUNTER.with(|c| c.set(0));
    PREFIX.with(|p| p.set(prefix));
}

pub fn get_next_global_id() -> u64 {
    COUNTER.with(|c| {
        let v = c.get() + 1;
        c.set(v);
        v
    }) + PREFIX.with(|p| p.get())
}

/// Look up or create a node for a variable reference.
pub fn get_node_for_variable(graph: &mut Graph, val: &Variable) -> Node {
    let id = jl_hash_str(&val.name);
    if let Some(node) = graph.node_dict.get(&id) {
        return node.clone();
    }
    Node::with_var(&val.name, "var_node", id, val.var_type, val.domain_size)
}

/// Look up or create a node for a parameter reference.
pub fn get_node_for_parameter(graph: &mut Graph, val: &Parameter) -> Node {
    let id = jl_hash_str(&val.name);
    if let Some(node) = graph.node_dict.get(&id) {
        return node.clone();
    }
    let node = Node::with_var(&val.name, "parameter_node", id, &val.par_type.type_name, 0);
    graph.add_node(node.clone());
    node
}

/// Look up or create a node for a parameter reference.
/// (typed variant handled inline by callers)

/// Look up or create a node for a plain string (literal or named value).
pub fn get_node_for_string(graph: &mut Graph, el: &str, node_type: &str) -> Node {
    let id = jl_hash_str(el);
    if let Some(node) = graph.node_dict.get(&id) {
        return node.clone();
    }
    let node = Node::with_var(el, node_type, id, node_type, 0);
    graph.add_node(node.clone());
    node
}

use super::parameters::ParValue;

/// `normalize_list` + `get_node_for_val` for arrays of parameters referenced
/// inside constraints: expands a parameter (or scalar) into its element nodes.
///
/// - Non-var array elements are Parameters named by their element string
///   (Julia: `Parameter(String(e), p_type, String(e))`) → `parameter_node`.
/// - Var array elements are plain Strings (literals) or Variables: literals
///   become `int` literal nodes (get_node_for_val default type), variables
///   become var_node lookups.
pub fn param_node_list(graph: &mut Graph, param: &Parameter) -> Vec<Node> {
    let element_type = param.par_type.type_name.clone();
    let is_var = param.par_type.is_var;
    match &param.value {
        ParValue::List(elements) => elements
            .iter()
            .map(|e| match e {
                ParElement::Var(name) => {
                    if is_var {
                        // element is a decision variable name
                        let id = jl_hash_str(name);
                        if let Some(node) = graph.node_dict.get(&id) {
                            node.clone()
                        } else {
                            Node::with_var(name, "var_node", id, "int", 0)
                        }
                    } else {
                        // non-var array: Parameter element named by string
                        let id = jl_hash_str(name);
                        if let Some(node) = graph.node_dict.get(&id) {
                            node.clone()
                        } else {
                            let n = Node::with_var(name, "parameter_node", id, &element_type, 0);
                            graph.add_node(n.clone());
                            n
                        }
                    }
                }
                ParElement::Lit(s) => {
                    if is_var {
                        // literal element in a var array: int literal node
                        let id = jl_hash_str(s);
                        if let Some(node) = graph.node_dict.get(&id) {
                            node.clone()
                        } else {
                            let n = Node::with_var(s, "int", id, "int", 0);
                            graph.add_node(n.clone());
                            n
                        }
                    } else {
                        let id = jl_hash_str(s);
                        if let Some(node) = graph.node_dict.get(&id) {
                            node.clone()
                        } else {
                            let n = Node::with_var(s, "parameter_node", id, &element_type, 0);
                            graph.add_node(n.clone());
                            n
                        }
                    }
                }
            })
            .collect(),
        ParValue::Scalar(s) => {
            let id = jl_hash_str(s);
            if let Some(node) = graph.node_dict.get(&id) {
                vec![node.clone()]
            } else {
                let n = Node::with_var(s, "parameter_node", id, &element_type, 0);
                graph.add_node(n.clone());
                vec![n]
            }
        }
    }
}
