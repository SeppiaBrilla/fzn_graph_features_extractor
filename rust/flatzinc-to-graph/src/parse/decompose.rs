//! Constraint decompositions, ports of `graph/decompose_*.jl`.
//!
//! Labels are constructed to be byte-identical with the Julia string
//! interpolations so node identity (hash of label) matches exactly.

use crate::graph::types::{Edge, EdgeLabel, Graph, Node};
use crate::julia_hash::jl_hash_str;

use super::constraint::Arg;
use super::graph_helper::{get_node_for_string, get_next_global_id};

// ---------------------------------------------------------------------------
// shared helpers
// ---------------------------------------------------------------------------

#[inline]
fn mk_node(label: &str, node_type: &str) -> Node {
    Node::new(label, node_type, jl_hash_str(label))
}

#[inline]
fn e0() -> Edge {
    Edge::new(EdgeLabel::Zero)
}
#[inline]
fn e1() -> Edge {
    Edge::new(EdgeLabel::One)
}
#[inline]
fn e2() -> Edge {
    Edge::new(EdgeLabel::Two)
}

fn add_edges_from_nodes(graph: &mut Graph, nodes: &[Node], to: &Node) {
    for n in nodes {
        graph.add_edge(n.id, to.id, &e0());
    }
}

/// Join node ids with ", " — the Julia `join([...], ", ")`.
fn join_ids(nodes: &[Node], sep: &str) -> String {
    let mut s = String::new();
    for (i, n) in nodes.iter().enumerate() {
        if i > 0 {
            s.push_str(sep);
        }
        push_u64(&mut s, n.id);
    }
    s
}

/// Append a u64 without the `fmt` machinery (itoa-style, ~2x faster than
/// `format!("{}", x)` and allocation-free for the digits).
#[inline]
pub fn push_u64(s: &mut String, mut v: u64) {
    let mut buf = [0u8; 20];
    let mut i = buf.len();
    loop {
        i -= 1;
        buf[i] = b'0' + (v % 10) as u8;
        v /= 10;
        if v == 0 {
            break;
        }
    }
    s.push_str(std::str::from_utf8(&buf[i..]).unwrap());
}

/// `"{a} = {b}"` without fmt machinery.
#[inline]
fn label_eq(a: impl AsRef<str>, b: impl AsRef<str>) -> String {
    let (a, b) = (a.as_ref(), b.as_ref());
    let mut s = String::with_capacity(a.len() + b.len() + 3);
    s.push_str(a);
    s.push_str(" = ");
    s.push_str(b);
    s
}

/// `"{a} <-> {b}"` without fmt machinery.
#[inline]
fn label_iff(a: impl AsRef<str>, b: impl AsRef<str>) -> String {
    let (a, b) = (a.as_ref(), b.as_ref());
    let mut s = String::with_capacity(a.len() + b.len() + 5);
    s.push_str(a);
    s.push_str(" <-> ");
    s.push_str(b);
    s
}

// ---------------------------------------------------------------------------
// int decompositions
// ---------------------------------------------------------------------------

/// Shared body of int_lin_le / int_lin_eq / int_lin_ne (+ reif variants):
/// mul nodes, a lin_sum_node, then the comparison node.
fn lin_sum(graph: &mut Graph, a_nodes: &[Node], b_nodes: &[Node], comma_sep: bool) -> Node {
    let mut sum_nodes: Vec<Node> = Vec::new();
    for (a, b) in a_nodes.iter().zip(b_nodes.iter()) {
        let mul_label = format!("{} * {}", a.id, b.id);
        let mul_node = mk_node(&mul_label, "mult_node");
        sum_nodes.push(mul_node.clone());
        graph.add_node(mul_node);
    }
    // Julia adds edges a->mul and b->mul in the same loop; edge dedup makes
    // repeated (a, mul) pairs collapse, matching Julia exactly.
    for (a, b) in a_nodes.iter().zip(b_nodes.iter()) {
        for n in [a, b] {
            let mul_label = format!("{} * {}", a.id, b.id);
            let mul_id = jl_hash_str(&mul_label);
            graph.add_edge(n.id, mul_id, &e0());
        }
    }

    let sep = if comma_sep { "," } else { ", " };
    let sum_label = format!("sum({})", join_ids(&sum_nodes, sep));
    let sum_node = mk_node(&sum_label, "lin_sum_node");
    graph.add_node(sum_node.clone());
    add_edges_from_nodes(graph, &sum_nodes, &sum_node);
    sum_node
}

pub fn decompose_int_lin_le(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    let b_nodes = args[1].nodes_ref();
    let c = args[2].first_ref();

    let sum_node = lin_sum(graph, &a_nodes, &b_nodes, false);
    let leq_label = format!("{}<={}", sum_node.id, c.id);
    let leq = mk_node(&leq_label, "leq_node");
    graph.add_node(leq.clone());
    graph.add_edge(c.id, leq.id, &e1());
    graph.add_edge(sum_node.id, leq.id, &e0());
}

pub fn decompose_int_lin_le_reif(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    let b_nodes = args[1].nodes_ref();
    let c = args[2].first_ref();
    let r = args[3].first_ref();

    let sum_node = lin_sum(graph, &a_nodes, &b_nodes, false);
    let leq_label = format!("{}<={}", sum_node.id, c.id);
    let leq = mk_node(&leq_label, "leq_node");
    graph.add_node(leq.clone());
    graph.add_edge(c.id, leq.id, &e1());
    graph.add_edge(sum_node.id, leq.id, &e0());

    let iff_label = format!("{}<->{}", r.id, leq.id);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(leq.id, iff_node.id, &e0());
}

pub fn decompose_int_lin_eq(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    let b_nodes = args[1].nodes_ref();
    let c = args[2].first_ref();

    let sum_node = lin_sum(graph, &a_nodes, &b_nodes, true);
    let eq_label = format!("{}={}", sum_node.id, c.id);
    let eq = mk_node(&eq_label, "equality_node");
    graph.add_node(eq.clone());
    graph.add_edge(c.id, eq.id, &e0());
    graph.add_edge(sum_node.id, eq.id, &e0());
}

