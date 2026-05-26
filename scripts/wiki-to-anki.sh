#!/usr/bin/env bash
# scripts/wiki-to-anki.sh — export flashcards from wiki pages to Anki-importable CSV.
#
# Convention:
#   Any wiki page may declare flashcards in a `## Flashcards` section using
#   simple bullet pairs:
#
#     ## Flashcards
#
#     - Q: What does FVG stand for?
#       A: Fair Value Gap.
#     - Q: How many candles form an FVG?
#       A: Three candles forming a price imbalance
#          across the middle candle.
#
#   A continuation line for an answer must be indented (any whitespace) and
#   must not start with `-`. Blank lines or another `## ` heading end the
#   Flashcards section.
#
# Output:
#   CSV with header `Front,Back,Tags` written to stdout. The `Tags` column is
#   the page slug (filename without `.md`), which Anki treats as a single
#   flashcard tag for filtering.
#
# Usage:
#   ./scripts/wiki-to-anki.sh                  # default: scan ./wiki/
#   ./scripts/wiki-to-anki.sh tests/canary/    # scan another dir
#   ./scripts/wiki-to-anki.sh > anki.csv       # save for Anki import
#
# Exit codes:
#   0 — completed (no flashcards found is not an error)
#   2 — usage error (input dir missing or not a directory)
#
# Idempotent. Reads only; writes nothing to disk.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

src="${1:-$REPO_ROOT/wiki}"

if [ ! -d "$src" ]; then
  echo "usage: ./scripts/wiki-to-anki.sh [DIR]" >&2
  echo "  default DIR: ${REPO_ROOT}/wiki" >&2
  echo "  '$src' is not a directory" >&2
  exit 2
fi

printf 'Front,Back,Tags\n'

find "$src" -type f -name '*.md' -print0 | while IFS= read -r -d '' file; do
  slug="$(basename "$file" .md)"
  awk -v slug="$slug" '
    function csv_escape(s,   needs_quote) {
      needs_quote = (index(s, ",") || index(s, "\""))
      gsub(/"/, "\"\"", s)
      if (needs_quote) return "\"" s "\""
      return s
    }
    function flush() {
      if (q != "" && a != "") {
        printf "%s,%s,%s\n", csv_escape(q), csv_escape(a), csv_escape(slug)
      }
      q = ""; a = ""; mode = ""
    }
    # Enter the Flashcards section.
    /^##[[:space:]]+Flashcards[[:space:]]*$/ { in_section=1; next }
    # Any other H2 heading ends the section.
    /^##[[:space:]]+/ && in_section { flush(); in_section=0; next }
    # Start of a new Q line.
    in_section && /^-[[:space:]]+Q:[[:space:]]/ {
      flush()
      line = $0
      sub(/^-[[:space:]]+Q:[[:space:]]*/, "", line)
      q = line
      mode = "q"
      next
    }
    # Start of the matching A line.
    in_section && /^[[:space:]]+A:[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+A:[[:space:]]*/, "", line)
      a = line
      mode = "a"
      next
    }
    # Continuation of an answer (indented, not a new bullet).
    in_section && mode == "a" && /^[[:space:]]+[^-[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+/, " ", line)
      a = a line
      next
    }
    END { flush() }
  ' "$file"
done
