//! Constraint line parsing and dispatch, port of `parse/constraint.jl`.

use crate::graph::types::{Graph, Node};
use crate::julia_hash::jl_hash_str;
use std::collections::HashMap;

use super::graph_helper;
use super::parameters::Parameter;
use super::variables::Variable;

/// A parsed constraint argument: single node or array of nodes.
#[derive(Debug, Clone)]
pub enum Arg {
    One(Node),
    Many(Vec<Node>),
}

impl Arg {
    pub fn as_nodes(&self) -> Vec<Node> {
        match self {
            Arg::One(n) => vec![n.clone()],
            Arg::Many(v) => v.clone(),
        }
    }
    /// Julia's implicit iteration: `args[1]` used where a vector is expected
    /// iterates elements; used where a scalar is expected, takes [1].
    /// (Kept for API parity; the hot paths use `first_ref`.)
    #[allow(dead_code)]
    pub fn first(&self) -> Node {
        match self {
            Arg::One(n) => n.clone(),
            Arg::Many(v) => v.first().cloned().unwrap(),
        }
    }
    /// Borrowed access to the first node (allocation-free `first`).
    pub fn first_ref(&self) -> &Node {
        match self {
            Arg::One(n) => n,
            Arg::Many(v) => v.first().unwrap(),
        }
    }
    /// Borrowed slice of all nodes (empty for `Arg::One`? no — one element).
    pub fn nodes_ref(&self) -> &[Node] {
        match self {
            Arg::One(n) => std::slice::from_ref(n),
            Arg::Many(v) => v,
        }
    }
}

/// `to_val`: resolve one raw argument token to node(s).
fn to_val(
    val: &str,
    vars: &HashMap<String, Variable>,
    parameters: &HashMap<String, Parameter>,
    graph: &mut Graph,
    normalize: bool,
) -> Arg {
    if let Some(var) = vars.get(val) {
        return Arg::One(graph_helper::get_node_for_variable(graph, var));
    }
    if let Some(param) = parameters.get(val) {
        if param.par_type.is_array && normalize {
            return Arg::Many(graph_helper::param_node_list(graph, param));
        }
        return Arg::One(graph_helper::get_node_for_parameter(graph, param));
    }
    let id = jl_hash_str(val);
    if let Some(node) = graph.node_dict.get(&id) {
        return Arg::One(node.clone());
    }
    let t = super::helper::get_type(val);
    Arg::One(graph_helper::get_node_for_string(graph, val, t))
}