pub fn decompose_int_lin_eq_reif(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    let b_nodes = args[1].nodes_ref();
    let c = args[2].first_ref();
    let r = args[3].first_ref();

    let sum_node = lin_sum(graph, &a_nodes, &b_nodes, true);
    let eq_label = format!("{}={}", sum_node.id, c.id);
    let eq = mk_node(&eq_label, "equality_node");
    graph.add_node(eq.clone());
    graph.add_edge(c.id, eq.id, &e0());
    graph.add_edge(sum_node.id, eq.id, &e0());

    let iff_label = format!("{}<->{}", r.id, eq.id);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(eq.id, iff_node.id, &e0());
}

pub fn decompose_int_lin_ne(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    let b_nodes = args[1].nodes_ref();
    let c = args[2].first_ref();

    let sum_node = lin_sum(graph, &a_nodes, &b_nodes, true);
    let neq_label = format!("{}={}", sum_node.id, c.id);
    let neq = mk_node(&neq_label, "inequality_node");
    graph.add_node(neq.clone());
    graph.add_edge(c.id, neq.id, &e0());
    graph.add_edge(sum_node.id, neq.id, &e0());
}

pub fn decompose_int_lin_ne_reif(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    let b_nodes = args[1].nodes_ref();
    let c = args[2].first_ref();
    let r = args[3].first_ref();

    let sum_node = lin_sum(graph, &a_nodes, &b_nodes, true);
    let neq_label = format!("{}!={}", sum_node.id, c.id);
    let neq = mk_node(&neq_label, "inequality_node");
    graph.add_node(neq.clone());
    graph.add_edge(c.id, neq.id, &e0());
    graph.add_edge(sum_node.id, neq.id, &e0());

    let iff_label = format!("{}<->{}", r.id, neq.id);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(neq.id, iff_node.id, &e0());
}

/// Shared "element" decomposition: index node + equality node.
fn element_decompose(args: &[Arg], graph: &mut Graph) {
    let b = args[0].first_ref();
    let as_arg = &args[1];
    let c = args[2].first_ref();

    // Julia: `_as = args[2]` used directly — if it's a Vector (array literal or
    // normalized array param), `label` interpolates the vector, giving
    // "Node[...]"; but in practice `array_int_element` args come from a
    // parameter, where normalize=false keeps the parameter node.
    let _as = match as_arg {
        Arg::One(n) => n.clone(),
        Arg::Many(v) => {
            // Julia "$(vector)" prints as Node[Node(...), ...]. This occurs
            // for inline array literals like [1,2,3]. We reproduce the label
            // format "Node[label, ...]"? — No: Julia prints Vector{Node} via
            // show, i.e. "Node[Node(...), Node(...)]". Extremely rare; we use
            // the Julia show format.
            let labels: Vec<String> = v.iter().map(|n| show_node(n)).collect();
            let label = format!("Node[{}]", labels.join(", "));
            Node::new(&label, "array_node", jl_hash_str(&label))
        }
    };

    let index_label = format!("{}[{}]", _as.label, b.label);
    let index_node = mk_node(&index_label, "index_node");
    let equality_label = label_eq(&&index_node.label, &b.label);
    let equality_node = mk_node(&equality_label, "equality_node");

    graph.add_node(index_node.clone());
    graph.add_node(equality_node.clone());

    graph.add_edge(_as.id, index_node.id, &e0());
    graph.add_edge(b.id, index_node.id, &e1());
    graph.add_edge(b.id, index_node.id, &e0());
    graph.add_edge(index_node.id, equality_node.id, &e0());
    graph.add_edge(c.id, equality_node.id, &e0());
}

/// Julia `show(::Node)` = "Node(label, type, id, var_type, var_dom_size)".
fn show_node(n: &Node) -> String {
    format!(
        "Node({}, {}, {}, {}, {})",
        n.label, n.node_type.as_str(), n.id, n.var_type.as_str(), n.var_dom_size
    )
}

pub fn decompose_array_int_element(args: &[Arg], graph: &mut Graph) {
    element_decompose(args, graph);
}
pub fn decompose_array_var_int_element(args: &[Arg], graph: &mut Graph) {
    element_decompose(args, graph);
}

pub fn decompose_int_abs(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();

    let abs_label = format!("abs({})", a.label);
    let abs_node = mk_node(&abs_label, "abs_node");
    let equality_label = label_eq(&&abs_node.label, &b.label);
    let equality_node = mk_node(&equality_label, "equality_node");

    graph.add_node(abs_node.clone());
    graph.add_node(equality_node.clone());

    graph.add_edge(a.id, abs_node.id, &e0());
    graph.add_edge(abs_node.id, equality_node.id, &e0());
    graph.add_edge(b.id, equality_node.id, &e0());
}

pub fn decompose_int_div(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let c = args[2].first_ref();

    let division_label = format!("{}/{}", a.label, b.label);
    let division_node = mk_node(&division_label, "division_node");
    let equality_label = label_eq(&&division_node.label, &c.label);
    let equality_node = mk_node(&equality_label, "equality_node");

    graph.add_node(division_node.clone());
    graph.add_node(equality_node.clone());

    graph.add_edge(a.id, division_node.id, &e0());
    graph.add_edge(b.id, division_node.id, &e1());
    graph.add_edge(division_node.id, equality_node.id, &e0());
    graph.add_edge(c.id, equality_node.id, &e0());
}

fn eq_2args(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let equality_label = label_eq(&&a.label, &b.label);
    let equality_node = mk_node(&equality_label, "equality_node");
    graph.add_node(equality_node.clone());
    graph.add_edge(a.id, equality_node.id, &e0());
    graph.add_edge(b.id, equality_node.id, &e0());
}

pub fn decompose_int_eq(args: &[Arg], graph: &mut Graph) {
    eq_2args(args, graph);
}

pub fn decompose_int_eq_reif(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let equality_label = label_eq(&&a.label, &b.label);
    let equality_node = mk_node(&equality_label, "equality_node");
    let iif_label = label_iff(&&r.label, &equality_node.label);
    let iif_node = mk_node(&iif_label, "iff_node");

    graph.add_node(equality_node.clone());
    graph.add_node(iif_node.clone());

    graph.add_edge(a.id, equality_node.id, &e0());
    graph.add_edge(b.id, equality_node.id, &e0());
    graph.add_edge(r.id, iif_node.id, &e0());
    graph.add_edge(equality_node.id, iif_node.id, &e0());
}

