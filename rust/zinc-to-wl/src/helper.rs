//! Shared WL helpers, port of `wl_features/Helper.jl`.

use std::collections::HashMap;

use flatzinc_to_graph::graph::types::{Graph, Node};
use flatzinc_to_graph::interner::{
    intern_static, TypeId, T_BOOL, T_FLOAT, T_INT, T_MAXIMISE_NODE, T_MINIMISE_NODE,
    T_PARAMETER_NODE, T_PAR_NODE, T_SETOFINT, T_VAR_NODE,
};
use flatzinc_to_graph::julia_hash::{hash_string, hash_symbol};

use crate::julia_dict::JuliaDict;

/// `typer`: collapse literal-ish node types to `literal_node`.
/// (String-based variant kept for reference; hot paths use `typer_id`.)
#[allow(dead_code)]
pub fn typer(t: &str) -> &str {
    match t {
        "int" | "float" | "bool" | "par_node" | "parameter_node" | "SetOfInt" => "literal_node",
        other => other,
    }
}

/// TypeId-based `typer` (hot path): collapse literal-ish node types to
/// `literal_node`.
#[inline]
pub fn typer_id(t: TypeId) -> TypeId {
    match t {
        T_INT | T_FLOAT | T_BOOL | T_PAR_NODE | T_PARAMETER_NODE | T_SETOFINT => {
            intern_static("literal_node")
        }
        other => other,
    }
}

pub const GLOBAL_NODES: &[&str] = &[
    "cumulatives_node",
    "int_element_node",
    "int_lin_eq_imp_node",
    "array_int_maximum_node",
    "schedule_unary_node",
    "int_le_imp_node",
    "global_cardinality_node",
    "global_cardinality_low_up_node",
    "maximum_arg_int_offset_node",
    "circuit_node",
    "count_eq_reif_node",
    "set_in_imp_node",
    "count_eq_node",
    "global_cardinality_low_up_closed_node",
    "bool_xor_imp_node",
    "nooverlap_node",
    "regular_node",
    "all_different_node",
    "eq_imp_node",
    "all_equal_node",
    "bool_element_node",
    "array_int_minimum_node",
    "bool_clause_reif_node",
    "int_element2d_node",
    "bin_packing_load_node",
    "table_int_node",
    "precede_node",
    "array_int_lq_node",
    "int_lin_le_imp_node",
    "int_lin_ne_imp_node",
    "increasing_int_node",
    "inverse_offsets_node",
    "nvalue_node",
    "int_ne_imp_node",
    "increasing_bool_node",
    "member_int_node",
    "table_int_imp_node",
    "at_least_node",
    "at_most_node",
    "int_pow_node",
    "global_cardinality_closed_node",
    "lin_sum_node",
];

pub const CUT_EXTRA: &[&str] = &["multi_and_node", "multi_or_node", "multi_xor_node"];

#[allow(dead_code)]
pub fn is_global(node_type: &str) -> bool {
    GLOBAL_NODES.contains(&node_type)
}

#[allow(dead_code)]
pub fn is_cut_node(node_type: &str) -> bool {
    is_global(node_type) || CUT_EXTRA.contains(&node_type)
}

/// Precomputed `TypeId` set of all cut-node types (globals + multi_*).
/// Built once; lookups are O(1) instead of a 45-entry linear scan.
static CUT_SET: std::sync::OnceLock<std::collections::HashSet<TypeId>> = std::sync::OnceLock::new();

#[inline]
pub fn is_cut_node_id(t: TypeId) -> bool {
    // The `_global` suffix marks unknown/solver-specific globals (e.g.
    // `chuffed_array_int_minimum_global`), created by
    // `decompose_unknown_global` for non-gecode FlatZinc. They behave as
    // cut nodes even though they are not in the static tables.
    if t.as_str().ends_with("_global") {
        return true;
    }
    CUT_SET
        .get_or_init(|| {
            GLOBAL_NODES
                .iter()
                .chain(CUT_EXTRA.iter())
                .map(|&s| intern_static(s))
                .collect()
        })
        .contains(&t)
}

/// Unknown/solver-specific global (node type suffixed `_global` by the parser).
#[allow(dead_code)]
pub fn is_unknown_global(node_type: &str) -> bool {
    node_type.ends_with("_global")
}

