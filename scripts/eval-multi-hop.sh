#!/usr/bin/env bash
# scripts/eval-multi-hop.sh — multi-hop /wiki-query eval comparing typed vs baseline.
#
# Reads tests/eval/multi-hop-questions.md. For each question:
#   1. Runs the question through `claude -p '/wiki-query "<Q>" --no-promote'` against
#      the typed fixture wiki (tests/eval/wiki-fixture/).
#   2. Runs the same question against a baseline copy of the fixture where verbs in
#      single-target `## Related` lines have been stripped.
#   3. Grades each answer by case-insensitive substring match on every `expects:`
#      token. All tokens present ⇒ PASS, else FAIL.
#
# Stdout: a markdown report.
#   baseline: X/N
#   typed: Y/N
#   verdict: improvement | no-improvement | null-result
#   (followed by per-question detail)
#
# Verdict rule:
#   typed - baseline >= 2  → improvement
#   typed - baseline <= -1 → no-improvement   (typed hurt)
#   otherwise              → null-result      (within noise)
#
# Exit 0 if the harness COMPLETED (regardless of verdict). Non-zero only on setup
# failures (missing fixture, missing claude CLI, etc.). Per spec, the deliverable
# is the measurement, not a particular verdict.
#
# The shared harness (build/strip/parse/run/verdict) lives in
# scripts/lib/eval-common.sh; only this variant's wiring stays here.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

QUESTIONS="$REPO_ROOT/tests/eval/multi-hop-questions.md"
FIXTURE_DIR="$REPO_ROOT/tests/eval/wiki-fixture"

LIB="$SCRIPT_DIR/lib/eval-common.sh"
if [ ! -f "$LIB" ]; then
  echo "error: shared harness missing: $LIB" >&2
  exit 1
fi
# shellcheck source=scripts/lib/eval-common.sh
. "$LIB"

if [ ! -f "$QUESTIONS" ]; then
  echo "error: questions file missing: $QUESTIONS" >&2
  exit 1
fi
if [ ! -d "$FIXTURE_DIR" ]; then
  echo "error: fixture dir missing: $FIXTURE_DIR" >&2
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "error: claude CLI not on PATH" >&2
  exit 1
fi

WORK="$(mktemp -d -t eval-multihop.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# --- Build typed + baseline; strip verbs from the baseline ---------------------

eval_build_variant typed    "$WORK" "$REPO_ROOT" "$FIXTURE_DIR"
eval_build_variant baseline "$WORK" "$REPO_ROOT" "$FIXTURE_DIR"
for f in "$WORK/baseline/wiki/"*.md; do
  eval_strip_related "$f" 0
done

# --- Parse questions, run both variants, grade by substring --------------------

tmp_q="$WORK/parsed-questions.tsv"
eval_parse_questions "$QUESTIONS" "$tmp_q"
n_questions=$(wc -l < "$tmp_q" | tr -d ' ')
if [ "$n_questions" -lt 1 ]; then
  echo "error: no questions parsed from $QUESTIONS" >&2
  exit 1
fi

results_md="$WORK/per-question.md"
eval_run_questions "$tmp_q" "$WORK" "$results_md" "eval" eval_grade_substring
baseline_pass=$EVAL_BASELINE_PASS
typed_pass=$EVAL_TYPED_PASS

# --- Verdict + report ----------------------------------------------------------

delta=$((typed_pass - baseline_pass))
verdict=$(eval_verdict "$typed_pass" "$baseline_pass" 2)

cat <<EOF
# multi-hop eval report

Fixture: tests/eval/wiki-fixture/ (6 pages, Brazilian agriculture)
Questions: tests/eval/multi-hop-questions.md ($n_questions questions)

baseline: $baseline_pass/$n_questions
typed: $typed_pass/$n_questions
delta: $delta
verdict: $verdict

## Per-question detail

EOF
cat "$results_md"

exit 0
