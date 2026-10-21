//! Weisfeiler-Lehman color refinement — all method variants from the Julia
//! `wl_features/*.jl` modules.
//!
//! Every method has directed / undirected / all-levels variants as in Julia
//! (undirected and all-levels are testing-only there too).
//!
//! Training mode registers new colors into the shared colors dict; inference
//! maps unseen hashes to a variant-specific fallback (the Julia variants
//! differ: `curr_colors[i]` for plain/node/cut, `h_key` for edge variants).
//!
//! Determinism: candidate hashes are computed for all nodes first (pure,
//! parallelizable with rayon), then colors are registered/applied in node
//! order. Julia's parallel training mode inserts into the colors dict under
//! a lock in nondeterministic order; ours is always deterministic, and the
//! node colors and counts are identical either way.

use flatzinc_to_graph::graph::types::Graph;

use crate::helper::{
    hash_cut_color_string, hash_node_type, is_cut_node_id, tailored_hash, typer_id,
};
use flatzinc_to_graph::interner::TypeId;
use crate::julia_dict::JuliaDict;

pub type Colors = JuliaDict<u64>;

/// Which fallback to use in inference mode when a color hash is unseen.
#[derive(Clone, Copy, PartialEq)]
enum Fallback {
    CurrentColor,
    HashItself,
}

/// One plain WL step's candidate hash for node i.
#[inline]
fn step_plain(adj_list: &[(usize, u64)], curr_colors: &[u64], i: usize, buffer: &mut Vec<u64>) -> u64 {
    buffer.clear();
    for (from_i, _) in adj_list {
        buffer.push(curr_colors[*from_i]);
    }
    buffer.sort_unstable();
    tailored_hash(curr_colors[i], buffer)
}

/// One edge-hashed WL step's candidate hash for node i.
#[inline]
fn step_edge(adj_list: &[(usize, u64)], curr_colors: &[u64], i: usize, buffer: &mut Vec<u64>) -> u64 {
    buffer.clear();
    for (from_i, h_edge) in adj_list {
        buffer.push(flatzinc_to_graph::julia_hash::hash_uint64(curr_colors[*from_i], *h_edge));
    }
    buffer.sort_unstable();
    tailored_hash(curr_colors[i], buffer)
}

/// Symmetrize the in-adjacency (undirected variants). Mirrors the Julia
/// construction order.
fn symmetrize(g: &Graph) -> Vec<Vec<(usize, u64)>> {
    let n = g.nodes.len();
    let mut adj: Vec<Vec<(usize, u64)>> = vec![Vec::new(); n];
    for to_i in 0..n {
        for &(from_i, edge_hash) in &g.in_adj[to_i] {
            adj[to_i].push((from_i, edge_hash));
            adj[from_i].push((to_i, edge_hash));
        }
    }
    adj
}

/// Non-cut in-adjacency (directed cut variants): both endpoints non-cut.
fn non_cut_in_adj(g: &Graph) -> Vec<Vec<(usize, u64)>> {
    let n = g.nodes.len();
    let mut adj: Vec<Vec<(usize, u64)>> = vec![Vec::new(); n];
    for i in 0..n {
        if !is_cut_node_id(g.nodes[i].node_type) {
            for &(from_i, h_edge) in &g.in_adj[i] {
                if !is_cut_node_id(g.nodes[from_i].node_type) {
                    adj[i].push((from_i, h_edge));
                }
            }
        }
    }
    adj
}

/// Non-cut symmetrized adjacency (undirected cut variants). Note the Julia
/// asymmetry: each direction is gated independently on the *opposite* endpoint
/// being non-cut — a cut node's neighbor still records the edge.
fn non_cut_adj_undirected(g: &Graph) -> Vec<Vec<(usize, u64)>> {
    let n = g.nodes.len();
    let mut adj: Vec<Vec<(usize, u64)>> = vec![Vec::new(); n];
    for to_i in 0..n {
        for &(from_i, h_edge) in &g.in_adj[to_i] {
            if !is_cut_node_id(g.nodes[to_i].node_type) {
                adj[to_i].push((from_i, h_edge));
            }
            if !is_cut_node_id(g.nodes[from_i].node_type) {
                adj[from_i].push((to_i, h_edge));
            }
        }
    }
    adj
}

