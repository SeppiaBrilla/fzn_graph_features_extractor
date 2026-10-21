#!/bin/sh
# rs-zinctowl — install script for the Rust port of flatzinc_to_graph.
#
# Builds the workspace in release mode and installs the three binaries
# (zinc-to-wl, flatzinc-to-graph, pb-to-graph) into a bin directory on PATH.
#
# Usage:
#   ./rs-zinctowl                 # build + install to ~/.local/bin
#   ./rs-zinctowl --prefix DIR    # install binaries into DIR/bin
#   ./rs-zinctowl --uninstall     # remove the installed binaries
#
# Requirements: a working Rust toolchain (cargo). No network access is
# needed beyond the crates.io fetch on first build (rayon, mimalloc, flate2).

set -eu

# --- locate the repository root (script may be run from anywhere) ---
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$script_dir" && pwd)"
if [ ! -d "$repo" ]; then
    echo "error: cannot locate the flatzinc_to_graph_rust repository" >&2
    echo "       run this script from inside the repository, or set repo=..." >&2
    exit 1
fi

BINARIES="ZincToWl flatzincToGraph PbToGraph"

usage() {
    cat >&2 <<EOF
./install.sh — install script

usage: ./install.sh [--prefix DIR] [--uninstall] [--no-build] [-h]

  --prefix DIR   install into DIR/bin (default: ~/.local, i.e. ~/.local/bin)
  --uninstall    remove the installed binaries instead of installing
  --no-build     skip cargo build (use existing target/release binaries)
  -h             show this help
EOF
    exit "${1:-0}"
}

prefix="$HOME/.local"
do_build=1
action=install

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)   prefix="${2:?--prefix needs a directory}"; shift 2 ;;
        --prefix=*) prefix="${1#--prefix=}"; shift ;;
        --uninstall) action=uninstall; shift ;;
        --no-build) do_build=0; shift ;;
        -h|--help)  usage 0 ;;
        *)          echo "unknown option: $1" >&2; usage 1 ;;
    esac
done

bindir="$prefix/bin"

# --- uninstall ---
if [ "$action" = "uninstall" ]; then
    for b in $BINARIES; do
        if [ -f "$bindir/$b" ] && [ -w "$bindir/$b" ]; then
            # only remove if it is (a copy of) this port's binary
            if [ ! -L "$bindir/$b" ] || [ "$(readlink -f "$bindir/$b" 2>/dev/null)" != "$(readlink -f "$repo/target/release/$b" 2>/dev/null)" ]; then
                rm -f "$bindir/$b"
                echo "removed  $bindir/$b"
            fi
        fi
    done
    echo "done."
    exit 0
fi

# --- toolchain check ---
if ! command -v cargo >/dev/null 2>&1; then
    echo "error: cargo not found on PATH" >&2
    echo "       install a Rust toolchain first: https://rustup.rs" >&2
    exit 1
fi

# --- build ---
if [ "$do_build" = 1 ]; then
    echo "==> building (release) in $repo"
    (cd "$repo" && cargo build --release)
    echo
else
    missing=0
    for b in $BINARIES; do
        if [ ! -x "$repo/target/release/$b" ]; then
            echo "error: $repo/target/release/$b not found (build first, or drop --no-build)" >&2
            missing=1
        fi
    done
    [ "$missing" = 0 ] || exit 1
fi

# --- install ---
mkdir -p "$bindir"
case ":$PATH:" in
    *":$bindir:") : ;;
    *) echo "note: $bindir is not on your PATH" >&2 ;;
esac

for b in $BINARIES; do
    src="$repo/target/release/$b"
    install -m 0755 "$src" "$bindir/$b"
    echo "installed $bindir/$b"
done

echo
echo "usage: ZincToWl model.fzn -m wl-nc -k 1 [--colors colors.bin]"
echo "uninstall with: ./rs-zinctowl --uninstall"
