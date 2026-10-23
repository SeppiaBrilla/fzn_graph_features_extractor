//! ZincToWl CLI: convert FlatZinc/PB/graph files into WL feature JSON.
//! Rust port of the Julia package (server mode dropped — a native binary
//! has no JIT/environment-load penalty to amortize).

mod graph_loader;
mod helper;
mod julia_colors;
mod julia_dict;
mod julia_float;
mod wl;

use std::io::Write;

use helper::{extract_extra_info, save_colors};
use julia_colors::load_julia_colors;
use julia_dict::JuliaDict;
use wl::*;

enum Method {
    Wl,
    WlN,
    WlE,
    WlNe,
    WlNc,
    WlNec,
    WlA,
    WlAn,
    WlAe,
    WlAne,
    WlAnc,
    WlAnec,
    WlU,
    WlUn,
    WlUe,
    WlUne,
    WlUnc,
    WlUnec,
}

fn parse_method(s: &str) -> Option<Method> {
    use Method::*;
    Some(match s {
        "wl" => Wl,
        "wl-n" => WlN,
        "wl-e" => WlE,
        "wl-ne" => WlNe,
        "wl-nc" => WlNc,
        "wl-nec" => WlNec,
        "wl-a" => WlA,
        "wl-an" => WlAn,
        "wl-ae" => WlAe,
        "wl-ane" => WlAne,
        "wl-anc" => WlAnc,
        "wl-anec" => WlAnec,
        "wl-u" => WlU,
        "wl-un" => WlUn,
        "wl-ue" => WlUe,
        "wl-une" => WlUne,
        "wl-unc" => WlUnc,
        "wl-unec" => WlUnec,
        _ => return None,
    })
}

struct Opts {
    input_file: Option<String>,
    check_colors: Option<String>,
    num_cores: usize,
    wl_iterations: usize,
    method: Method,
    colors: String,
    training: bool,
}

fn print_usage_and_exit(code: i32) -> ! {
    eprintln!("usage: zinc-to-wl [input_file] [options]");
    eprintln!();
    eprintln!("options:");
    eprintln!("  -m, --method <METHOD>        WL method (wl, wl-n, wl-e, wl-ne, wl-nc, wl-nec, ...)");
    eprintln!("  -k, --wl-iterations <INT>    Number of WL iterations (default 1)");
    eprintln!("  -c, --num-cores <INT>         Number of worker threads (default 1)");
    eprintln!("      --colors <PATH>           Colors dict path (default colors.bin)");
    eprintln!("  -t, --training               Register unseen colors into the colors dict");
    eprintln!("      --check-colors <PATH>     Print the colors of the given file and exit");
    std::process::exit(code);
}

fn parse_args(args: &[String]) -> Opts {
    let mut input_file = None;
    let mut check_colors = None;
    let mut num_cores = 1usize;
    let mut wl_iterations = 1usize;
    let mut method = Method::WlNc;
    let mut colors = "colors.bin".to_string();
    let mut training = false;

    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        match a.as_str() {
            "-m" | "--method" => {
                i += 1;
                let Some(v) = args.get(i) else { print_usage_and_exit(2) };
                method = parse_method(v).unwrap_or_else(|| {
                    eprintln!("error: unknown method '{}'", v);
                    std::process::exit(2);
                });
            }
            "-k" | "--wl-iterations" => {
                i += 1;
                let Some(v) = args.get(i) else { print_usage_and_exit(2) };
                wl_iterations = v.parse().unwrap_or_else(|_| {
                    eprintln!("error: invalid wl-iterations '{}'", v);
                    std::process::exit(2);
                });
            }
            "-c" | "--num-cores" => {
                i += 1;
                let Some(v) = args.get(i) else { print_usage_and_exit(2) };
                num_cores = v.parse().unwrap_or_else(|_| {
                    eprintln!("error: invalid num-cores '{}'", v);
                    std::process::exit(2);
                });
            }
            "--colors" => {
                i += 1;
                let Some(v) = args.get(i) else { print_usage_and_exit(2) };
                colors = v.clone();
            }
            "-t" | "--training" => {
                if let Some(next) = args.get(i + 1) {
                    if next == "true" {
                        training = true;
                        i += 1;
                    } else if next == "false" {
                        training = false;
                        i += 1;
                    } else {
                        training = true;
                    }
                } else {
                    training = true;
                }
            }
            "--check-colors" => {
                i += 1;
                let Some(v) = args.get(i) else { print_usage_and_exit(2) };
                check_colors = Some(v.clone());
            }
            "-h" | "--help" => print_usage_and_exit(0),
            other => {
                if other.starts_with('-') {
                    eprintln!("error: unknown option '{}'", other);
                    print_usage_and_exit(2);
                }
                if input_file.is_some() {
                    eprintln!("error: multiple input files");
                    std::process::exit(2);
                }
                input_file = Some(other.to_string());
            }
        }
        i += 1;
    }

    Opts {
        input_file,
        check_colors,
        num_cores,
        wl_iterations,
        method,
        colors,
        training,
    }
}

