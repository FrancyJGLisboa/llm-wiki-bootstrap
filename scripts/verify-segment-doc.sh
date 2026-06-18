#!/usr/bin/env bash
# scripts/verify-segment-doc.sh — deterministic oracle for the long-source
# segmenter (scripts/extract/segment-doc.py). Proves checks C1-C5 of
# .scratch/long-source-tree-retrieval/GOAL.md with exit codes. No agent needed.
#
#   C1 fixture exists with >= 6 sections
#   C2 deterministic: segmenter run twice -> byte-identical
#   C3 lossless: every non-blank source line survives into the sidecar
#   C4 anchored: every section emits a heading carrying a positional range
#   C5 anti-gaming: regenerating from source byte-matches the committed sidecar
#
# Usage: ./scripts/verify-segment-doc.sh
# Exit: 0 all green, 1 a check failed, 2 environment error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SEG="$REPO_ROOT/scripts/extract/segment-doc.py"
FIX="$REPO_ROOT/tests/segment/long-source.md"
EXPECTED="$REPO_ROOT/tests/segment/expected-sidecar.md"

if [ -t 1 ]; then
  RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  RED=; YELLOW=; GREEN=; RESET=
fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN"  "$RESET" "$1"; }
warn() { printf "%s⚠%s %s\n" "$YELLOW" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"    "$RESET" "$1"; failures=$((failures + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 2; }
[ -f "$SEG" ] || { echo "missing segmenter: $SEG" >&2; exit 2; }

# A regex matching a section heading that carries a positional range, e.g.
#   ## Overview (lines 6-12)      ### Methods — part 2 (lines 40-71)
#   # Intro (pages 1-5)
RANGE_RE='^#{1,6} .+\((lines|pages) [0-9]+-[0-9]+\)$'
# Strip the trailing range annotation back off a heading line.
DERANGE='s/ \((lines|pages) [0-9]+-[0-9]+\)$//'

# --- C1 ---------------------------------------------------------------------
if [ -f "$FIX" ]; then
  secs=$(grep -c '^## ' "$FIX" || true)
  if [ "$secs" -ge 6 ]; then ok "C1 fixture present with $secs sections"
  else fail "C1 fixture has only $secs sections (need >= 6)"; fi
else
  fail "C1 fixture missing: $FIX"; secs=0
fi

# --- C2 ---------------------------------------------------------------------
a=$(mktemp); b=$(mktemp)
python3 "$SEG" "$FIX" > "$a"
python3 "$SEG" "$FIX" > "$b"
if diff -q "$a" "$b" >/dev/null; then ok "C2 deterministic (two runs byte-identical)"
else fail "C2 non-deterministic — two runs differ"; fi

# --- C3 ---------------------------------------------------------------------
# Every non-blank source line must appear in the de-ranged sidecar (source is a
# subset of the sidecar's lines). Tolerates synthetic Preamble/part headings.
src_lines=$(mktemp); side_lines=$(mktemp)
grep -v '^[[:space:]]*$' "$FIX" | sed 's/[[:space:]]*$//' | sort -u > "$src_lines"
sed -E "$DERANGE" "$a" | grep -v '^[[:space:]]*$' | sed 's/[[:space:]]*$//' | sort -u > "$side_lines"
missing=$(comm -23 "$src_lines" "$side_lines" | wc -l | tr -d ' ')
if [ "$missing" -eq 0 ]; then ok "C3 lossless (all source lines present in sidecar)"
else fail "C3 lossy — $missing source line(s) absent from sidecar"; fi

# --- C4 ---------------------------------------------------------------------
ranged=$(grep -cE "$RANGE_RE" "$a" || true)
# Expect at least one ranged heading per source section.
if [ "$ranged" -ge "${secs:-6}" ]; then ok "C4 anchored ($ranged headings carry a positional range)"
else fail "C4 under-anchored ($ranged ranged headings < $secs sections)"; fi

# --- C5 ---------------------------------------------------------------------
if [ -f "$EXPECTED" ]; then
  if diff -q "$a" "$EXPECTED" >/dev/null; then ok "C5 anti-gaming (regenerated == committed expected-sidecar.md)"
  else fail "C5 drift — regenerated output differs from committed expected-sidecar.md (run: python3 $SEG $FIX > $EXPECTED)"; fi
else
  fail "C5 missing committed expected-sidecar.md"
fi

rm -f "$a" "$b" "$src_lines" "$side_lines"
echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d deterministic check(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s C1-C5 green — segmenter is deterministic, lossless, anchored, and tamper-evident.\n" "$GREEN" "$RESET"
exit 0
