//! PB → graph construction, port of `parse/graph/add_to_graph.jl`.

use std::collections::HashMap;

use flatzinc_to_graph::graph::types::{Edge, EdgeLabel, Graph, Node};
use flatzinc_to_graph::julia_hash::jl_hash_str;

use super::constraints::Constraint;
use super::solve::SolveType;
use super::terms::{Term, Variable};

fn get_or_create_var(graph: &mut Graph, var_name: &str, variables: &mut HashMap<String, Node>) -> Node {
    if let Some(node) = variables.get(var_name) {
        return node.clone();
    }
    let id = jl_hash_str(var_name);
    let var_node = Node::with_var(var_name, "var_node", id, "bool", 2);
    graph.add_node(var_node.clone());
    variables.insert(var_name.to_string(), var_node.clone());
    var_node
}

fn get_literal_node(
    graph: &mut Graph,
    lit: &Variable,
    variables: &mut HashMap<String, Node>,
) -> Node {
    if lit.is_negative {
        let base_var = get_or_create_var(graph, &lit.name, variables);
        let not_label = format!("not {}", base_var.label);
        let not_hash = jl_hash_str(&not_label);
        if let Some(not_node) = graph.node_dict.get(&not_hash) {
            return not_node.clone();
        }
        let not_node = Node::new(not_label, "not_node", not_hash);
        graph.add_node(not_node.clone());
        graph.add_edge(base_var.id, not_node.id, &Edge::new(EdgeLabel::Zero));
        not_node
    } else {
        get_or_create_var(graph, &lit.name, variables)
    }
}

fn get_term_node(graph: &mut Graph, term: &Term, variables: &mut HashMap<String, Node>) -> Node {
    let coeff_str = term.coefficient.to_string();
    let coeff_id = jl_hash_str(&coeff_str);
    let coeff_node = match graph.node_dict.get(&coeff_id) {
        Some(n) => n.clone(),
        None => {
            let n = Node::with_var(&coeff_str, "int", coeff_id, "int", 0);
            graph.add_node(n.clone());
            n
        }
    };

    if term.variables.is_empty() {
        return coeff_node;
    }

    // Product of the literals (left fold)
    let lit_nodes: Vec<Node> = term
        .variables
        .iter()
        .map(|var| get_literal_node(graph, var, variables))
        .collect();
    let mut current_prod_node = lit_nodes[0].clone();

    for next_lit in &lit_nodes[1..] {
        let mul_l_label = format!("{} * {}", current_prod_node.id, next_lit.id);
        let mul_l_hash = jl_hash_str(&mul_l_label);
        if let Some(n) = graph.node_dict.get(&mul_l_hash) {
            current_prod_node = n.clone();
        } else {
            let mul_l_node = Node::new(&mul_l_label, "mult_node", mul_l_hash);
            graph.add_node(mul_l_node.clone());
            graph.add_edge(current_prod_node.id, mul_l_node.id, &Edge::new(EdgeLabel::Zero));
            graph.add_edge(next_lit.id, mul_l_node.id, &Edge::new(EdgeLabel::Zero));
            current_prod_node = mul_l_node;
        }
    }

    // Multiply by coefficient
    let mul_label = format!("{} * {}", coeff_node.id, current_prod_node.id);
    let mul_hash = jl_hash_str(&mul_label);
    if let Some(n) = graph.node_dict.get(&mul_hash) {
        return n.clone();
    }
    let mul_node = Node::new(&mul_label, "mult_node", mul_hash);
    graph.add_node(mul_node.clone());
    graph.add_edge(coeff_node.id, mul_node.id, &Edge::new(EdgeLabel::Zero));
    graph.add_edge(current_prod_node.id, mul_node.id, &Edge::new(EdgeLabel::Zero));
    mul_node
}

fn mk(label: String, node_type: &str) -> Node {
    Node::new(label.clone(), node_type, jl_hash_str(&label))
}

