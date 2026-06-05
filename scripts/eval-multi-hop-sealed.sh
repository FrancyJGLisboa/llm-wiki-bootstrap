#!/usr/bin/env bash
# scripts/eval-multi-hop-sealed.sh — sealed-channels variant for phase-3.
#
# Reads tests/eval/sealed-multi-hop-questions.md. Builds two working wikis:
#
#   typed:    full sealed-fixture pages, with verbs + numeric attrs + tags
#             intact.  If scripts/wiki-to-kg.py exists, the harness also
#             generates wiki/_kg.jsonl in the typed dir (only).
#
#   baseline: same pages, but with (a) `^tags:` frontmatter lines stripped,
#             (b) verbs AND numeric attrs stripped from single-target
#             `## Related` lines.  Closes leak channels 1 (attr) and 2 (tags).
#             Baseline NEVER gets a _kg.jsonl sidecar.
#
# For each question, runs `claude -p '/wiki-query "<Q>" --no-promote'` against
# both variants and grades by **word-boundary** numeric match for numeric
# `expects:` tokens (NOT substring — fixes the phase-2 grader bug that would
# false-pass "page 12 of …" on expects: 12).
#
# Stdout: a markdown report.
#   baseline: X/N
#   typed: Y/N
#   verdict: improvement | no-improvement | null-result
#
# Verdict rule:
#   typed - baseline >= 3  → improvement   (phase-3's stricter delta)
#   typed - baseline <= -1 → no-improvement
#   otherwise              → null-result
#
# CLI:
#   ./eval-multi-hop-sealed.sh                  — full eval
#   ./eval-multi-hop-sealed.sh --dry-run-baseline — print post-strip baseline
#                                                   wiki/ to stdout and exit 0
#                                                   (used by C8)
#
# Exit 0 if the harness COMPLETED. Non-zero only on setup failures.
#
# The shared harness (build/strip/parse/run/verdict) lives in
# scripts/lib/eval-common.sh; only this variant's wiring stays here.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

QUESTIONS="$REPO_ROOT/tests/eval/sealed-multi-hop-questions.md"
FIXTURE_DIR="$REPO_ROOT/tests/eval/sealed-fixture"
KG_GENERATOR="$REPO_ROOT/scripts/wiki-to-kg.py"

LIB="$SCRIPT_DIR/lib/eval-common.sh"
if [ ! -f "$LIB" ]; then
  echo "error: shared harness missing: $LIB" >&2
  exit 1
fi
# shellcheck source=scripts/lib/eval-common.sh
. "$LIB"

DRY_RUN_BASELINE=0
if [ "${1:-}" = "--dry-run-baseline" ]; then
  DRY_RUN_BASELINE=1
fi

if [ ! -f "$QUESTIONS" ] && [ $DRY_RUN_BASELINE -eq 0 ]; then
  echo "error: questions file missing: $QUESTIONS" >&2
  exit 1
fi
if [ ! -d "$FIXTURE_DIR" ]; then
  echo "error: fixture dir missing: $FIXTURE_DIR" >&2
  exit 1
fi
if [ $DRY_RUN_BASELINE -eq 0 ] && ! command -v claude >/dev/null 2>&1; then
  echo "error: claude CLI not on PATH" >&2
  exit 1
fi

WORK="$(mktemp -d -t eval-sealed.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# Build the sealed baseline: strip tags AND verbs+attrs (strip_tags=1).
build_sealed_baseline() {
  eval_build_variant baseline "$WORK" "$REPO_ROOT" "$FIXTURE_DIR"
  for f in "$WORK/baseline/wiki/"*.md; do
    eval_strip_related "$f" 1
  done
}

if [ $DRY_RUN_BASELINE -eq 1 ]; then
  build_sealed_baseline
  for f in "$WORK/baseline/wiki/"*.md; do
    echo "===== $(basename "$f") ====="
    cat "$f"
  done
  exit 0
fi

eval_build_variant typed "$WORK" "$REPO_ROOT" "$FIXTURE_DIR"
build_sealed_baseline

# --- (Phase-3b only) KG sidecar in the typed work dir, NEVER baseline ----------

eval_gen_kg_sidecar "$WORK" "$KG_GENERATOR" "eval-sealed" || exit 1

# --- Parse questions, run both variants, grade with numeric word-boundary ------

tmp_q="$WORK/parsed-questions.tsv"
eval_parse_questions "$QUESTIONS" "$tmp_q"
n_questions=$(wc -l < "$tmp_q" | tr -d ' ')
if [ "$n_questions" -lt 1 ]; then
  echo "error: no questions parsed from $QUESTIONS" >&2
  exit 1
fi

results_md="$WORK/per-question.md"
eval_run_questions "$tmp_q" "$WORK" "$results_md" "eval-sealed" eval_grade_numeric_wordboundary
baseline_pass=$EVAL_BASELINE_PASS
typed_pass=$EVAL_TYPED_PASS

# --- Verdict + report ----------------------------------------------------------

delta=$((typed_pass - baseline_pass))
verdict=$(eval_verdict "$typed_pass" "$baseline_pass" 3)

cat <<EOF
# sealed multi-hop eval report

Fixture: tests/eval/sealed-fixture/ (7 pseudonym pages, integer-attr graph)
Questions: tests/eval/sealed-multi-hop-questions.md ($n_questions questions)

baseline: $baseline_pass/$n_questions
typed: $typed_pass/$n_questions
delta: $delta
verdict: $verdict

## Per-question detail

EOF
cat "$results_md"

exit 0
