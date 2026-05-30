#!/usr/bin/env bash
# scripts/verify-citation-audit.sh — assert the C1+C2 deterministic floor of the
# citation-faithfulness eval actually catches broken citations.
#
# Runs scripts/citation-audit.py against tests/eval/faithfulness-fixture/, which
# plants four cases:
#   page-good.md          — resolves + (live judge) faithful
#   page-unfaithful.md    — resolves but contradicts evidence (caught only by C3)
#   page-broken-file.md   — cites a nonexistent raw file        (C1 must flag)
#   page-broken-anchor.md — cites a nonexistent heading anchor  (C2 must flag)
#
# This pins the deterministic half (no LLM): the floor must flag exactly the two
# broken citations and must NOT flag the two that resolve. The C3 entailment
# teeth are proven by a live `scripts/eval-citation-faithfulness.sh` run (needs
# the claude CLI, like the smoke harness) — not here.
#
# Exit 0 iff the floor behaves correctly.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

AUDIT="$SCRIPT_DIR/citation-audit.py"
WIKI="tests/eval/faithfulness-fixture/wiki"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

command -v python3 >/dev/null 2>&1 || { fail "python3 required"; exit 1; }

report="$(python3 "$AUDIT" "$WIKI" 2>&1)"; rc=$?

# 1. Non-zero exit because broken citations exist.
[ "$rc" -ne 0 ] && ok "audit exits non-zero (broken citations present)" \
                || fail "audit exited 0 — broken citations not detected"

# 2. The broken-file case is flagged (C1).
printf '%s' "$report" | grep -q 'page-broken-file.md.*file missing' \
  && ok "C1 flags the nonexistent raw file" \
  || fail "C1 did not flag page-broken-file.md"

# 3. The broken-anchor case is flagged (C2).
printf '%s' "$report" | grep -q 'page-broken-anchor.md.*anchor unresolved' \
  && ok "C2 flags the nonexistent heading anchor" \
  || fail "C2 did not flag page-broken-anchor.md"

# 4. The two resolving pages are NOT flagged (no false positives on the floor).
if printf '%s' "$report" | grep -qE 'page-good\.md|page-unfaithful\.md'; then
  fail "floor false-positive: a resolving citation was flagged as broken"
else
  ok "resolving citations (good + unfaithful) pass the floor — C3's job to judge"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s).\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s Citation-audit floor catches broken citations and passes resolving ones.\n" "$GREEN" "$RESET"
exit 0