/// `decompose_parameters`: split the argument list at top-level commas,
/// handling `[...]` arrays and `{...}` sets.
pub fn decompose_parameters(
    components: &str,
    vars: &HashMap<String, Variable>,
    parameters: &HashMap<String, Parameter>,
    graph: &mut Graph,
    normalize: bool,
) -> Vec<Arg> {
    let mut constraint_parameters: Vec<Arg> = Vec::new();
    let bytes = components.as_bytes();
    let len = bytes.len();
    let mut i = 0usize;

    fn skip_ws(b: &[u8], mut idx: usize) -> usize {
        while idx < b.len() && matches!(b[idx], b' ' | b'\t' | b'\n' | b'\r') {
            idx += 1;
        }
        idx
    }

    i = skip_ws(bytes, i);
    while i < len {
        if bytes[i] == b'[' {
            let array_start = i + 1;
            let close_idx = match components[array_start..].find(']') {
                Some(rel) => array_start + rel,
                None => break,
            };

            let mut arr_nodes: Vec<Node> = Vec::new();
            let mut p = array_start;
            let p_end = close_idx; // exclusive
            while p < p_end {
                p = skip_ws(bytes, p);
                if p >= p_end {
                    break;
                }
                let next_comma = components[p..].find(',').map(|r| p + r);
                let val_end = match next_comma {
                    Some(nc) if nc < p_end => nc - 1,
                    _ => p_end - 1,
                };
                // strip trailing whitespace
                let mut v_end = val_end as isize;
                while v_end >= p as isize
                    && matches!(bytes[v_end as usize], b' ' | b'\t' | b'\n' | b'\r')
                {
                    v_end -= 1;
                }
                if (v_end as usize) >= p && v_end >= 0 {
                    let val_sub = &components[p..=v_end as usize];
                    match to_val(val_sub, vars, parameters, graph, false) {
                        Arg::One(n) => arr_nodes.push(n),
                        Arg::Many(v) => arr_nodes.extend(v),
                    }
                }
                p = match next_comma {
                    Some(nc) if nc < p_end => nc + 1,
                    _ => p_end + 1,
                };
            }
            constraint_parameters.push(Arg::Many(arr_nodes));

            i = close_idx + 1;
            i = skip_ws(bytes, i);
            if i < len && bytes[i] == b',' {
                i += 1;
                i = skip_ws(bytes, i);
            }
        } else if bytes[i] == b'{' {
            let close_idx = match components[i + 1..].find('}') {
                Some(rel) => i + 1 + rel,
                None => break,
            };
            let set_sub = &components[i..=close_idx];
            constraint_parameters.push(Arg::One(graph_helper::get_node_for_string(
                graph,
                set_sub,
                "set of int",
            )));

            i = close_idx + 1;
            i = skip_ws(bytes, i);
            if i < len && bytes[i] == b',' {
                i += 1;
                i = skip_ws(bytes, i);
            }
        } else {
            let comma_idx = components[i..].find(',').map(|r| i + r);
            let val_end = match comma_idx {
                Some(ci) if ci <= len => ci - 1,
                _ => len - 1,
            };

            let mut v_start = i;
            while v_start <= val_end
                && matches!(bytes[v_start], b' ' | b'\t' | b'\n' | b'\r')
            {
                v_start += 1;
            }
            let mut v_end = val_end;
            while v_end >= v_start && matches!(bytes[v_end], b' ' | b'\t' | b'\n' | b'\r') {
                v_end -= 1;
            }

            if v_start <= v_end {
                let val_sub = &components[v_start..=v_end];
                constraint_parameters.push(to_val(val_sub, vars, parameters, graph, normalize));
            }

            i = match comma_idx {
                Some(ci) => ci + 1,
                None => len + 1,
            };
            i = skip_ws(bytes, i);
        }
    }

    constraint_parameters
}

/// `parse_constraint`: extract identifier + args, then dispatch.
pub fn parse_constraint(
    line: &str,
    parameters: &HashMap<String, Parameter>,
    vars: &HashMap<String, Variable>,
    graph: &mut Graph,
) {
    // Julia: findnext('(', line, 12) — "constraint " is 11 chars
    let open_idx = match line.get(11..).and_then(|rest| rest.find('(')).map(|r| 11 + r) {
        Some(i) if i >= 11 => i,
        _ => return,
    };

    let mut id_start = 11usize;
    let mut id_end = open_idx - 1;
    while id_start <= id_end && (bytes_at(line, id_start) == b' ' || bytes_at(line, id_start) == b'\t')
    {
        id_start += 1;
    }
    while id_end >= id_start && (bytes_at(line, id_end) == b' ' || bytes_at(line, id_end) == b'\t') {
        id_end -= 1;
    }
    if id_start > id_end || id_end + 1 > line.len() {
        return;
    }
    let identifier = &line[id_start..id_end + 1];

    // find matching close paren
    let mut close_idx: Option<usize> = None;
    let mut nest_level = 0i32;
    for (idx, c) in line.bytes().enumerate().skip(open_idx) {
        if c == b'(' {
            nest_level += 1;
        } else if c == b')' {
            nest_level -= 1;
            if nest_level == 0 {
                close_idx = Some(idx);
                break;
            }
        }
    }
    let close_idx = match close_idx {
        Some(c) => c,
        None => return,
    };

    let components_str = &line[open_idx + 1..close_idx];

    let normalize = !identifier.contains("element") || identifier.starts_with("gecode");
    let components = decompose_parameters(components_str, vars, parameters, graph, normalize);

    super::decompose::dispatch(&identifier, &components, graph);
}

#[inline]
fn bytes_at(s: &str, i: usize) -> u8 {
    s.as_bytes()[i]
}



