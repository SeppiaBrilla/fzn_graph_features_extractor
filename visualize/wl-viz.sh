#!/bin/sh
# Convenience wrapper for building the WL color derivation visualization.
# Usage: ./wl-viz.sh <corpus-dir-or-file> [output.html] [extra args...]
# Run from anywhere; resolves the Julia project relative to this script.
#
# Note: prefers the juliaup launcher when available. A juliac-built julia
# whose system image bakes in an older ZincToWl would otherwise shadow the
# local source files.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(dirname "$here")"

if [ -x "$HOME/.juliaup/bin/julialauncher" ]; then
    JULIA_BIN="$HOME/.juliaup/bin/julialauncher"
else
    JULIA_BIN="julia"
fi

exec "$JULIA_BIN" --startup-file=no --project="$repo/julia/ZincToWl" "$here/build_color_tree.jl" "$@"
