//! Julia-compatible `Dict` for u64 keys.
//!
//! We replicate Julia's open-addressing hash table (base/dict.jl) because
//! iteration order is observable in the output:
//!
//! 1. `format_colors` prints the colors dict in iteration order;
//! 2. `extract_extra_info` sums floats over `freq` (Dict{Int,Int}) and
//!    `pairs` in iteration order — float addition is non-associative, so a
//!    different order can change the last bits of `v_ent_deg_vars` etc.
//!
//! The implementation mirrors Julia: power-of-two table, linear probing,
//! `hashindex = ((h % Int) & (sz-1)) + 1` (truncating the hash to Int64),
//! insertion-appended slots iterated in slot order, rehash on >2/3 load
//! (count*4 or count*2 if >64000; table sizes via `_tablesz`).

/// Julia `_tablesz(x)` = x < 16 ? 16 : next_pow2(x).
fn tablesz(x: usize) -> usize {
    if x < 16 {
        16
    } else {
        x.next_power_of_two()
    }
}

#[inline]
fn hashindex(h: u64, sz: usize) -> usize {
    // ((h % Int) & (sz-1)) + 1  — h as i64, then as usize
    ((h as i64 as usize) & (sz - 1)) + 1
}

/// Julia `Dict{K,V}` clone for our use cases: K = u64 (or (u64,u64) pairs
/// pre-hashed), V generic. We keep slots 1-based like Julia (index 0 unused).
#[derive(Debug, Clone)]
pub struct JuliaDict<V> {
    /// slot state: 0 = empty, 0x7f = deleted, else shorthash (7 high bits | 0x80)
    slots: Vec<u8>,
    keys: Vec<Option<u64>>,
    vals: Vec<Option<V>>,
    ndel: usize,
    count: usize,
    idxfloor: usize,
    maxprobe: usize,
    /// When true, keys are pre-hashed values used as-is (Julia dicts whose
    /// keys are tuples: hash((a,b)) computed by the caller). When false,
    /// keys are u64s hashed via hash_64_64 (Julia Dict{UInt64,...}).
    raw_keys: bool,
}

impl<V> Default for JuliaDict<V> {
    fn default() -> Self {
        JuliaDict {
            slots: Vec::new(),
            keys: Vec::new(),
            vals: Vec::new(),
            ndel: 0,
            count: 0,
            idxfloor: 1,
            maxprobe: 0,
            raw_keys: false,
        }
    }
}

const MAXALLOWEDPROBE: usize = 16;
const MAXPROBESHIFT: usize = 6;

impl<V> JuliaDict<V> {
    pub fn new() -> Self {
        Self::default()
    }

    /// A dict whose keys are pre-computed hashes (Julia tuple-keyed dicts).
    pub fn new_raw_keys() -> Self {
        JuliaDict {
            raw_keys: true,
            ..Self::default()
        }
    }

    pub fn len(&self) -> usize {
        self.count
    }

    #[allow(dead_code)]
    pub fn is_empty(&self) -> bool {
        self.count == 0
    }

    #[inline]
    fn shorthash7(h: u64) -> u8 {
        ((h >> (64 - 7)) as u8) | 0x80
    }

    /// Julia `rehash!`
    fn rehash(&mut self, newsz: usize) {
        let newsz = tablesz(newsz.max(self.count));
        if self.count == 0 {
            self.slots = vec![0u8; newsz];
            self.keys = (0..newsz).map(|_| None).collect();
            self.vals = (0..newsz).map(|_| None).collect();
            self.ndel = 0;
            self.maxprobe = 0;
            self.idxfloor = 1;
            return;
        }

        let old_slots = std::mem::replace(&mut self.slots, vec![0u8; newsz]);
        let old_keys = std::mem::replace(&mut self.keys, (0..newsz).map(|_| None).collect());
        let mut old_vals = std::mem::replace(&mut self.vals, (0..newsz).map(|_| None).collect());
        let sz = old_slots.len();

        // Julia iterates i = 1:sz and skips empty slots
        let mut maxprobe = 0usize;
        for i in 0..sz {
            if (old_slots[i] & 0x80) != 0 {
                let k = old_keys[i].unwrap();
                let v = old_vals[i].take().unwrap();
                let h = self.key_hash(k);
                let mut index = hashindex(h, newsz);
                let index0 = index;
                while self.slots[index - 1] != 0 {
                    // Julia 1-based wrap: index = (index & (sz-1)) + 1
                    index = (index & (newsz - 1)) + 1;
                }
                let probe = (index.wrapping_sub(index0)) & (newsz - 1);
                if probe > maxprobe {
                    maxprobe = probe;
                }
                self.slots[index - 1] = old_slots[i];
                self.keys[index - 1] = Some(k);
                self.vals[index - 1] = Some(v);
            }
        }
        self.ndel = 0;
        self.maxprobe = maxprobe;
        self.idxfloor = 1;
    }

