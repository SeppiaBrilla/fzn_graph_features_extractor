//! PB solve item parsing, port of `parse/solve.jl`.

use super::terms::{parse_term, Term};

#[derive(Debug, Clone)]
pub struct SolveType {
    /// "min" or "max"
    pub solve_type: &'static str,
    pub objective_vars: Option<Vec<Term>>,
}

pub fn is_solve(line: &str) -> bool {
    line.starts_with("min:") || line.starts_with("max:")
}

pub fn parse_solve(line: &str) -> Option<SolveType> {
    if !is_solve(line) {
        return None;
    }
    let t_type: &'static str = if line.starts_with("min:") {
        "min"
    } else {
        "max"
    };
    let term_body = line[4..].trim();
    let terms = parse_term(term_body);
    Some(SolveType {
        solve_type: t_type,
        objective_vars: Some(terms),
    })
}
