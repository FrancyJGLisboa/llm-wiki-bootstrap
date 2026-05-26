#!/usr/bin/env bash
# scripts/mcp-server.sh — launch an MCP server pointed at this wiki.
#
# Purpose:
#   Expose `wiki/` (default) over the Model Context Protocol so any MCP-aware
#   client — Claude Desktop, Claude Code, Cursor, ChatGPT Desktop, Gemini CLI,
#   etc. — can read, search (BM25), and (optionally) write wiki pages without
#   a slash-command roundtrip.
#
#   Uses `@bitbonsai/mcpvault` (https://github.com/bitbonsai/mcpvault) which
#   works on any directory of markdown files. No Obsidian plugin or runtime
#   required.
#
# Usage:
#   ./scripts/mcp-server.sh                  # serve wiki/
#   ./scripts/mcp-server.sh raw              # serve raw/ instead
#   ./scripts/mcp-server.sh /abs/path        # serve an arbitrary directory
#
# Prerequisites:
#   - Node.js ≥ 18 with `npx` on PATH (run ./scripts/preflight.sh to check).
#   - First run downloads the package via npx; subsequent runs are cached.
#
# To register the server with a client, see docs/MCP.md.
#
# Exit codes:
#   0 — server exited cleanly
#   1 — server exited with error or npx missing
#   2 — usage error (target directory not found)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

target_arg="${1:-wiki}"

# Resolve target to an absolute path. Accept both repo-relative and absolute.
case "$target_arg" in
  /*) target="$target_arg" ;;
  *)  target="$REPO_ROOT/$target_arg" ;;
esac

if [ ! -d "$target" ]; then
  echo "usage: ./scripts/mcp-server.sh [DIR]" >&2
  echo "  default DIR: ./wiki (resolved to ${REPO_ROOT}/wiki)" >&2
  echo "  '$target' is not a directory" >&2
  exit 2
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not found on PATH." >&2
  echo "       Install Node.js ≥18 (https://nodejs.org)." >&2
  echo "       Then re-run ./scripts/preflight.sh to confirm." >&2
  exit 1
fi

echo "Starting MCP server on $target ..."
echo "(first run will fetch @bitbonsai/mcpvault; later runs use the npm cache)"
echo

exec npx -y @bitbonsai/mcpvault@latest "$target"
