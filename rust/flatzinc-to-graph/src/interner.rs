//! Global string interner for node types (and any other repeated strings).
//!
//! Julia's `Node.type::Symbol` is an interned pointer: cloning a Node never
//! allocates. This module provides the same semantics for the Rust port:
//! `TypeId` is a `u16` index into an append-only interned-string table, so
//! `Node::clone()` copies two `u16`s instead of cloning two heap `String`s.
//!
//! The well-known types (those matched on by the WL kernels, the graph
//! writer, and `extract_extra_info`) are pre-registered at indexes
//! `0..WELL_KNOWN_COUNT` so hot paths can compare `TypeId`s directly.

use std::sync::Mutex;

/// Interned string handle. `u16` is plenty: the closed set of node types in
/// the Julia implementation is ~200 entries, and unknown global constraints
/// add at most a few hundred more per corpus.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TypeId(pub u16);

impl TypeId {
    #[inline]
    pub fn as_str(self) -> &'static str {
        // safe: entries are never removed and live for the process lifetime
        table_str(self)
    }
}

// Well-known types, pre-interned at fixed indexes (index == position).
pub const T_VAR_NODE: TypeId = TypeId(0);
pub const T_LITERAL_NODE: TypeId = TypeId(1);
pub const T_PARAMETER_NODE: TypeId = TypeId(2);
pub const T_PAR_NODE: TypeId = TypeId(3);
pub const T_INT: TypeId = TypeId(4);
pub const T_FLOAT: TypeId = TypeId(5);
pub const T_BOOL: TypeId = TypeId(6);
pub const T_SETOFINT: TypeId = TypeId(7);
pub const T_NONE: TypeId = TypeId(8);
pub const T_ARRAY_NODE: TypeId = TypeId(9);
pub const T_MAXIMISE_NODE: TypeId = TypeId(10);
pub const T_MINIMISE_NODE: TypeId = TypeId(11);
pub const T_SATISFY_NODE: TypeId = TypeId(12);
pub const T_SATISFY: TypeId = TypeId(13);

pub const WELL_KNOWN: [&str; 14] = [
    "var_node",
    "literal_node",
    "parameter_node",
    "par_node",
    "int",
    "float",
    "bool",
    "SetOfInt",
    "None",
    "array_node",
    "maximise_node",
    "minimise_node",
    "satisfy_node",
    "satisfy",
];

/// The append-only table for dynamic (non-well-known) types. Guarded by a
/// mutex only on the slow path (first-time interning of an unseen string);
/// well-known types resolve through the static `WELL_KNOWN` array with no
/// locking.
struct Table {
    strings: Vec<&'static str>,
}

static TABLE: Mutex<Option<Table>> = Mutex::new(None);

#[inline]
fn table_str(id: TypeId) -> &'static str {
    let i = id.0 as usize;
    if i < WELL_KNOWN.len() {
        WELL_KNOWN[i]
    } else {
        let guard = TABLE.lock().unwrap_or_else(|e| e.into_inner());
        guard
            .as_ref()
            .and_then(|t| t.strings.get(i - WELL_KNOWN.len()).copied())
            .unwrap_or("")
    }
}

/// Intern a string, returning its stable `TypeId`.
pub fn intern(s: &str) -> TypeId {
    // fast path: well-known types (linear scan of 14 static strings, no lock)
    for (i, w) in WELL_KNOWN.iter().enumerate() {
        if *w == s {
            return TypeId(i as u16);
        }
    }
    let mut guard = TABLE.lock().unwrap_or_else(|e| e.into_inner());
    let table = guard.get_or_insert_with(|| Table {
        strings: Vec::new(),
    });
    // well-known indexes live in the static array; dynamic entries follow
    let dyn_start = WELL_KNOWN.len();
    let mut i = dyn_start;
    while i < table.strings.len() + dyn_start {
        if table.strings[i - dyn_start] == s {
            return TypeId(i as u16);
        }
        i += 1;
    }
    if table.strings.len() + dyn_start >= u16::MAX as usize {
        // degenerate corpus with >65k distinct types: fall back to a shared
        // bucket rather than growing beyond u16
        return TypeId(u16::MAX);
    }
    let leaked: &'static str = Box::leak(s.to_string().into_boxed_str());
    table.strings.push(leaked);
    TypeId((table.strings.len() + dyn_start - 1) as u16)
}

/// Intern a string known to be `'static` (avoids the leak for literals the
/// caller already owns).
pub fn intern_static(s: &'static str) -> TypeId {
    for (i, w) in WELL_KNOWN.iter().enumerate() {
        if *w == s {
            return TypeId(i as u16);
        }
    }
    let mut guard = TABLE.lock().unwrap_or_else(|e| e.into_inner());
    let table = guard.get_or_insert_with(|| Table {
        strings: Vec::new(),
    });
    let dyn_start = WELL_KNOWN.len();
    let mut i = dyn_start;
    while i < table.strings.len() + dyn_start {
        if table.strings[i - dyn_start] == s {
            return TypeId(i as u16);
        }
        i += 1;
    }
    if table.strings.len() + dyn_start >= u16::MAX as usize {
        return TypeId(u16::MAX);
    }
    table.strings.push(s);
    TypeId((table.strings.len() + dyn_start - 1) as u16)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn well_known_ids() {
        assert_eq!(T_VAR_NODE.as_str(), "var_node");
        assert_eq!(T_PARAMETER_NODE.as_str(), "parameter_node");
        assert_eq!(T_INT.as_str(), "int");
        assert_eq!(intern("var_node"), T_VAR_NODE);
        assert_eq!(intern("some_unknown_node"), intern_static("some_unknown_node"));
    }
}