pub fn add_constraint_to_graph(graph: &mut Graph, constr: &Constraint, variables: &mut HashMap<String, Node>) {
    let sum_nodes: Vec<Node> = constr
        .terms
        .iter()
        .map(|t| get_term_node(graph, t, variables))
        .collect();

    let sum_label = format!(
        "sum({})",
        sum_nodes
            .iter()
            .map(|n| n.id.to_string())
            .collect::<Vec<_>>()
            .join(", ")
    );
    let sum_hash = jl_hash_str(&sum_label);
    let sum_node = match graph.node_dict.get(&sum_hash) {
        Some(n) => n.clone(),
        None => {
            let n = mk(sum_label, "lin_sum_node");
            graph.add_node(n.clone());
            for n2 in &sum_nodes {
                graph.add_edge(n2.id, n.id, &Edge::new(EdgeLabel::Zero));
            }
            n
        }
    };

    let rhs_str = constr.rhs.to_string();
    let rhs_id = jl_hash_str(&rhs_str);
    let rhs_node = match graph.node_dict.get(&rhs_id) {
        Some(n) => n.clone(),
        None => {
            let n = Node::with_var(&rhs_str, "int", rhs_id, "int", 0);
            graph.add_node(n.clone());
            n
        }
    };

    let top_node: Node = if constr.constr_type == "leq_node" {
        let leq_label = format!("{}<={}", sum_node.id, rhs_node.id);
        let leq_hash = jl_hash_str(&leq_label);
        match graph.node_dict.get(&leq_hash) {
            Some(n) => n.clone(),
            None => {
                let leq = mk(leq_label, "leq_node");
                graph.add_node(leq.clone());
                graph.add_edge(sum_node.id, leq.id, &Edge::new(EdgeLabel::Zero));
                graph.add_edge(rhs_node.id, leq.id, &Edge::new(EdgeLabel::One));
                leq
            }
        }
    } else {
        let eq_label = format!("{}={}", sum_node.id, rhs_node.id);
        let eq_hash = jl_hash_str(&eq_label);
        match graph.node_dict.get(&eq_hash) {
            Some(n) => n.clone(),
            None => {
                let eq = mk(eq_label, "equality_node");
                graph.add_node(eq.clone());
                graph.add_edge(sum_node.id, eq.id, &Edge::new(EdgeLabel::Zero));
                graph.add_edge(rhs_node.id, eq.id, &Edge::new(EdgeLabel::Zero));
                eq
            }
        }
    };

    if constr.is_weighted {
        if let Some(weight) = constr.weight {
            let weight_str = weight.to_string();
            let weight_id = jl_hash_str(&weight_str);
            let weight_node = match graph.node_dict.get(&weight_id) {
                Some(n) => n.clone(),
                None => {
                    let n = Node::with_var(&weight_str, "int", weight_id, "int", 0);
                    graph.add_node(n.clone());
                    n
                }
            };

            let soft_label = format!("soft({}, {})", top_node.id, weight_node.id);
            let soft_node = mk(soft_label, "soft_node");
            graph.add_node(soft_node.clone());
            graph.add_edge(top_node.id, soft_node.id, &Edge::new(EdgeLabel::Zero));
            graph.add_edge(weight_node.id, soft_node.id, &Edge::new(EdgeLabel::One));
        }
    }
}

pub fn add_solve_to_graph(graph: &mut Graph, solve: &Option<SolveType>, variables: &mut HashMap<String, Node>) {
    let solve = match solve {
        Some(s) if s.objective_vars.as_ref().is_some_and(|v| !v.is_empty()) => s,
        _ => return,
    };

    let term_nodes: Vec<Node> = solve
        .objective_vars
        .as_ref()
        .unwrap()
        .iter()
        .map(|t| get_term_node(graph, t, variables))
        .collect();

    let sum_label = format!(
        "sum({})",
        term_nodes
            .iter()
            .map(|n| n.id.to_string())
            .collect::<Vec<_>>()
            .join(", ")
    );
    let sum_hash = jl_hash_str(&sum_label);
    let sum_node = match graph.node_dict.get(&sum_hash) {
        Some(n) => n.clone(),
        None => {
            let n = mk(sum_label, "lin_sum_node");
            graph.add_node(n.clone());
            for n2 in &term_nodes {
                graph.add_edge(n2.id, n.id, &Edge::new(EdgeLabel::Zero));
            }
            n
        }
    };

    let obj_name = "obj";
    let obj_id = jl_hash_str(obj_name);
    let obj_node = match graph.node_dict.get(&obj_id) {
        Some(n) => n.clone(),
        None => {
            let n = Node::with_var(obj_name, "var_node", obj_id, "int", 0);
            graph.add_node(n.clone());
            n
        }
    };

    let eq_label = format!("{}={}", sum_node.id, obj_node.id);
    let eq_hash = jl_hash_str(&eq_label);
    if graph.node_dict.get(&eq_hash).is_none() {
        let eq_node = mk(eq_label, "equality_node");
        graph.add_node(eq_node.clone());
        graph.add_edge(sum_node.id, eq_node.id, &Edge::new(EdgeLabel::Zero));
        graph.add_edge(obj_node.id, eq_node.id, &Edge::new(EdgeLabel::Zero));
    }

    if solve.solve_type == "min" {
        let min_label = "Minimise(obj)".to_string();
        let min_id = jl_hash_str(&min_label);
        graph.add_node(mk(min_label, "minimise_node"));
        graph.add_edge(min_id, obj_node.id, &Edge::new(EdgeLabel::Zero));
    } else {
        let max_label = "Maximise(obj)".to_string();
        let max_id = jl_hash_str(&max_label);
        graph.add_node(mk(max_label, "maximise_node"));
        graph.add_edge(max_id, obj_node.id, &Edge::new(EdgeLabel::Zero));
    }
}
