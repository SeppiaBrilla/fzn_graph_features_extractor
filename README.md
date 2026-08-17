# FlatZinc Graph & Weisfeiler-Lehman Feature Extractor

This repository provides tools for converting Constraint Satisfaction and Optimization Problems expressed in FlatZinc (`.fzn`) format into graph representations and computing graph-based structural features via Weisfeiler-Lehman (WL) graph kernels and domain statistics.

The repository consists of two interrelated Julia packages:
1. **FlatzincToGraph**: Parses FlatZinc constraint models and constructs attributed, directed graph representations.
2. **ZincToWl**: Performs Weisfeiler-Lehman color refinement algorithms on the constructed graphs and extracts topological and constraint-specific feature vectors.

---

## Repository Structure

```text
.
├── FlatzincToGraph/            # FlatZinc parser and graph representation engine
│   ├── Project.toml            # Project configuration and dependencies
│   ├── Manifest.toml           # Pinned dependency manifest
│   ├── build.jl                # Standalone compilation script (PackageCompiler)
│   ├── precompile_script.jl    # Precompilation workload for binary builds
│   ├── src/
│   │   ├── FlatzincToGraph.jl  # Module entry point and CLI runner
│   │   └── parse/
│   │       ├── flatzinc_to_graph.jl # Main FlatZinc AST-to-graph pipeline
│   │       ├── constraint.jl        # Constraint parser and node/edge mappings
│   │       ├── variables.jl         # Variable declaration parser
│   │       ├── parameters.jl        # Parameter and array parser
│   │       ├── solve.jl             # Solve goal item parser
│   │       ├── helper.jl            # Parsing utilities and type helpers
│   │       └── graph/               # Graph data structures and serialization
│   └── test/                   # Unit and integration tests
│
├── ZincToWl/                   # Weisfeiler-Lehman feature extraction pipeline
│   ├── Project.toml            # Project configuration and dependencies
│   ├── Manifest.toml           # Pinned dependency manifest
│   ├── build.jl                # Standalone compilation script (PackageCompiler)
│   ├── precompile_script.jl    # Precompilation workload for binary builds
│   ├── src/
│   │   ├── ZincToWl.jl         # CLI interface, IPC server, and main execution flow
│   │   ├── GraphLoader.jl      # Deserializer for `.graph` files
│   │   └── wl_features/
│   │       ├── Helper.jl       # Common hashing, serialization, and statistics routines
│   │       ├── StandardWl.jl   # Base directed WL kernel (wl)
│   │       ├── NodeWl.jl       # Node-typed WL kernel (wl-n)
│   │       ├── EdgeWl.jl       # Edge-typed WL kernel (wl-e)
│   │       ├── NodeEdgeWl.jl   # Node- and edge-typed WL kernel (wl-ne)
│   │       ├── WlNodeCut.jl    # Node-cut localized WL kernel (wl-nc)
│   │       └── WlNodeEdgeCut.jl# Node- and edge-cut localized WL kernel (wl-nec)
│   └── test/                   # Unit and integration tests
│
└── README.md                   # Project documentation
```

---

## Projects Overview

### 1. FlatzincToGraph

FlatzincToGraph translates a `.fzn` constraint model into an directed graph where:
- **Nodes** represent decision variables (`var_node`), constants/parameters (`literal_node` / `par_node`), operator definitions (e.g., `sum_node`, `mult_node`), constraint definitions (e.g., `int_lin_eq_node`, `all_different_node`, `equality_node`), and solve objectives (`satisfy_node`, `minimise_node`, `maximise_node`).
- **Edges** represent variable and parameter participation in constraints and objectives, labeled with positional or relational semantics.

The output can be saved directly as a `.graph` file for persistent storage and subsequent analysis.

### 2. ZincToWl

ZincToWl consumes either `.fzn` files directly (invoking `FlatzincToGraph` internally) or pre-generated `.graph` files. It computes Weisfeiler-Lehman color iterations across the graph topology, aggregates color histogram frequencies, and derives a set of structural, variable, and objective metrics in JSON format.

---

## Prerequisites and Building

### Prerequisites
- Julia 1.9 or higher
- System C toolchain (`gcc`, `clang`, or equivalent) for `PackageCompiler.jl`

### Installation and Direct Julia Usage

Both projects can be run directly inside the Julia environment without compilation:

