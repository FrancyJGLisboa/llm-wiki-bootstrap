#!/usr/bin/env bash
# scripts/verify-entity-eval.sh — oracle for scripts/eval-entities.sh.
# No LLM, no spend, runnable in CI.
#
# The entity eval's two headline numbers are each individually gameable, so the
# only thing worth verifying is that the games actually LOSE. Each check below
# builds a wiki that plays one strategy and asserts the score punishes it.
#
#   N1 honest wiki        : good recall + no decoys + tight cites scores 3/3
#   N2 dump-everything    : capturing every Title Case phrase wins recall and
#                           MUST fail E2 (the false_pass for E1)
#   N3 obvious-only       : capturing two famous names wins precision and MUST
#                           fail E1 (the false_pass for E2)
#   N4 whole-file cites   : citing the document instead of the passage MUST fail
#                           E3 (the false_pass for E3)
#   N5 uncited entities   : bullets with no (source: …) MUST fail E3
#   N6 missing section    : no `## Entities` anywhere is reported as its own
#                           outcome, NOT as 0% recall — a section that was never
#                           written and one that is wrong need different fixes,
#                           and collapsing them hides which happened
#   N7 name parsing       : the entity name is taken from before the em-dash.
#                           BSD sed has no `\|` alternation, so an earlier
#                           version extracted the whole bullet (citation
#                           included) and E3 read 0% on correct data.
#
# Usage: ./scripts/verify-entity-eval.sh   Exit: 0 all green, 1 a check failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

EVAL="$SCRIPT_DIR/eval-entities.sh"
if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# A raw thread whose five From: headers are the gold set, one per line.
mkraw() {
  mkdir -p "$1/raw"
  { echo "From: Dan Okafor <dan@example.com>"
    echo "From: Mei Sato <mei@example.com>"
    echo "From: Priya Raman <priya@example.com>"
    echo "From: Tomas Vela <tomas@example.com>"
    echo "From: Ada Bekele <ada@example.com>"
    echo "Cutover set for 2026-08-19."
    for i in $(seq 1 40); do echo "Filler line $i to make whole-file cites wide."; done
  } > "$1/raw/thread.eml"
}
# entities <dir> <bullet>... — a summary page carrying those bullets
entities() {
  local d="$1"; shift; mkdir -p "$d/wiki"
  { echo "## Entities"; echo ""; for b in "$@"; do echo "$b"; done; } > "$d/wiki/s.md"
}
verdict() { "$EVAL" "$1" 2>/dev/null | grep -E "^$2" | grep -oE 'PASS|FAIL' | head -1; }

# N1 — honest
d="$TMP/n1"; mkraw "$d"
entities "$d" \
  "- Dan Okafor — closed the decision (source: raw/thread.eml#L1)" \
  "- Mei Sato — commented (source: raw/thread.eml#L2)" \
  "- Priya Raman — commented (source: raw/thread.eml#L3)" \
  "- Tomas Vela — commented (source: raw/thread.eml#L4)" \
  "- Ada Bekele — commented (source: raw/thread.eml#L5)"
if [ "$(verdict "$d" 'E1')" = PASS ] && [ "$(verdict "$d" 'E2')" = PASS ] && [ "$(verdict "$d" 'E3')" = PASS ]; then
  ok "N1 honest capture scores 3/3"
else
  fail "N1 an honest wiki did not score 3/3 (E1=$(verdict "$d" 'E1') E2=$(verdict "$d" 'E2') E3=$(verdict "$d" 'E3'))"
fi

# N2 — dump every Title Case phrase: recall wins, precision must lose
d="$TMP/n2"; mkraw "$d"
entities "$d" \
  "- Dan Okafor — x (source: raw/thread.eml#L1)" \
  "- Mei Sato — x (source: raw/thread.eml#L2)" \
  "- Priya Raman — x (source: raw/thread.eml#L3)" \
  "- Tomas Vela — x (source: raw/thread.eml#L4)" \
  "- Ada Bekele — x (source: raw/thread.eml#L5)" \
  "- Instrumentation Debt — x (source: raw/thread.eml#L1)" \
  "- Capacity Headroom — x (source: raw/thread.eml#L1)" \
  "- Schema Evolution — x (source: raw/thread.eml#L1)" \
  "- Replication Lag — x (source: raw/thread.eml#L1)" \
  "- Cold Start — x (source: raw/thread.eml#L1)"
