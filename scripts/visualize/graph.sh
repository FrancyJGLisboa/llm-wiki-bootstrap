#!/usr/bin/env bash
# scripts/visualize/graph.sh — generate a D3 graph HTML from a directory of markdown.
#
# Thin wrapper around scripts/visualize/graph-html.py. Pure passthrough so the
# Python module remains the single locus of parsing logic.
#
# Usage:
#   ./scripts/visualize/graph.sh <input-dir>                      # write to stdout
#   ./scripts/visualize/graph.sh <input-dir> --out graph.html     # write to file
#   ./scripts/visualize/graph.sh <input-dir> --inline             # embed local D3
#   ./scripts/visualize/graph.sh <input-dir> --json --out g.json  # deterministic graph JSON
#
# Exit codes match the underlying Python.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  INSTALL_CMD="<your-package-manager> install"
  [ -f "$SCRIPT_DIR/../lib/platform-hint.sh" ] && . "$SCRIPT_DIR/../lib/platform-hint.sh"
  echo "error: python3 not found on PATH (required for the graph generator)." >&2
  echo "       install: ${INSTALL_CMD} python3" >&2
  exit 1
fi

if [ "$#" -lt 1 ]; then
  cat >&2 <<EOF
usage: ./scripts/visualize/graph.sh <input-dir> [--inline] [--json] [--out <path>]

  Walks <input-dir> recursively for *.md files, parses [[wiki-links]],
  and emits a self-contained D3 graph as HTML to stdout (or --out).
  --json emits the {nodes, links} graph as deterministic JSON instead of HTML.
EOF
  exit 2
fi

exec python3 "$SCRIPT_DIR/graph-html.py" "$@"
