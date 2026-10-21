# FlatZinc Graph & Weisfeiler-Lehman Feature Extractor

This repository provides tools for converting Constraint Satisfaction and Optimization Problems expressed in FlatZinc (`.fzn`), Pseudo-Boolean (`.opb`, `.wbo`), and SAT (`.cnf`) formats into graph representations and computing graph-based structural features via Weisfeiler-Lehman (WL) graph kernels and domain statistics.

The repository offers two implementations:
1. **[Rust Implementation (`rust/`)](#rust-implementation-recommended)**: High-performance, output-compatible reimplementation in Rust. Significantly faster runtime and instant execution without JIT/server overhead.
2. **[Julia Implementation (`julia/`)](#julia-implementation-reference)**: The original reference implementation across packages `FlatzincToGraph`, `ZincToWl` and `PbToGraph`.

---

## Repository Structure

```text
.
├── rust/                       # High-performance Rust reimplementation (Cargo workspace)
│   ├── Cargo.toml              # Cargo workspace definition
│   ├── flatzinc-to-graph/      # FlatZinc parser & graph builder (produces FlatzincToGraph)
│   ├── pb-to-graph/            # Pseudo-Boolean parser & graph builder (produces PbToGraph)
│   ├── zinc-to-wl/             # WL feature extraction pipeline (produces ZincToWl)
│   └── README.md               # Detailed Rust documentation & benchmarks
│
├── julia/                      # Reference Julia implementation
│   ├── FlatzincToGraph/        # FlatZinc parser and graph representation engine
│   ├── ZincToWl/               # Weisfeiler-Lehman feature extraction pipeline
│   ├── PbToGraph/              # Pseudo-Boolean parser and graph engine
│   ├── SatToGraph/             # CNF SAT parser and graph engine
│   └── precompile_files/       # Sample models used for PackageCompiler builds
│
├── visualize/                  # WL color derivation tree visualization
│   ├── build_color_tree.jl     # Corpus replay → self-contained HTML builder
│   ├── template.html           # Interactive HTML/JS template
│   ├── wl-viz.sh               # Convenience wrapper
│   ├── colors_bin_tree.html    # Pre-built tree of the repo's colors.bin
│   └── README.md               # Visualization documentation
│
├── benchmark.py                # Benchmarking and comparison script
├── colors.bin                  # Pre-trained color dictionary
└── README.md                   # Project documentation
```

---

## Rust Implementation (Recommended)

The Rust implementation is located in the [`rust/`](rust/) workspace. It matches the outputs of the Julia implementation byte-for-byte while offering substantial speedups and lower memory footprint.

When built, the Rust executables have the **exact same names** as the Julia binaries: `ZincToWl`, `FlatzincToGraph`, and `PbToGraph`.

### Building

```bash
cd rust
cargo build --release
```

Binaries will be placed in `rust/target/release/`:
- `rust/target/release/ZincToWl`
- `rust/target/release/FlatzincToGraph`
- `rust/target/release/PbToGraph`

### Usage: ZincToWl

```bash
./rust/target/release/ZincToWl model.fzn -m wl-nc -k 1 -c 4
```

| Argument          | Short | Type   | Default      | Description                                        |
| :---------------- | :---- | :----- | :----------- | :------------------------------------------------- |
| `input_file`      |       | path   | *(required)* | `.fzn`, `.opb`, `.wbo`, `.xz`, or `.graph` file    |
| `--method`        | `-m`  | string | `wl-nc`      | WL method (`wl`, `wl-n`, `wl-e`, `wl-ne`, `wl-nc`, `wl-nec`, etc.) |
| `--wl-iterations` | `-k`  | int    | `1`          | Number of WL iterations                            |
| `--num-cores`     | `-c`  | int    | `1`          | Worker threads                                     |
| `--colors`        |       | path   | `colors.bin` | Persistent color dictionary                        |
| `--training`      | `-t`  | flag   | off          | Register unseen colors into the colors file        |
| `--check-colors`  |       | path   |              | Print all known colors and exit                    |

Recommended configuration:
```bash
./rust/target/release/ZincToWl model.fzn -m wl-nc -k 1
```

For more details on the Rust implementation, see [rust/README.md](rust/README.md).

---

## Julia Implementation (Reference)

The original Julia packages are located under the [`julia/`](julia/) directory:
- `julia/FlatzincToGraph`: FlatZinc parser and graph representation engine
- `julia/ZincToWl`: Weisfeiler-Lehman color refinement and feature extraction
- `julia/PbToGraph`: Pseudo-Boolean model parser
- `julia/SatToGraph`: CNF SAT formula parser

### Running directly with Julia

```bash
cd julia/ZincToWl
julia --project=. src/ZincToWl.jl input.fzn [options]
```

Or using the server mode (amortizes Julia startup and JIT compilation across many instances):
```bash
julia --project=julia/ZincToWl julia/ZincToWl/src/ZincToWl.jl --server /tmp/zinctowl.sock
```

### Building Standalone Executables (PackageCompiler)

Each Julia package includes a `build.jl` script using `PackageCompiler.jl`:
```bash
cd julia/ZincToWl
julia --project=. build.jl
```
The compiled standalone executable will be placed in `julia/ZincToWl/out/bin/ZincToWl`.

---

## Output Format

The output of `ZincToWl` (both Rust and Julia) is a single JSON object containing:
1. **WL color histogram**: Every known color hash mapped to its occurrence count (0 for unseen colors).
2. **Structural graph features**: `n_nodes`, `cpv`, `cpp`, `d_ratio_int_vars`, `d_ratio_bool_vars`, `o_deg_cons`, `o_deg_std`, `o_dom_deg`, `v_ent_deg_vars`, `v_sum_domdeg_vars`.
3. **Co-occurrence counts** (for `wl-nc` and `wl-nec`): Frequency counts of `"(<source_type>, <target_type>)"` for cut and global constraint nodes.

---

## Performance Comparison

On the MiniZinc Challenge corpus (160 `.fzn` instances, `wl-nc k=1`):

| Implementation | Mode | Median / file | Total (160 files) |
| :--- | :--- | :---: | :---: |
| **Rust** | Native CLI (`ZincToWl`) | **~12 ms** | **~35 s** |
| **Julia** | `--server` (warm socket) | ~9–11 ms | ~64 s |
| **Julia** | Compiled binary (`PackageCompiler`) | ~330 ms | ~127 s |
| **Julia** | Script invocation (per-file JIT) | ~11 s | ~30 min |

---

## Visualizing Color Dictionary Evolution

The `visualize/` directory contains tools to inspect the evolution of the color dictionary:
```bash
./visualize/wl-viz.sh <corpus_dir> [out.html] [options]
```
See [visualize/README.md](visualize/README.md) for full instructions.