/// `tailored_hash`: fold `hash(c, h)` over sorted neighbor colors.
/// Julia `hash(c::UInt64, h) = hash_64_64(c) - 3h`.
#[inline]
pub fn tailored_hash(self_color: u64, sorted_neibs: &[u64]) -> u64 {
    let mut h = self_color;
    for &c in sorted_neibs {
        h = flatzinc_to_graph::julia_hash::hash_uint64(c, h);
    }
    h
}

/// Hash of a node type symbol (wl-n initial colors).
#[inline]
pub fn hash_node_type(t: &str) -> u64 {
    hash_symbol(t)
}

/// Hash of the cut-node color string `"$type,$from1,$from2,..."`.
#[inline]
pub fn hash_cut_color_string(s: &str) -> u64 {
    hash_string(s, 0)
}

// ---------------------------------------------------------------------------
// colors persistence (Rust-native format: little-endian u64 count + pairs)
// ---------------------------------------------------------------------------

pub fn save_colors(file_path: &str, colors: &JuliaDict<u64>) -> std::io::Result<()> {
    use std::io::Write;
    let mut buf: Vec<u8> = Vec::with_capacity(8 + colors.len() * 16);
    buf.extend_from_slice(&(colors.len() as u64).to_le_bytes());
    for (k, v) in colors.iter() {
        buf.extend_from_slice(&k.to_le_bytes());
        buf.extend_from_slice(&v.to_le_bytes());
    }
    std::fs::File::create(file_path)?.write_all(&buf)
}

// ---------------------------------------------------------------------------
// extract_extra_info
// ---------------------------------------------------------------------------

pub struct ExtraInfo {
    /// (from_type, to_type) -> count, iterated in Julia Dict order
    pub globals_pairs: JuliaDict<i64>,
    /// label lookup for the pairs (hash -> printable pair)
    pub pair_labels: HashMap<u64, PairKey>,
    pub n_nodes: usize,
    pub cpv: f64,
    pub cpp: f64,
    pub d_ratio_int_vars: f64,
    pub d_ratio_bool_vars: f64,
    pub o_deg_cons: f64,
    pub o_deg_std: f64,
    pub o_dom_deg: f64,
    pub v_ent_deg_vars: f64,
    pub v_sum_domdeg_vars: f64,
}

/// (typer(from), to) pair — hashed with Julia's 2-tuple hash for the dict.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PairKey {
    pub from: String,
    pub to: String,
    /// precomputed tuple hash (Julia hash((:a, :b)))
    pub hash: u64,
}

impl PairKey {
    pub fn new(from: &str, to: &str) -> Self {
        // Julia: hash((typer(from), to))
        let h = flatzinc_to_graph::julia_hash::hash_tuple2_symbols(from, to, 0);
        PairKey {
            from: from.to_string(),
            to: to.to_string(),
            hash: h,
        }
    }
}

impl std::fmt::Display for PairKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "({}, {})", self.from, self.to)
    }
}

