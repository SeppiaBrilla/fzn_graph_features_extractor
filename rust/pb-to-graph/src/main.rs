//! CLI: PbToGraph <input_file> <output_file> [num_cores]

use pb_to_graph::pb_to_graph;
use flatzinc_to_graph::write_graph;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        println!("usage: PbToGraph <input_file> <output_file> [num_cores]");
        std::process::exit(1);
    }
    let file_in = &args[1];
    let file_out = &args[2];
    let num_cores: usize = args.get(3).and_then(|s| s.parse().ok()).unwrap_or(1);

    let graph = match pb_to_graph(file_in, num_cores) {
        Ok(g) => g,
        Err(e) => {
            eprintln!("ERROR: {}", e);
            std::process::exit(1);
        }
    };
    if let Err(e) = write_graph(&graph, file_out) {
        eprintln!("ERROR: {}", e);
        std::process::exit(1);
    }
}