    /// Julia hash of the key. For u64 keys: `hash_64_64(x)` (seed 0).
    /// For raw-key dicts (tuple-keyed), the stored value IS the hash.
    #[inline]
    fn key_hash(&self, k: u64) -> u64 {
        if self.raw_keys {
            k
        } else {
            flatzinc_to_graph::julia_hash::hash_64_64(k)
        }
    }

    /// sizehint!-equivalent used on deserialize: `_tablesz(cld(3n, 2))`.
    pub fn sizehint(&mut self, newsz: usize) {
        let oldsz = self.slots.len();
        // Julia: _tablesz(cld(3 * newsz, 2)) = ceil(3n/2)
        let newsz = tablesz((3 * newsz + 1) / 2);
        if newsz > oldsz {
            self.rehash(newsz);
        }
    }

    /// Julia `setindex!` / `get!` semantics with default value.
    pub fn get_or_insert_with<F: FnOnce() -> V>(&mut self, key: u64, default: F) -> &mut V {
        let index = self.ht_keyindex2(key);
        if index > 0 {
            return self.vals[(index - 1) as usize].as_mut().unwrap();
        }
        let sh = Self::shorthash7(self.key_hash(key));
        let v = default();
        // setindex may rehash (invalidating indices), so re-locate afterwards.
        self.insert_with_sh(key, v, sh);
        let index = self.ht_keyindex(key);
        debug_assert!(index > 0);
        self.vals[(index - 1) as usize].as_mut().unwrap()
    }

    /// Julia `_setindex!` core.
    fn insert_with_sh(&mut self, key: u64, value: V, sh: u8) {
        let index = self.ht_keyindex2(key);
        debug_assert!(index <= 0);
        let index = (-index) as usize;
        self.setindex(key, value, index, sh);
    }

    pub fn get(&self, key: u64) -> Option<&V> {
        let index = self.ht_keyindex(key);
        if index > 0 {
            self.vals[(index - 1) as usize].as_ref()
        } else {
            None
        }
    }

    pub fn contains_key(&self, key: u64) -> bool {
        self.ht_keyindex(key) > 0
    }

    /// Julia `get(h, key, default)`
    pub fn get_or(&self, key: u64, default: V) -> V
    where
        V: Clone,
    {
        match self.get(key) {
            Some(v) => v.clone(),
            None => default,
        }
    }

    pub fn insert(&mut self, key: u64, value: V) {
        let index = self.ht_keyindex2(key);
        if index > 0 {
            self.vals[(index - 1) as usize] = Some(value);
            return;
        }
        let index = (-index) as usize;
        let sh = Self::shorthash7(self.key_hash(key));
        self.setindex(key, value, index, sh);
    }

    /// Julia `_setindex!`
    fn setindex(&mut self, key: u64, value: V, index: usize, sh: u8) {
        if self.slots[index - 1] == 0x7f {
            self.ndel -= 1;
        }
        self.slots[index - 1] = sh;
        self.keys[index - 1] = Some(key);
        self.vals[index - 1] = Some(value);
        self.count += 1;
        if index < self.idxfloor {
            self.idxfloor = index;
        }
        let sz = self.slots.len();
        if (self.count + self.ndel) * 3 > sz * 2 {
            let newsz = if self.count > 64000 {
                self.count * 2
            } else {
                (self.count * 4).max(4)
            };
            self.rehash(newsz);
        }
    }

