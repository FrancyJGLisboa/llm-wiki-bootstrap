#!/usr/bin/env bash
# scripts/eval-causal.sh — causal multi-hop eval: typed-causal vs causal-stripped.
#
# Reads tests/eval/causal-questions.md. For each question:
#   1. typed variant: tests/eval/causal-fixture/ with `## Related` causal verbs
#      intact, plus a generated wiki/_kg.jsonl (causal triples only) so
#      /wiki-query can traverse the causal graph.
#   2. baseline variant: the same fixture with `## Related` verbs stripped and
#      NO _kg.jsonl — the causal-blind control.
#   3. Grades each answer by case-insensitive substring on every `expects:`
#      token. All present ⇒ PASS.
#
# Stdout: a markdown report (baseline X/N, typed Y/N, delta, verdict).
# Verdict: typed - baseline >= 2 → improvement; <= -1 → no-improvement; else null-result.
#
# This is the C5 "real-capability proof": causality is real only if the typed
# variant beats the causal-blind baseline. Exit 0 if the harness COMPLETED.
#
# The shared harness (build/strip/parse/run/verdict) lives in
# scripts/lib/eval-common.sh; the --causal-only KG sidecar is generated INLINE
# here (the shared eval_gen_kg_sidecar helper does not pass --causal-only).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

QUESTIONS="$REPO_ROOT/tests/eval/causal-questions.md"
FIXTURE_DIR="$REPO_ROOT/tests/eval/causal-fixture"
KG_GENERATOR="$REPO_ROOT/scripts/wiki-to-kg.py"

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

WORK="$(mktemp -d -t eval-causal.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# --- Build typed + baseline; strip causal verbs from the baseline -------------

eval_build_variant typed    "$WORK" "$REPO_ROOT" "$FIXTURE_DIR"
eval_build_variant baseline "$WORK" "$REPO_ROOT" "$FIXTURE_DIR"
for f in "$WORK/baseline/wiki/"*.md; do
  eval_strip_related "$f" 0
done

# --- Generate the causal KG sidecar in the TYPED variant only (inline) --------

if [ -f "$KG_GENERATOR" ]; then
  echo "[eval-causal] generating wiki/_kg.jsonl (--causal-only) in typed variant only" >&2
  python3 "$KG_GENERATOR" --causal-only "$WORK/typed/wiki/" > "$WORK/typed/wiki/_kg.jsonl" \
    || { echo "error: $KG_GENERATOR failed" >&2; exit 1; }
  echo "[eval-causal] typed wiki/_kg.jsonl: $(wc -l < "$WORK/typed/wiki/_kg.jsonl" | tr -d ' ') causal triples" >&2
else
  echo "[eval-causal] KG generator absent; both variants sidecar-less" >&2
fi

# --- Parse questions, run both variants, grade by substring -------------------

tmp_q="$WORK/parsed-questions.tsv"
eval_parse_questions "$QUESTIONS" "$tmp_q"
n_questions=$(wc -l < "$tmp_q" | tr -d ' ')
if [ "$n_questions" -lt 1 ]; then
  echo "error: no questions parsed from $QUESTIONS" >&2
  exit 1
fi

results_md="$WORK/per-question.md"
eval_run_questions "$tmp_q" "$WORK" "$results_md" "eval-causal" eval_grade_substring
baseline_pass=$EVAL_BASELINE_PASS
typed_pass=$EVAL_TYPED_PASS

# --- Verdict + report ----------------------------------------------------------

delta=$((typed_pass - baseline_pass))
verdict=$(eval_verdict "$typed_pass" "$baseline_pass" 2)

cat <<EOF
# causal multi-hop eval report

Fixture: tests/eval/causal-fixture/ (causal chain, typed vs causal-stripped)
Questions: tests/eval/causal-questions.md ($n_questions questions)

baseline: $baseline_pass/$n_questions
typed: $typed_pass/$n_questions
delta: $delta
verdict: $verdict

## Per-question detail

EOF
cat "$results_md"

exit 0