if [ "$(verdict "$d" 'E1')" = PASS ] && [ "$(verdict "$d" 'E2')" = FAIL ]; then
  ok "N2 dump-everything wins recall and loses precision (E1's false_pass is priced)"
else
  fail "N2 capturing every Title Case phrase was not punished (E1=$(verdict "$d" 'E1') E2=$(verdict "$d" 'E2'))"
fi

# N3 — capture only the two obvious names: precision wins, recall must lose
d="$TMP/n3"; mkraw "$d"
entities "$d" \
  "- Dan Okafor — x (source: raw/thread.eml#L1)" \
  "- Mei Sato — x (source: raw/thread.eml#L2)"
if [ "$(verdict "$d" 'E2')" = PASS ] && [ "$(verdict "$d" 'E1')" = FAIL ]; then
  ok "N3 obvious-only wins precision and loses recall (E2's false_pass is priced)"
else
  fail "N3 capturing only the obvious names was not punished (E1=$(verdict "$d" 'E1') E2=$(verdict "$d" 'E2'))"
fi

# N4 — cite the document, not the passage
d="$TMP/n4"; mkraw "$d"
entities "$d" \
  "- Dan Okafor — x (source: raw/thread.eml)" \
  "- Mei Sato — x (source: raw/thread.eml)" \
  "- Priya Raman — x (source: raw/thread.eml)" \
  "- Tomas Vela — x (source: raw/thread.eml)" \
  "- Ada Bekele — x (source: raw/thread.eml)"
if [ "$(verdict "$d" 'E3')" = FAIL ]; then
  ok "N4 whole-file citations fail provenance (a gesture is not a locus)"
else
  fail "N4 whole-file citations passed E3"
fi

# N5 — no citations at all
d="$TMP/n5"; mkraw "$d"
entities "$d" "- Dan Okafor — x" "- Mei Sato — x" "- Priya Raman — x" \
              "- Tomas Vela — x" "- Ada Bekele — x"
if [ "$(verdict "$d" 'E3')" = FAIL ]; then
  ok "N5 uncited entities fail provenance"
else
  fail "N5 uncited entities passed E3"
fi

# N6 — no ## Entities section at all is a distinct outcome
d="$TMP/n6"; mkraw "$d"; mkdir -p "$d/wiki"
printf '# Summary\n\nNo entities section here.\n' > "$d/wiki/s.md"
# Captured into a variable rather than piped into `grep -q`: with `pipefail`,
# grep -q exits on the first match and closes the pipe, the eval takes SIGPIPE on
# its next write, and the pipeline reports failure on correct output.
n6_out=$("$EVAL" "$d" 2>/dev/null)
case "$n6_out" in
  *"NO ENTITIES CAPTURED"*)
    ok "N6 a missing ## Entities section is reported distinctly, not as 0% recall" ;;
  *)
    fail "N6 missing section was not distinguished from a wrong one" ;;
esac

# N7 — name parsing survives the em-dash (and BSD sed)
d="$TMP/n7"; mkraw "$d"
entities "$d" \
  "- Dan Okafor — a long trailing clause mentioning Mei Sato and others (source: raw/thread.eml#L1)" \
  "- Mei Sato — x (source: raw/thread.eml#L2)" \
  "- Priya Raman — x (source: raw/thread.eml#L3)" \
  "- Tomas Vela — x (source: raw/thread.eml#L4)" \
  "- Ada Bekele — x (source: raw/thread.eml#L5)"
if [ "$(verdict "$d" 'E3')" = PASS ]; then
  ok "N7 the name is parsed from before the em-dash, trailing prose ignored"
else
  fail "N7 a bullet with trailing prose broke name extraction (BSD sed alternation?)"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d entity-eval check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s N1-N7 green — recall and precision each punish the other's false pass.\n" "$GREEN" "$RESET"
exit 0
