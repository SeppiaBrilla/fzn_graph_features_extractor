//! Graph data structures, mirroring the Julia `GraphType` module.
//!
//! Node identity is the (stable, in-process) hash of the node label, exactly
//! like the Julia implementation: two nodes with the same label are the same
//! node, whichever constraint creates them first.
//!
//! Edge identity is the (from, to) pair — the Julia version dedups on the
//! (from, to) pair only; we keep that behaviour so edge counts match.
//!
//! `Node.node_type` / `Node.var_type` are interned `TypeId`s (u16 indexes),
//! mirroring Julia's `Symbol` fields: cloning a `Node` clones one `String`
//! (the label) and copies two `u16`s — no extra heap allocations.

use super::fast_hasher::FastHashMap;
use crate::interner::{intern, intern_static, TypeId, T_NONE};
use crate::julia_hash::{hash_symbol, jl_hash_str};
use std::collections::HashSet;

/// Positional edge labels (`Symbol(0)`, `Symbol(1)`, `Symbol(2)` in Julia).
pub const EDGE_0: &str = "0";
pub const EDGE_1: &str = "1";
pub const EDGE_2: &str = "2";

pub type NodeId = u64;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Node {
    /// Shared label. `Arc<str>` makes `Node::clone()` a refcount bump: node
    /// labels are shared across constraints (dedup by id), so this removes
    /// the dominant per-clone heap allocation of the `String` version.
    pub label: std::sync::Arc<str>,
    pub node_type: TypeId,
    pub id: NodeId,
    pub var_type: TypeId,
    pub var_dom_size: i64,
}

impl Node {
    pub fn new(label: impl Into<String>, node_type: impl AsRef<str>, id: NodeId) -> Self {
        let node_type = intern(node_type.as_ref());
        Node {
            label: label.into().into(),
            node_type,
            id,
            var_type: T_NONE,
            var_dom_size: 0,
        }
    }

    pub fn with_var(
        label: impl Into<String>,
        node_type: impl AsRef<str>,
        id: NodeId,
        var_type: impl AsRef<str>,
        var_dom_size: i64,
    ) -> Self {
        Node {
            label: label.into().into(),
            node_type: intern(node_type.as_ref()),
            id,
            var_type: intern(var_type.as_ref()),
            var_dom_size,
        }
    }

    /// Type-interned constructor (no string lookups on the type fields).
    pub fn with_types(
        label: impl Into<String>,
        node_type: TypeId,
        id: NodeId,
        var_type: TypeId,
        var_dom_size: i64,
    ) -> Self {
        Node {
            label: label.into().into(),
            node_type,
            id,
            var_type,
            var_dom_size,
        }
    }

    /// Construct with a node type known to be already interned (avoids a
    /// redundant table scan when the caller has the `TypeId` handy).
    pub fn new_static(label: impl Into<String>, node_type: &'static str, id: NodeId) -> Self {
        Node {
            label: label.into().into(),
            node_type: intern_static(node_type),
            id,
            var_type: T_NONE,
            var_dom_size: 0,
        }
    }

    /// Like [`Node::with_var`], but returns a node that does NOT take ownership
    /// of a heap label when the caller only has a `&str` and knows the node is
    /// already in the graph (avoids allocating just to look it up).
    pub fn key(id: NodeId) -> NodeKey {
        NodeKey(id)
    }
}

/// Zero-allocation lookup key for `Graph::get_node`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NodeKey(pub NodeId);

/// Edge label. Interned to avoid re-allocating the positional labels.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum EdgeLabel {
    Zero,
    One,
    Two,
    Other(String),
}

impl EdgeLabel {
    pub fn new(s: &str) -> Self {
        match s {
            "0" => EdgeLabel::Zero,
            "1" => EdgeLabel::One,
            "2" => EdgeLabel::Two,
            other => EdgeLabel::Other(other.to_string()),
        }
    }

