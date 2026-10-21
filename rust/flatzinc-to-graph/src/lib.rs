//! FlatzincToGraph: parse FlatZinc (Gecode-flavored) models into attributed
//! directed graphs. Rust port of the Julia package of the same name.

pub mod graph;
pub mod interner;
pub mod julia_hash;
pub mod parse;

pub use graph::fast_hasher::{FastHashMap, FastHashSet, U64Build};
pub use graph::types::{Edge, EdgeLabel, Graph, Node, NodeId};
pub use graph::writer::write_graph;
pub use interner::{intern, intern_static, TypeId};
pub use parse::flatzinc_to_graph;
