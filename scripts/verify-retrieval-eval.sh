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
#   E13 caps + misgradings   : a model-cap message is no-answer (not a wrong
#                              answer), count-and-refuse is a clarification, an
#                              unexercised R5 is not a loss, and the VOID gate
#                              counts commitments rather than files
#   E14 loop corpus honest   : M5's three legs are separately dated and never
#                              name the cycle, so a closed loop can only come
#                              from composition; graded on a graph cycle
#   E15 prose is not a log   : an uppercase transport code is matched as a
#                              TOKEN (ENOTFOUND fired inside
#                              ModuleNotFoundError and voided a good answer),
#                              and markdown emphasis is normalised before any
#                              prose match (**three** retention windows)
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
# shellcheck source=scripts/lib/commitment.sh
. "$SCRIPT_DIR/lib/commitment.sh"

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
grep -q 'committed" -eq 0' "$EVAL" \
  || { fail "E7 VOID gate does not check that any raw source was actually committed"; e7=1; }
# Every nested invocation must pin stdin: the /dev/null is on the same line as
# the redirect, within two lines of the call.
sites=$(grep -c 'claude -p "' "$EVAL")
pinned=$(grep -A2 'claude -p "' "$EVAL" | grep -c '</dev/null')
if [ "$pinned" -lt "$sites" ]; then
  fail "E7 only $pinned of $sites nested 'claude -p' sites pin stdin to /dev/null"; e7=1
fi
[ "$e7" -eq 0 ] && ok "E7 eval voids an unpopulated wiki and pins nested-claude stdin ($sites sites)"

# ── E13: the two misgradings a real 500-page run produced ────────────────────
# Both were scored as capability failures when neither was one. Locked in here
# because each cost a whole scored run: the first read as "quality collapses at
# scale" (it was a model cap), the second as "clarify-on-ambiguity regressed"
# (it was the best answer in the run, phrased in a shape the markers missed).
e13=0

# (a) A model-cap message is NO ANSWER — excluded, never graded FAIL.
printf "You've reached your Fable 5 limit. Run /usage-credits to continue or switch models with /model.\n" > "$TMP/cap.md"
retr_answer_broken "$TMP/cap.md" || { fail "E13 model-cap message not recognised as a non-answer"; e13=1; }
printf 'You have reached your weekly limit. Upgrade to continue.\n' > "$TMP/cap2.md"
retr_answer_broken "$TMP/cap2.md" || { fail "E13 alternate cap phrasing not recognised"; e13=1; }
# A real answer that merely mentions a limit is NOT broken (no over-broadening).
printf 'The retry budget is 7 attempts, the documented per-message limit.\n' > "$TMP/notcap.md"
retr_answer_broken "$TMP/notcap.md" && { fail "E13 real answer mentioning a limit misread as broken"; e13=1; }

# (b) Counting the readings and refusing the single pick IS a clarification.
printf 'There are three retention periods, not one: production logs 180 days, sandbox logs 30 days, database backup 35 days.\n' > "$TMP/m4-count.md"
retr_grade_answer "$TMP/m4-count.md" "$M4_EXPECTS" "" clarify \
  || { fail "E13 count-and-refuse enumeration graded FAIL (the strongest M4 shape)"; e13=1; }
# …and the confident single pick still fails, so (b) did not loosen the check.
retr_grade_answer "$TMP/m4-pick.md" "$M4_EXPECTS" "" clarify \
  && { fail "E13 broadened markers let a confident single pick through"; e13=1; }

# (c) An inconclusive R5 precondition must not be scored as a failed check.
grep -q 'r5_total=0' "$EVAL" \
  || { fail "E13 eval never zeroes r5_total — an unexercised R5 is counted as a loss"; e13=1; }
grep -q 'Commitment: \$committed' "$EVAL" \
  || { fail "E13 report lacks the ingest-commitment line (the real signal behind R5 inconclusives)"; e13=1; }