    pub fn as_str(&self) -> &str {
        match self {
            EdgeLabel::Zero => "0",
            EdgeLabel::One => "1",
            EdgeLabel::Two => "2",
            EdgeLabel::Other(s) => s,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Edge {
    pub label: EdgeLabel,
}

impl Edge {
    pub fn new(label: EdgeLabel) -> Self {
        Edge { label }
    }
}

/// Stable hash used for node ids (and, downstream, WL colors). Uses the
/// Julia-exact string hash so node identity/dedup behaves identically to the
/// Julia implementation and differential tests can compare raw ids.
pub fn stable_hash(s: &str) -> u64 {
    jl_hash_str(s)
}

/// Hash of an edge label symbol (Julia `hash(Symbol(...))`).
pub fn label_hash(l: &EdgeLabel) -> u64 {
    match l {
        EdgeLabel::Zero => hash_symbol("0"),
        EdgeLabel::One => hash_symbol("1"),
        EdgeLabel::Two => hash_symbol("2"),
        EdgeLabel::Other(s) => hash_symbol(s),
    }
}

/// Graph: insertion-ordered nodes and edges, with node lookup by id and a
/// prebuilt in-adjacency (indexed by node position) for the WL iterations.
#[derive(Debug, Clone, Default)]
pub struct Graph {
    pub nodes: Vec<Node>,
    /// (from_id, to_id, label)
    pub edges: Vec<(NodeId, NodeId, EdgeLabel)>,
    /// Edge identity is the (from, to) pair — the label is NOT part of edge
    /// identity (matches the Julia `UInt128(from)<<64 | to` edge_set).
    pub edge_set: HashSet<(NodeId, NodeId)>,
    pub node_dict: FastHashMap<NodeId, Node>,
    pub node_idx: FastHashMap<NodeId, usize>,
    /// in_adj[i] = list of (from_index, edge_hash) for incoming edges of node i.
    pub in_adj: Vec<Vec<(usize, u64)>>,
}

impl Graph {
    pub fn new() -> Self {
        Graph::default()
    }

    /// Reserve capacity for the expected node/edge counts (avoids rehashing
    /// and Vec growth during bulk insertion).
    pub fn reserve(&mut self, nodes: usize, edges: usize) {
        self.nodes.reserve(nodes);
        self.edges.reserve(edges);
        self.node_dict.reserve(nodes);
        self.node_idx.reserve(nodes);
        self.edge_set.reserve(edges);
        // in_adj grows with add_node; approximate the reserve via nodes too
        let extra = nodes.saturating_sub(self.in_adj.len());
        self.in_adj.reserve(extra);
    }

    #[inline]
    pub fn get_node(&self, id: NodeId) -> Option<&Node> {
        self.node_dict.get(&id)
    }

    /// Add a node unless one with the same id already exists.
    ///
    /// Takes the node by value (the common case: caller constructed it); the
    /// dedup check happens before any internal clone.
    #[inline]
    pub fn add_node(&mut self, node: Node) {
        if !self.node_dict.contains_key(&node.id) {
            let idx = self.nodes.len();
            self.node_idx.insert(node.id, idx);
            self.node_dict.insert(node.id, node.clone());
            self.nodes.push(node);
            self.in_adj.push(Vec::new());
        }
    }

    /// Add a node from parts, avoiding the construction (and label
    /// allocation) of a temporary `Node` when the id is already present.
    /// Returns the stored node (a clone) either way.
    #[inline]
    pub fn add_node_parts(
        &mut self,
        label: &str,
        node_type: TypeId,
        id: NodeId,
        var_type: TypeId,
        var_dom_size: i64,
    ) -> Node {
        if let Some(existing) = self.node_dict.get(&id) {
            return existing.clone();
        }
        let node = Node::with_types(label.to_string(), node_type, id, var_type, var_dom_size);
        let idx = self.nodes.len();
        self.node_idx.insert(id, idx);
        self.node_dict.insert(id, node.clone());
        self.nodes.push(node.clone());
        self.in_adj.push(Vec::new());
        node
    }

    #[inline]
    pub fn add_edge(&mut self, from: NodeId, to: NodeId, e: &Edge) {
        let key = (from, to);
        if !self.edge_set.contains(&key) {
            self.edge_set.insert(key);
            self.edges.push((from, to, e.label.clone()));
            // The Julia version updates in_adj only when both endpoints exist.
            if let (Some(&to_i), Some(&from_i)) =
                (self.node_idx.get(&to), self.node_idx.get(&from))
            {
                self.in_adj[to_i].push((from_i, label_hash(&e.label)));
            }
        }
    }

    /// Like `add_edge`, for the common case of positional labels, avoiding
    /// the `Edge` wrapper and its clone.
    #[inline]
    pub fn add_edge_label(&mut self, from: NodeId, to: NodeId, label: &EdgeLabel) {
        let key = (from, to);
        if !self.edge_set.contains(&key) {
            self.edge_set.insert(key);
            self.edges.push((from, to, label.clone()));
            if let (Some(&to_i), Some(&from_i)) =
                (self.node_idx.get(&to), self.node_idx.get(&from))
            {
                self.in_adj[to_i].push((from_i, label_hash(label)));
            }
        }
    }
}
