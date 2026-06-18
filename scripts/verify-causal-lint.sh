#!/usr/bin/env bash
# scripts/verify-causal-lint.sh — oracle for the causal lint (wiki-lint-causal.sh).
# Mirrors the R6/R7 good/bad/wiki idiom. No agent, no key.
#
#   L1 canonical accepted : the good causal fixture (canonical verbs) → exit 0
#   L2 synonyms rejected   : the bad fixture (≥3 synonyms → ≥2 canonicals) → exit≠0
#                            AND stderr names EACH synonym's correct canonical
#                            (a lint that special-cases one verb fails this)
#   L3 real wiki clean     : wiki/ has no causal-synonym misuse → exit 0
#
# Usage: ./scripts/verify-causal-lint.sh   Exit: 0 all green, 1 a check failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

LINT="scripts/wiki-lint-causal.sh"
GOOD="tests/canary/causal-fixture"
BAD="tests/canary/causal-fixture-bad"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

# L1 — canonical accepted
if "$LINT" "$GOOD" >/dev/null 2>&1; then ok "L1 good fixture (canonical verbs) accepted"
else fail "L1 good fixture rejected (canonical verbs should pass)"; fi

# L2 — synonyms rejected, each with its correct canonical suggestion
err=$("$LINT" "$BAD" 2>&1 >/dev/null); rc=$?
miss=0
for pair in 'results-in.*causes' 'due-to.*caused-by' 'enabled-by.*enables'; do
  printf '%s' "$err" | grep -Eq "$pair" || { fail "L2 missing suggestion for ${pair%%.*}"; miss=1; }
done
if [ "$rc" -ne 0 ] && [ "$miss" -eq 0 ]; then ok "L2 synonym fixture rejected; all 3 canonical suggestions present"
elif [ "$rc" -eq 0 ]; then fail "L2 synonym fixture wrongly accepted (exit 0)"; fi

# L3 — real wiki clean
if "$LINT" wiki/ >/dev/null 2>&1; then ok "L3 wiki/ has no causal-synonym misuse"
else fail "L3 wiki/ flagged (unexpected causal synonyms in the real wiki)"; fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d causal-lint check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s L1-L3 green — causal lint accepts canonical, rejects synonyms with suggestions.\n" "$GREEN" "$RESET"
exit 0