/// The cut-node globals_from_types map: for each cut node type, the sorted
/// list of distinct `typer(from)` types that connect to it (first-seen group
/// order, matching Julia's Dict insertion order).
fn globals_from_types(g: &Graph) -> Vec<(String, Vec<String>)> {
    // dedup on (TypeId, TypeId) pairs — allocation-free
    let mut seen: Vec<(TypeId, TypeId)> = Vec::new();
    for (from_id, to_id, _) in &g.edges {
        let to_node = &g.node_dict[to_id];
        if is_cut_node_id(to_node.node_type) {
            let from_node = &g.node_dict[from_id];
            let pair = (typer_id(from_node.node_type), to_node.node_type);
            if !seen.contains(&pair) {
                seen.push(pair);
            }
        }
    }
    let mut order: Vec<TypeId> = Vec::new();
    let mut groups: Vec<Vec<String>> = Vec::new();
    for (from, to) in &seen {
        match order.iter().position(|t| t == to) {
            Some(i) => groups[i].push(from.as_str().to_string()),
            None => {
                order.push(*to);
                groups.push(vec![from.as_str().to_string()]);
            }
        }
    }
    for v in &mut groups {
        v.sort();
    }
    order
        .into_iter()
        .map(|t| t.as_str().to_string())
        .zip(groups)
        .collect()
}

/// Initial colors for node-typed variants (wl-n / wl-ne).
fn init_colors_by_type(g: &Graph, colors: &mut Colors, training: bool) -> Vec<u64> {
    g.nodes
        .iter()
        .map(|node| {
            let h_type = hash_node_type(typer_id(node.node_type).as_str());
            if training {
                if !colors.contains_key(h_type) {
                    colors.insert(h_type, h_type);
                }
                h_type
            } else {
                colors.get_or(h_type, h_type)
            }
        })
        .collect()
}

/// Initial colors for cut variants.
fn init_colors_cut(g: &Graph, colors: &mut Colors, training: bool) -> Vec<u64> {
    let gft = globals_from_types(g);
    let gft_ids: Vec<(&str, String)> = gft
        .iter()
        .map(|(k, v)| (k.as_str(), v.join(",")))
        .collect();
    g.nodes
        .iter()
        .map(|node| {
            if is_cut_node_id(node.node_type) {
                let matching = gft_ids
                    .iter()
                    .find(|(k, _)| *k == node.node_type.as_str())
                    .map(|(_, v)| v.clone())
                    .unwrap_or_default();
                let color_str = format!("{},{}", node.node_type.as_str(), matching);
                let h_color = hash_cut_color_string(&color_str);
                if training {
                    if !colors.contains_key(h_color) {
                        colors.insert(h_color, h_color);
                    }
                    h_color
                } else {
                    colors.get_or(h_color, hash_node_type(node.node_type.as_str()))
                }
            } else {
                let h_type = hash_node_type(typer_id(node.node_type).as_str());
                if training {
                    if !colors.contains_key(h_type) {
                        colors.insert(h_type, h_type);
                    }
                    h_type
                } else {
                    colors.get_or(h_type, h_type)
                }
            }
        })
        .collect()
}

/// The main iteration loop. `step` computes a candidate hash per node;
/// application of colors happens in node order (deterministic). `keep_color`
/// selects which nodes don't participate (cut nodes keep their color).
#[allow(clippy::too_many_arguments)]
fn run_loop<S>(
    adj: &[Vec<(usize, u64)>],
    curr_colors: &mut Vec<u64>,
    colors: &mut Colors,
    iterations: usize,
    training: bool,
    num_cores: usize,
    fallback: Fallback,
    step: S,
    keep_color: Option<&[bool]>,
    mut collect_all: impl FnMut(&[u64]),
) where
    S: Fn(&[(usize, u64)], &[u64], usize, &mut Vec<u64>) -> u64 + Send + Sync,
{
    let n = curr_colors.len();
    if n == 0 {
        return;
    }
    let use_parallel = n >= 1000 && num_cores > 1 && rayon::current_num_threads() > 1;
    let mut next_colors = vec![0u64; n];

    for _ in 0..iterations {
        // Phase 1: candidate hashes (pure). Parallel when worthwhile.
        let hashes: Vec<u64> = if use_parallel {
            use rayon::prelude::*;
            (0..n)
                .into_par_iter()
                .map_init(
                    || Vec::with_capacity(64),
                    |buf: &mut Vec<u64>, i| {
                        if keep_color.map_or(false, |kc| kc[i]) {
                            // cut nodes keep their color; skip hashing
                            curr_colors[i]
                        } else {
                            step(&adj[i], curr_colors, i, buf)
                        }
                    },
                )
                .collect()
        } else {
            let mut buf = Vec::with_capacity(64);
            (0..n)
                .map(|i| {
                    if keep_color.map_or(false, |kc| kc[i]) {
                        curr_colors[i]
                    } else {
                        step(&adj[i], curr_colors, i, &mut buf)
                    }
                })
                .collect()
        };

        // Phase 2: apply colors in node order (deterministic dict growth).
        for i in 0..n {
            if keep_color.map_or(false, |kc| kc[i]) {
                next_colors[i] = curr_colors[i];
                continue;
            }
            let h_key = hashes[i];
            if training {
                if !colors.contains_key(h_key) {
                    colors.insert(h_key, h_key);
                }
                next_colors[i] = h_key;
            } else {
                next_colors[i] = match fallback {
                    Fallback::CurrentColor => colors.get_or(h_key, curr_colors[i]),
                    Fallback::HashItself => colors.get_or(h_key, h_key),
                };
            }
        }
        std::mem::swap(curr_colors, &mut next_colors);
        collect_all(curr_colors);
    }
}