```bash
# Set up FlatzincToGraph
cd FlatzincToGraph
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Set up ZincToWl
cd ../ZincToWl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Compiling Standalone Executables

Compiling standalone binaries with `PackageCompiler.jl` eliminates Just-In-Time (JIT) compilation latency during execution:

1. **Build FlatzincToGraph**:
   ```bash
   cd FlatzincToGraph
   julia --project=. build.jl
   ```
   The binary is generated at `FlatzincToGraph/out/bin/FlatzincToGraph`.

2. **Build ZincToWl**:
   ```bash
   cd ZincToWl
   julia --project=. build.jl
   ```
   The binary is generated at `ZincToWl/out/bin/ZincToWl`.

Both pre-compiled binaries for linux can be found in the release tab.

---

## Usage Guide

### ZincToWl (Main Feature Extractor)

ZincToWl can process input files in standalone CLI mode or in persistent UNIX domain socket server mode.

#### Command-Line Arguments

| Argument | Short | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `input_file` | | `String` | *(Required)* | Path to `.fzn` or `.graph` file (not required in server mode) |
| `--method` | `-m` | `String` | `wl-nc` | Weisfeiler-Lehman method (`wl`, `wl-n`, `wl-e`, `wl-ne`, `wl-nc`, `wl-nec`) |
| `--wl-iterations` | `-k` | `Int` | `1` | Number of Weisfeiler-Lehman iterations |
| `--num-cores` | `-c` | `Int` | `1` | Number of worker threads for parallel iteration |
| `--colors` | | `String` | `colors.bin` | Path to persistent serialized color dictionary |
| `--training` | `-t` | `Bool` | `false` | When true, registers newly discovered colors into `--colors` |
| `--server` | | `String` | | Starts ZincToWl as a persistent server on the specified UNIX domain socket |

#### Recommended Default Configuration

For standard feature extraction pipelines, the recommended options are:
```bash
--method wl-nc --wl-iterations 1
```
Using `wl-nc` with `k=1` prevents exponential neighborhood expansion on large linear and global constraints while capturing discriminative localized relational structures.

#### Direct CLI Execution

Using compiled binary:
```bash
./ZincToWl/out/bin/ZincToWl model.fzn -m wl-nc -k 1 -c 4
```

Using Julia script directly:
```bash
julia --project=ZincToWl ZincToWl/src/ZincToWl.jl model.fzn -m wl-nc -k 1 -c 4
```

---

### High-Throughput Server Mode (`--server`)

When extracting features across a large dataset or benchmark suite of FlatZinc models, starting a new process per file incurs process instantiation and memory mapping overhead. 

It is strongly recommended to use the **`--server`** option. In this mode, the program starts a persistent server listening on a UNIX domain socket. Client processes connect, send null-delimited arguments (`\0`), and receive the resulting JSON output over the socket.

#### 1. Starting the Server

```bash
./ZincToWl/out/bin/ZincToWl --server /tmp/zinctowl.sock
```

#### 2. Querying the Server (Python Example)

```python
import socket

def extract_features(socket_path, fzn_file, method="wl-nc", k=1, cores=1):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(socket_path)
    
    # Arguments separated by null bytes (\0) terminated by \0\n
    args = ["--method", method, "-k", str(k), "--num-cores", str(cores), fzn_file]
    payload = "\0".join(args) + "\0\n"
    sock.sendall(payload.encode("utf-8"))
    
    # Receive JSON output
    response = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
    sock.close()
    return response.decode("utf-8")

output_json = extract_features("/tmp/zinctowl.sock", "problem.fzn")
print(output_json)
```

---

### FlatzincToGraph (Standalone Graph Converter)

To convert a `.fzn` model into a serialized `.graph` file:

```bash
# Compiled binary
./FlatzincToGraph/out/bin/FlatzincToGraph input.fzn output.graph [num_cores]

# Direct Julia script
julia --project=FlatzincToGraph FlatzincToGraph/src/FlatzincToGraph.jl input.fzn output.graph 4
```

---

## Feature Set Specification

ZincToWl outputs a single structured JSON object containing Weisfeiler-Lehman color histogram counts alongside high-level problem and graph properties.

### 1. Weisfeiler-Lehman Graph Feature Methods

The choice of `--method` determines how graph nodes and edges are initialized and refined during the $k$-step aggregation:

- **`wl` (Standard WL)**:
  Standard directed 1-Weisfeiler-Lehman color refinement. Nodes initialize with neutral colors, and each iteration updates a node's color based on the sorted multiset of incoming neighbor colors.
- **`wl-n` (Node-Aware WL)**:
  Seeds initial node colors with their categorical domain types (`literal_node`, `var_node`, constraint type identifiers, etc.) prior to standard WL neighbor refinement.
- **`wl-e` (Edge-Aware WL)**:
  Incorporates edge relation labels into the neighbor aggregation hash, distinguishing different roles of variables within constraints.
- **`wl-ne` (Node- and Edge-Aware WL)**:
  Combines both initial node type classification and edge-label hashing in each refinement step.
- **`wl-nc` (Node Cut WL - Recommended)**:
  Identifies dense constraint nodes (such as global constraints and multi-variable linear expressions) as *cut nodes*. Cut nodes do not propagate neighbor colors across their boundaries during WL iterations, preventing neighborhood over-saturation and preserving local substructure.
- **`wl-nec` (Node and Edge Cut WL)**:
  Combines the cut node isolation mechanism of `wl-nc` with edge-label hashing.

### 2. Structural and Domain Statistical Features

In addition to the WL color frequency dictionary, the output includes structural metrics extracted from the constraint graph:

| Feature Key | Description |
| :--- | :--- |
| `n_nodes` | Total number of nodes in the graph representation. |
| `cpv` | Constraints per variable (average out-degree of variable nodes). |
| `cpp` | Constraints per parameter (average out-degree of parameter/literal nodes). |
| `d_ratio_int_vars` | Ratio of integer decision variables to total variables. |
| `d_ratio_bool_vars` | Ratio of Boolean decision variables to total variables. |
| `v_ent_deg_vars` | Entropy of the variable degree distribution ($-\sum p \log_2 p$). |
| `v_sum_domdeg_vars` | Sum of domain-size-to-degree ratios across connected decision variables ($\sum_{v, \text{deg}(v) > 0} \frac{|\text{dom}(v)|}{\text{deg}(v)}$). |
| `o_deg_cons` | Objective variable degree normalized by total number of constraints. |
| `o_deg_std` | Standardized objective variable degree relative to mean variable degree. |
| `o_dom_deg` | Ratio of objective variable domain size to its degree. |
| `"(<source_type>, <target_type>)"` | Co-occurrence counts of variable/parameter types connected to specific cut/global constraint nodes (e.g., `("literal_node", "all_different_node")`) (only for `wl-nc` and `wl-nec` features). |

Some of the features, specifically those starting with `d_`, `v_` and `o_`, have been ported from [fzn2feat](https://github.com/CP-Unibo/mzn2feat/tree/master/fzn2feat)
