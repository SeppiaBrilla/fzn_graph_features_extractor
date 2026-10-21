pub mod terms;
pub mod constraints;
pub mod solve;
pub mod add_to_graph;

mod pb {
    use super::add_to_graph::{add_constraint_to_graph, add_solve_to_graph};
    use super::constraints::parse_constraint;
    use super::solve::{is_solve, parse_solve};
    use flatzinc_to_graph::graph::types::Graph;
    use std::collections::HashMap;
    use std::io::{BufRead, BufReader};

    /// Open a PB file, transparently decompressing `.xz` (via flate2's xz
    /// decoder — replaces Julia's `xz -dc` subprocess).
    fn open_pb_file(filepath: &str) -> std::io::Result<Box<dyn BufRead>> {
        if filepath.ends_with(".xz") {
            let f = std::fs::File::open(filepath)?;
            let decoder = xz2::read::XzDecoder::new(f);
            Ok(Box::new(BufReader::new(decoder)))
        } else {
            let f = std::fs::File::open(filepath)?;
            Ok(Box::new(BufReader::new(f)))
        }
    }

    /// Main parsing entrypoint for Pseudo-Boolean (.opb, .wbo, .xz) files.
    pub fn pb_to_graph(filepath: &str, _num_cores: usize) -> std::io::Result<Graph> {
        let mut graph = Graph::new();
        let mut solve_item = None;
        let mut constraints = Vec::new();
        let mut variables: HashMap<String, flatzinc_to_graph::graph::types::Node> = HashMap::new();

        let reader = open_pb_file(filepath)?;
        for raw_line in reader.lines() {
            let line = raw_line?.trim().to_string();
            if line.is_empty() || line.starts_with('*') {
                continue;
            }
            if line.starts_with("soft:") {
                continue;
            }
            if is_solve(&line) {
                solve_item = parse_solve(&line);
            } else {
                constraints.push(parse_constraint(&line)?);
            }
        }

        for constr in &constraints {
            add_constraint_to_graph(&mut graph, constr, &mut variables);
        }

        if solve_item.is_some() {
            add_solve_to_graph(&mut graph, &solve_item, &mut variables);
        }

        Ok(graph)
    }
}

pub use pb::pb_to_graph;
