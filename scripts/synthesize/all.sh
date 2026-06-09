#!/usr/bin/env bash
# scripts/synthesize/all.sh — regenerate every synthesis artifact for a wiki.
#
# Runs the mechanical generators (build.py) for the three navigation dashboards,
# then emits the knowledge graph as JSON by reusing the D3 graph parser
# (visualize/graph-html.py --json) so the JSON and the rendered graph can never
# diverge.
#
# Called as the final step of every wiki-mutating command (/wiki-ingest always,
# /wiki-query on promote, /wiki-lint --apply) so the synthesis pages can't drift.
# Output is deterministic — re-running with no wiki change rewrites nothing.
#
# Usage:
#   ./scripts/synthesize/all.sh            # operate on ./wiki and ./log.md (cwd)
#   ./scripts/synthesize/all.sh <root>     # operate on <root>/wiki and <root>/log.md
#
# Exit codes:
#   0 — completed (also 0 when skipped: no Python interpreter — degrades gracefully)
#   2 — usage error (wiki dir absent)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$PWD}"
WIKI_DIR="$ROOT/wiki"
LOG="$ROOT/log.md"
GRAPH_JSON="$WIKI_DIR/knowledge-graph.json"

if [ ! -d "$WIKI_DIR" ]; then
  echo "usage: ./scripts/synthesize/all.sh [ROOT]" >&2
  echo "  expected a wiki at '$WIKI_DIR' (ROOT defaults to the current directory)" >&2
  exit 2
fi

# Resolve a Python interpreter. Windows' python.org build ships `python`, not
# `python3`; macOS/Linux ship `python3`. Accept either.
PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then
  INSTALL_CMD="<your-package-manager> install"
  [ -f "$SCRIPT_DIR/../lib/platform-hint.sh" ] && . "$SCRIPT_DIR/../lib/platform-hint.sh"
  # Degrade gracefully (the project's "every dependency optional" posture): the
  # text loop (ingest/query/lint) already succeeded; only the derived views wait.
  echo "synthesis: skipped — no Python interpreter (python3 / python) on PATH." >&2
  echo "           install Python 3 to generate the dashboards + knowledge-graph.json (${INSTALL_CMD} python3)." >&2
  echo "           the core text loop (ingest / query / lint) is unaffected." >&2
  exit 0
fi

"$PY" "$SCRIPT_DIR/build.py" --wiki "$WIKI_DIR" --log "$LOG"
"$PY" "$SCRIPT_DIR/../visualize/graph-html.py" "$WIKI_DIR" --json --out "$GRAPH_JSON"

echo "synthesis: knowledge-graph.json + dashboards up to date" >&2