fn cut_mask(g: &Graph) -> Vec<bool> {
    g.nodes.iter().map(|n| is_cut_node_id(n.node_type)).collect()
}

// ---------------------------------------------------------------------------
// Standard WL (wl, wl-a, wl-u)
// ---------------------------------------------------------------------------

pub fn wl_directed_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let mut curr = vec![0u64; n];
    let mut noop = |_: &[u64]| {};
    run_loop(&g.in_adj, &mut curr, colors, iterations, training, num_cores, Fallback::CurrentColor, step_plain, None, &mut noop);
    curr
}

pub fn wl_directed_all_levels(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let mut curr = vec![0u64; n];
    let mut all: Vec<u64> = Vec::with_capacity(n * iterations);
    {
        let mut collect = |level: &[u64]| all.extend_from_slice(level);
        run_loop(&g.in_adj, &mut curr, colors, iterations, training, num_cores, Fallback::CurrentColor, step_plain, None, &mut collect);
    }
    all
}

pub fn wl_undirected_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, _num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let adj = symmetrize(g);
    let mut curr = vec![0u64; n];
    let mut noop = |_: &[u64]| {};
    run_loop(&adj, &mut curr, colors, iterations, training, 1, Fallback::CurrentColor, step_plain, None, &mut noop);
    curr
}

// ---------------------------------------------------------------------------
// Node WL (wl-n, wl-an, wl-un)
// ---------------------------------------------------------------------------

pub fn wl_node_directed_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let mut curr = init_colors_by_type(g, colors, training);
    let mut noop = |_: &[u64]| {};
    run_loop(&g.in_adj, &mut curr, colors, iterations, training, num_cores, Fallback::CurrentColor, step_plain, None, &mut noop);
    curr
}

/// Julia quirk: `wl_node_directed_all_levels` builds all_colors but returns
/// `curr_colors` — we replicate the returned value.
pub fn wl_node_directed_all_levels(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    wl_node_directed_last(g, colors, iterations, training, num_cores)
}

pub fn wl_node_undirected_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, _num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let adj = symmetrize(g);
    let mut curr = init_colors_by_type(g, colors, training);
    let mut noop = |_: &[u64]| {};
    run_loop(&adj, &mut curr, colors, iterations, training, 1, Fallback::CurrentColor, step_plain, None, &mut noop);
    curr
}

// ---------------------------------------------------------------------------
// Edge WL (wl-e, wl-ae, wl-ue)
// ---------------------------------------------------------------------------

pub fn wl_edge_directed_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let mut curr = vec![0u64; n];
    let mut noop = |_: &[u64]| {};
    // Julia EdgeWl inference fallback: get(colors, h_key, h_key)
    run_loop(&g.in_adj, &mut curr, colors, iterations, training, num_cores, Fallback::HashItself, step_edge, None, &mut noop);
    curr
}

pub fn wl_edge_directed_all_levels(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let mut curr = vec![0u64; n];
    let mut all: Vec<u64> = Vec::with_capacity(n * iterations);
    {
        let mut collect = |level: &[u64]| all.extend_from_slice(level);
        run_loop(&g.in_adj, &mut curr, colors, iterations, training, num_cores, Fallback::HashItself, step_edge, None, &mut collect);
    }
    all
}