    /// Julia `ht_keyindex` (lookup only).
    fn ht_keyindex(&self, key: u64) -> isize {
        if self.count == 0 {
            return -1;
        }
        let sz = self.slots.len();
        if self.maxprobe >= sz {
            return -1;
        }
        let h = self.key_hash(key);
        let mut index = hashindex(h, sz);
        let sh = Self::shorthash7(h);
        let mut iter = 0usize;
        loop {
            let slot = self.slots[index - 1];
            if slot == 0 {
                return -1;
            }
            if slot == sh && self.keys[index - 1] == Some(key) {
                return index as isize;
            }
            index = (index & (sz - 1)) + 1;
            iter += 1;
            if iter > self.maxprobe {
                return -1;
            }
        }
    }

    /// Julia `ht_keyindex2_shorthash!` — returns index (>0) or -index of the
    /// insertion slot (<0).
    fn ht_keyindex2(&mut self, key: u64) -> isize {
        let sz = self.slots.len();
        if sz == 0 {
            // Julia: rehash!(h, 4) -> tablesz(4) = 16 slots
            self.rehash(4);
            let h = self.key_hash(key);
            return -(hashindex(h, self.slots.len()) as isize);
        }
        let h = self.key_hash(key);
        let sh = Self::shorthash7(h);
        let mut index = hashindex(h, sz);
        let mut avail: isize = 0;
        let mut iter = 0usize;
        let maxprobe = self.maxprobe;
        loop {
            let slot = self.slots[index - 1];
            if slot == 0 {
                return if avail < 0 { avail } else { -(index as isize) };
            }
            if slot == 0x7f {
                if avail == 0 {
                    avail = -(index as isize);
                }
            } else if slot == sh && self.keys[index - 1] == Some(key) {
                return index as isize;
            }
            index = (index & (sz - 1)) + 1;
            iter += 1;
            if iter > maxprobe {
                break;
            }
        }

        if avail < 0 {
            return avail;
        }

        let maxallowed = MAXALLOWEDPROBE.max(sz >> MAXPROBESHIFT);
        while iter < maxallowed {
            let slot = self.slots[index - 1];
            if slot == 0 || slot == 0x7f {
                self.maxprobe = iter;
                return -(index as isize);
            }
            index = (index & (sz - 1)) + 1;
            iter += 1;
        }

        let newsz = if self.count > 64000 {
            sz * 2
        } else {
            sz * 4
        };
        self.rehash(newsz);
        self.ht_keyindex2(key)
    }

    /// Iterate in Julia slot order: (key, value) pairs from idxfloor,
    /// skipping empty/deleted slots.
    pub fn iter(&self) -> impl Iterator<Item = (u64, &V)> {
        self.slots
            .iter()
            .enumerate()
            .skip(self.idxfloor.saturating_sub(1))
            .filter(|(_, s)| ((**s & 0x80) != 0) && (**s != 0x7f))
            .filter_map(|(i, _)| {
                let k = self.keys[i]?;
                let v = self.vals[i].as_ref()?;
                Some((k, v))
            })
    }

    #[allow(dead_code)]
    pub fn values(&self) -> impl Iterator<Item = &V> {
        self.iter().map(|(_, v)| v)
    }

    #[allow(dead_code)]
    pub fn keys_iter(&self) -> Vec<u64> {
        self.iter().map(|(k, _)| k).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_julia_probe_order() {
        // Ground truth from Julia 1.12.6:
        // d = Dict{UInt64,UInt64}(); keys inserted [12345, 999, 42, 7, 100000, 2^62+1, 5]
        // iteration order: [5, 12345, 7, 100000, 2^62+1, 42, 999]
        let mut d = JuliaDict::new();
        for k in [12345u64, 999, 42, 7, 100000, 1 << 62 | 1, 5] {
            d.insert(k, k);
        }
        let order: Vec<u64> = d.keys_iter();
        assert_eq!(order, vec![5, 12345, 7, 100000, 1 << 62 | 1, 42, 999]);
    }

    #[test]
    fn matches_julia_growth() {
        // Full ground truth from Julia 1.12.6 (insertion i*97, i in 1..=20):
        let mut d = JuliaDict::new();
        for i in 1..=20u64 {
            d.insert(i * 97, i);
        }
        let expected: Vec<u64> = vec![679, 1843, 388, 291, 1552, 1261, 485, 776, 1067, 1746, 873, 1455, 97, 1358, 194, 970, 1940, 1164, 1649, 582];
        assert_eq!(d.keys_iter(), expected);
    }
}
