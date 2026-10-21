//! Julia-compatible hashing, exactly replicating Julia 1.12's `hash`:
//!
//! - `hash_string(s, h)` — `MurmurHash3_x64_128` (high half), matching
//!   `Base.hash(s::String, h::UInt)` = `memhash(s, UInt32(h + memhash_seed)) + h`.
//! - `hash_symbol` — the `objectid` of a Symbol:
//!   `int64hash(-((memhash(s) ^ ~(uintptr_t)0/3*2)))`.
//! - `hash_uint64(x, h)` — `hash_64_64(x) - 3h` (the "3h" mixing).
//!
//! Node ids and WL colors in the Rust port use these exact functions so the
//! graph structure (dedup on `hash(label)`) matches the Julia implementation
//! even under adversarial label collisions, and so differential tests against
//! the Julia binaries can compare color counts directly.
//!
//! The colors.bin format itself is Rust-specific (see `zinc-to-wl/src/colors.rs`).

// ---------------------------------------------------------------------------
// MurmurHash3 x64 128 (from Julia src/support/MurmurHash3.c)
// ---------------------------------------------------------------------------

#[inline(always)]
fn rotl64(x: u64, r: i8) -> u64 {
    (x << r) | (x >> (64 - r))
}

#[inline(always)]
fn fmix64(mut k: u64) -> u64 {
    k ^= k >> 33;
    k = k.wrapping_mul(0xff51afd7ed558ccd);
    k ^= k >> 33;
    k = k.wrapping_mul(0xc4ceb9fe1a85ec53);
    k ^= k >> 33;
    k
}

/// MurmurHash3_x64_128, returning (h1, h2).
pub fn murmur3_x64_128(data: &[u8], seed: u32) -> (u64, u64) {
    let nblocks = data.len() / 16;
    let mut h1: u64 = seed as u64;
    let mut h2: u64 = seed as u64;

    const C1: u64 = 0x87c37b91114253d5;
    const C2: u64 = 0x4cf5ad432745937f;

    let mut i = 0usize;
    for _ in 0..nblocks {
        let mut k1 = u64::from_le_bytes(data[i..i + 8].try_into().unwrap());
        let mut k2 = u64::from_le_bytes(data[i + 8..i + 16].try_into().unwrap());
        i += 16;

        k1 = k1.wrapping_mul(C1);
        k1 = rotl64(k1, 31);
        k1 = k1.wrapping_mul(C2);
        h1 ^= k1;

        h1 = rotl64(h1, 27);
        h1 = h1.wrapping_add(h2);
        h1 = h1.wrapping_mul(5).wrapping_add(0x52dce729);

        k2 = k2.wrapping_mul(C2);
        k2 = rotl64(k2, 33);
        k2 = k2.wrapping_mul(C1);
        h2 ^= k2;

        h2 = rotl64(h2, 31);
        h2 = h2.wrapping_add(h1);
        h2 = h2.wrapping_mul(5).wrapping_add(0x38495ab5);
    }

    let tail = &data[nblocks * 16..];
    let mut k1: u64 = 0;
    let mut k2: u64 = 0;

    let tl = tail.len();
    if tl >= 15 {
        k2 ^= (tail[14] as u64) << 48;
    }
    if tl >= 14 {
        k2 ^= (tail[13] as u64) << 40;
    }
    if tl >= 13 {
        k2 ^= (tail[12] as u64) << 32;
    }
    if tl >= 12 {
        k2 ^= (tail[11] as u64) << 24;
    }
    if tl >= 11 {
        k2 ^= (tail[10] as u64) << 16;
    }
    if tl >= 10 {
        k2 ^= (tail[9] as u64) << 8;
    }
    if tl >= 9 {
        k2 ^= tail[8] as u64;
        k2 = k2.wrapping_mul(C2);
        k2 = rotl64(k2, 33);
        k2 = k2.wrapping_mul(C1);
        h2 ^= k2;
    }
    if tl >= 8 {
        k1 ^= (tail[7] as u64) << 56;
    }
    if tl >= 7 {
        k1 ^= (tail[6] as u64) << 48;
    }
    if tl >= 6 {
        k1 ^= (tail[5] as u64) << 40;
    }
    if tl >= 5 {
        k1 ^= (tail[4] as u64) << 32;
    }
    if tl >= 4 {
        k1 ^= (tail[3] as u64) << 24;
    }
    if tl >= 3 {
        k1 ^= (tail[2] as u64) << 16;
    }
    if tl >= 2 {
        k1 ^= (tail[1] as u64) << 8;
    }
    if tl >= 1 {
        k1 ^= tail[0] as u64;
        k1 = k1.wrapping_mul(C1);
        k1 = rotl64(k1, 31);
        k1 = k1.wrapping_mul(C2);
        h1 ^= k1;
    }

    let len = data.len() as u64;
    h1 ^= len;
    h2 ^= len;

    h1 = h1.wrapping_add(h2);
    h2 = h2.wrapping_add(h1);

    h1 = fmix64(h1);
    h2 = fmix64(h2);

    h1 = h1.wrapping_add(h2);
    h2 = h2.wrapping_add(h1);

    (h1, h2)
}

// ---------------------------------------------------------------------------
// Julia Base integer hash mixers (base/hashing.jl)
// ---------------------------------------------------------------------------