fn le_2args(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let leq_label = format!("{} < {}", a.label, b.label);
    let leq_node = mk_node(&leq_label, "leq_node");
    graph.add_node(leq_node.clone());
    graph.add_edge(a.id, leq_node.id, &e0());
    graph.add_edge(b.id, leq_node.id, &e0());
}

pub fn decompose_int_le(args: &[Arg], graph: &mut Graph) {
    le_2args(args, graph);
}

fn le_reif(args: &[Arg], node_type: &str) -> (Node, Node) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let leq_label = format!("{} < {}", a.label, b.label);
    let leq_node = mk_node(&leq_label, node_type);
    let iif_label = label_iff(&&r.label, &leq_node.label);
    let iif_node = mk_node(&iif_label, "iff_node");
    (leq_node, iif_node)
}

pub fn decompose_int_le_reif(args: &[Arg], graph: &mut Graph) {
    let (leq_node, iif_node) = le_reif(args, "leq_node");
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();
    graph.add_node(leq_node.clone());
    graph.add_node(iif_node.clone());
    graph.add_edge(a.id, leq_node.id, &e0());
    graph.add_edge(b.id, leq_node.id, &e0());
    graph.add_edge(r.id, iif_node.id, &e0());
    graph.add_edge(leq_node.id, iif_node.id, &e0());
}

fn lt_2args(args: &[Arg], graph: &mut Graph, type_le: &str) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let le_label = format!("{} < {}", a.label, b.label);
    let le_node = mk_node(&le_label, type_le);
    graph.add_node(le_node.clone());
    graph.add_edge(a.id, le_node.id, &e0());
    graph.add_edge(b.id, le_node.id, &e0());
}

pub fn decompose_int_lt(args: &[Arg], graph: &mut Graph) {
    lt_2args(args, graph, "le_node");
}

pub fn decompose_int_lt_reif(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();
    let le_label = format!("{} < {}", a.label, b.label);
    let le_node = mk_node(&le_label, "le_node");
    let iif_label = label_iff(&&r.label, &le_node.label);
    let iif_node = mk_node(&iif_label, "iff_node");

    graph.add_node(le_node.clone());
    graph.add_node(iif_node.clone());
    graph.add_edge(a.id, le_node.id, &e0());
    graph.add_edge(b.id, le_node.id, &e0());
    graph.add_edge(r.id, iif_node.id, &e0());
    graph.add_edge(le_node.id, iif_node.id, &e0());
}

pub fn decompose_int_max(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let c = args[2].first_ref();

    let max_label = format!("max({}, {})", a.label, b.label);
    let max_node = mk_node(&max_label, "max_node");
    let eq_label = label_eq(&&max_node.label, &c.label);
    let eq_node = mk_node(&eq_label, "equality_node");

    graph.add_node(max_node.clone());
    graph.add_node(eq_node.clone());

    graph.add_edge(a.id, max_node.id, &e0());
    graph.add_edge(b.id, max_node.id, &e0());
    graph.add_edge(max_node.id, eq_node.id, &e0());
    graph.add_edge(c.id, eq_node.id, &e0());
}

pub fn decompose_int_min(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let c = args[2].first_ref();

    let min_label = format!("min({}, {})", a.label, b.label);
    let min_node = mk_node(&min_label, "min_node");
    let eq_label = label_eq(&&min_node.label, &c.label);
    let eq_node = mk_node(&eq_label, "equality_node");

    graph.add_node(min_node.clone());
    graph.add_node(eq_node.clone());

    graph.add_edge(a.id, min_node.id, &e0());
    graph.add_edge(b.id, min_node.id, &e0());
    graph.add_edge(min_node.id, eq_node.id, &e0());
    graph.add_edge(c.id, eq_node.id, &e0());
}

pub fn decompose_int_mod(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let c = args[2].first_ref();

    let mod_label = format!("{} % {}", a.label, b.label);
    let mod_node = mk_node(&mod_label, "modulo_node");
    let eq_label = label_eq(&&mod_node.label, &c.label);
    let eq_node = mk_node(&eq_label, "equality_node");

    graph.add_node(mod_node.clone());
    graph.add_node(eq_node.clone());

    graph.add_edge(a.id, mod_node.id, &e0());
    graph.add_edge(b.id, mod_node.id, &e0());
    graph.add_edge(mod_node.id, eq_node.id, &e0());
    graph.add_edge(c.id, eq_node.id, &e0());
}

fn ne_2args(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let neq_label = format!("{} != {}", a.label, b.label);
    let neq_node = mk_node(&neq_label, "inequality_node");
    graph.add_node(neq_node.clone());
    graph.add_edge(a.id, neq_node.id, &e0());
    graph.add_edge(b.id, neq_node.id, &e0());
}

pub fn decompose_int_ne(args: &[Arg], graph: &mut Graph) {
    ne_2args(args, graph);
}

pub fn decompose_int_ne_reif(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let neq_label = format!("{} != {}", a.label, b.label);
    let neq_node = mk_node(&neq_label, "inequality_node");
    let iif_label = label_iff(&&r.label, &neq_node.label);
    let iif_node = mk_node(&iif_label, "iff_node");

    graph.add_node(neq_node.clone());
    graph.add_node(iif_node.clone());

    graph.add_edge(a.id, neq_node.id, &e0());
    graph.add_edge(b.id, neq_node.id, &e0());
    graph.add_edge(neq_node.id, iif_node.id, &e0());
    graph.add_edge(r.id, iif_node.id, &e0());
}

pub fn decompose_int_plus(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let c = args[2].first_ref();

    let sum_label = format!("{} + {}", a.label, b.label);
    let sum_node = mk_node(&sum_label, "sum_node");
    let eq_label = label_eq(&&sum_node.label, &c.label);
    let eq_node = mk_node(&eq_label, "equality_node");

    graph.add_node(sum_node.clone());
    graph.add_node(eq_node.clone());

    graph.add_edge(a.id, sum_node.id, &e0());
    graph.add_edge(b.id, sum_node.id, &e0());
    graph.add_edge(sum_node.id, eq_node.id, &e0());
    graph.add_edge(c.id, eq_node.id, &e0());
}

