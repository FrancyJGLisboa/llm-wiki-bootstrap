#!/usr/bin/env bash
# scripts/visualize/serve.sh — serve the wiki (and generated graph HTML) on localhost.
#
# Wraps `python3 -m http.server` against an optional directory.
#
# Usage:
#   ./scripts/visualize/serve.sh                # serve current dir on http://localhost:8000
#   ./scripts/visualize/serve.sh wiki           # serve wiki/ on http://localhost:8000
#   ./scripts/visualize/serve.sh wiki 9000      # serve wiki/ on http://localhost:9000
#
# Env vars:
#   VISUALIZE_DRY_RUN=1  — print "would serve <dir> on <port>" and exit 0 without
#                          binding a port. Used by verify-visualizers.sh.
#
# Spec: .scratch/visualization-tools/GOAL.md §5.

set -euo pipefail

target_dir="${1:-.}"
port="${2:-8000}"

if [ ! -d "$target_dir" ]; then
  echo "error: not a directory: $target_dir" >&2
  exit 2
fi

# Windows' python.org build ships `python`, not `python3`; accept either.
PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then
  echo "error: no Python interpreter (python3 / python) on PATH (required for http.server)." >&2
  exit 1
fi

if [ -n "${VISUALIZE_DRY_RUN:-}" ]; then
  echo "[serve.sh] would serve $target_dir on http://localhost:$port (dry run)"
  exit 0
fi

echo "Serving $target_dir on http://localhost:$port"
echo "Ctrl+C to stop."
exec "$PY" -m http.server "$port" --directory "$target_dir"
