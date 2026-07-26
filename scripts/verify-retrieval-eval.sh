#!/usr/bin/env bash
# scripts/verify-retrieval-eval.sh — oracle for the retrieval eval's corpus and
# graders. No LLM, no `claude` CLI, no spend — runnable in CI.
#
# An eval nobody checks measures nothing: a grader that always returns PASS
# reports a perfect score on a broken system, and a corpus whose needles sit
# inside the first page makes a truncating extractor look correct. This verifies
# the parts of scripts/eval-retrieval.sh that can be checked deterministically,
# so the only unverified thing left in a real run is the model's behaviour —
# which is the thing being measured.
#
#   E1 corpus deterministic  : two generations are byte-identical (scores are
#                              only comparable across runs if the input is fixed)
#   E2 needles past boundary : no needle appears in the first 40 lines of its
#                              source (a preview-only reader must NOT pass R1)
#   E3 answer grader honest  : correct answer passes, missing-needle answer fails
#   E4 citation grader tight : the exact locus passes; whole-file, wrong-line,
#                              and oversized-but-containing cites all FAIL
#                              (containment alone is the Goodhart hole here)
#   E5 refusal grader        : a decline passes; a confident fabrication matching
#                              forbids-pattern fails
#   E6 questions well-formed : every question parses with the fields its check
#                              needs (a missing cite-contains silently skips R4)
#
# Usage: ./scripts/verify-retrieval-eval.sh   Exit: 0 all green, 1 a check failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

GEN="tests/eval/retrieval-corpus/gen-corpus.sh"
QUESTIONS="tests/eval/retrieval-questions.md"
HOLDOUT_Q="tests/eval/retrieval-questions-holdout.md"
CITE_SPAN="$SCRIPT_DIR/cite-span.py"
# shellcheck source=scripts/lib/eval-common.sh
. "$SCRIPT_DIR/lib/eval-common.sh"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
A="$TMP/a"; B="$TMP/b"

# E1 — deterministic corpus
"$GEN" "$A" >/dev/null 2>&1; "$GEN" "$B" >/dev/null 2>&1
if diff -r "$A" "$B" >/dev/null 2>&1; then ok "E1 corpus generation is byte-identical across runs"
else fail "E1 corpus differs between runs (scores would not be comparable)"; fi

# E2 — every needle sits past a naive first-40-lines read
e2=0
for pair in "sales-2026.csv:NEEDLE-CSV-7f3a91" \
            "thread-q3-planning.eml:NEEDLE-EML-4c2d80" \
            "field-report.md:NEEDLE-DOC-9b17e5"; do
  f="${pair%%:*}"; needle="${pair##*:}"
  if ! grep -q -F "$needle" "$A/$f"; then
    fail "E2 needle $needle absent from $f"; e2=1
  elif head -40 "$A/$f" | grep -q -F "$needle"; then
    fail "E2 needle $needle is inside the first 40 lines of $f (a preview reader would pass)"; e2=1
  fi
done
[ "$e2" -eq 0 ] && ok "E2 all three needles planted past the first-40-lines boundary"

# E3 — answer grader
printf 'The row is ORD-00947 with note NEEDLE-CSV-7f3a91.\n' > "$TMP/good.md"
printf 'The dataset contains 1200 orders across four regions.\n' > "$TMP/vague.md"
e3=0
retr_grade_answer "$TMP/good.md"  "NEEDLE-CSV-7f3a91, ORD-00947" "" false || { fail "E3 correct answer graded FAIL"; e3=1; }
retr_grade_answer "$TMP/vague.md" "NEEDLE-CSV-7f3a91, ORD-00947" "" false && { fail "E3 answer missing the needle graded PASS"; e3=1; }
[ "$e3" -eq 0 ] && ok "E3 answer grader: needle-bearing passes, needle-less fails"

# E4 — citation grader: the Goodhart hole is "contains", so probe each way to fake it
mk() { printf 'Answer text. (source: %s)\n' "$1" > "$2"; }
mk 'raw/sales-2026.csv#L948'      "$TMP/c-exact.md"      # the locus
mk 'raw/sales-2026.csv'           "$TMP/c-wholefile.md"  # cite everything, prove nothing
mk 'raw/sales-2026.csv#L500'      "$TMP/c-wrongline.md"  # tight but wrong
mk 'raw/sales-2026.csv#L900-L960' "$TMP/c-oversized.md"  # contains it, gestures at 61 lines
printf 'Answer. (source: raw/field-report.md#scope-and-method) (source: raw/sales-2026.csv#L948)\n' \
  > "$TMP/c-multi.md"
