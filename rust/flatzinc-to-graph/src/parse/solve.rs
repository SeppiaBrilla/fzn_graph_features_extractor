//! Solve item parsing, port of `parse/solve.jl`.

use super::variables::Variable;

#[derive(Debug, Clone, PartialEq)]
pub struct SolveType {
    /// "SAT", "minimize", "maximize"
    pub solve_type: String,
    pub objective_var: Option<Variable>,
}

/// `parse_solve(line, vars)`.
///
/// Julia quirk: `split(line, "minimize")[end]` — when the separator occurs
/// multiple times, keeps the LAST part; `replace(..., ";" => "")` strips ALL
/// semicolons.
pub fn parse_solve(line: &str, vars: &std::collections::HashMap<String, Variable>) -> SolveType {
    if line.contains("satisfy") {
        return SolveType {
            solve_type: "SAT".to_string(),
            objective_var: None,
        };
    } else if let Some(pos) = line.rfind("minimize") {
        let var_name = line[pos + "minimize".len()..].replace(';', "").trim().to_string();
        return SolveType {
            solve_type: "minimize".to_string(),
            objective_var: vars.get(&var_name).cloned(),
        };
    } else if let Some(pos) = line.rfind("maximize") {
        let var_name = line[pos + "maximize".len()..].replace(';', "").trim().to_string();
        return SolveType {
            solve_type: "maximize".to_string(),
            objective_var: vars.get(&var_name).cloned(),
        };
    }
    // Julia falls through returning `nothing` implicitly; the caller's
    // `if !isnothing(solve)` would throw on accessing `.type`. We mimic by
    // returning an empty SAT — the Julia code would only reach here for
    // malformed models.
    SolveType {
        solve_type: String::new(),
        objective_var: None,
    }
}
