//! Parsing/type utilities, port of `parse/helper.jl`.

/// `Helper.is_bounded_number_set`: size of the domain if the type string is a
/// bounded int range `lb..ub` or an explicit set `{a, b, ...}`, else `None`.
pub fn is_bounded_number_set(type_str: &str) -> Option<i64> {
    if type_str.starts_with("set of") {
        return None;
    }
    if let Some(idx) = type_str.find("..") {
        let lb: i64 = type_str[..idx].parse().ok()?;
        let ub: i64 = type_str[idx + 2..].parse().ok()?;
        return Some(ub - lb + 1);
    }
    if type_str.starts_with('{') && type_str.ends_with('}') {
        // count commas + 1 (matches Julia, even for malformed sets like "{}" -> 1)
        let commas = type_str.bytes().filter(|&c| c == b',').count();
        return Some(commas as i64 + 1);
    }
    None
}

/// `Helper.is_set`
pub fn is_set(value: &str) -> bool {
    if value.is_empty() {
        return false;
    }
    if value.starts_with('{') && value.ends_with('}') {
        return true;
    }
    if let Some(idx) = value.find("..") {
        let lb_ok: Result<i64, _> = value[..idx].parse();
        let ub_ok: Result<i64, _> = value[idx + 2..].parse();
        return lb_ok.is_ok() && ub_ok.is_ok();
    }
    false
}

/// `Helper.is_literal`: true/false, or does not start with a letter/underscore.
pub fn is_literal(value: &str) -> bool {
    if value == "true" || value == "false" {
        return true;
    }
    match value.chars().next() {
        Some(c) => !(c.is_ascii_lowercase() || c.is_ascii_uppercase() || c == '_'),
        None => true,
    }
}

/// `Helper.get_type`: classify a value string into a type name.
///
/// Note the Julia quirk: any string that parses as Float32 is "float" —
/// including plain integers like "5" (`tryparse(Float32, "5")` succeeds).
/// Only `true`/`false` (bool) and sets avoid that.
pub fn get_type(value: &str) -> &'static str {
    if value == "true" || value == "false" {
        return "bool";
    }
    if is_set(value) {
        return "set of int";
    }
    if julia_parse_f32(value).is_some() {
        return "float";
    }
    "int"
}

/// Julia `tryparse(Float32, s)`: accepts surrounding whitespace, `+`/`-`
/// signs, hex (`0x..`), `Inf`/`NaN`, and rejects underscores and over/underflow.
/// Rust's `f32::from_str` differs (no hex, no `+`), so replicate Julia's rules.
pub fn julia_parse_f32(s: &str) -> Option<f32> {
    let t = s.trim_matches(|c| c == ' ' || c == '\t' || c == '\n' || c == '\r');
    if t.is_empty() {
        return None;
    }
    // handle sign
    let (neg, rest) = match t.as_bytes()[0] {
        b'+' => (false, &t[1..]),
        b'-' => (true, &t[1..]),
        _ => (false, t),
    };
    if rest.is_empty() {
        return None;
    }
    let lower = rest.to_ascii_lowercase();
    let val: f32 = if lower == "inf" || lower == "infinity" {
        f32::INFINITY
    } else if lower == "nan" {
        f32::NAN
    } else if lower.starts_with("0x") {
        // Julia accepts hex floats (incl. hex ints like 0x10 -> 16.0)
        parse_hex_f32(&lower)?
    } else {
        // Rust parses "5." and ".5" too; but rejects "_" and overflow -> None
        if lower.contains('_') {
            return None;
        }
        // Rust f32::from_str handles "5", "5.", ".5", "5e3" etc.
        let v: f32 = lower.parse().ok()?;
        // Julia: 1e400 (overflow) -> nothing; underflow to subnormal is fine.
        if v.is_infinite() {
            return None;
        }
        v
    };
    Some(if neg { -val } else { val })
}

fn parse_hex_f32(s: &str) -> Option<f32> {
    // minimal hex float support: 0x<hexdigits>[.][p<exp>] — flatzinc never has
    // these in practice; hex ints like 0x10 are handled.
    let body = &s[2..];
    if body.is_empty() {
        return None;
    }
    let (mant_str, exp) = match body.find('p') {
        Some(i) => {
            let e: i32 = body[i + 1..].parse().ok()?;
            (&body[..i], e)
        }
        None => (body, 0i32),
    };
    let (int_part, frac_part) = match mant_str.find('.') {
        Some(i) => (&mant_str[..i], &mant_str[i + 1..]),
        None => (mant_str, ""),
    };
    if int_part.is_empty() && frac_part.is_empty() {
        return None;
    }
    let mut v = 0f64;
    for c in int_part.chars() {
        v = v * 16.0 + c.to_digit(16)? as f64;
    }
    let mut scale = 1f64 / 16.0;
    for c in frac_part.chars() {
        v += c.to_digit(16)? as f64 * scale;
        scale /= 16.0;
    }
    Some((v * 2f64.powi(exp)) as f32)
}
