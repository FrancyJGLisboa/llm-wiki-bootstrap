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
#   E7 empty wiki voids      : an unpopulated wiki is not scored, and nested
#                              `claude -p` never inherits the loop's stdin
#   E8 no answer = INCONC    : an API/network failure is excluded, not counted a
#                              loss — a dropped connection scored as FAIL reads
#                              exactly like a real capability gap
#   E9 clock-free            : no question asks about "now". Fixed corpus dates
#                              plus a present-tense question cannot both be
#                              right, and mis-scored a correct answer once
#   E10 multi-valued honest  : the M1 pair leaks nothing across docs, and the
#                              grader fails both false-pass routes (pick one
#                              figure; recite both but dismiss one as stale)
#   E11 supersession honest  : the M2 memo pair is cue-free (no supersession
#                              prose) and M2 is gated on a KG edge, not answer
#   E12 clarify honest       : M4 accepts ask-or-enumerate, fails a confident
#                              pick; the anti-reflex control is held out (H4)
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

# E3b — a vintage answer that LEADS with the wrong figure must fail even though
# the right figure appears further down. This is a real observed false pass: an
# as-of answer headlined 999 and passed on `expects: 412` because 412 turned up
# in a caveat explaining why 999 was suspect. The guard is the question's
# headline-anchored forbids-pattern, not a grader-wide rule — scoping `expects`
# to the first N lines was tried and failed answers that open with a preamble.
{ printf '**999 GB/day** — the Q1 2026 figure.\n\n'
  printf 'Caveat: the raw was edited from 412 to 999, so 412 may be the truth.\n'; } > "$TMP/buried.md"
printf '**412 GB/day** was the figure of record on that date.\n' > "$TMP/lead.md"
ASOF_FORBIDS='^[^a-zA-Z0-9]{0,4}(389|999)'
e3b=0
retr_grade_answer "$TMP/lead.md"   "412" "$ASOF_FORBIDS" false || { fail "E3b correct headline graded FAIL"; e3b=1; }
retr_grade_answer "$TMP/buried.md" "412" "$ASOF_FORBIDS" false && { fail "E3b wrong headline graded PASS (right figure buried in a caveat)"; e3b=1; }
[ "$e3b" -eq 0 ] && ok "E3b vintage answer leading with the wrong figure fails despite a later mention"

# E3c — every question with a competing wrong answer must carry that guard, or
# the false pass above silently returns the next time a question is added.
if [ "$(grep -c '^forbids-pattern:' "$QUESTIONS")" -lt 3 ]; then
  fail "E3c fewer than 3 forbids-patterns in $QUESTIONS (R2-asof, R2-current, R3-absent each need one)"
else
  ok "E3c both vintage questions and the refusal question carry a forbids-pattern"
fi

# E5b — an exemplary refusal must not be graded FAIL. This exact phrasing was a
# false negative: every marker required "for"/"in" straight after the noun.
printf 'No Q2 2026 sustained throughput figure exists in this wiki.\n\nI will not interpolate a value.\n' \
  > "$TMP/refuse2.md"
retr_grade_answer "$TMP/refuse2.md" "" 'Q2[^.]{0,80}[0-9]{3} ?GB' true \
  && ok "E5b 'no X figure exists in this wiki' is recognised as a refusal" \
  || fail "E5b textbook refusal graded FAIL (marker list too narrow)"

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