fn format_colors(colors_arr: &[u64], colors: &JuliaDict<u64>, out: &mut String) {
    let mut counts = JuliaDict::new();
    for &c in colors_arr {
        *counts.get_or_insert_with(c, || 0) += 1;
    }

    if colors.len() == 0 {
        out.push_str("{}");
    } else {
        out.push_str("{\n\t");
        let mut first = true;
        for (color, _) in colors.iter() {
            if first {
                first = false;
            } else {
                out.push_str(",\n\t");
            }
            let count = counts.get(color).copied().unwrap_or(0);
            out.push_str(&format!("\"{}\":{}", color, count));
        }
    }
}

fn run(opts: Opts) -> std::io::Result<()> {
    // --check-colors mode
    if let Some(path) = &opts.check_colors {
        if opts.input_file.is_none() {
            let colors = match load_colors_rust(path) {
                Some(c) => c,
                None => load_julia_colors(path)?,
            };
            let mut first = true;
            let stdout = std::io::stdout();
            let mut out = stdout.lock();
            for (_, v) in colors.iter() {
                if first {
                    write!(out, "{}", v)?;
                    first = false;
                } else {
                    write!(out, ",{}", v)?;
                }
            }
            return Ok(());
        }
    }

    let Some(input_file) = opts.input_file.clone() else {
        eprintln!("error: input_file is required unless checking colors with --check-colors");
        std::process::exit(2);
    };

    if opts.num_cores > 1 {
        rayon::ThreadPoolBuilder::new()
            .num_threads(opts.num_cores)
            .build_global()
            .ok();
    }

    let g = if input_file.ends_with(".fzn") {
        flatzinc_to_graph::flatzinc_to_graph(&input_file, opts.num_cores)?
    } else if input_file.ends_with(".opb")
        || input_file.ends_with(".wbo")
        || input_file.ends_with(".opb.xz")
        || input_file.ends_with(".wbo.xz")
        || (input_file.ends_with(".xz") && !input_file.ends_with(".fzn.xz"))
    {
        pb_to_graph::pb_to_graph(&input_file, opts.num_cores)?
    } else if input_file.ends_with(".graph") {
        graph_loader::load_graph(&input_file)?
    } else {
        eprintln!("error: unknown file type: {}", input_file);
        std::process::exit(2);
    };

    // Load colors: support both the Rust format and legacy Julia
    // Serialization files (written by the previous Julia implementation).
    let mut colors = match load_colors_rust(&opts.colors) {
        Some(c) => c,
        None => load_julia_colors(&opts.colors)?,
    };
    let extra_info = extract_extra_info(&g, opts.num_cores);

    let warnings = matches!(
        opts.method,
        Method::WlA
            | Method::WlAn
            | Method::WlAe
            | Method::WlAne
            | Method::WlAnc
            | Method::WlAnec
            | Method::WlU
            | Method::WlUn
            | Method::WlUe
            | Method::WlUne
            | Method::WlUnc
            | Method::WlUnec
    );
    if warnings {
        eprintln!("WARNING: all_levels/undirected graphs are not recommended to use and are kept for testing purposes only");
    }

    let node_colors = match opts.method {
        Method::Wl => wl_directed_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlN => wl_node_directed_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlE => wl_edge_directed_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlNe => wl_node_edge_directed_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlNc => wl_node_cut_directed_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlNec => wl_node_edge_cut_directed_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlA => wl_directed_all_levels(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlAn => wl_node_directed_all_levels(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlAe => wl_edge_directed_all_levels(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlAne => wl_node_edge_directed_all_levels(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlAnc => wl_node_cut_directed_all_colors(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlAnec => wl_node_edge_cut_directed_all_levels(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlU => wl_undirected_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlUn => wl_node_undirected_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlUe => wl_edge_undirected_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlUne => wl_node_edge_undirected_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlUnc => wl_node_cut_undirected_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
        Method::WlUnec => wl_node_edge_cut_undirected_last(&g, &mut colors, opts.wl_iterations, opts.training, opts.num_cores),
    };

    // Assemble output — byte-identical to Julia's print sequence.
    let mut out = String::new();
    out.push('\n');
    format_colors(&node_colors, &colors, &mut out);
    use julia_float::julia_fmt_f64;
    out.push_str(&format!(",\n\t\"n_nodes\":{}", extra_info.n_nodes));
    out.push_str(&format!(",\n\t\"cpv\":{}", julia_fmt_f64(extra_info.cpv)));
    out.push_str(&format!(",\n\t\"cpp\":{}", julia_fmt_f64(extra_info.cpp)));
    out.push_str(&format!(
        ",\n\t\"d_ratio_int_vars\":{}",
        julia_fmt_f64(extra_info.d_ratio_int_vars)
    ));
    out.push_str(&format!(
        ",\n\t\"d_ratio_bool_vars\":{}",
        julia_fmt_f64(extra_info.d_ratio_bool_vars)
    ));
    out.push_str(&format!(
        ",\n\t\"o_deg_cons\":{}",
        julia_fmt_f64(extra_info.o_deg_cons)
    ));
    out.push_str(&format!(
        ",\n\t\"o_deg_std\":{}",
        julia_fmt_f64(extra_info.o_deg_std)
    ));
    out.push_str(&format!(
        ",\n\t\"o_dom_deg\":{}",
        julia_fmt_f64(extra_info.o_dom_deg)
    ));
    out.push_str(&format!(
        ",\n\t\"v_ent_deg_vars\":{}",
        julia_fmt_f64(extra_info.v_ent_deg_vars)
    ));
    out.push_str(&format!(
        ",\n\t\"v_sum_domdeg_vars\":{}",
        julia_fmt_f64(extra_info.v_sum_domdeg_vars)
    ));
    if matches!(opts.method, Method::WlNc | Method::WlNec) {
        for (k, v) in extra_info.globals_pairs.iter() {
            let label = extra_info
                .pair_labels
                .get(&k)
                .map(|p| p.to_string())
                .unwrap_or_default();
            out.push_str(&format!(",\n\t\"{}\":{}", label, v));
        }
    }
    out.push_str("\n}");

    {
        let stdout = std::io::stdout();
        let mut lock = stdout.lock();
        lock.write_all(out.as_bytes())?;
        lock.flush()?;
    }

    if opts.training {
        save_colors(&opts.colors, &colors)?;
    }
    Ok(())
}

#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let opts = parse_args(&args);
    if let Err(e) = run(opts) {
        eprintln!("ERROR: {}", e);
        std::process::exit(1);
    }
}

/// Try the Rust-native colors format; None if the file is absent or in the
/// legacy Julia format.
fn load_colors_rust(path: &str) -> Option<JuliaDict<u64>> {
    let bytes = std::fs::read(path).ok()?;
    if bytes.first() == Some(&0x37) {
        return None; // Julia serialization stream
    }
    if bytes.len() < 8 || (bytes.len() - 8) % 16 != 0 {
        return None;
    }
    let n = u64::from_le_bytes(bytes[..8].try_into().ok()?) as usize;
    let mut off = 8usize;
    let mut pairs = Vec::with_capacity(n.min(bytes.len() / 16));
    for _ in 0..n {
        if off + 16 > bytes.len() {
            break;
        }
        let k = u64::from_le_bytes(bytes[off..off + 8].try_into().ok()?);
        let v = u64::from_le_bytes(bytes[off + 8..off + 16].try_into().ok()?);
        pairs.push((k, v));
        off += 16;
    }
    let mut d = JuliaDict::new();
    d.sizehint(pairs.len());
    for (k, v) in pairs {
        d.insert(k, v);
    }
    Some(d)
}