pub fn decompose_int_pow(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let z = args[2].first_ref();

    let pow_label = format!("{}^{}", x.label, y.label);
    let pow_node = mk_node(&pow_label, "pow_node");
    let eq_label = label_eq(&&pow_node.label, &z.label);
    let eq_node = mk_node(&eq_label, "equality_node");

    graph.add_node(pow_node.clone());
    graph.add_node(eq_node.clone());

    graph.add_edge(x.id, pow_node.id, &e0());
    graph.add_edge(y.id, pow_node.id, &e1());
    graph.add_edge(pow_node.id, eq_node.id, &e0());
    graph.add_edge(z.id, eq_node.id, &e0());
}

pub fn decompose_int_times(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let c = args[2].first_ref();

    let mul_label = format!("{} * {}", a.label, b.label);
    let mul_node = mk_node(&mul_label, "mult_node");
    let eq_label = label_eq(&&mul_node.label, &c.label);
    let eq_node = mk_node(&eq_label, "equality_node");

    graph.add_node(mul_node.clone());
    graph.add_node(eq_node.clone());

    graph.add_edge(a.id, mul_node.id, &e0());
    graph.add_edge(b.id, mul_node.id, &e0());
    graph.add_edge(mul_node.id, eq_node.id, &e0());
    graph.add_edge(c.id, eq_node.id, &e0());
}

pub fn decompose_set_in(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let s = args[1].first_ref();

    let in_label = format!("{} in {}", x.label, s.label);
    let in_node = mk_node(&in_label, "in_node");

    graph.add_node(in_node.clone());

    graph.add_edge(x.id, in_node.id, &e0());
    graph.add_edge(s.id, in_node.id, &e1());
}

// ---------------------------------------------------------------------------
// bool decompositions
// ---------------------------------------------------------------------------

pub fn decompose_array_bool_and(args: &[Arg], graph: &mut Graph) {
    let as_nodes = args[0].nodes_ref();
    let r = args[1].first_ref();

    let and_label = as_nodes
        .iter()
        .map(|n| n.label.clone())
        .collect::<Vec<_>>()
        .join("/\\ ");
    let and_node = mk_node(&and_label, "multi_and_node");
    graph.add_node(and_node.clone());

    for n in as_nodes {
        graph.add_edge(n.id, and_node.id, &e0());
    }

    let iff_label = label_iff(&&r.label, &and_node.label);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());

    graph.add_edge(and_node.id, iff_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
}

fn bool_element_decompose(args: &[Arg], graph: &mut Graph) {
    let b = args[0].first_ref();
    let _as = args[1].first_ref();
    let c = args[2].first_ref();

    let index_label = format!("{}[{}]", _as.label, b.label);
    let index_node = mk_node(&index_label, "index_node");
    let equality_label = label_eq(&&index_node.label, &b.label);
    let equality_node = mk_node(&equality_label, "equality_node");

    graph.add_node(index_node.clone());
    graph.add_node(equality_node.clone());

    graph.add_edge(_as.id, index_node.id, &e0());
    graph.add_edge(b.id, index_node.id, &e1());
    graph.add_edge(index_node.id, equality_node.id, &e0());
    graph.add_edge(c.id, equality_node.id, &e0());
}

pub fn decompose_array_bool_element(args: &[Arg], graph: &mut Graph) {
    bool_element_decompose(args, graph);
}

pub fn decompose_array_var_bool_element(args: &[Arg], graph: &mut Graph) {
    bool_element_decompose(args, graph);
}

pub fn decompose_array_bool_xor(args: &[Arg], graph: &mut Graph) {
    let as_nodes = args[0].nodes_ref();

    let xor_label = as_nodes
        .iter()
        .map(|n| n.label.clone())
        .collect::<Vec<_>>()
        .join("xor ");
    let xor_node = mk_node(&xor_label, "multi_xor_node");
    graph.add_node(xor_node.clone());

    for n in as_nodes {
        graph.add_edge(n.id, xor_node.id, &e0());
    }
}

pub fn decompose_bool2int(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();

    let one = get_node_for_string(graph, "1", "int");

    let equality_label = format!("{} = 1", b.label);
    let equality_node = mk_node(&equality_label, "equality_node");
    let iff_label = label_iff(&&a.label, &equality_node.label);
    let iff_node = mk_node(&iff_label, "iff_node");

    graph.add_node(equality_node.clone());
    graph.add_node(iff_node.clone());

    graph.add_edge(one.id, equality_node.id, &e0());
    graph.add_edge(b.id, equality_node.id, &e0());
    graph.add_edge(a.id, iff_node.id, &e0());
    graph.add_edge(equality_node.id, iff_node.id, &e0());
}