# (d) The commitment sensor must not cry wolf. Replay its exact loop over a
# fixture raw/ holding: a committed source, an UNcommitted one (the real
# signal), scaffolding, filler, and a .csv whose hash lives on its .md sidecar.
# Truth is 2/3 — the first run of this line printed "22/12", a numerator above
# its own denominator, by counting all four wrong things.
fx="$TMP/rawfx"; mkdir -p "$fx"
printf -- '---\ningested_hash: "abc123def"\n---\nbody\n' > "$fx/committed.md"
printf -- '---\ningested_hash: ""\n---\nbody\n'          > "$fx/uncommitted.md"
printf -- '---\ningested_hash: "9f9f9f9f"\n---\nbody\n'  > "$fx/scale-billing-ops-notes.md"
: > "$fx/.gitkeep"
printf 'a,b\n1,2\n'                                       > "$fx/sales.csv"
printf -- '---\ningested_hash: "cafe1234"\n---\nparsed\n' > "$fx/sales.csv.md"
fx_committed=0; fx_total=0
while IFS= read -r f; do
  base=$(basename "$f")
  case "$base" in .*|scale-*) continue ;; esac
  case "$f" in *.md) [ -f "${f%.md}" ] && continue ;; esac
  fx_total=$((fx_total + 1))
  if has_commitment "$f"; then
    fx_committed=$((fx_committed + 1))
  fi
done < <(find "$fx" -type f | sort)
[ "$fx_total" -eq 3 ] \
  || { fail "E13 commitment denominator counts non-sources (got $fx_total, want 3: committed, uncommitted, sales.csv)"; e13=1; }
[ "$fx_committed" -eq 2 ] \
  || { fail "E13 commitment numerator wrong (got $fx_committed, want 2 — the .csv is committed via its .md sidecar)"; e13=1; }
[ "$fx_committed" -le "$fx_total" ] \
  || { fail "E13 numerator exceeds denominator — the original 22/12 bug"; e13=1; }
# (e) The VOID gate must consume the counted loop, never a `grep -rlc` pipeline:
# -l mixed with -c emits a line per file (non-matches included), so the gate
# counted FILES and scored a run whose provenance layer was entirely missing.
grep -q 'if \[ "\$pages" -le 1 \] || \[ "\$committed" -eq 0 \]' "$EVAL" \
  || { fail "E13 VOID gate does not gate on \$committed"; e13=1; }
# Code lines only — the comment above the fix names the banned form on purpose.
grep -v '^[[:space:]]*#' "$EVAL" | grep -q 'grep -rlc' \
  && { fail "E13 'grep -rlc' is back in code — it counts files, not commitments"; e13=1; }
[ "$e13" -eq 0 ] && ok "E13 model caps excluded, count-and-refuse clarifications pass, unexercised R5 not a loss"

# ── E14: M5's loop corpus states the legs and never the loop ─────────────────
e14=0
m5_files="$A/alerting-queue-depth-note.md $A/oncall-rotation-note.md $A/incident-review-backlog.md"
for f in $m5_files; do
  [ -f "$f" ] || { fail "E14 M5 source missing: $(basename "$f")"; e14=1; }
done
if [ "$e14" -eq 0 ]; then
  # The cycle must be unliftable from any single body: no loop vocabulary at all.
  if grep -qiE 'loop|cycle|feedback|reinforc|spiral|vicious|self-sustain' $m5_files; then
    fail "E14 M5 corpus names the cycle — the answer could be lifted from one source"; e14=1
  fi
  # Each source must state exactly one leg with an explicit causal verb, so the
  # check measures whether ingest TYPES narrated causation (not whether it can
  # infer causation from nothing).
  for pair in "alerting-queue-depth-note.md:causes a rise in pager volume" \
              "oncall-rotation-note.md:causes the on-call rotation to mute" \
              "incident-review-backlog.md:cause further growth in ingest queue depth"; do
    f="$A/${pair%%:*}"; needle="${pair#*:}"
    grep -qF "$needle" "$f" || { fail "E14 $(basename "$f") lost its causal leg ('$needle')"; e14=1; }
  done
  # Three distinct vintages: the legs are separately dated, so composing them
  # is cross-source work, not one document's narrative.
  n_dates=$(grep -h '^Published:' $m5_files | sort -u | wc -l | tr -d ' ')
  [ "$n_dates" -eq 3 ] || { fail "E14 M5 legs are not three distinct vintages (got $n_dates)"; e14=1; }
  # The eval must gate M5 on a REINFORCING cycle in the materialised graph.
  grep -q 'wiki-loops.py' "$EVAL" \
    || { fail "E14 eval never materialises loops — M5's structural leg is missing"; e14=1; }
  grep -q "grep '\^reinforcing:'" "$EVAL" \
    || { fail "E14 eval does not require a reinforcing cycle for M5"; e14=1; }
  # Grading: a correct walk passes; denying the loop fails on the forbids.
  M5_EXPECTS="pager, mut, queue"
  M5_FORBIDS='no (such )?(feedback|self-reinforcing|reinforcing) (loop|cycle|dynamic)'
  printf 'Queue depth growth raises pager volume; sustained paging leads the on-call to mute the noisiest rules; muted rules let the queue grow further.\n' > "$TMP/m5-walk.md"
  retr_grade_answer "$TMP/m5-walk.md" "$M5_EXPECTS" "$M5_FORBIDS" false \
    || { fail "E14 a correct cycle walk graded FAIL"; e14=1; }
  printf 'There is no self-reinforcing loop between queue depth and paging in this wiki.\n' > "$TMP/m5-deny.md"
  retr_grade_answer "$TMP/m5-deny.md" "$M5_EXPECTS" "$M5_FORBIDS" false \
    && { fail "E14 denying the loop graded PASS"; e14=1; }
  # A partial walk (one leg only) must not pass — every node is required.
  printf 'Growing queue depth raises pager volume.\n' > "$TMP/m5-partial.md"
  retr_grade_answer "$TMP/m5-partial.md" "$M5_EXPECTS" "$M5_FORBIDS" false \
    && { fail "E14 a one-leg partial walk graded PASS"; e14=1; }
