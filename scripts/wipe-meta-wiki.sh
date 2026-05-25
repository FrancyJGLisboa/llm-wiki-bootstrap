#!/usr/bin/env bash
# scripts/wipe-meta-wiki.sh — remove the shipped meta-wiki content for a clean start.
#
# Purpose:
#   Delete wiki/*.md and raw/* and reset wiki/index.md + log.md to minimal stubs,
#   so the user can start their own wiki from an empty slate without manually
#   running rm and touch commands. Keeps AGENTS.md, README.md, shims, scripts,
#   .claude/, and the directory structure intact.
#
# Usage:
#   ./scripts/wipe-meta-wiki.sh         # prompts for confirmation
#   ./scripts/wipe-meta-wiki.sh --yes   # skip confirmation (for automation)
#
# Exit codes:
#   0 — wiped successfully (or nothing to wipe)
#   1 — user declined confirmation
#   2 — usage error

set -euo pipefail

# Resolve repo root so the script works from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse args
yes_flag=no
for arg in "$@"; do
  case "$arg" in
    --yes|-y) yes_flag=yes ;;
    -h|--help)
      cat <<'HELP'
wipe-meta-wiki.sh — remove the shipped meta-wiki content for a clean start.

Usage:
  ./scripts/wipe-meta-wiki.sh         prompts for confirmation
  ./scripts/wipe-meta-wiki.sh --yes   skip confirmation

Deletes:
  - wiki/*.md (all wiki pages)
  - raw/* (all raw sources, including binaries like .png)

Resets to minimal stubs:
  - wiki/index.md
  - log.md (header line only)

Preserves:
  - AGENTS.md, README.md, CLAUDE.md, GEMINI.md, shim files
  - .claude/commands/, scripts/, docs/, LICENSE
  - directory structure of raw/ and wiki/
HELP
      exit 0
      ;;
    *) echo "unknown argument: $arg" >&2; echo "try --help" >&2; exit 2 ;;
  esac
done

# Inventory what's about to be wiped
wiki_files=$(find "$REPO_ROOT/wiki" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
raw_files=$(find "$REPO_ROOT/raw" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "$wiki_files" = "0" ] && [ "$raw_files" = "0" ]; then
  echo "Already empty: wiki/ has no *.md, raw/ has no files. Nothing to do."
  exit 0
fi

echo "About to wipe:"
echo "  - $wiki_files file(s) under wiki/*.md"
echo "  - $raw_files file(s) under raw/*"
echo "  - reset wiki/index.md to an empty stub"
echo "  - reset log.md to its header line only"
echo
echo "Preserved: AGENTS.md, README.md, CLAUDE.md, GEMINI.md, .clinerules,"
echo "  .cursor/, .github/, .claude/commands/, scripts/, docs/, LICENSE."
echo

if [ "$yes_flag" = "no" ]; then
  printf "Proceed? [y/N] "
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# Wipe
rm -f "$REPO_ROOT"/wiki/*.md
rm -f "$REPO_ROOT"/raw/*

# Recreate minimal index.md (use unquoted heredoc to expand $(date))
today=$(date +%Y-%m-%d)
cat > "$REPO_ROOT/wiki/index.md" <<EOF
---
title: Index
type: navigation
source: analysis
updated: ${today}
tags: [navigation]
---

# Wiki Index

_(empty — run \`/wiki-extract <source>\` then \`/wiki-ingest\` in your AI tool to populate.)_
EOF

# Reset log.md to header only
cat > "$REPO_ROOT/log.md" <<'EOF'
# log.md

Append-only log of every `/wiki-ingest`, `/wiki-query` promotion, and `/wiki-lint --apply` operation. Newest at top.
EOF

echo "Wiped. wiki/ and raw/ are empty."
echo "Next: run /wiki-extract <source> in your AI tool to add your first source."
