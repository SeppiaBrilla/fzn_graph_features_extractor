//! Reader for Julia `Serialization`-format colors.bin files (`Dict{UInt64,UInt64}`).
//!
//! Supports reading files written by the Julia implementation so existing
//! training data can be migrated. Rust writes its own simple format (see
//! `save_colors`), but both can be read.
//!
//! Julia serialization layout for `Dict{UInt64,UInt64}` (ser_version 30):
//! ```text
//! <HEADER_TAG:1> "JL" <ver:1> <flags:1> <reserved:3>          (8 bytes)
//! 0x35 0x10 0x01 0x04 "Dict" <uid:16> 0x02 <0 0 0> 0x00      (type blob)
//! 0x09 0x00 0x09                                              (params: UInt64, UInt64)
//! <count:Int32 LE>
//! repeated: 0x09 <key:8 LE> 0x09 <value:8 LE>
//! ```
//! (small ints < 33 would use tag-shorthand bytes, but color hashes are large
//! so the 0x09-tagged form is what occurs in practice; we handle both).

use crate::julia_dict::JuliaDict;

pub fn load_julia_colors(file_path: &str) -> std::io::Result<JuliaDict<u64>> {
    let mut d = JuliaDict::new();
    let Ok(bytes) = std::fs::read(file_path) else {
        return Ok(d);
    };
    parse_julia_serialized_dict(&bytes, &mut d);
    Ok(d)
}

struct Reader<'a> {
    b: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    fn u8(&mut self) -> Option<u8> {
        let v = *self.b.get(self.pos)?;
        self.pos += 1;
        Some(v)
    }
    fn take(&mut self, n: usize) -> Option<&'a [u8]> {
        if self.pos + n > self.b.len() {
            return None;
        }
        let s = &self.b[self.pos..self.pos + n];
        self.pos += n;
        Some(s)
    }
    fn i32le(&mut self) -> Option<i32> {
        Some(i32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn u64le(&mut self) -> Option<u64> {
        Some(u64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
}

fn parse_julia_serialized_dict(bytes: &[u8], d: &mut JuliaDict<u64>) {
    let mut r = Reader { b: bytes, pos: 0 };

    // header: 8 bytes (37 4a 4c 1e 04 00 00 00)
    if r.take(8).is_none() {
        return;
    }
    if !bytes.starts_with(&[0x37, b'J', b'L', 0x1e]) {
        return; // not a Julia serialization stream
    }

    // type blob + params (20 bytes):
    //   35 REF_OBJECT, 10 OBJECT_TAG, 01, 04 "Dict" (4 chars),
    //   1f4e9e44 object uuid, 02 nparams, 00 00 00 00, 09 00 09 (UInt64,UInt64)
    if r.take(20).is_none() {
        return;
    }

    let Some(count) = r.i32le() else {
        return;
    };
    if count < 0 {
        return;
    }
    // sanity: each pair is at least 2 bytes; guard against corrupt files
    let max_pairs = bytes.len().saturating_sub(r.pos) / 2;
    let count = (count as usize).min(max_pairs) as i32;
    d.sizehint(count as usize);
    for _ in 0..count {
        // each key/value: 0x09 tag + 8-byte LE u64 (large hashes always use
        // the tagged form; small ints < 33 use single-byte shorthand)
        let (Some(k), Some(v)) = (read_julia_uint64(&mut r), read_julia_uint64(&mut r)) else {
            break;
        };
        d.insert(k, v);
    }
}

/// Read a Julia-serialized UInt64: `09` + 8 LE bytes, or the tag shorthand
/// ZERO64_TAG + n (value n, 0..=32).
fn read_julia_uint64(r: &mut Reader) -> Option<u64> {
    let tag = r.u8()?;
    // ZERO64_TAG = NTAGS - (n_int_literals - 1) = 255 - 32 = 223 (0xdf)
    if tag == 0x09 {
        r.u64le()
    } else if tag >= 0xdf {
        Some((tag - 0xdf) as u64)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_julia_colors_file() {
        // Written by Julia 1.12.6 with 7 color pairs (simple_bool_sat, wl-nc k1)
        let path = "/tmp/opencode/difftest/simple_bool_sat_wl-nc_k1_train.colors";
        if !std::path::Path::new(path).exists() {
            return; // reference data not present (e.g. CI)
        }
        let d = load_julia_colors(path).unwrap();
        assert_eq!(d.len(), 7);
        // keys and values are identical in colors dicts
        let mut seen = Vec::new();
        for (k, v) in d.iter() {
            assert_eq!(k, *v);
            seen.push(k);
        }
        assert_eq!(seen.len(), 7);
    }
}