fi
[ "$e14" -eq 0 ] && ok "E14 M5 loop corpus states legs not loops, three vintages, graded on a closed cycle"

# ── E15: prose is not a log, and markdown is not plain text ──────────────────
# Two misgradings from one real run, both the same species — a pattern matching
# inside ordinary writing instead of against the thing it names.
e15=0

# (a) An uppercase transport code is a TOKEN. Matched case-insensitively as a
# substring, `ENOTFOUND` fires inside `ModuleNotFoundError`, and a complete
# correct answer is reported as "no answer reached us".
printf 'The lint crashes with ModuleNotFoundError because scripts/lib/wikitext.py is absent.\n' > "$TMP/prose-err.md"
retr_answer_broken "$TMP/prose-err.md" \
  && { fail "E15 answer mentioning ModuleNotFoundError misread as a transport failure"; e15=1; }
printf 'request to api.anthropic.com failed: ENOTFOUND\n' > "$TMP/real-err.md"
retr_answer_broken "$TMP/real-err.md" \
  || { fail "E15 a real ENOTFOUND is no longer recognised"; e15=1; }
printf 'The socket was closed: ECONNRESET.\n' > "$TMP/real-err2.md"
retr_answer_broken "$TMP/real-err2.md" \
  || { fail "E15 a real ECONNRESET is no longer recognised"; e15=1; }

# (b) Markdown emphasis must not defeat prose matching. The model bolds its
# count; the marker looking for "three retention window" then sees
# "three** retention" and the best answer in the run grades FAIL.
printf 'The question is under-specified — the wiki holds **three** retention windows: production logs, sandbox logs, and database backups.\n' > "$TMP/m4-bold.md"
retr_grade_answer "$TMP/m4-bold.md" "log, backup" "" clarify \
  || { fail "E15 bolded-count clarification graded FAIL (markdown defeated the markers)"; e15=1; }
# …and an emphasised expects token must still be found.
printf 'The current budget is **7** attempts per message.\n' > "$TMP/bold-token.md"
retr_grade_answer "$TMP/bold-token.md" "7 attempts" "" false \
  || { fail "E15 emphasised expects token not matched after normalisation"; e15=1; }
# …while a confident single pick still fails, so (b) loosened nothing.
retr_grade_answer "$TMP/m4-pick.md" "log, backup" "" clarify \
  && { fail "E15 normalisation let a confident single pick pass M4"; e15=1; }
# …and a headline-anchored forbids still fires through emphasis.
printf '**999 GB/day** was the figure.\n' > "$TMP/bold-wrong.md"
retr_grade_answer "$TMP/bold-wrong.md" "412" '^[^a-zA-Z0-9]{0,4}(389|999)' false \
  && { fail "E15 emphasised wrong headline slipped past its forbids-pattern"; e15=1; }
[ "$e15" -eq 0 ] && ok "E15 error codes matched as tokens, markdown emphasis normalised, guards intact"