/// Per-node data used by the statistics pass (sequential port of the
/// parallel Julia version; the parallel version merges deterministically,
/// so a sequential pass yields the same numbers — except float summation
/// order, which we replicate below).
pub fn extract_extra_info(g: &Graph, num_cores: usize) -> ExtraInfo {
    let n_nodes = g.nodes.len();
    if n_nodes == 0 {
        return ExtraInfo {
            globals_pairs: JuliaDict::new_raw_keys(),
            pair_labels: HashMap::new(),
            n_nodes: 0,
            cpv: 0.0,
            cpp: 0.0,
            d_ratio_int_vars: 0.0,
            d_ratio_bool_vars: 0.0,
            o_deg_cons: 0.0,
            o_deg_std: 0.0,
            o_dom_deg: 0.0,
            v_ent_deg_vars: 0.0,
            v_sum_domdeg_vars: 0.0,
        };
    }

    // objective var id (first maximise/minimise node's EDGE_0 successor)
    let mut obj_var_id: u64 = 0;
    'outer: for node in &g.nodes {
        if node.node_type == T_MAXIMISE_NODE || node.node_type == T_MINIMISE_NODE {
            for (f, t, _) in &g.edges {
                if *f == node.id {
                    obj_var_id = *t;
                    break 'outer;
                }
            }
            break;
        }
    }

    // degrees + pairs. Mirrors the Julia structure: a per-"thread" chunk dict
    // is built first (insertion in edge order), then merged into the result
    // dict by iterating the chunk dict in ITS slot order. With one thread the
    // chunk covers all edges, but the intermediate iteration order still
    // differs from edge order — and the final dict layout depends on it.
    let mut out_degrees: flatzinc_to_graph::FastHashMap<u64, i64> =
        flatzinc_to_graph::FastHashMap::default();
    let mut in_degrees: flatzinc_to_graph::FastHashMap<u64, i64> =
        flatzinc_to_graph::FastHashMap::default();
    let mut pairs: JuliaDict<i64> = JuliaDict::new_raw_keys();
    let mut pair_labels: HashMap<u64, PairKey> = HashMap::new();

    // Julia: n_threads = min(num_cores, Threads.nthreads()); the chunks are
    // spawned per thread and merged in thread order. We replicate the chunk
    // structure; with num_cores > 1 we process chunks in parallel and merge
    // in chunk order (deterministic).
    let n_threads = num_cores.max(1);
    let n_edges = g.edges.len();
    let chunk_size = n_edges.div_ceil(n_threads);
    // Precompute the cut-node ids once (avoids a node_dict lookup + type
    // check per edge in the loop below).
    let cut_ids: flatzinc_to_graph::FastHashSet<u64> = g
        .nodes
        .iter()
        .filter(|n| is_cut_node_id(n.node_type))
        .map(|n| n.id)
        .collect();
    // Cache of (typer(from), to) pair -> tuple hash. Keyed by the type pair
    // (not node ids) because the pair value only depends on the two types.
    let mut pair_hash_cache: flatzinc_to_graph::FastHashMap<(u16, u16), u64> =
        flatzinc_to_graph::FastHashMap::default();
    // node_id -> TypeId for from-nodes (avoids repeated node_dict lookups).
    let mut from_type_cache: flatzinc_to_graph::FastHashMap<u64, u16> =
        flatzinc_to_graph::FastHashMap::default();

    for t in 0..n_threads {
        let start = t * chunk_size;
        let end = ((t + 1) * chunk_size).min(n_edges);
        if start >= end {
            break;
        }
        let mut chunk_pairs: JuliaDict<i64> = JuliaDict::new_raw_keys();
        let mut chunk_out: flatzinc_to_graph::FastHashMap<u64, i64> =
            flatzinc_to_graph::FastHashMap::default();
        let mut chunk_in: flatzinc_to_graph::FastHashMap<u64, i64> =
            flatzinc_to_graph::FastHashMap::default();
        for i in start..end {
            let (from_id, to_id, _) = &g.edges[i];
            *chunk_out.entry(*from_id).or_insert(0) += 1;
            *chunk_in.entry(*to_id).or_insert(0) += 1;

            if cut_ids.contains(to_id) {
                let from_t = match from_type_cache.get(from_id) {
                    Some(&t) => t,
                    None => {
                        let t = typer_id(g.node_dict[from_id].node_type).0;
                        from_type_cache.insert(*from_id, t);
                        t
                    }
                };
                let to_t = g.node_dict[to_id].node_type.0;
                let h = match pair_hash_cache.get(&(from_t, to_t)) {
                    Some(&h) => h,
                    None => {
                        let key = PairKey::new(
                            flatzinc_to_graph::interner::TypeId(from_t).as_str(),
                            flatzinc_to_graph::interner::TypeId(to_t).as_str(),
                        );
                        let h = key.hash;
                        pair_labels.insert(h, key);
                        pair_hash_cache.insert((from_t, to_t), h);
                        h
                    }
                };
                *chunk_pairs.get_or_insert_with(h, || 0) += 1;
            }
        }
        for (k, v) in chunk_out {
            *out_degrees.entry(k).or_insert(0) += v;
        }
        for (k, v) in chunk_in {
            *in_degrees.entry(k).or_insert(0) += v;
        }
        // merge in the chunk dict's iteration (slot) order
        for (h, v) in chunk_pairs.iter() {
            *pairs.get_or_insert_with(h, || 0) += *v;
        }
    }

    // node pass (sequential; Julia's parallel chunks merge in order t=1..N
    // which for plain integer sums is order-independent)
    let mut n_constraints: i64 = 0;
    let mut constraints_per_variable: i64 = 0;
    let mut constraints_per_par: i64 = 0;
    let mut n_var: i64 = 0;
    let mut n_par: i64 = 0;
    let mut int_vars: i64 = 0;
    let mut bool_vars: i64 = 0;
    // freq: Julia Dict{Int,Int} — int keys hash via hash_64_64(x as u64)
    let mut freq = JuliaDict::new();
    let mut v_sum_domdeg_vars: f64 = 0.0;
    let mut obj_deg: f64 = 0.0;
    let mut obj_dom: f64 = 0.0;

    for node in &g.nodes {
        let t_node = typer_id(node.node_type);
        if node.node_type == T_VAR_NODE {
            let out_d = *out_degrees.get(&node.id).unwrap_or(&0);
            constraints_per_variable += out_d;
            n_var += 1;

            *freq.get_or_insert_with(out_d as u64, || 0) += 1;

            match node.var_type {
                T_INT => int_vars += 1,
                T_BOOL => bool_vars += 1,
                _ => {}
            }

            if out_d > 0 {
                // Julia: node.var_dom_size / float(out_d)
                v_sum_domdeg_vars += node.var_dom_size as f64 / out_d as f64;
            }

            if node.id == obj_var_id {
                obj_deg = out_d as f64;
                obj_dom = node.var_dom_size as f64;
            }
        } else if t_node == intern_static("literal_node") {
            let out_d = *out_degrees.get(&node.id).unwrap_or(&0);
            constraints_per_par += out_d;
            n_par += 1;
        }

        if *in_degrees.get(&node.id).unwrap_or(&0) > 0
            && *out_degrees.get(&node.id).unwrap_or(&0) == 0
        {
            n_constraints += 1;
        }
    }

    let cpv = if n_var > 0 {
        constraints_per_variable as f64 / n_var as f64
    } else {
        0.0
    };
    let cpp = if n_par > 0 {
        constraints_per_par as f64 / n_par as f64
    } else {
        0.0
    };

    let d_ratio_int_vars = if n_var > 0 {
        int_vars as f64 / n_var as f64
    } else {
        0.0
    };
    let d_ratio_bool_vars = if n_var > 0 {
        bool_vars as f64 / n_var as f64
    } else {
        0.0
    };

    // entropy: iterate freq in Julia dict order (float sum order matters)
    let mut v_ent_deg_vars = 0.0f64;
    if n_var > 0 {
        for (_, count) in freq.iter() {
            let p = *count as f64 / n_var as f64;
            v_ent_deg_vars -= p * p.log2();
        }
    }

    let mean_deg = cpv; // constraints_per_variable / n_var
    let mut var_deg = 0.0f64;
    if n_var > 0 {
        for (d, count) in freq.iter() {
            let d = (d as i64) as f64;
            var_deg += (*count as f64) * ((d - mean_deg) * (d - mean_deg));
        }
        var_deg /= n_var as f64;
    }
    let std_deg = var_deg.sqrt();

    let o_deg_std = if obj_var_id != 0 && std_deg > 0.0 {
        (obj_deg - mean_deg) / std_deg
    } else {
        0.0
    };

    let o_deg_cons = if obj_var_id != 0 && n_constraints > 0 {
        obj_deg / n_constraints as f64
    } else {
        0.0
    };

    let o_dom_deg = if obj_var_id != 0 && obj_deg > 0.0 {
        obj_dom / obj_deg
    } else {
        0.0
    };

    ExtraInfo {
        globals_pairs: pairs,
        pair_labels: pair_labels,
        n_nodes,
        cpv,
        cpp,
        d_ratio_int_vars,
        d_ratio_bool_vars,
        o_deg_cons,
        o_deg_std,
        o_dom_deg,
        v_ent_deg_vars,
        v_sum_domdeg_vars,
    }
}

// silence unused import
#[allow(unused)]
fn _use(_: &Node) {}