/// `Base.hash_64_64` (a.k.a. `int64hash` / `hash_uint` on 64-bit).
#[inline(always)]
pub fn hash_64_64(mut a: u64) -> u64 {
    a = (!a).wrapping_add(a << 21);
    a ^= a >> 24;
    a = a.wrapping_add(a << 3).wrapping_add(a << 8);
    a ^= a >> 14;
    a = a.wrapping_add(a << 2).wrapping_add(a << 4);
    a ^= a >> 28;
    a = a.wrapping_add(a << 31);
    a
}

// ---------------------------------------------------------------------------
// Julia Base hash entry points
// ---------------------------------------------------------------------------

const MEMHASH_SEED: u64 = 0x71e729fd56419c81;

/// Julia `hash(s::String, h::UInt)`:
/// `h += memhash_seed; memhash(s, UInt32(h)) + h`
#[inline]
pub fn hash_string(s: &str, h: u64) -> u64 {
    let h = h.wrapping_add(MEMHASH_SEED);
    let (_, hi) = murmur3_x64_128(s.as_bytes(), h as u32);
    hi.wrapping_add(h)
}

/// Julia `objectid(sym::Symbol)`:
/// `inthash(-oid)` where `oid = memhash(str) ^ ~(uintptr_t)0/3*2`.
///
/// `memhash` = MurmurHash3_x64_128 with `_MHASH_SEED_ = 0xcafe8881`, high half.
#[inline]
pub fn objectid_symbol(s: &str) -> u64 {
    let (lo, hi) = murmur3_x64_128(s.as_bytes(), 0xcafe8881);
    let _ = lo;
    let oid = hi ^ ((!(0u64)) / 3 * 2);
    hash_64_64(oid.wrapping_neg())
}

/// Julia `hash(x::UInt64, h::UInt) = hash_uint64(x) - 3h`.
#[inline]
pub fn hash_uint64(x: u64, h: u64) -> u64 {
    hash_64_64(x).wrapping_sub(3u64.wrapping_mul(h))
}

/// Julia `hash(x::Symbol, h::UInt) = hash_uint(3h - objectid(x))`
/// (generic object hash, NOT the UInt64 path).
#[inline]
pub fn hash_symbol_seeded(s: &str, h: u64) -> u64 {
    hash_64_64(3u64.wrapping_mul(h).wrapping_sub(objectid_symbol(s)))
}

/// Julia `hash((a, b), h) = hash(a, hash((b,), h))` for Symbol elements:
/// `hash(b, hash((), h))` then `hash(a, ...)` — symbols hash via objectid.
/// With seed 0 this equals `hash((:a, :b))`.
#[inline]
pub fn hash_tuple2_symbols(a: &str, b: &str, h: u64) -> u64 {
    let hb = hash_symbol_seeded(b, h.wrapping_add(TUPLEHASH_SEED));
    hash_symbol_seeded(a, hb)
}

/// Julia `hash(x::Int64, h) = hash_uint64(bitcast(UInt64, x)) - 3h`.
#[inline]
pub fn hash_int64(x: i64, h: u64) -> u64 {
    hash_uint64(x as u64, h)
}

/// Hash a symbol-like interned string with the default seed (matches `hash(:sym)`).
#[inline]
pub fn hash_symbol(s: &str) -> u64 {
    objectid_symbol(s)
}

/// Julia `hash(t::Tuple{}, h) = h + tuplehash_seed`.
const TUPLEHASH_SEED: u64 = 0x77cfa1eef01bca90;

#[inline]
pub fn hash_tuple2_symbols0(a: &str, b: &str) -> u64 {
    hash_tuple2_symbols(a, b, 0)
}


// ---------------------------------------------------------------------------
// convenience wrappers
// ---------------------------------------------------------------------------

/// Hash a string with seed 0 (Julia `hash(s)`).
#[inline]
pub fn jl_hash_str(s: &str) -> u64 {
    hash_string(s, 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn julia_ground_truth() {
        // From Julia 1.12.6: hash("x1"), etc.
        assert_eq!(hash_string("x1", 0), 18339862948315581042);
        assert_eq!(hash_string("abc", 0), 8543511489601552240);
        assert_eq!(hash_string("", 0), 13633231208144796923);
        assert_eq!(hash_string("a", 0), 18024302447460810957);
        assert_eq!(hash_string("abcdefghijklmnop", 0), 3257230385288674194);
        assert_eq!(hash_string("12345678901234567890", 0), 16502722464095290489);
        assert_eq!(hash_string("abc", 123), 308244454369013382);
        // symbols
        assert_eq!(hash_symbol("var_node"), 9147556824139758745);
        assert_eq!(hash_symbol("a"), 7711146526977742512);
        assert_eq!(hash_symbol("abc"), 16076289990349425027);
        // uint64 with seed
        assert_eq!(hash_uint64(1, 0), 6614235796240398542);
        assert_eq!(hash_uint64(0, 0), 8633297058295171728);
        assert_eq!(hash_uint64(42, 0), 1098236396662648698);
        assert_eq!(hash_uint64(12345, 0), 7658450573117590115);
        assert_eq!(hash_uint64(123456789, 0), 16581954974024456952);
        assert_eq!(hash_uint64(123, 456), 2085723870385663402);
        // tuples
        assert_eq!(
            hash_tuple2_symbols("literal_node", "all_different_node", 0),
            1450088642104188365
        );
        assert_eq!(hash_tuple2_symbols("var_node", "leq_node", 0), 17037048527188603474);
    }
}