# ── E16: M6 citation integrity — a receipt that cannot be checked ────────────
# R4 asks whether ONE citation is good; M6 asks whether ANY citation is a lie.
# The observed failure: an answer cited `field-report.md#instrumentation-debt`,
# an anchor absent from that file, and passed everything else on its question.
e16=0
printf 'Answer. (source: raw/sales-2026.csv#L948)\n' > "$TMP/i-good.md"
retr_cite_integrity "$TMP/i-good.md" "$A" "$CITE_SPAN" \
  || { fail "E16 a resolving citation graded as unresolvable"; e16=1; }
[ "${RETR_CITE_TOTAL:-0}" -eq 1 ] || { fail "E16 citation count wrong (got ${RETR_CITE_TOTAL:-unset}, want 1)"; e16=1; }

printf 'Answer. (source: raw/field-report.md#no-such-anchor-here)\n' > "$TMP/i-anchor.md"
retr_cite_integrity "$TMP/i-anchor.md" "$A" "$CITE_SPAN" \
  && { fail "E16 a non-existent ANCHOR graded as resolving (the observed defect)"; e16=1; }

printf 'Answer. (source: raw/not-a-real-file.md#L1)\n' > "$TMP/i-file.md"
retr_cite_integrity "$TMP/i-file.md" "$A" "$CITE_SPAN" \
  && { fail "E16 a non-existent FILE graded as resolving"; e16=1; }

# One bad target among several good ones must still fail, and be named.
printf 'A. (source: raw/sales-2026.csv#L948) (source: raw/field-report.md#nope-not-here)\n' > "$TMP/i-mixed.md"
retr_cite_integrity "$TMP/i-mixed.md" "$A" "$CITE_SPAN" \
  && { fail "E16 one unresolvable target among good ones still passed"; e16=1; }
[ "${RETR_CITE_BAD:-0}" -eq 1 ] || { fail "E16 bad-citation count wrong (got ${RETR_CITE_BAD:-unset}, want 1)"; e16=1; }
case "${RETR_CITE_BAD_LIST:-}" in *nope-not-here*) ;; *) fail "E16 offending target not named in the report list"; e16=1 ;; esac

# The false-pass route: cite NOTHING. It must not score M6 at all — and the
# eval must only count answers that offered a citation, so silence buys nothing
# here while still failing R4, which is what forces a citation to exist.
printf 'The wiki does not cover Q2 2026.\n' > "$TMP/i-none.md"
retr_cite_integrity "$TMP/i-none.md" "$A" "$CITE_SPAN" \
  || { fail "E16 an uncited answer treated as a citation failure"; e16=1; }
[ "${RETR_CITE_TOTAL:-1}" -eq 0 ] || { fail "E16 uncited answer reported citations"; e16=1; }
grep -q 'RETR_CITE_TOTAL:-0}" -gt 0' "$EVAL" \
  || { fail "E16 eval scores M6 on answers that cited nothing (silence would pass)"; e16=1; }
grep -q 'M6 citation integrity' "$EVAL" \
  || { fail "E16 report has no M6 line"; e16=1; }
# Two receipts in ONE parenthetical must extract as TWO targets. Grabbing up to
# the closing paren produced a single comma-joined string that resolves to
# nothing, inventing citation failures on correct answers.
printf 'A. (source: raw/sales-2026.csv#L948, source: raw/sales-2026.csv#L949)\n' > "$TMP/i-pair.md"
n_pair=$(retr_citations "$TMP/i-pair.md" | wc -l | tr -d ' ')
[ "$n_pair" -eq 2 ] || { fail "E16 comma-joined citations extracted as $n_pair target(s), want 2"; e16=1; }
retr_cite_integrity "$TMP/i-pair.md" "$A" "$CITE_SPAN" \
  || { fail "E16 two valid receipts in one paren graded unresolvable"; e16=1; }
# A line range that lands inside frontmatter cites METADATA, not content — the
# resolver rejects it and M6 must surface that as the real defect it is.
printf 'A. (source: raw/sales-2026.csv.md#L2-L4)\n' > "$TMP/i-fm.md"
retr_cite_integrity "$TMP/i-fm.md" "$A" "$CITE_SPAN" \
  && { fail "E16 a citation pointing into frontmatter graded as resolving"; e16=1; }
[ "$e16" -eq 0 ] && ok "E16 M6 catches unresolvable files/anchors + frontmatter cites, splits paired receipts, silence cannot pass"

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d retrieval-eval check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s E1-E16 green — corpus fixed, graders not fakeable, empty-wiki voids, no-answer excluded (incl. model caps), clock-free, multi-valued/supersession/clarify/loop honest.\n" "$GREEN" "$RESET"
exit 0
