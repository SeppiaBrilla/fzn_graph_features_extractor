//! PB term parsing, port of `parse/terms.jl`.

#[derive(Debug, Clone, PartialEq)]
pub struct Variable {
    pub name: String,
    pub is_negative: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Term {
    pub variables: Vec<Variable>,
    pub coefficient: i64,
}

/// Julia token classification: a token is a coefficient if it starts with
/// '+', '-', or a digit, and (length==1 or second char is a digit).
fn token_is_coeff(t: &str) -> bool {
    let b = t.as_bytes();
    if b.is_empty() {
        return false;
    }
    let first = b[0];
    if first == b'+' || first == b'-' || first.is_ascii_digit() {
        return b.len() == 1 || b[1].is_ascii_digit();
    }
    false
}

/// `parse_term(tokens)`: sequence of terms, each = coefficient followed by
/// one or more variable literals.
pub fn parse_term_tokens(tokens: &[&str]) -> Vec<Term> {
    let mut end_tokens = tokens.len();
    if end_tokens > 0 && tokens[end_tokens - 1] == ";" {
        end_tokens -= 1;
    }

    let mut terms: Vec<Term> = Vec::new();
    let mut vars: Vec<Variable> = Vec::new();
    let mut coeff: Option<i64> = None;

    let mut i = 0usize;
    while i < end_tokens {
        let t = tokens[i];
        if token_is_coeff(t) {
            if let Ok(parsed) = t.parse::<i64>() {
                if let Some(c) = coeff {
                    terms.push(Term {
                        variables: vars.clone(),
                        coefficient: c,
                    });
                    vars.clear();
                }
                coeff = Some(parsed);
                i += 1;
                continue;
            }
        }

        if let Some(name) = t.strip_prefix('~') {
            vars.push(Variable {
                name: name.to_string(),
                is_negative: true,
            });
        } else {
            vars.push(Variable {
                name: t.to_string(),
                is_negative: false,
            });
        }
        i += 1;
    }

    if let Some(c) = coeff {
        terms.push(Term {
            variables: vars,
            coefficient: c,
        });
    }

    terms
}

/// `parse_term(term_line)`: tokenize on whitespace then delegate.
pub fn parse_term(term_line: &str) -> Vec<Term> {
    let tokens: Vec<&str> = term_line.split_whitespace().collect();
    parse_term_tokens(&tokens)
}
