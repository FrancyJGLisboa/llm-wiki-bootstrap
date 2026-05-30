#!/usr/bin/env bash
# scripts/visualize/slides.sh — turn a wiki page into HTML slides via MARP CLI.
#
# Wraps `npx -y @marp-team/marp-cli@latest`. First-run downloads marp-cli; later
# runs are cached. The wiki page should contain MARP-flavoured slide separators
# (---) and a `marp: true` line in its frontmatter.
#
# Usage:
#   ./scripts/visualize/slides.sh <wiki-page.md>            # writes <page>.html next to source
#   ./scripts/visualize/slides.sh <wiki-page.md> -o <out>   # custom output path
#
# Spec: .scratch/visualization-tools/GOAL.md §5.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: ./scripts/visualize/slides.sh <wiki-page.md> [-o <out>]" >&2
  exit 2
fi

if ! command -v npx >/dev/null 2>&1; then
  INSTALL_CMD="<your-package-manager> install"
  _here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$_here/../lib/platform-hint.sh" ] && . "$_here/../lib/platform-hint.sh"
  echo "error: npx not found on PATH. Install Node.js ≥18 (https://nodejs.org)." >&2
  echo "       install: ${INSTALL_CMD} node   (Debian/Ubuntu package: nodejs)" >&2
  echo "       Then re-run this script. marp-cli is downloaded on first run." >&2
  exit 1
fi

exec npx -y "@marp-team/marp-cli@latest" "$@"
