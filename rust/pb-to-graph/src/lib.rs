//! PbToGraph: parse Pseudo-Boolean (.opb/.wbo, incl. xz-compressed) problems
//! into attributed directed graphs. Rust port of the Julia package.

mod parse;

pub use parse::pb_to_graph;