# E8 — a file holding no answer must be INCONCLUSIVE, never graded. An ENOTFOUND
# mid-run scored R5 as FAIL on a run where the drift logic was never invoked, and
# in the report that is indistinguishable from a real capability gap. Also asserts
# the eval excludes INCONC from the denominator rather than counting it as a loss.
printf 'API Error: Unable to connect to API (ENOTFOUND)\n' > "$TMP/broken.md"
printf 'API Error: 529 Overloaded.\n'                      > "$TMP/overloaded.md"
printf "You've hit your session limit · resets 10:40am\n"   > "$TMP/caplimit.md"
: > "$TMP/empty.md"
printf '**7 attempts per message**, per the April memo.\n' > "$TMP/real.md"
e8=0
retr_answer_broken "$TMP/broken.md"     || { fail "E8 ENOTFOUND answer would be graded as a real result"; e8=1; }
retr_answer_broken "$TMP/overloaded.md" || { fail "E8 529 answer would be graded as a real result"; e8=1; }
retr_answer_broken "$TMP/empty.md"      || { fail "E8 empty answer would be graded as a real result"; e8=1; }
# The session/usage cap is the one that actually bit: a full run's last two
# questions came back as "You've hit your session limit" and were scored FAIL,
# which in the report is indistinguishable from a refusal defect.
retr_answer_broken "$TMP/caplimit.md"   || { fail "E8 session-limit answer would be graded as a real result"; e8=1; }
retr_answer_broken "$TMP/real.md"       && { fail "E8 a genuine answer was flagged as broken"; e8=1; }
grep -q 'a_verdict=INCONC' "$SCRIPT_DIR/eval-retrieval.sh" \
  || { fail "E8 eval does not mark unanswerable questions INCONC"; e8=1; }
grep -q 'if \[ "\$a_verdict" = INCONC \]' "$SCRIPT_DIR/eval-retrieval.sh" \
  || { fail "E8 eval counts INCONC into the score instead of excluding it"; e8=1; }
[ "$e8" -eq 0 ] && ok "E8 no-answer files are INCONCLUSIVE and excluded, not scored as failures"

# E9 — the corpus must not ask about "now". Fixed dates plus a question about the
# present cannot both be right: a memo dated after the run date is not yet
# published, so the honest "now" answer is the older figure. That mis-scored a
# correct answer as FAIL once.
e9=0
grep -qE '^What is .*\bnow\b' "$QUESTIONS" \
  && { fail "E9 a question asks about \"now\" — clock-dependent against a fixed corpus"; e9=1; }
if grep -hoE 'Published: 20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$GEN" | grep -qv 'Published: 2026-0[1-4]'; then
  fail "E9 a corpus Published: date is late enough to fall after a plausible run date"; e9=1
fi
[ "$e9" -eq 0 ] && ok "E9 no \"now\" questions; corpus dates stay behind the run date"

# E10 — M1 multi-valued grader: the corpus holds two coequal scoped answers, and
# only an answer surfacing BOTH figures WITH their scopes may pass. The two
# false-pass routes are probed directly: pick-one (missing tokens) and
# recite-both-but-dismiss-one-as-stale (forbids-pattern). Each corpus doc must
# also state ONLY its own figure — if either leaks the other's, a single read
# yields all tokens and M1 stops measuring synthesis across documents.
M1_EXPECTS="180 days, 30 days, production, sandbox"
M1_FORBIDS='[Oo]utdated|[Oo]bsolete|[Ss]tale'
printf 'Depends on scope: production logs are kept 180 days, sandbox logs 30 days.\n' > "$TMP/m1-both.md"
printf 'Application logs are retained for 180 days before purge.\n' > "$TMP/m1-one.md"
printf '180 days for production; a sandbox doc says 30 days but looks stale.\n' > "$TMP/m1-dismiss.md"
e10=0
retr_grade_answer "$TMP/m1-both.md"    "$M1_EXPECTS" "$M1_FORBIDS" false || { fail "E10 both-figures-with-scopes answer graded FAIL"; e10=1; }
retr_grade_answer "$TMP/m1-one.md"     "$M1_EXPECTS" "$M1_FORBIDS" false && { fail "E10 pick-one answer graded PASS"; e10=1; }
retr_grade_answer "$TMP/m1-dismiss.md" "$M1_EXPECTS" "$M1_FORBIDS" false && { fail "E10 dismissive answer graded PASS (one value waved off as stale)"; e10=1; }
grep -q -F '180 days' "$A/log-retention-production.md" || { fail "E10 production doc missing its figure"; e10=1; }
grep -q -F '30 days'  "$A/log-retention-sandbox.md"    || { fail "E10 sandbox doc missing its figure"; e10=1; }
grep -q -F '30 days'  "$A/log-retention-production.md" && { fail "E10 production doc leaks the sandbox figure (single read would pass M1)"; e10=1; }
grep -q -F '180 days' "$A/log-retention-sandbox.md"    && { fail "E10 sandbox doc leaks the production figure (single read would pass M1)"; e10=1; }
[ "$e10" -eq 0 ] && ok "E10 M1 grader: only both-figures-both-scopes passes; corpus docs don't leak each other"

