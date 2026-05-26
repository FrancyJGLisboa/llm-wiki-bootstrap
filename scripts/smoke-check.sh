#!/usr/bin/env bash
# scripts/smoke-check.sh — pure-shell assertions for the smoke (C1–C5 in GOAL.md §3).
#
# Sub-second. No LLM calls. Reads the artifacts produced by smoke-build.sh.
# Exit 0 only if all 5 smoke checks pass.
#
# Each check has a single shell predicate; if the predicate exits non-zero,
# the check is red and we exit 1 with a clear diagnostic.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/smoke/smoke-source.md"
BASELINE="tests/smoke/output/baseline-wiki.txt"
LAST_ANSWER="tests/smoke/output/last-answer.md"
RAW="raw/smoke-source.md"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  RED=; GREEN=; RESET=
fi

failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

# C1 — fixture exists with the 3 fictitious anchors
check_c1() {
  if [ ! -f "$FIXTURE" ]; then
    fail "C1 fixture missing: $FIXTURE"
    return
  fi
  if grep -q 'Quortex protocol' "$FIXTURE" \
     && grep -q 'Dr\. Alma Voss' "$FIXTURE" \
     && grep -q '47 phase rotations' "$FIXTURE"; then
    ok "C1 fixture has all 3 anchors (Quortex protocol / Dr. Alma Voss / 47 phase rotations)"
  else
    fail "C1 fixture missing one or more anchors"
  fi
}

# C2 — ingest produced ≥1 NEW wiki page containing 'Quortex' (anti-gaming)
check_c2() {
  if [ ! -f "$BASELINE" ]; then
    fail "C2 baseline manifest missing: $BASELINE (run smoke-build.sh first)"
    return
  fi
  local found=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -f "$f" ] && grep -qF 'Quortex' "$f"; then
      found="$f"
      break
    fi
  done < <(comm -13 <(sort "$BASELINE") <(ls wiki/*.md 2>/dev/null | sort))
  if [ -n "$found" ]; then
    ok "C2 new wiki page containing 'Quortex': $found"
  else
    fail "C2 no new wiki/*.md page (created since baseline) contains 'Quortex'"
  fi
}

# C3 — log.md cites raw/smoke-source.md
check_c3() {
  if [ ! -f log.md ]; then
    fail "C3 log.md missing"
    return
  fi
  if grep -qF 'raw/smoke-source.md' log.md; then
    ok "C3 log.md cites raw/smoke-source.md"
  else
    fail "C3 log.md does not reference raw/smoke-source.md"
  fi
}

# C4 — captured query answer recalls '47 phase rotations' AND cites raw/smoke-source.md
check_c4() {
  if [ ! -f "$LAST_ANSWER" ]; then
    fail "C4 last-answer.md missing: $LAST_ANSWER"
    return
  fi
  local has_anchor=no has_cite=no
  grep -qF '47 phase rotations' "$LAST_ANSWER" && has_anchor=yes
  grep -qF 'raw/smoke-source.md' "$LAST_ANSWER" && has_cite=yes
  if [ "$has_anchor" = yes ] && [ "$has_cite" = yes ]; then
    ok "C4 answer has '47 phase rotations' AND cites raw/smoke-source.md"
  else
    fail "C4 answer missing anchor (anchor=$has_anchor, cite=$has_cite)"
  fi
}

# C5 — raw/smoke-source.md has non-empty ingested_hash (proof /wiki-ingest ran)
check_c5() {
  if [ ! -f "$RAW" ]; then
    fail "C5 raw/smoke-source.md missing"
    return
  fi
  if grep -qE '^ingested_hash: (sha256:)?[0-9a-f]{16,}' "$RAW"; then
    ok "C5 raw/smoke-source.md has populated ingested_hash"
  else
    fail "C5 raw/smoke-source.md ingested_hash empty or malformed"
  fi
}

check_c1
check_c2
check_c3
check_c4
check_c5

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d of 5 smoke checks did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s All 5 smoke checks green.\n" "$GREEN" "$RESET"