e4=0
retr_grade_citation "$TMP/c-exact.md"     "$A" NEEDLE-CSV-7f3a91 5 "$CITE_SPAN" || { fail "E4 exact locus graded FAIL"; e4=1; }
retr_grade_citation "$TMP/c-wholefile.md" "$A" NEEDLE-CSV-7f3a91 5 "$CITE_SPAN" && { fail "E4 whole-file citation graded PASS"; e4=1; }
retr_grade_citation "$TMP/c-wrongline.md" "$A" NEEDLE-CSV-7f3a91 5 "$CITE_SPAN" && { fail "E4 wrong-line citation graded PASS"; e4=1; }
retr_grade_citation "$TMP/c-oversized.md" "$A" NEEDLE-CSV-7f3a91 5 "$CITE_SPAN" && { fail "E4 oversized citation graded PASS (span ignored)"; e4=1; }
retr_grade_citation "$TMP/c-multi.md"     "$A" NEEDLE-CSV-7f3a91 5 "$CITE_SPAN" || { fail "E4 correct citation among several graded FAIL"; e4=1; }
[ "$e4" -eq 0 ] && ok "E4 citation grader: only a passage that contains AND pinpoints passes"

# E5 — refusal grader
printf 'There is no Q2 2026 capacity report in the wiki; only Q1 and Q3 were ingested.\n' > "$TMP/refuse.md"
printf 'Q2 2026 sustained throughput was 400 GB/day.\n' > "$TMP/fabricate.md"
FORBIDS='Q2[^.]{0,80}[0-9]{3} ?GB'
e5=0
retr_grade_answer "$TMP/refuse.md"    "" "$FORBIDS" true || { fail "E5 honest refusal graded FAIL"; e5=1; }
retr_grade_answer "$TMP/fabricate.md" "" "$FORBIDS" true && { fail "E5 fabricated Q2 figure graded PASS"; e5=1; }
[ "$e5" -eq 0 ] && ok "E5 refusal grader: decline passes, fabricated figure fails"

# E6 — questions parse with the fields their check needs
e6=0
for qf in "$QUESTIONS" "$HOLDOUT_Q"; do
  tsv="$TMP/$(basename "$qf").tsv"
  retr_parse_questions "$qf" "$tsv"
  n=$(wc -l < "$tsv" | tr -d ' ')
  [ "$n" -ge 1 ] || { fail "E6 $qf parsed 0 questions"; e6=1; continue; }
  while IFS=$'\t' read -r qid question modality expects cite span forbids refusal; do
    question=$(retr_field "$question"); modality=$(retr_field "$modality")
    expects=$(retr_field "$expects");   cite=$(retr_field "$cite")
    span=$(retr_field "$span");         forbids=$(retr_field "$forbids")
    refusal=$(retr_field "$refusal")
    [ -z "$question" ] && { fail "E6 $qid has no question text"; e6=1; }
    [ -z "$modality" ] && { fail "E6 $qid has no modality"; e6=1; }
    if [ "$refusal" = "true" ]; then
      [ -z "$forbids" ] && { fail "E6 $qid is a refusal check with no forbids-pattern (nothing guards fabrication)"; e6=1; }
    else
      [ -z "$expects" ] && { fail "E6 $qid has no expects tokens"; e6=1; }
      [ -z "$cite" ] && { fail "E6 $qid has no cite-contains (R4 would silently skip it)"; e6=1; }
      [ -z "$span" ] && { fail "E6 $qid has no max-span (R4 would default-pass wide cites)"; e6=1; }
    fi
  done < "$tsv"
done
[ "$e6" -eq 0 ] && ok "E6 every question carries the fields its check scores on"

# E7 — the eval must refuse to score an unpopulated wiki, and must never let a
# nested claude inherit the question loop's stdin. Both were live bugs: a run
# reported 6/12 (R1 3/3, R2 2/2) against an empty wiki, because /wiki-query fell
# back to reading raw/ directly, and the first question's args had the rest of
# the eval table leaked into them off the loop's stdin.
EVAL="$SCRIPT_DIR/eval-retrieval.sh"
e7=0
grep -q 'VOID (not a score)' "$EVAL" \
  || { fail "E7 eval has no VOID gate (an empty wiki would be scored)"; e7=1; }
grep -q 'ingested" -eq 0' "$EVAL" \
  || { fail "E7 VOID gate does not check that any raw source was actually ingested"; e7=1; }
# Every nested invocation must pin stdin: the /dev/null is on the same line as
# the redirect, within two lines of the call.
sites=$(grep -c 'claude -p "' "$EVAL")
pinned=$(grep -A2 'claude -p "' "$EVAL" | grep -c '</dev/null')
if [ "$pinned" -lt "$sites" ]; then
  fail "E7 only $pinned of $sites nested 'claude -p' sites pin stdin to /dev/null"; e7=1
fi
[ "$e7" -eq 0 ] && ok "E7 eval voids an unpopulated wiki and pins nested-claude stdin ($sites sites)"

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d retrieval-eval check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s E1-E7 green — corpus fixed, needles deep, graders not fakeable, empty-wiki runs void.\n" "$GREEN" "$RESET"
exit 0
