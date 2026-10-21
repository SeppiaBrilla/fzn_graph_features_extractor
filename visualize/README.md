# WL Color Derivation Tree

This folder contains a visualization tool for the **color dictionary** used by
ZincToWl's Weisfeiler-Lehman feature extraction.

Given a corpus of graphs (`.graph` or `.fzn`) and optionally a `colors.bin`
file, it replays the training-mode WL color refinement **exactly** as ZincToWl
does, records *how every color was derived*, and emits a single
self-contained interactive HTML file.

## Background: how WL colors work

Each node of the constraint graph starts with an **initial color** (level 0)
determined by its type. Then, at every WL iteration, every non-cut node computes
a new color:

```
new_color = hash( own current color , sorted multiset of neighbors' colors )
```

(`tailored_hash` in `ZincToWl/src/wl_features/Helper.jl`.) The result is a new
color that did not exist at initialization — a **refined** color. Two nodes
get the same refined color if and only if they had the same color before *and*
see the same multiset of neighbor colors, i.e. they are structurally
indistinguishable up to that radius.

The color histogram at the final level **is** the WL part of the ZincToWl
feature vector: refined colors are what carries the structural information.

With cut-node methods (`wl-nc`, `wl-nec`), **cut nodes** (global constraints
plus `multi_and/or/xor`) are handled specially: their initial color already
encodes their constraint type *and* the distinct types of their neighbors
(e.g. `all_different_node,var_node,literal_node`), and they **keep this color
forever** — colors do not propagate through them.

## What the visualization shows

- **Every color in the dictionary as a node** in a derivation tree/DAG:
  - **type roots** (`var_node`, `literal_node`, `mult_node`, …) — the initial
    colors of non-cut nodes (hash of the node type),
  - **cut roots** (`all_different_node,var_node`, …) — initial colors of
    cut/global nodes, encoding their constraint type and the distinct types of
    their neighbors (these connect to the type roots listed in their
    signature),
  - **refined colors** — produced during WL iterations: a node's color combined
    with the sorted multiset of its neighbors' colors (`hash(self, nbs…)`),
  - **unobserved roots** (dimmed, dashed) — colors present in the seed
    `colors.bin` that never appeared in the replayed corpus.
- **Discovery timeline** — a slider (▶ to animate) that replays the corpus
  file-by-file: colors pop into existence when first discovered, and the
  dictionary-growth chart shows how the feature space expands over the corpus.
- **Color details** — click any node to see:
  - its exact **derivation recipe** (self color + neighbor colors with edge
    labels and multiplicities),
  - its **evolution chain** — how a node's color evolves level by level
    (`level 0: root → level 1: refined → …`), following the self-parent
    chain; cut roots show an explanation of why they never change,
  - when and in which file it was first seen, how many nodes have it, and in
    which graphs it is most used.
  Selecting a color also **highlights its full lineage** on the canvas (thick
  blue arrows along the self-parent chain, green for neighbor contributions,
  everything else dimmed).
- Colors present in the seed `colors.bin` get a **white ring** (★ in lists) —
  compare them against the replay to see which colors your corpus *would*
  discover anew.

## Usage

```bash
# from the repository root
julia --project=ZincToWl visualize/build_color_tree.jl <corpus> [out.html] [options]

# or via the wrapper (uses the juliaup launcher; see note below)
./visualize/wl-viz.sh <corpus> [out.html] [options]
```

`<corpus>` is one of:

- a **directory** — every `*.graph` / `*.fzn` inside it, recursively, in
  sorted order;
- a **single** `.graph` / `.fzn` file;
- anything else, together with `--files-list list.txt` — one path per line
  (e.g. the exact training split that produced your colors file).

Options:

| option | default | description |
| :-- | :-- | :-- |
| `-m, --method` | `wl-nc` | WL method; must match how the colors file was trained (`wl`, `wl-n`, `wl-e`, `wl-ne`, `wl-nc`, `wl-nec`) |
| `-k, --wl-iterations` | `1` | number of WL iterations |
| `--colors colors.bin` | — | seed colors file; its colors are marked as known |
| `--files-list f` | — | corpus paths, one per line |
| `--json out.json` | — | also write the raw JSON data |
| `--limit N` | all | process only the first N corpus files |
| `--title t` | auto | title shown in the HTML |
| `--template f` | `template.html` | HTML template to inject data into |

Example — reproduce the derivation tree of the repository's `colors.bin`
(trained with `wl-nc`, `k=1` on the MiniZinc Challenge fold-0 split):

```bash
julia --project=ZincToWl visualize/build_color_tree.jl \
    /path/to/graph_features/data/graphs \
    colors_tree.html \
    -m wl-nc -k 1 \
    --colors colors.bin \
    --title "colors.bin derivation tree"
```

The output `colors_tree.html` is fully self-contained (no network, no server):
open it in any browser.

## JSON output format

`--json out.json` writes the same data the HTML embeds. All `UInt64` color
hashes are serialized as JSON **strings** (JS numbers lose precision above
2^53). Top-level structure:

```jsonc
{
  "meta": {
    "title": "...", "method": "wl-nc", "iterations": 1,
    "n_files": 1077, "n_colors": 163,
    "colors_file": "colors.bin",  // "" when no seed was given
    "n_seed": 163,                // colors in the seed file
    "generated": "2026-10-12T10:09:57.783"
  },
  "files":   ["abs/path/a.graph", "..."],   // corpus, in processing order
  "discovery": ["hash", "hash", ...],       // hashes in first-seen order
  "new_per_file": [3, 12, 0, ...],          // new colors discovered per file
  "colors": { "<hash>": { ... }, ... },    // see below
  "edges":  [["<parent-hash>", "<child-hash>"], ...]
}
```

