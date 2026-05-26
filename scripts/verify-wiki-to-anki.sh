#!/usr/bin/env bash
# scripts/verify-wiki-to-anki.sh — verify wiki-to-anki.sh produces output with
# the expected shape against the canary flashcards fixture.
#
# Scope:
#   Validates SHAPE, not SEMANTICS. The verifier catches:
#     - Exporter exits non-zero
#     - Header row missing or wrong
#     - No data rows produced from the canary fixture
#     - CSV columns malformed (wrong field count on a row)
#   It does NOT catch:
#     - Whether the Q/A pairs are pedagogically useful
#     - Whether Anki imports the CSV without warnings (a manual eyeball step)
#
# Usage:
#   ./scripts/verify-wiki-to-anki.sh
#
# Exit codes:
#   0 — all shape checks passed
#   1 — at least one check failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# TTY-aware coloring
if [ -t 1 ]; then
  RED=$'\033[31m'
  YELLOW=$'\033[33m'
  GREEN=$'\033[32m'
  RESET=$'\033[0m'
else
  RED=
  YELLOW=
  GREEN=
  RESET=
fi

failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN"  "$RESET" "$1"; }
warn() { printf "%s⚠%s %s\n" "$YELLOW" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"    "$RESET" "$1"; failures=$((failures + 1)); }

fixture_dir="$REPO_ROOT/tests/canary"
fixture_file="$fixture_dir/canary-flashcards.md"

if [ ! -f "$fixture_file" ]; then
  fail "fixture missing: $fixture_file"
  echo
  printf "%sFailed.%s Canary fixture is required for this verifier.\n" "$RED" "$RESET"
  exit 1
fi
ok "fixture present: tests/canary/canary-flashcards.md"

# Run the exporter against the canary dir and capture output.
out_file="$(mktemp)"
trap 'rm -f "$out_file"' EXIT

if ! "$SCRIPT_DIR/wiki-to-anki.sh" "$fixture_dir" > "$out_file" 2>&1; then
  fail "wiki-to-anki.sh exited non-zero"
  cat "$out_file" >&2
  echo
  printf "%sFailed.%s\n" "$RED" "$RESET"
  exit 1
fi
ok "wiki-to-anki.sh exited 0"

# Header row check.
header="$(head -n 1 "$out_file")"
if [ "$header" = "Front,Back,Tags" ]; then
  ok "header row: ${header}"
else
  fail "header row wrong — got '${header}', expected 'Front,Back,Tags'"
fi

# Data row count.
data_rows="$(tail -n +2 "$out_file" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
if [ "$data_rows" -ge 1 ]; then
  ok "data rows: ${data_rows} (expected ≥1)"
else
  fail "no data rows produced from canary fixture"
fi

# Field count per row (every row should have exactly 3 fields once you
# account for quoted commas). Use awk in CSV-aware mode: split on commas
# that are NOT inside double quotes.
bad_rows="$(awk '
  NR == 1 { next }
  {
    n = 0; in_q = 0
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (c == "\"") in_q = !in_q
      else if (c == "," && !in_q) n++
    }
    # n commas => n+1 fields. We expect 3 fields => 2 commas.
    if (n != 2) print NR": "n+1" fields"
  }
' "$out_file")"

if [ -z "$bad_rows" ]; then
  ok "every data row has exactly 3 fields"
else
  fail "rows with wrong field count:"
  printf '  %s\n' "$bad_rows" >&2
fi

echo

if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d shape check(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi

warn "semantics — whether the Q/A pairs are useful, and whether Anki imports them cleanly — still need a human eye."
printf "%sPassed.%s Shape checks all green.\n" "$GREEN" "$RESET"
exit 0
