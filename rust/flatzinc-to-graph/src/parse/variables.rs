//! Variable declaration parsing, port of `parse/variables.jl`.

use super::helper::is_bounded_number_set;

#[derive(Debug, Clone, PartialEq)]
pub struct Variable {
    /// one of "int", "bool", "float", "SetOfInt"
    pub var_type: &'static str,
    pub name: String,
    pub domain_size: i64,
}

/// `parse_domain`: returns (type, size) for a domain string.
fn parse_domain(domain: &str) -> Option<(&'static str, i64)> {
    if let Some(bound) = is_bounded_number_set(domain) {
        return Some(("int", bound));
    }
    match domain {
        "bool" => Some(("bool", 2)),
        "int" => Some(("int", 1_000_000)),
        "float" => Some(("float", 1_000_000)),
        _ => {
            if let Some(rest) = domain.strip_prefix("set of") {
                let rest = rest.trim();
                if rest == "int" {
                    return Some(("SetOfInt", 1_000_000));
                }
                if let Some(idx) = rest.find("..") {
                    let lb: i64 = rest[..idx].parse().ok()?;
                    let ub: i64 = rest[idx + 2..].parse().ok()?;
                    return Some(("SetOfInt", ub - lb + 1));
                }
                if rest.starts_with('{') && rest.ends_with('}') {
                    let commas = rest.bytes().filter(|&c| c == b',').count();
                    return Some(("SetOfInt", commas as i64 + 1));
                }
                None
            } else {
                None
            }
        }
    }
}

/// `parse_variable(line)`: parse a `var <domain>: <name>...;` line.
pub fn parse_variable(line: &str) -> Option<Variable> {
    let domain_separator = line.find(':')?;
    // Julia: SubString(line, 5, sep-1) — skips "var " (4 chars)
    let domain_str = line.get(4..domain_separator)?.trim();
    let (domain_type, size) = parse_domain(domain_str)?;

    let start_idx = domain_separator + 1;
    let end_idx = line.len();

    let mut end_pos = end_idx;
    if let Some(cc) = line[start_idx..].find("::").map(|i| i + start_idx) {
        end_pos = end_pos.min(cc);
    }
    if let Some(eq) = line[start_idx..].find('=').map(|i| i + start_idx) {
        end_pos = end_pos.min(eq);
    }
    if let Some(semi) = line[start_idx..].find(';').map(|i| i + start_idx) {
        end_pos = end_pos.min(semi);
    }

    let name = line[start_idx..end_pos.max(start_idx)].trim();
    if name.is_empty() {
        return None;
    }
    Some(Variable {
        var_type: domain_type,
        name: name.to_string(),
        domain_size: size,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_output_var() {
        let v = parse_variable("var bool: x1:: output_var;").unwrap();
        assert_eq!(v.name, "x1");
        assert_eq!(v.var_type, "bool");
        assert_eq!(v.domain_size, 2);

        let v = parse_variable("var 0..1: item1:: output_var;").unwrap();
        assert_eq!(v.name, "item1");
        assert_eq!(v.var_type, "int");
        assert_eq!(v.domain_size, 2);

        let v = parse_variable("var 0..12: total_value:: is_defined_var;").unwrap();
        assert_eq!(v.name, "total_value");
        assert_eq!(v.domain_size, 13);
    }
}
