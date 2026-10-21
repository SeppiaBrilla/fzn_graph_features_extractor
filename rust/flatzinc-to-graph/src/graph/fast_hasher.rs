//! Fast `BuildHasher` for integer keys (node ids, colors).
//!
//! Rust's default `HashMap` hasher (SipHash-1-3) is designed for hash-flood
//! resistance; for our `u64` keys that is unnecessary — the keys are already
//! output of Julia's MurmurHash3 (well-mixed). Julia's own `Dict` uses a
//! trivial hash for `UInt64` keys, so using an identity-style hasher here
//! both matches Julia's performance characteristics and is safe: the inputs
//! are 128-bit-truncated cryptographic-quality hashes, not attacker data.
//!
//! The implementation follows the well-known `nohash-hasher` approach:
//! finish() runs a single avalanche mix (fxhash-style) so that
//! `hashindex = (h & (sz-1)) + 1` probes well even for structured keys.

use std::hash::{BuildHasherDefault, Hasher};

#[derive(Default)]
pub struct U64Hasher(u64);

impl Hasher for U64Hasher {
    #[inline]
    fn finish(&self) -> u64 {
        // final avalanche (murmur3 fmix64): low bits are what matters for
        // bucket masks, and structured u64s (e.g. sequential ids) need this
        let mut k = self.0;
        k ^= k >> 33;
        k = k.wrapping_mul(0xff51afd7ed558ccd);
        k ^= k >> 33;
        k = k.wrapping_mul(0xc4ceb9fe1a85ec53);
        k ^= k >> 33;
        k
    }

    #[inline]
    fn write(&mut self, _bytes: &[u8]) {
        unreachable!("only integer/tuple keys are used with U64Hasher");
    }

    #[inline]
    fn write_u16(&mut self, v: u16) {
        // combine into the state like a FNV step so (a, b) tuples mix
        self.0 = (self.0 << 16) | v as u64;
    }

    #[inline]
    fn write_u8(&mut self, v: u8) {
        self.0 = (self.0 << 8) | v as u64;
    }

    #[inline]
    fn write_u64(&mut self, v: u64) {
        self.0 = v;
    }

    #[inline]
    fn write_usize(&mut self, v: usize) {
        self.0 = v as u64;
    }
}

/// `BuildHasherDefault<U64Hasher>` alias.
pub type U64Build = BuildHasherDefault<U64Hasher>;

/// Convenience alias for a `HashMap` with the fast hasher.
pub type FastHashMap<K, V> = std::collections::HashMap<K, V, U64Build>;
pub type FastHashSet<K> = std::collections::HashSet<K, U64Build>;
