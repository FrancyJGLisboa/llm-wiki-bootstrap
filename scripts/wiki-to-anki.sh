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
#   CSV with header `Front,Back,Tags,Source` written to stdout. The `Tags`
#   column is the page slug (filename without `.md`), which Anki treats as a
#   single flashcard tag for filtering. The `Source` column carries the raw
#   receipt — the `(source: raw/<file>#<anchor>)` citation attached to the
#   card's Q or A line, or the nearest such citation above the card within the
#   same `## Flashcards` section.
#
#   A card with NO resolvable raw citation is EXCLUDED from the CSV and a
#   warning is written to stderr — a factual Q/A assertion must not escape the
#   wiki's receipts guarantee by landing in Anki uncited.
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

printf 'Front,Back,Tags,Source\n'

# Citation pattern: (source: raw/<file>#<anchor>) — mirrors the canonical
# CITATION_RE in scripts/citation-audit.py. The first such match on (or above,
# within the section) a card is the card's raw receipt.
find "$src" -type f -name '*.md' -print0 | while IFS= read -r -d '' file; do
  slug="$(basename "$file" .md)"
  awk -v slug="$slug" -v file="$file" '
    function csv_escape(s,   needs_quote) {
      needs_quote = (index(s, ",") || index(s, "\""))
      gsub(/"/, "\"\"", s)
      if (needs_quote) return "\"" s "\""
      return s
    }
    # Extract the first (source: raw/...) citation in a string, or "".
    function cite_in(s,   m) {
      if (match(s, /\(source:[[:space:]]*raw\/[^)]*\)/)) {
        m = substr(s, RSTART, RLENGTH)
        return m
      }
      return ""
    }
    function flush() {
      if (q != "" && a != "") {
        # Source priority: a citation on the card (Q or A) wins; otherwise the
        # nearest citation seen above the card within this Flashcards section.
        src = card_cite != "" ? card_cite : section_cite
        if (src == "") {
          printf "wiki-to-anki: excluding uncited card (no resolving raw citation): %s -> Q: %s\n", file, q > "/dev/stderr"
        } else {
          printf "%s,%s,%s,%s\n", csv_escape(q), csv_escape(a), csv_escape(slug), csv_escape(src)
        }
      }
      q = ""; a = ""; mode = ""; card_cite = ""
    }
    # Enter the Flashcards section. Reset the section-level citation tracker.
    /^##[[:space:]]+Flashcards[[:space:]]*$/ { in_section=1; section_cite=""; next }
    # Any other H2 heading ends the section.
    /^##[[:space:]]+/ && in_section { flush(); in_section=0; next }
    # Start of a new Q line.
    in_section && /^-[[:space:]]+Q:[[:space:]]/ {
      flush()
      line = $0
      sub(/^-[[:space:]]+Q:[[:space:]]*/, "", line)
      q = line
      mode = "q"
      c = cite_in($0)
      if (c != "") card_cite = c
      next
    }
    # Start of the matching A line.
    in_section && /^[[:space:]]+A:[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+A:[[:space:]]*/, "", line)
      a = line
      mode = "a"
      c = cite_in($0)
      if (card_cite == "" && c != "") card_cite = c
      next
    }
    # Continuation of an answer (indented, not a new bullet).
    in_section && mode == "a" && /^[[:space:]]+[^-[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+/, " ", line)
      a = a line
      c = cite_in($0)
      if (card_cite == "" && c != "") card_cite = c
      next
    }
    # Any other in-section line (prose, blank): track the nearest citation seen
    # above the next card. The Q/A/continuation rules above all `next`, so this
    # only sees lines that are NOT part of the current card.
    in_section {
      c = cite_in($0)
      if (c != "") section_cite = c
    }
    END { flush() }
  ' "$file"
done