### Per-color record

```
"<hash>": {
  "kind":        "type" | "cut" | "neutral" | "refined" | "unknown",
  "sig":         "var_node" | "all_different_node,var_node" | ... | "",
  "first_file":  1,            // 1-based index into "files"
  "first_level": 0,             // 0 = initialization, k = after k-th iteration
  "seed":        true|false,    // present in the --colors file?
  "g_init":      800,           // graphs where it occurs at level 0
  "g_final":     750,           // graphs where it occurs at the final level
  "hist":        [12345, 9000],// occurrences per level, aggregated over corpus
  "use":         [[3, 128]],   // top (file index, final-level count) pairs
  // refined only:
  "self":        "<hash>",      // the node's own color before refinement
  "nbs":         [ ... ]       // neighbor multiset, see below
}
```

### The `nbs` array

`nbs` is the **neighbor half** of the derivation recipe of a refined color;
the full input of the hash is `hash(self, nbs_multiset)`. It is the *sorted,
aggregated multiset* of the neighbors' contributions — sorted by the value
that enters the hash, and aggregated by identical contributions. Each entry
is a 4-tuple:

```
[mixed, nb, labels, mult]
```

| field | meaning |
| :-- | :-- |
| `mixed` | the value that actually enters the hash. For `wl`, `wl-n`, `wl-nc` this is simply the neighbor's color (`mixed == nb`). For edge-aware methods (`wl-e`, `wl-ne`, `wl-nec`) it is `hash(neighbor color, edge hash)`, so `mixed ≠ nb` |
| `nb` | the neighbor's color **before** this refinement step (its level-`k-1` color, e.g. its type-root color when `k = 1`) |
| `labels` | edge label(s) of the aggregated edges, as a string: `"0"`, `"1"` or `"2"` (distinct labels of aggregated neighbors joined with `"/"`, e.g. `"0/1"`) |
| `mult` | multiplicity: how many neighbors contributed this exact `mixed` value |

Reading entries:

- *number of distinct array entries* = number of **distinct neighbor colors**;
- *sum of multiplicities* = actual **number of neighbors** (in-degree).

So a `mult_node` fed by one constant and one variable yields two entries
`[h(lit), h(lit), "0", 1]` and `[h(var), h(var), "0", 1]` — "one constant plus
one variable" — while a `mult_node` fed by two variables yields a single entry
`[h(var), h(var), "0", 2]` — "two variables".

Edge labels come from the FlatzincToGraph parser and encode the role of the
operand in the decomposition. In practice only three positional labels exist
(`EDGE_0`/`EDGE_1`/`EDGE_2`):

- `"0"` — plain operand edges (e.g. both inputs of a `mult_node`, terms into a
  `lin_sum_node`, variables/parameters into global constraint nodes, objective
  variable into `minimise_node`/`maximise_node`),
- `"1"` — right-hand-side/index role (e.g. the constant `c` feeding a
  `leq_node`, the index operand of `index_node`/`division_node`/`pow_node`),
- `"2"` — arguments of global constraints (`decompose_global.jl`). These
  never appear in `nbs` of a `wl-nc` replay, because global constraint nodes
  are cut nodes: their incoming edges shape the cut-root signature instead of
  any refined color.

Note: with `wl-nc` (and `wl`, `wl-n`) **edge labels do not influence the color**
— they are recorded for display only. Only the edge-aware methods mix them
into the hash (via `mixed`).

### The `edges` array

`edges` encodes the derivation DAG used for drawing:

- for every **refined** color: `self → refined` plus one edge per distinct
  neighbor color `nb → refined`;
- for every **cut root**: one edge from each type root mentioned in its
  signature (e.g. `var_node → all_different_node,var_node,...`), because the
  cut node's initial color is derived from its type plus its neighbor types.

Type roots are the only nodes without parents.

## Implementation notes

- `ZincToWl/src/wl_features/WlTrace.jl` (in the ZincToWl package) contains the
  traced WL implementation. It reuses `Helper.typer`, `Helper.is_cut_node`,
  `Helper.tailored_hash` and the same adjacency construction as the original
  kernels, so recorded colors are **bit-identical** to a training run.
- `visualize/build_color_tree.jl` drives the replay and serializes the JSON
  (all `UInt64` hashes are emitted as JSON strings to avoid JS precision loss).
- `visualize/template.html` is the interactive page (vanilla JS + canvas).
- The graph structure is a DAG in general (a color can feed into many other
  colors, and a refined color has both a *self parent* and *neighbor parents*).
  The radial layout clusters children under their self-parent.
- Replaying the fold-0 training split of the MiniZinc Challenge corpus (1077
  graphs, `wl-nc`, `k=1`) reproduces the repository's `colors.bin` **exactly**
  (163/163 colors, no extras). `ZincToWl/test/test_wl_trace.jl` checks that the
  traced refinement matches the original kernels on sample graphs.

### Note on Julia binaries

`wl-viz.sh` prefers `~/.juliaup/bin/julialauncher` over `julia` from `PATH`: a
juliac-built `julia` whose system image baked in an older ZincToWl would
silently ignore the local source files. If you use `julia` directly and the
package seems stale, this is most likely the cause.
