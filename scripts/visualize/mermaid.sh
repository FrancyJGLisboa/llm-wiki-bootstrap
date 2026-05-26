#!/usr/bin/env bash
# scripts/visualize/mermaid.sh — render mermaid code blocks in a wiki page to images.
#
# Wraps `npx -y @mermaid-js/mermaid-cli@latest`. mmdc detects fenced
# ```mermaid blocks in the input and emits PNG or SVG.
#
# Usage:
#   ./scripts/visualize/mermaid.sh <wiki-page.md>                  # input → page-N.png next to source
#   ./scripts/visualize/mermaid.sh <wiki-page.md> -o <out.svg>     # explicit output path/format
#
# Spec: .scratch/visualization-tools/GOAL.md §5.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: ./scripts/visualize/mermaid.sh <wiki-page.md> [-o <out>]" >&2
  exit 2
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not found on PATH. Install Node.js ≥18 (https://nodejs.org)." >&2
  echo "       Then re-run this script. mermaid-cli is downloaded on first run." >&2
  exit 1
fi

input="$1"
shift

# mmdc requires -i and at least -o; if user didn't pass -o we derive one next to the source.
if printf '%s\n' "$@" | grep -q '^-o$'; then
  exec npx -y "@mermaid-js/mermaid-cli@latest" -i "$input" "$@"
else
  default_out="${input%.md}.png"
  exec npx -y "@mermaid-js/mermaid-cli@latest" -i "$input" -o "$default_out" "$@"
fi