pub fn wl_edge_undirected_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, _num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let adj = symmetrize(g);
    let mut curr = vec![0u64; n];
    let mut noop = |_: &[u64]| {};
    run_loop(&adj, &mut curr, colors, iterations, training, 1, Fallback::HashItself, step_edge, None, &mut noop);
    curr
}

// ---------------------------------------------------------------------------
// Node-Edge WL (wl-ne, wl-ane, wl-une)
// ---------------------------------------------------------------------------

pub fn wl_node_edge_directed_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let mut curr = init_colors_by_type(g, colors, training);
    let mut noop = |_: &[u64]| {};
    run_loop(&g.in_adj, &mut curr, colors, iterations, training, num_cores, Fallback::CurrentColor, step_edge, None, &mut noop);
    curr
}

/// Julia allocates n*n (bug) and returns all_colors including uninitialized
/// tail; we return the well-defined prefix of (iterations+1) levels? No —
/// the Julia loop fills iteration levels only (init level not stored in the
/// loop)... it stores all_colors[i] at init and base+i per iteration, then
/// returns the whole n*n buffer. We return the filled prefix.
pub fn wl_node_edge_directed_all_levels(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let mut curr = init_colors_by_type(g, colors, training);
    let mut all: Vec<u64> = Vec::with_capacity(n * (iterations + 1));
    all.extend_from_slice(&curr);
    {
        let mut collect = |level: &[u64]| all.extend_from_slice(level);
        run_loop(&g.in_adj, &mut curr, colors, iterations, training, num_cores, Fallback::CurrentColor, step_edge, None, &mut collect);
    }
    all
}

pub fn wl_node_edge_undirected_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, _num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let adj = symmetrize(g);
    let mut curr = init_colors_by_type(g, colors, training);
    let mut noop = |_: &[u64]| {};
    run_loop(&adj, &mut curr, colors, iterations, training, 1, Fallback::CurrentColor, step_edge, None, &mut noop);
    curr
}

// ---------------------------------------------------------------------------
// Node Cut WL (wl-nc, wl-anc, wl-unc)
// ---------------------------------------------------------------------------

pub fn wl_node_cut_directed_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let adj = non_cut_in_adj(g);
    let mask = cut_mask(g);
    let mut curr = init_colors_cut(g, colors, training);
    let mut noop = |_: &[u64]| {};
    run_loop(&adj, &mut curr, colors, iterations, training, num_cores, Fallback::CurrentColor, step_plain, Some(&mask), &mut noop);
    curr
}

/// Julia quirk: `wl_node_cut_directed_all_colors` returns curr_colors.
pub fn wl_node_cut_directed_all_colors(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    wl_node_cut_directed_last(g, colors, iterations, training, num_cores)
}

pub fn wl_node_cut_undirected_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, _num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let adj = non_cut_adj_undirected(g);
    let mask = cut_mask(g);
    let mut curr = init_colors_cut(g, colors, training);
    let mut noop = |_: &[u64]| {};
    run_loop(&adj, &mut curr, colors, iterations, training, 1, Fallback::CurrentColor, step_plain, Some(&mask), &mut noop);
    curr
}

// ---------------------------------------------------------------------------
// Node-Edge Cut WL (wl-nec, wl-anec, wl-unec)
// ---------------------------------------------------------------------------

pub fn wl_node_edge_cut_directed_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let adj = non_cut_in_adj(g);
    let mask = cut_mask(g);
    let mut curr = init_colors_cut(g, colors, training);
    let mut noop = |_: &[u64]| {};
    run_loop(&adj, &mut curr, colors, iterations, training, num_cores, Fallback::CurrentColor, step_edge, Some(&mask), &mut noop);
    curr
}

/// Julia quirk: returns curr_colors.
pub fn wl_node_edge_cut_directed_all_levels(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, num_cores: usize) -> Vec<u64> {
    wl_node_edge_cut_directed_last(g, colors, iterations, training, num_cores)
}

pub fn wl_node_edge_cut_undirected_last(g: &Graph, colors: &mut Colors, iterations: usize, training: bool, _num_cores: usize) -> Vec<u64> {
    let n = g.nodes.len();
    if n == 0 {
        return Vec::new();
    }
    let adj = non_cut_adj_undirected(g);
    let mask = cut_mask(g);
    let mut curr = init_colors_cut(g, colors, training);
    let mut noop = |_: &[u64]| {};
    run_loop(&adj, &mut curr, colors, iterations, training, 1, Fallback::CurrentColor, step_edge, Some(&mask), &mut noop);
    curr
}
