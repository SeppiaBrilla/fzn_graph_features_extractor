//! Parameter parsing, port of `parse/parameters.jl`.

use super::helper::is_literal;

const ALL_TYPES: [&str; 5] = ["bool", "int", "float", "set of int", "array"];
use super::variables::Variable;

#[derive(Debug, Clone, PartialEq)]
pub struct ParType {
    /// base type name, e.g. "int", "bool", "float", "set of int", "var int"...
    pub type_name: String,
    pub is_var: bool,
    pub is_array: bool,
}

/// A parsed parameter value: scalar string, or a list of elements (each either
/// a literal string or the name of a decision variable).
#[derive(Debug, Clone, PartialEq)]
pub enum ParValue {
    Scalar(String),
    List(Vec<ParElement>),
}

#[derive(Debug, Clone, PartialEq)]
pub enum ParElement {
    Lit(String),
    Var(String),
}

#[derive(Debug, Clone, PartialEq)]
pub struct Parameter {
    pub name: String,
    pub par_type: ParType,
    pub value: ParValue,
}

/// `bounded_type`: for anonymous bounded parameter types like `1..3` or `{1,2}`.
fn bounded_type(par_type_str: &str) -> Option<&'static str> {
    if par_type_str.contains("..") {
        let stripped = par_type_str.replace("..", "");
        // Julia: occursin(".", replace(str, ".." => "")) ? "float" : "int"
        return Some(if stripped.contains('.') { "float" } else { "int" });
    }
    if par_type_str.starts_with('{') && par_type_str.ends_with('}') {
        return Some(if par_type_str.contains('.') { "float" } else { "int" });
    }
    None
}

/// `parse_type`
pub fn parse_type(par_type_str: &str) -> Option<ParType> {
    if par_type_str == "bool"
        || par_type_str == "int"
        || par_type_str == "float"
        || par_type_str == "set of int"
    {
        return Some(ParType {
            type_name: par_type_str.to_string(),
            is_var: false,
            is_array: false,
        });
    }
    if par_type_str.starts_with("array") {
        let of_idx = par_type_str.find("of")?;
        let array_value_type = par_type_str[of_idx + 2..].trim();
        let is_var = array_value_type.starts_with("var ");
        let type_name = if is_var {
            array_value_type[4..].trim()
        } else {
            array_value_type
        };
        return Some(ParType {
            type_name: type_name.to_string(),
            is_var,
            is_array: true,
        });
    }
    let bound = bounded_type(par_type_str)?;
    Some(ParType {
        type_name: bound.to_string(),
        is_var: false,
        is_array: false,
    })
}

/// `parse_par_value`: parse the value part of a parameter declaration.
fn parse_par_value(
    par_value_str: &str,
    par_type: &ParType,
    vars: &std::collections::HashMap<String, Variable>,
) -> ParValue {
    let mut val_str = par_value_str.trim();
    if let Some(stripped) = val_str.strip_suffix(';') {
        val_str = stripped.trim();
    }
    if par_type.is_array {
        if val_str.starts_with('[') && val_str.ends_with(']') {
            val_str = &val_str[1..val_str.len() - 1];
        }
        let mut elements: Vec<String> = Vec::new();
        if val_str.contains('{') || val_str.contains('[') {
            // scan with bracket awareness (port of the Julia while loop)
            let bytes = val_str.as_bytes();
            let mut i = 0usize;
            while i < bytes.len() {
                while i < bytes.len() && (bytes[i] == b' ' || bytes[i] == b',') {
                    i += 1;
                }
                if i >= bytes.len() {
                    break;
                }
                let mut end_idx = bytes.len();
                if bytes[i] == b'{' {
                    if let Some(m) = val_str[i + 1..].find('}') {
                        end_idx = i + 1 + m;
                    }
                } else if bytes[i] == b'[' {
                    if let Some(m) = val_str[i + 1..].find(']') {
                        end_idx = i + 1 + m;
                    }
                } else if let Some(c) = val_str[i..].find(',') {
                    end_idx = i + c - 1;
                }
                elements.push(val_str[i..=end_idx.min(val_str.len() - 1)].to_string());
                i = end_idx + 2;
            }
        } else {
            for x in val_str.split(',') {
                elements.push(x.trim().to_string());
            }
        }
        if !par_type.is_var {
            // Non-var arrays: elements are opaque strings (Julia stores
            // Parameter(e) whose value is the element string itself).
            ParValue::List(
                elements
                    .into_iter()
                    .map(|e| ParElement::Lit(e))
                    .collect(),
            )
        } else {
            ParValue::List(
                elements
                    .into_iter()
                    .map(|e| {
                        if is_literal(&e) {
                            ParElement::Lit(e)
                        } else if let Some(v) = vars.get(&e) {
                            let _ = v;
                            ParElement::Var(e)
                        } else {
                            // Julia: vars[element] would KeyError; treat as var
                            // name (the parser only sees declared vars).
                            ParElement::Var(e)
                        }
                    })
                    .collect(),
            )
        }
    } else if !par_type.is_var {
        ParValue::Scalar(val_str.to_string())
    } else {
        // Julia returns the Variable object; we keep the name. The only use is
        // array-of-var indexing and node lookup, which work from the name.
        ParValue::List(vec![ParElement::Var(val_str.to_string())])
    }
}

/// `parse_parameter(line, vars)`
pub fn parse_parameter(
    line: &str,
    vars: &std::collections::HashMap<String, Variable>,
) -> Option<Parameter> {
    let type_separator_idx = line.find(':')?;
    let value_separator_idx = line.find('=')?;

    let par_type = parse_type(&line[..type_separator_idx])?;

    let start_idx = type_separator_idx + 1;
    let mut end_pos = value_separator_idx;
    if let Some(cc) = line[start_idx..].find("::").map(|i| i + start_idx) {
        if cc < end_pos {
            end_pos = cc;
        }
    }
    let name = line[start_idx..end_pos.max(start_idx)].trim();
    if name.is_empty() {
        return None;
    }

    let value = parse_par_value(&line[value_separator_idx + 1..], &par_type, vars);
    Some(Parameter {
        name: name.to_string(),
        par_type,
        value,
    })
}

/// `is_parameter`: quick check whether a line is a parameter declaration.
#[allow(dead_code)]
pub fn is_parameter(line: &str) -> bool {
    if !line.contains(':') {
        return false;
    }
    if !line.contains('=') {
        return false;
    }
    let type_separator = line.find(':').unwrap();
    let type_part = &line[..type_separator];
    if type_part.starts_with("var") {
        return false;
    }
    for t in ALL_TYPES {
        if line.starts_with(t) {
            return true;
        }
    }
    type_part.contains("..")
}

