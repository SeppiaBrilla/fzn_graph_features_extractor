use std::io::BufRead;
mod constraint;
mod decompose;
pub(crate) mod graph_helper;
mod helper;
mod parameters;
mod solve;
mod variables;

use std::collections::HashMap;

use rayon::prelude::*;

use crate::graph::types::{Edge, EdgeLabel, Graph, Node};
use crate::julia_hash::jl_hash_str;

use constraint::parse_constraint;
use parameters::{parse_parameter, Parameter};
use solve::parse_solve;
use variables::{parse_variable, Variable};

/// Main entry: parse a FlatZinc file into a Graph.
pub fn flatzinc_to_graph(file_name: &str, num_cores: usize) -> std::io::Result<Graph> {
    graph_helper::reset_counter();
    let mut variables: HashMap<String, Variable> = HashMap::new();
    let mut parameters: HashMap<String, Parameter> = HashMap::new();
    let mut graph = Graph::new();

    let mut constraint_lines: Vec<String> = Vec::new();
    let mut solve_line: Option<String> = None;
    let _ = &solve_line;

    let file = std::fs::File::open(file_name)?;
    // reusable line buffer: one allocation reused for every input line
    let mut line_buf = String::new();
    let mut reader = std::io::BufReader::with_capacity(1 << 20, file);
    loop {
        line_buf.clear();
        let bytes_read = reader.read_line(&mut line_buf)?;
        if bytes_read == 0 {
            break;
        }
        while line_buf.ends_with('\n') || line_buf.ends_with('\r') {
            line_buf.pop();
        }
        let line: &str = &line_buf;
        if line.is_empty() {
            continue;
        }
        let first_char = line.as_bytes()[0];
        if first_char == b'%' {
            continue;
        } else if line.starts_with("constraint") {
            constraint_lines.push(line.to_string());
        } else if line.starts_with("var ") {
            if let Some(var) = parse_variable(&line) {
                variables.insert(var.name.clone(), var.clone());
                let id = jl_hash_str(&var.name);
                graph.add_node(Node::with_var(
                    &var.name,
                    "var_node",
                    id,
                    var.var_type,
                    var.domain_size,
                ));
            }
        } else if line.starts_with("solve") {
            solve_line = Some(line.to_string());
        } else if line.starts_with("predicate") {
            continue;
        } else {
            if let Some(par) = parse_parameter(&line, &variables) {
                parameters.insert(par.name.clone(), par);
            }
        }
    }

    let num_constraints = constraint_lines.len();

    if num_cores <= 1 || num_constraints < 1000 {
        graph_helper::set_task_prefix(0);
        for line in &constraint_lines {
            parse_constraint(line, &parameters, &variables, &mut graph);
        }
    } else {
        let actual_cores = num_cores.min(rayon::current_num_threads()).max(1);
        if actual_cores <= 1 {
            graph_helper::set_task_prefix(0);
            for line in &constraint_lines {
                parse_constraint(line, &parameters, &variables, &mut graph);
            }
        } else {
            let chunk_size = num_constraints.div_ceil(actual_cores);
            // Parse chunks in parallel. Each chunk gets a unique task prefix so
            // generated ids (array_/global labels) don't collide, and each
            // local graph keeps its own node/edge insertion order. Chunks are
            // merged in order c=1..N afterwards, so the result is independent
            // of scheduling — identical to Julia's @spawn + ordered merge.
            let local_graphs: Vec<Graph> = (1..=actual_cores)
                .into_par_iter()
                .map(|c| {
                    let start = (c - 1) * chunk_size;
                    let end = (c * chunk_size).min(num_constraints);
                    let mut lg = Graph::new();
                    if start < end {
                        graph_helper::set_task_prefix(c as u64 * 1_000_000_000);
                        for line in &constraint_lines[start..end] {
                            parse_constraint(line, &parameters, &variables, &mut lg);
                        }
                    }
                    lg
                })
                .collect();

            // Merge: nodes first (in chunk order), then edges, matching Julia.
            for mut lg in local_graphs {
                for node in std::mem::take(&mut lg.nodes) {
                    graph.add_node(node);
                }
                for (f, t, label) in std::mem::take(&mut lg.edges) {
                    graph.add_edge(f, t, &Edge::new(label));
                }
            }
        }
    }

    // Solve line
    if let Some(sl) = solve_line {
        let solve = parse_solve(&sl, &variables);
        match solve.solve_type.as_str() {
            "maximize" => {
                if let Some(obj) = &solve.objective_var {
                    let label = format!("Maximise({})", obj.name);
                    let id = jl_hash_str(&label);
                    graph.add_node(Node::new(&label, "maximise_node", id));
                    graph.add_edge(id, jl_hash_str(&obj.name), &Edge::new(EdgeLabel::Zero));
                }
            }
            "minimize" => {
                if let Some(obj) = &solve.objective_var {
                    let label = format!("Minimise({})", obj.name);
                    let id = jl_hash_str(&label);
                    graph.add_node(Node::new(&label, "minimise_node", id));
                    graph.add_edge(id, jl_hash_str(&obj.name), &Edge::new(EdgeLabel::Zero));
                }
            }
            _ => {}
        }
    }

    Ok(graph)
}
