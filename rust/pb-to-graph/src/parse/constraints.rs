//! PB constraint parsing, port of `parse/constraints.jl`.

use super::terms::{parse_term_tokens, Term};

#[derive(Debug, Clone)]
pub struct Constraint {
    pub weight: Option<i64>,
    pub is_weighted: bool,
    pub terms: Vec<Term>,
    /// "leq_node" or "eq_node"
    pub constr_type: &'static str,
    pub rhs: i64,
}

/// `parse_constraint(line)` — errors on malformed input (like Julia).
pub fn parse_constraint(line: &str) -> std::io::Result<Constraint> {
    let mut weight: Option<i64> = None;
    let mut start_idx = 0usize;

    if line.starts_with('[') {
        let weight_end = line
            .find(']')
            .ok_or_else(|| bad(line, "unterminated weight"))?;
        let w_str = line[1..weight_end].trim();
        // Julia: parse(Int64, ...) — throws on garbage; we error out.
        weight = Some(
            w_str
                .parse::<i64>()
                .map_err(|_| bad(line, "invalid weight"))?,
        );
        start_idx = weight_end + 1;
    }

    let clean_line = match line.find("/*") {
        Some(ci) => line[start_idx..ci].trim(),
        None => line[start_idx..].trim(),
    };

    let tokens: Vec<&str> = clean_line.split_whitespace().collect();
    let op_idx = tokens
        .iter()
        .position(|t| *t == ">=" || *t == "<=" || *t == "=");

    let op_idx = match op_idx {
        Some(i) if i + 1 < tokens.len() => i,
        _ => return Err(bad(line, "Invalid constraint format")),
    };

    let op_str = tokens[op_idx];
    let mut rhs_str = tokens[op_idx + 1];
    if let Some(stripped) = rhs_str.strip_suffix(';') {
        rhs_str = stripped;
    }
    let rhs: i64 = rhs_str
        .parse()
        .map_err(|_| bad(line, "invalid rhs"))?;

    let terms = parse_term_tokens(&tokens[..op_idx]);

    if op_str == ">=" {
        // Invert to <= matching FlatZinc decomposition: sum(-coeff * term) <= -rhs
        let inverted_terms: Vec<Term> = terms
            .into_iter()
            .map(|t| Term {
                variables: t.variables,
                coefficient: -1 * t.coefficient,
            })
            .collect();
        Ok(Constraint {
            weight,
            is_weighted: weight.is_some(),
            terms: inverted_terms,
            constr_type: "leq_node",
            rhs: -1 * rhs,
        })
    } else if op_str == "<=" {
        Ok(Constraint {
            weight,
            is_weighted: weight.is_some(),
            terms,
            constr_type: "leq_node",
            rhs,
        })
    } else {
        Ok(Constraint {
            weight,
            is_weighted: weight.is_some(),
            terms,
            constr_type: "eq_node",
            rhs,
        })
    }
}

fn bad(line: &str, msg: &str) -> std::io::Error {
    std::io::Error::new(
        std::io::ErrorKind::InvalidData,
        format!("{}: {}", msg, line),
    )
}