pub fn decompose_bool_and(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let and_label = format!("{} /\\ {}", a.label, b.label);
    let and_node = mk_node(&and_label, "and_node");
    let iff_label = format!("{} /\\ {}", r.label, and_node.label);
    let iff_node = mk_node(&iff_label, "iff_node");

    graph.add_node(and_node.clone());
    graph.add_node(iff_node.clone());

    graph.add_edge(a.id, and_node.id, &e0());
    graph.add_edge(b.id, and_node.id, &e0());
    graph.add_edge(and_node.id, iff_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
}

pub fn decompose_bool_clause(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    // Julia: normalize_list(_bs) — if args[1] is a Parameter it expands;
    // for Vector{Node} args (array literal) it passes through.
    let bs_list = match &args[1] {
        Arg::One(n) => vec![n.clone()],
        Arg::Many(v) => v.clone(),
    };

    let mut not_b_nodes: Vec<Node> = Vec::new();
    for b in &bs_list {
        let not_label = format!("not {}", b.label);
        let not_b = mk_node(&not_label, "not_node");
        graph.add_node(not_b.clone());
        graph.add_edge(b.id, not_b.id, &e0());
        not_b_nodes.push(not_b);
    }

    let mut a_or: Option<Node> = None;
    if !a_nodes.is_empty() {
        let a_or_label = a_nodes
            .iter()
            .map(|n| n.label.clone())
            .collect::<Vec<_>>()
            .join(" \\\\/ ");
        let node = mk_node(&a_or_label, "multi_or_node");
        graph.add_node(node.clone());
        for n in a_nodes {
            graph.add_edge(n.id, node.id, &e0());
        }
        a_or = Some(node);
    }

    let mut b_or: Option<Node> = None;
    if !not_b_nodes.is_empty() {
        let b_or_label = not_b_nodes
            .iter()
            .map(|n| n.label.clone())
            .collect::<Vec<_>>()
            .join(" \\\\/ ");
        let node = mk_node(&b_or_label, "multi_or_node");
        graph.add_node(node.clone());
        for n in &not_b_nodes {
            graph.add_edge(n.id, node.id, &e0());
        }
        b_or = Some(node);
    }

    if let (Some(a_or), Some(b_or)) = (a_or, b_or) {
        let label = format!("{} \\\\/ {}", a_or.label, b_or.label);
        let or_node = mk_node(&label, "or_node");
        graph.add_node(or_node.clone());
        graph.add_edge(a_or.id, or_node.id, &e0());
        graph.add_edge(b_or.id, or_node.id, &e0());
    }
}

pub fn decompose_bool_eq(args: &[Arg], graph: &mut Graph) {
    eq_2args(args, graph);
}

pub fn decompose_bool_eq_reif(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let equality_label = label_eq(&&a.label, &b.label);
    let equality_node = mk_node(&equality_label, "equality_node");
    let iff_label = format!("{} <-> ({})", r.label, equality_node.label);
    let iff_node = mk_node(&iff_label, "iff_node");

    graph.add_node(equality_node.clone());
    graph.add_node(iff_node.clone());

    graph.add_edge(a.id, equality_node.id, &e0());
    graph.add_edge(b.id, equality_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(equality_node.id, iff_node.id, &e0());
}

pub fn decompose_bool_le(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let leq_label = format!("{} <= {}", a.label, b.label);
    let leq_node = mk_node(&leq_label, "leq_node");
    graph.add_node(leq_node.clone());
    graph.add_edge(a.id, leq_node.id, &e0());
    graph.add_edge(b.id, leq_node.id, &e0());
}

pub fn decompose_bool_le_reif(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let leq_label = format!("{} <= {}", a.label, b.label);
    let leq_node = mk_node(&leq_label, "leq_node");
    let iff_label = format!("{} <-> ({})", r.label, leq_node.label);
    let iff_node = mk_node(&iff_label, "iff_node");

    graph.add_node(leq_node.clone());
    graph.add_node(iff_node.clone());

    graph.add_edge(a.id, leq_node.id, &e0());
    graph.add_edge(b.id, leq_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(leq_node.id, iff_node.id, &e0());
}

pub fn decompose_bool_lin_eq(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    let b_nodes = args[1].nodes_ref();
    let c = args[2].first_ref();

    let sum_node = lin_sum(graph, &a_nodes, &b_nodes, true);
    let eq_label = format!("{}={}", sum_node.id, c.id);
    let eq = mk_node(&eq_label, "equality_node");
    graph.add_node(eq.clone());
    graph.add_edge(c.id, eq.id, &e0());
    graph.add_edge(sum_node.id, eq.id, &e0());
}

pub fn decompose_bool_lin_le(args: &[Arg], graph: &mut Graph) {
    let a_nodes = args[0].nodes_ref();
    let b_nodes = args[1].nodes_ref();
    let c = args[2].first_ref();

    let sum_node = lin_sum(graph, &a_nodes, &b_nodes, true);
    let leq_label = format!("{}<={}", sum_node.id, c.id);
    let leq = mk_node(&leq_label, "leq_node");
    graph.add_node(leq.clone());
    graph.add_edge(c.id, leq.id, &e0());
    graph.add_edge(sum_node.id, leq.id, &e0());
}

pub fn decompose_bool_lt(args: &[Arg], graph: &mut Graph) {
    lt_2args(args, graph, "le_node");
}

pub fn decompose_bool_lt_reif(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let le_label = format!("{} < {}", a.label, b.label);
    let le_node = mk_node(&le_label, "le_node");
    let iff_label = format!("{} <-> ({})", r.label, le_node.label);
    let iff_node = mk_node(&iff_label, "iff_node");

    graph.add_node(le_node.clone());
    graph.add_node(iff_node.clone());

    graph.add_edge(a.id, le_node.id, &e0());
    graph.add_edge(b.id, le_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(le_node.id, iff_node.id, &e0());
}

pub fn decompose_bool_not(args: &[Arg], graph: &mut Graph) {
    ne_2args(args, graph);
}

pub fn decompose_bool_or(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let or_label = format!("{} \\/ {}", a.label, b.label);
    let or_node = mk_node(&or_label, "or_node");
    let iff_label = format!("{} <-> ({})", r.label, or_node.label);
    let iff_node = mk_node(&iff_label, "iff_node");

    graph.add_node(or_node.clone());
    graph.add_node(iff_node.clone());

    graph.add_edge(a.id, or_node.id, &e0());
    graph.add_edge(b.id, or_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(or_node.id, iff_node.id, &e0());
}

pub fn decompose_bool_xor(args: &[Arg], graph: &mut Graph) {
    let a = args[0].first_ref();
    let b = args[1].first_ref();
    let r = args[2].first_ref();

    let xor_label = format!("{} xor {}", a.label, b.label);
    let xor_node = mk_node(&xor_label, "xor_node");
    let iff_label = format!("{} <-> ({})", r.label, xor_node.label);
    let iff_node = mk_node(&iff_label, "iff_node");

    graph.add_node(xor_node.clone());
    graph.add_node(iff_node.clone());

    graph.add_edge(a.id, xor_node.id, &e0());
    graph.add_edge(b.id, xor_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(xor_node.id, iff_node.id, &e0());
}

// ---------------------------------------------------------------------------
// set decompositions
// ---------------------------------------------------------------------------

pub fn decompose_array_set_element(args: &[Arg], graph: &mut Graph) {
    let b = args[0].first_ref();
    let _as = args[1].first_ref();
    let c = args[2].first_ref();

    let index_label = format!("{}[{}]", _as.label, b.label);
    let index_node = mk_node(&index_label, "index_node");
    graph.add_node(index_node.clone());

    let eq_label = label_eq(&&index_node.label, &c.label);
    let equality_node = mk_node(&eq_label, "equality_node");
    graph.add_node(equality_node.clone());

    graph.add_edge(_as.id, index_node.id, &e0());
    graph.add_edge(b.id, index_node.id, &e1());
    graph.add_edge(b.id, index_node.id, &e0());
    graph.add_edge(index_node.id, equality_node.id, &e0());
    graph.add_edge(c.id, equality_node.id, &e0());
}

pub fn decompose_array_var_set_element(args: &[Arg], graph: &mut Graph) {
    decompose_array_set_element(args, graph);
}

pub fn decompose_set_card(args: &[Arg], graph: &mut Graph) {
    let s = args[0].first_ref();
    let x = args[1].first_ref();

    let card_label = format!("|{}|", s.label);
    let card_node = mk_node(&card_label, "card_node");
    graph.add_node(card_node.clone());

    let eq_label = label_eq(&&x.label, &card_node.label);
    let equality_node = mk_node(&eq_label, "equality_node");
    graph.add_node(equality_node.clone());

    graph.add_edge(s.id, card_node.id, &e0());
    graph.add_edge(card_node.id, equality_node.id, &e0());
    graph.add_edge(x.id, equality_node.id, &e0());
}

pub fn decompose_set_diff(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let diff_label = format!("{} \\ {}", x.label, y.label);
    let diff_node = mk_node(&diff_label, "diff_node");
    graph.add_node(diff_node.clone());

    let eq_label = label_eq(&r.label, diff_label);
    let equality_node = mk_node(&eq_label, "equality_node");
    graph.add_node(equality_node.clone());

    graph.add_edge(x.id, diff_node.id, &e0());
    graph.add_edge(y.id, diff_node.id, &e1());
    graph.add_edge(diff_node.id, equality_node.id, &e0());
    graph.add_edge(r.id, equality_node.id, &e0());
}

pub fn decompose_set_eq(args: &[Arg], graph: &mut Graph) {
    eq_2args(args, graph);
}

pub fn decompose_set_eq_reif(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let eq_label = label_eq(&&x.label, &y.label);
    let equality_node = mk_node(&eq_label, "equality_node");
    graph.add_node(equality_node.clone());

    let iff_label = format!("{} <-> ({})", r.label, eq_label);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());

    graph.add_edge(x.id, equality_node.id, &e0());
    graph.add_edge(y.id, equality_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(equality_node.id, iff_node.id, &e0());
}

pub fn decompose_set_in_reif(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let s = args[1].first_ref();
    let r = args[2].first_ref();

    let in_label = format!("{} in {}", x.label, s.label);
    let in_node = mk_node(&in_label, "in_node");
    graph.add_node(in_node.clone());

    let iff_label = format!("{} <-> ({})", r.label, in_label);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());

    graph.add_edge(x.id, in_node.id, &e0());
    graph.add_edge(s.id, in_node.id, &e1());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(in_node.id, iff_node.id, &e0());
}

pub fn decompose_set_intersect(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let intersect_label = format!("{} /\\ {}", x.label, y.label);
    let intersect_node = mk_node(&intersect_label, "intersect_node");
    graph.add_node(intersect_node.clone());

    let eq_label = label_eq(&r.label, intersect_label);
    let equality_node = mk_node(&eq_label, "equality_node");
    graph.add_node(equality_node.clone());

    graph.add_edge(x.id, intersect_node.id, &e0());
    graph.add_edge(y.id, intersect_node.id, &e1());
    graph.add_edge(intersect_node.id, equality_node.id, &e0());
    graph.add_edge(r.id, equality_node.id, &e0());
}

pub fn decompose_set_le(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let leq_label = format!("{} <= {}", x.label, y.label);
    let leq_node = mk_node(&leq_label, "leq_node");
    graph.add_node(leq_node.clone());
    graph.add_edge(x.id, leq_node.id, &e0());
    graph.add_edge(y.id, leq_node.id, &e1());
}

pub fn decompose_set_le_reif(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let leq_label = format!("{} <= {}", x.label, y.label);
    let leq_node = mk_node(&leq_label, "leq_node");
    graph.add_node(leq_node.clone());

    let iff_label = format!("{} <-> ({})", r.label, leq_label);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());

    graph.add_edge(x.id, leq_node.id, &e0());
    graph.add_edge(y.id, leq_node.id, &e1());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(leq_node.id, iff_node.id, &e0());
}

pub fn decompose_set_lt(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let le_label = format!("{} < {}", x.label, y.label);
    let le_node = mk_node(&le_label, "le_node");
    graph.add_node(le_node.clone());
    graph.add_edge(x.id, le_node.id, &e0());
    graph.add_edge(y.id, le_node.id, &e1());
}

pub fn decompose_set_lt_reif(args: &[Arg], graph: &mut Graph) {
    // Julia quirk: uses "<=" for the label but "le_node" as the type
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let leq_label = format!("{} <= {}", x.label, y.label);
    let leq_node = mk_node(&leq_label, "le_node");
    graph.add_node(leq_node.clone());

    let iff_label = format!("{} <-> ({})", r.label, leq_label);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());

    graph.add_edge(x.id, leq_node.id, &e0());
    graph.add_edge(y.id, leq_node.id, &e1());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(leq_node.id, iff_node.id, &e0());
}

pub fn decompose_set_ne(args: &[Arg], graph: &mut Graph) {
    ne_2args(args, graph);
}

pub fn decompose_set_ne_reif(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let ineq_label = format!("{} != {}", x.label, y.label);
    let inequality_node = mk_node(&ineq_label, "inequality_node");
    graph.add_node(inequality_node.clone());

    let iff_label = format!("{} <-> ({})", r.label, ineq_label);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());

    graph.add_edge(x.id, inequality_node.id, &e0());
    graph.add_edge(y.id, inequality_node.id, &e0());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(inequality_node.id, iff_node.id, &e0());
}

pub fn decompose_set_subset(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();

    let subset_label = format!("{} \\subset {}", x.label, y.label);
    let subset_node = mk_node(&subset_label, "subset_node");
    graph.add_node(subset_node.clone());

    graph.add_edge(x.id, subset_node.id, &e0());
    graph.add_edge(y.id, subset_node.id, &e0());
}

pub fn decompose_set_subset_reif(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let subset_label = format!("{} \\subset {}", x.label, y.label);
    let subset_node = mk_node(&subset_label, "subset_node");
    graph.add_node(subset_node.clone());

    let iff_label = format!("{} <-> ({})", r.label, subset_label);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());

    graph.add_edge(x.id, subset_node.id, &e0());
    graph.add_edge(y.id, subset_node.id, &e1());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(subset_node.id, iff_node.id, &e0());
}

pub fn decompose_set_superset(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();

    let subset_label = format!("{} \\subset {}", y.label, x.label);
    let subset_node = mk_node(&subset_label, "subset_node");
    graph.add_node(subset_node.clone());

    graph.add_edge(x.id, subset_node.id, &e0());
    graph.add_edge(y.id, subset_node.id, &e0());
}

pub fn decompose_set_superset_reif(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let subset_label = format!("{} \\subset {}", y.label, x.label);
    subset_reif_common(x, y, r, subset_label, graph);
}

fn subset_reif_common(x: &Node, y: &Node, r: &Node, subset_label: String, graph: &mut Graph) {
    let subset_node = mk_node(&subset_label, "subset_node");
    graph.add_node(subset_node.clone());

    let iff_label = format!("{} <-> ({})", r.label, subset_label);
    let iff_node = mk_node(&iff_label, "iff_node");
    graph.add_node(iff_node.clone());

    graph.add_edge(x.id, subset_node.id, &e0());
    graph.add_edge(y.id, subset_node.id, &e1());
    graph.add_edge(r.id, iff_node.id, &e0());
    graph.add_edge(subset_node.id, iff_node.id, &e0());
}

pub fn decompose_set_symdiff(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let symdiff_label = format!("{} symdiff {}", x.label, y.label);
    let symdiff_node = mk_node(&symdiff_label, "symdiff_node");
    graph.add_node(symdiff_node.clone());

    let eq_label = label_eq(&r.label, symdiff_label);
    let equality_node = mk_node(&eq_label, "equality_node");
    graph.add_node(equality_node.clone());

    graph.add_edge(x.id, symdiff_node.id, &e0());
    graph.add_edge(y.id, symdiff_node.id, &e1());
    graph.add_edge(symdiff_node.id, equality_node.id, &e0());
    graph.add_edge(r.id, equality_node.id, &e0());
}

pub fn decompose_set_union(args: &[Arg], graph: &mut Graph) {
    let x = args[0].first_ref();
    let y = args[1].first_ref();
    let r = args[2].first_ref();

    let union_label = format!("{} union {}", x.label, y.label);
    let union_node = mk_node(&union_label, "union_node");
    graph.add_node(union_node.clone());

    let eq_label = label_eq(&r.label, union_label);
    let equality_node = mk_node(&eq_label, "equality_node");
    graph.add_node(equality_node.clone());

    graph.add_edge(x.id, union_node.id, &e0());
    graph.add_edge(y.id, union_node.id, &e0());
    graph.add_edge(union_node.id, equality_node.id, &e0());
    graph.add_edge(r.id, equality_node.id, &e0());
}

// ---------------------------------------------------------------------------
// global decompositions (generic)
// ---------------------------------------------------------------------------

/// `decompose_generic_global`: one global node with EDGE_2 to every arg node.
pub fn decompose_generic_global(
    args: &[Arg],
    graph: &mut Graph,
    label_prefix: &str,
    node_type: &str,
) {
    let global_label = format!("{}{}", label_prefix, get_next_global_id());
    let global_node = mk_node(&global_label, node_type);
    graph.add_node(global_node.clone());

    for arg in args {
        for node in arg.as_nodes() {
            graph.add_node(node.clone());
            graph.add_edge(node.id, global_node.id, &e2());
        }
    }
}

/// The global-constraint table: identifier -> (label prefix, node type).
/// Values mirror `decompose_global.jl` and the CONSTRAINT_HANDLERS dict.
pub fn global_dispatch_entry(identifier: &str) -> Option<(&'static str, &'static str)> {
    Some(match identifier {
        "gecode_cumulatives" => ("cumulatives", "cumulatives_node"),
        "gecode_int_element" => ("int_element", "int_element_node"),
        "int_lin_eq_imp" => ("int_lin_eq_imp", "int_lin_eq_imp_node"),
        "array_int_maximum" => ("array_int_maximum", "array_int_maximum_node"),
        "gecode_schedule_unary" => ("schedule_unary", "schedule_unary_node"),
        "int_le_imp" => ("int_le_imp", "int_le_imp_node"),
        "gecode_global_cardinality" => ("global_cardinality", "global_cardinality_node"),
        "fzn_global_cardinality_low_up" => {
            ("global_cardinality_low_up", "global_cardinality_low_up_node")
        }
        "gecode_maximum_arg_int_offset" => {
            ("maximum_arg_int_offset", "maximum_arg_int_offset_node")
        }
        "gecode_circuit" => ("circuit", "circuit_node"),
        "fzn_count_eq_reif" => ("count_eq_reif", "count_eq_reif_node"),
        "set_in_imp" => ("set_in_imp", "set_in_imp_node"),
        "fzn_count_eq" => ("count_eq", "count_eq_node"),
        "fzn_global_cardinality_low_up_closed" => (
            "global_cardinality_low_up_closed",
            "global_cardinality_low_up_closed_node",
        ),
        "bool_xor_imp" => ("bool_xor_imp", "bool_xor_imp_node"),
        "gecode_nooverlap" => ("nooverlap", "nooverlap_node"),
        "gecode_regular" => ("regular", "regular_node"),
        "fzn_all_different_int" => ("all_different_int", "all_different_node"),
        "int_eq_imp" => ("int_eq_imp", "eq_imp_node"),
        "fzn_all_equal_int" => ("all_equal", "all_equal_node"),
        "gecode_bool_element" => ("bool_element", "bool_element_node"),
        "array_int_minimum" => ("array_int_minimum", "array_int_minimum_node"),
        "bool_clause_reif" => ("bool_clause_reif", "bool_clause_reif_node"),
        "gecode_int_element2d" => ("int_element2d", "int_element2d_node"),
        "gecode_bin_packing_load" => ("bin_packing_load", "bin_packing_load_node"),
        "gecode_table_int" => ("table_int", "table_int_node"),
        "gecode_precede" => ("precede", "precede_node"),
        "array_int_lq" => ("array_int_lq", "array_int_lq_node"),
        "int_lin_le_imp" => ("int_lin_le_imp", "int_lin_le_imp_node"),
        "int_lin_ne_imp" => ("int_lin_ne_imp", "int_lin_ne_imp_node"),
        "fzn_increasing_int" => ("increasing_int", "increasing_int_node"),
        "inverse_offsets" => ("inverse_offsets", "inverse_offsets_node"),
        "fzn_nvalue" => ("nvalue", "nvalue_node"),
        "int_ne_imp" => ("int_ne_imp", "int_ne_imp_node"),
        "gecode_table_int_imp" => ("table_int_imp", "table_int_imp_node"),
        "fzn_member_int" => ("fzn_member_int", "member_int_node"),
        "gecode_global_cardinality_closed" => {
            ("global_cardinality_closed", "global_cardinality_closed_node")
        }
        "gecode_int_pow" => ("gecode_int_pow", "int_pow_node"),
        "fzn_at_most_int" => ("fzn_at_most_int", "at_most_node"),
        "fzn_at_least_int" => ("fzn_at_least_int", "at_least_node"),
        "fzn_increasing_bool" => ("fzn_increasing_bool", "increasing_bool_node"),
        _ => return None,
    })
}

/// `decompose_unknown_global`: node type = constraint name + `_global`
/// suffix, so solver-specific globals (non-gecode FlatZinc) are recognized
/// as cut nodes by the WL feature extractor (see `is_unknown_global`).
pub fn decompose_unknown_global(args: &[Arg], graph: &mut Graph, global_name: &str) {
    let node_type = format!("{}_global", global_name);
    decompose_generic_global(args, graph, global_name, &node_type);
}

pub fn dispatch(identifier: &str, args: &[Arg], graph: &mut Graph) {
    match identifier {
        // --- int ---
        "int_lin_eq" => decompose_int_lin_eq(args, graph),
        "int_lin_eq_reif" => decompose_int_lin_eq_reif(args, graph),
        "int_lin_le" => decompose_int_lin_le(args, graph),
        "int_lin_le_reif" => decompose_int_lin_le_reif(args, graph),
        "array_int_element" => decompose_array_int_element(args, graph),
        "array_var_int_element" => decompose_array_var_int_element(args, graph),
        "int_div" => decompose_int_div(args, graph),
        "int_abs" => decompose_int_abs(args, graph),
        "int_eq" => decompose_int_eq(args, graph),
        "int_eq_reif" => decompose_int_eq_reif(args, graph),
        "int_le" => decompose_int_le(args, graph),
        "int_le_reif" => decompose_int_le_reif(args, graph),
        "int_lin_ne" => decompose_int_lin_ne(args, graph),
        "int_lin_ne_reif" => decompose_int_lin_ne_reif(args, graph),
        "int_lt" => decompose_int_lt(args, graph),
        "int_lt_reif" => decompose_int_lt_reif(args, graph),
        "int_max" => decompose_int_max(args, graph),
        "int_min" => decompose_int_min(args, graph),
        "int_times" => decompose_int_times(args, graph),
        "set_in" => decompose_set_in(args, graph),
        "int_mod" => decompose_int_mod(args, graph),
        "int_ne" => decompose_int_ne(args, graph),
        "int_ne_reif" => decompose_int_ne_reif(args, graph),
        "int_plus" => decompose_int_plus(args, graph),
        "int_pow" => decompose_int_pow(args, graph),
        // --- bool ---
        "bool_clause" => decompose_bool_clause(args, graph),
        "array_bool_element" => decompose_array_bool_element(args, graph),
        "array_bool_and" => decompose_array_bool_and(args, graph),
        "array_bool_xor" => decompose_array_bool_xor(args, graph),
        "bool2int" => decompose_bool2int(args, graph),
        "array_var_bool_element" => decompose_array_var_bool_element(args, graph),
        "bool_and" => decompose_bool_and(args, graph),
        "bool_eq" => decompose_bool_eq(args, graph),
        "bool_eq_reif" => decompose_bool_eq_reif(args, graph),
        "bool_le" => decompose_bool_le(args, graph),
        "bool_le_reif" => decompose_bool_le_reif(args, graph),
        "bool_lin_le" => decompose_bool_lin_le(args, graph),
        "bool_lin_eq" => decompose_bool_lin_eq(args, graph),
        "bool_lt" => decompose_bool_lt(args, graph),
        "bool_lt_reif" => decompose_bool_lt_reif(args, graph),
        "bool_not" => decompose_bool_not(args, graph),
        "bool_xor" => decompose_bool_xor(args, graph),
        "bool_or" => decompose_bool_or(args, graph),
        // --- set ---
        "set_le" => decompose_set_le(args, graph),
        "set_le_reif" => decompose_set_le_reif(args, graph),
        "set_lt" => decompose_set_lt(args, graph),
        "set_lt_reif" => decompose_set_lt_reif(args, graph),
        "array_set_element" => decompose_array_set_element(args, graph),
        "array_var_set_element" => decompose_array_var_set_element(args, graph),
        "set_card" => decompose_set_card(args, graph),
        "set_diff" => decompose_set_diff(args, graph),
        "set_eq" => decompose_set_eq(args, graph),
        "set_eq_reif" => decompose_set_eq_reif(args, graph),
        "set_in_reif" => decompose_set_in_reif(args, graph),
        "set_intersect" => decompose_set_intersect(args, graph),
        "set_superset" => decompose_set_superset(args, graph),
        "set_superset_reif" => decompose_set_superset_reif(args, graph),
        "set_ne" => decompose_set_ne(args, graph),
        "set_ne_reif" => decompose_set_ne_reif(args, graph),
        "set_subset" => decompose_set_subset(args, graph),
        "set_subset_reif" => decompose_set_subset_reif(args, graph),
        "set_symdiff" => decompose_set_symdiff(args, graph),
        "set_union" => decompose_set_union(args, graph),
        // --- globals: table-driven ---
        other => {
            if let Some((prefix, node_type)) = global_dispatch_entry(other) {
                decompose_generic_global(args, graph, prefix, node_type);
            } else {
                decompose_unknown_global(args, graph, other);
            }
        }
    }
}
