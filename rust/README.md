# FlatZinc Graph & Weisfeiler-Lehman Feature Extractor (Rust)

Rust port of the Julia `flatzinc_to_graph` project: converts Constraint
Satisfaction and Optimization Problems (FlatZinc `.fzn`, Pseudo-Boolean
`.opb`/`.wbo`, incl. xz-compressed) into attributed directed graphs and
computes Weisfeiler-Lehman graph-kernel features plus fzn2feat-style
structural statistics, output as JSON.

The port is **output-compatible** with the Julia implementation: given the
same input and colors file, it produces byte-identical JSON (color histogram,
feature values, key ordering). This was validated differentially against the
Julia implementation on 49 models × 6 WL methods × 2 iteration counts
(576 feature extractions).

## Workspace layout

```text
flatzinc-to-graph/   # FlatZinc parser → attributed directed graph (lib + bin)
pb-to-graph/         # Pseudo-Boolean parser → same graph type (lib + bin)
zinc-to-wl/          # WL feature extraction pipeline (bin)
```

Mirrors the Julia packages:
- `flatzinc-to-graph` — port of `FlatzincToGraph`: variable/parameter/solve
  parsing, ~104 constraint decompositions (int/bool/set/global), `.graph`
  serialization, parallel constraint parsing via rayon.
- `pb-to-graph` — port of `PbToGraph`: PB terms/constraints/objective → graph.
- `zinc-to-wl` — port of `ZincToWl`: graph loading, all 18 WL variants
  (`wl`, `wl-n`, `wl-e`, `wl-ne`, `wl-nc`, `wl-nec` + undirected/all-levels
  testing variants), fzn2feat features, colors persistence, JSON output.

## Building

```bash
cargo build --release
```

## Usage

### ZincToWl (main feature extractor)

```bash
./target/release/zinc-to-wl model.fzn -m wl-nc -k 1 -c 4
```

| Argument          | Short | Type   | Default      | Description                                        |
| :---------------- | :---- | :----- | :----------- | :------------------------------------------------- |
| `input_file`      |       | path   | *(required)* | `.fzn`, `.opb`, `.wbo`, `.xz`, or `.graph` file    |
| `--method`        | `-m`  | string | `wl-nc`      | WL method (below)                                 |
| `--wl-iterations` | `-k`  | int    | `1`          | Number of WL iterations                            |
| `--num-cores`     | `-c`  | int    | `1`          | Worker threads                                     |
| `--colors`        |       | path   | `colors.bin` | Persistent color dictionary                        |
| `--training`      | `-t`  | flag   | off          | Register unseen colors into the colors file        |
| `--check-colors`  |       | path   |              | Print all known colors (comma-separated) and exit  |

Recommended configuration (as in the Julia version):

```bash
--method wl-nc --wl-iterations 1
```

### FlatzincToGraph (standalone converter)

```bash
./target/release/flatzinc-to-graph input.fzn output.graph [num_cores]
```

### PbToGraph (standalone converter)

```bash
./target/release/pb-to-graph input.opb output.graph [num_cores]
```

## Colors files

Training mode (`-t`) extends the persistent color dictionary; inference
mode maps unseen color hashes back to a per-method fallback, exactly like
the Julia implementation. Two on-disk formats are supported for reading:

- **Rust format** (written by this implementation): `u64 LE count` followed
  by `count` × (`u64 key`, `u64 value`) pairs.
- **Legacy Julia format** (written by the Julia implementation via
  `Serialization.serialize` of `Dict{UInt64,UInt64}`): read for migration,
  so existing `colors.bin` files keep working.

## Output

A single JSON object: the WL color histogram (every known color with its
occurrence count, 0 for unseen ones), then structural features:
`n_nodes`, `cpv`, `cpp`, `d_ratio_int_vars`, `d_ratio_bool_vars`,
`o_deg_cons`, `o_deg_std`, `o_dom_deg`, `v_ent_deg_vars`,
`v_sum_domdeg_vars`, and — for `wl-nc`/`wl-nec` — co-occurrence counts
`"(<source_type>, <target_type>)"` for cut/global constraint nodes.

## Differences from the Julia implementation

- **No server mode.** The Julia version needed a persistent UNIX-socket
  server to amortize Julia's startup/JIT cost; a native binary has no such
  penalty, so `zinc-to-wl` is CLI-only.
- **Deterministic parallel training.** Julia's parallel WL inserts new colors
  under a lock in scheduler-dependent order; this port computes candidate
  hashes in parallel and registers colors in deterministic node order.
  Node colors and counts are identical; only the colors-dict iteration order
  of a *concurrently-trained* dictionary can differ from Julia's racing one.
- **Colors file format** is Rust-native (see above); Julia-format files are
  readable for migration.

## Performance

On the MiniZinc Challenge corpus (160 `.fzn` files, `wl-nc k=1`, one process
per file), the Rust binary is the fastest of the three execution modes of
the Julia implementation:

| mode                          | median/file | total (160 files) |
| :--                           | --:         | --:               |
| **rust (this port)**          | **~12 ms**  | **~35 s**         |
| julia `--server` (warm)       | ~9–11 ms    | ~64 s             |
| julia compiled binary         | ~330 ms     | ~127 s            |
| julia script (JIT, per file) | ~11 s       | ~30 min           |

The per-file medians are close because a per-process invocation pays ~1 ms
of process spawn that the warm server avoids; on total time — and on every
file larger than a few KB — the Rust binary is decisively ahead (1.7× vs the
warm server, 3.5× vs the compiled binary, ~40× vs the script).

## Testing

```bash
cargo test        # unit tests: Julia-hash ground truths, Dict order, float fmt
```