# E11 — M2 corpus honesty: the retry memo pair carries NO supersession prose, so
# the typed edge can only come from same-subject + date inference (T2
# discipline). If a cue word creeps into a memo body, the edge stops proving
# inference. Also assert the eval gates M2 on the KG edge, not just the answer —
# a right answer alone proves date reasoning, not machine-readable succession.
e11=0
for f in retry-budget-memo-feb.md retry-budget-memo-apr.md; do
  if grep -qiE 'supersede|replace|obsolet|outdated|current|previous|newer|older' "$A/$f"; then
    fail "E11 $f contains supersession prose (the edge would be authorable from a cue)"; e11=1
  fi
done
grep -q '"verb": "supersede' "$SCRIPT_DIR/eval-retrieval.sh" \
  || { fail "E11 eval does not gate M2 on a supersedes edge in the KG"; e11=1; }
[ "$e11" -eq 0 ] && ok "E11 retry memos are cue-free and M2 is KG-gated, not answer-only"

# E12 — M4 clarify grader: ambiguity must be surfaced with every candidate
# reading named. Asking which is meant and enumerating all readings both pass
# (enumeration is the better answer); a confident single pick fails on marker
# and/or missing candidates. The anti-reflex control is held out: H4-direct has
# one overwhelmingly likely reading and FORBIDS clarify markers, so "clarify on
# everything" cannot become the safe default.
M4_EXPECTS="log, backup"
printf 'Ambiguous — do you mean application logs or database backups?\n' > "$TMP/m4-ask.md"
printf 'It depends on which system: application logs (180/30 days by environment) or database backups (35 days).\n' > "$TMP/m4-enum.md"
printf '35 days.\n' > "$TMP/m4-guess.md"
printf 'The retention period for application logs is 180 days.\n' > "$TMP/m4-pick.md"
e12=0
retr_grade_answer "$TMP/m4-ask.md"   "$M4_EXPECTS" "" clarify || { fail "E12 clarifying question graded FAIL"; e12=1; }
retr_grade_answer "$TMP/m4-enum.md"  "$M4_EXPECTS" "" clarify || { fail "E12 enumerate-all-readings answer graded FAIL"; e12=1; }
retr_grade_answer "$TMP/m4-guess.md" "$M4_EXPECTS" "" clarify && { fail "E12 bare confident figure graded PASS"; e12=1; }
retr_grade_answer "$TMP/m4-pick.md"  "$M4_EXPECTS" "" clarify && { fail "E12 confident single pick graded PASS"; e12=1; }
grep -q 'refusal: clarify' "$QUESTIONS" || { fail "E12 no clarify question in $QUESTIONS"; e12=1; }
grep -qE 'forbids-pattern:.*mean' "$HOLDOUT_Q" \
  || { fail "E12 holdout lacks the anti-reflex control (clarify markers must be forbidden there)"; e12=1; }
[ "$e12" -eq 0 ] && ok "E12 M4 grader: ask or enumerate passes, confident pick fails; anti-reflex held out"

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
    elif [ "$refusal" = "clarify" ]; then
      # A clarify check needs the candidate readings in expects; a citation is
      # not required (a clarification needn't cite).
      [ -z "$expects" ] && { fail "E6 $qid is a clarify check with no expects (candidate readings unguarded)"; e6=1; }
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
printf "%sPassed.%s E1-E12 green — corpus fixed, graders not fakeable, empty-wiki voids, no-answer excluded, clock-free, multi-valued/supersession/clarify honest.\n" "$GREEN" "$RESET"
exit 0
