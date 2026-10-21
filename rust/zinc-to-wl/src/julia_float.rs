//! Julia-compatible float formatting (`string(x::Float64)`), a port of
//! `Base.Ryu.writeshortest` for Float64 with default options
//! (plus=false, space=false, hash=true, precision=-1, expchar='e',
//! padexp=false, typed=false, compact=false).
//!
//! This is only needed so the JSON feature values print identically to the
//! Julia implementation (e.g. `1.0e-5` vs Rust's `0.00001`), which makes the
//! differential test suite compare outputs byte-for-byte.
//!
//! Algorithm: get the shortest round-tripping decimal via Rust's `format!("{}", x)`
//! (both Rust and Julia use Ryu's shortest representation, which is unique),
//! then re-format the digits under Julia's placement rules.

/// Format a finite f64 the way Julia's `string()` does.
pub fn julia_fmt_f64(x: f64) -> String {
    if x.is_nan() {
        return "NaN".to_string();
    }
    if x.is_infinite() {
        return if x > 0.0 { "Inf".to_string() } else { "-Inf".to_string() };
    }

    // Shortest round-trip digits from Rust (Ryu shortest; same digits Julia's
    // reduce_shortest would produce).
    let rust = format!("{:e}", x); // e.g. "1.23456e2", "-4.5e-7", "5e0"
    let (mantissa, exp10_str) = rust.split_once('e').unwrap();
    let exp10: i32 = exp10_str.parse().unwrap();
    let neg = mantissa.starts_with('-');
    let mantissa = mantissa.trim_start_matches('-');

    // digits and decimal point position: "d.ddd" -> digits "dddd", or "d" -> "d"
    let (int_part, frac_part) = match mantissa.split_once('.') {
        Some((i, f)) => (i, f),
        None => (mantissa, ""),
    };
    let mut digits = String::with_capacity(int_part.len() + frac_part.len());
    digits.push_str(int_part);
    digits.push_str(frac_part);
    // strip trailing zeros (Ryu never emits them, but be safe)
    while digits.len() > 1 && digits.ends_with('0') {
        digits.pop();
    }
    let olength = digits.len() as i32;
    let nexp = exp10 + 1 - olength; // value = 0.digits * 10^(nexp+olength)

    let mut out = String::new();
    if neg {
        out.push('-');
    }

    // Julia: exp_form = false iff -4 < pt <= 6 && !(pt >= olength && abs(mod(x+0.05, 10^(pt-olength)) - 0.05) > 0.05)
    let pt = nexp + olength;
    let exp_form = !(-4 < pt && pt <= 6 && !(pt >= olength && julia_mod_check(x, pt - olength)));

    if !exp_form {
        if pt <= 0 {
            out.push('0');
            out.push('.');
            for _ in 0..(-pt) {
                out.push('0');
            }
            out.push_str(&digits);
        } else if pt >= olength {
            out.push_str(&digits);
            for _ in 0..nexp {
                out.push('0');
            }
            out.push('.'); // hash=true always writes the point
            out.push('0');
        } else {
            let pointoff = olength - nexp.abs();
            out.push_str(&digits[..pointoff as usize]);
            out.push('.');
            out.push_str(&digits[pointoff as usize..]);
        }
        return out;
    }

    // exponent form: d.ddd e±XX
    out.push_str(&digits[..1]);
    if olength > 1 {
        out.push('.');
        out.push_str(&digits[1..]);
    } else if true {
        // hash=true: single digit still gets ".0"
        out.push_str(".0");
    }
    out.push('e');
    let exp2 = nexp + olength - 1;
    if exp2 < 0 {
        out.push('-');
    }
    let exp_abs = exp2.unsigned_abs();
    // Julia with padexp=false: 2 digits if >= 10, else 1 digit (no zero pad)
    out.push_str(&exp_abs.to_string());
    out
}

/// Julia's `mod(x, y)`: result has the sign of y (always in [0, |y|) for y>0),
/// unlike Rust's `%` which truncates toward zero.
#[inline]
fn julia_mod_check(x: f64, k: i32) -> bool {
    let m = 10f64.powi(k);
    // Julia: mod(x + 0.05, m)
    let v = {
        let a = x + 0.05;
        let r = a % m;
        if r < 0.0 { r + m.abs() } else { r }
    };
    (v - 0.05).abs() > 0.05
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Ground truths collected from Julia 1.12.6 `string(x)`.
    #[test]
    fn matches_julia_corpus() {
        let cases: &[(f64, &str)] = &[
            (0.0, "0.0"),
            (1.0, "1.0"),
            (-1.0, "-1.0"),
            (0.5, "0.5"),
            (2.0 / 3.0, "0.6666666666666666"),
            (1.0 / 3.0, "0.3333333333333333"),
            (10.0 / 3.0, "3.3333333333333335"),
            (5.0 / 7.0, "0.7142857142857143"),
            (13.0 / 17.0, "0.7647058823529411"),
            (1e-5, "1.0e-5"),
            (1e-6, "1.0e-6"),
            (1e-7, "1.0e-7"),
            (123456.0, "123456.0"),
            (1234567.0, "1.234567e6"),
            (999999.0, "999999.0"),
            (100000.0, "100000.0"),
            (1000000.0, "1.0e6"),
            (0.1 + 0.2, "0.30000000000000004"),
            (1.5, "1.5"),
            (2.25, "2.25"),
            (12.0 / 7.0, "1.7142857142857142"),
            (42.0, "42.0"),
            (0.049999999999999996, "0.049999999999999996"),
            (123456.0 / 7.0, "17636.571428571428"),
            (1e15, "1.0e15"),
            (1e16, "1.0e16"),
            (9.007199254740992e15, "9.007199254740992e15"),
            (0.6931471805599453, "0.6931471805599453"),
            (1.4426950408889634, "1.4426950408889634"),
            (2.095903274289385, "2.095903274289385"),
            (6.02e23, "6.02e23"),
            (1e-300, "1.0e-300"),
            (-1.5, "-1.5"),
            (0.1, "0.1"),
            (0.001, "0.001"),
            (0.0001, "0.0001"),
            (120000.0, "120000.0"),
            (1234.0, "1234.0"),
            (123.0, "123.0"),
            (12.0, "12.0"),
            (1.2, "1.2"),
            (0.12, "0.12"),
            (870000.0, "870000.0"),
        ];
        for (v, expected) in cases {
            let got = julia_fmt_f64(*v);
            assert_eq!(&got, expected, "value {:e}", v);
        }
    }
}
