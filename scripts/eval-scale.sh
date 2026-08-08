#!/usr/bin/env bash
# scripts/eval-scale.sh — where does retrieval bend as the wiki grows?
#
# Runs the FULL retrieval eval (scripts/eval-retrieval.sh — real installer,
# real /ctx-extract → /ctx-compile, real /ctx-query) at increasing corpus
# sizes, with deterministic distractor filler injected before ingest, and
# reports the curve: score and reads-per-answer at each size.
#
# Default sizes: 0 (baseline, ~19 pages) · 100 filler · 480 filler (~500 pages).
#
# Gates (the loss function; oracle-verified by scripts/verify-scale-eval.sh):
#   G1 scale-parity     every check green at the smallest size is green at the
#                       largest — quality survives 25× the corpus
#   G2 reads-budget     max wiki+raw file reads per answered question at the
#                       largest size <= 12 — cost is O(hops), not O(corpus)
#   G3 index-integrity  needle pages are index-linked at the largest size AND
#                       every filler index entry survived ingest — the
#                       librarian extended the big index, didn't truncate it
#
# Each size runs in its own resumable --work subdir; re-invoke after a kill.
# Exit 0 when the measurement completed (whatever the gates say); non-zero on
# setup failure; 3 if any size came back VOID (unscoreable, not a score).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVAL="$SCRIPT_DIR/eval-retrieval.sh"

WORK=
SIZES="0 100 480"
for arg in "$@"; do
  case "$arg" in
    --work=*)  WORK="${arg#--work=}" ;;
    --sizes=*) SIZES="${arg#--sizes=}" ;;
    *) echo "usage: eval-scale.sh --work=DIR [--sizes=\"0 100 480\"]" >&2; exit 2 ;;
  esac
done
[ -n "$WORK" ] || { echo "error: --work=DIR is required (runs are resumable)" >&2; exit 2; }
mkdir -p "$WORK" || { echo "error: cannot create $WORK" >&2; exit 1; }

CHECKS="R1 needle retrieval|R2 point-in-time|R3 refusal on absence|R4 citation locus|R5 stale evidence|M1 multi-valued answer|M2 supersession|M4 clarify-on-ambig"

# report_field <report> <label>  → "pass/total"
report_field() {
  sed -n "s/^$2:[[:space:]]*\([0-9]*\/[0-9]*\).*/\1/p" "$1" | head -1
}

for n in $SIZES; do
  report="$WORK/s$n.report.md"
  if [ -s "$report" ] && grep -q '^retrieval score:' "$report"; then
    echo "[scale] size $n: report cached" >&2
    continue
  fi
  echo "[scale] size $n: running full retrieval eval" >&2
  args=(--work="$WORK/s$n")
  [ "$n" -gt 0 ] && args+=(--scale="$n")
  "$EVAL" "${args[@]}" > "$report"
  rc=$?
  if [ "$rc" -eq 3 ]; then
    echo "[scale] size $n came back VOID — the curve cannot be scored" >&2
    cat "$report"
    exit 3
  elif [ "$rc" -ne 0 ]; then
    echo "[scale] size $n failed (exit $rc)" >&2
    exit "$rc"
  fi
done

# ── Curve + gates ─────────────────────────────────────────────────────────────
smallest=$(echo "$SIZES" | tr ' ' '\n' | sort -n | head -1)
largest=$(echo "$SIZES" | tr ' ' '\n' | sort -n | tail -1)
s_small="$WORK/s$smallest.report.md"
s_large="$WORK/s$largest.report.md"

echo "# retrieval scale eval — the curve"
echo ""
echo "| filler | wiki pages | score | reads median | reads max |"
echo "|---|---|---|---|---|"
for n in $SIZES; do
  report="$WORK/s$n.report.md"
  pages=$(sed -n 's/.*raw files, \([0-9]*\) wiki pages.*/\1/p' "$report" | head -1)
  score=$(sed -n 's/^retrieval score: \([0-9]*\/[0-9]*\).*/\1/p' "$report" | head -1)
  med=$(sed -n 's/^Reads: median=\([0-9]*\).*/\1/p' "$report" | head -1)
  max=$(sed -n 's/^Reads: median=[0-9]* max=\([0-9]*\).*/\1/p' "$report" | head -1)
  printf '| %s | %s | %s | %s | %s |\n' "$n" "${pages:-?}" "${score:-?}" "${med:-?}" "${max:-?}"
done
echo ""

g1=PASS; g1_note=""
OLD_IFS="$IFS"; IFS='|'
for label in $CHECKS; do
  IFS="$OLD_IFS"
  small_v=$(report_field "$s_small" "$label")
  large_v=$(report_field "$s_large" "$label")
  sp="${small_v%%/*}"; st="${small_v##*/}"
  lp="${large_v%%/*}"; lt="${large_v##*/}"
  if [ -n "$st" ] && [ "$st" != "0" ] && [ "$sp" = "$st" ]; then
    if [ -z "$lt" ] || [ "$lt" = "0" ] || [ "$lp" != "$lt" ]; then
      # Brace EVERY expansion touching the arrow: `$small_v→` makes bash read
      # the multibyte arrow's bytes as part of the variable NAME, so under
      # `set -u` the gate section died with "small_v<mojibake>: unbound
      # variable" after a completed 3-size run — the measurement was done and
      # the report crashed on the way out.
      g1=FAIL; g1_note="${g1_note} ${label}:${small_v}→${large_v:-absent}"
    fi
  fi
  IFS='|'
done
IFS="$OLD_IFS"

max_large=$(sed -n 's/^Reads: median=[0-9]* max=\([0-9]*\).*/\1/p' "$s_large" | head -1)
if [ -n "$max_large" ] && [ "$max_large" -le 12 ]; then g2=PASS; else g2=FAIL; fi

g3=PASS; g3_note=""
idx="$WORK/s$largest/wiki/wiki/index.md"
manifest="$WORK/s$largest/wiki/.scale-manifest"
if [ -f "$idx" ] && [ -f "$manifest" ]; then
  for needle in retry-budget-memo-apr log-retention-production; do
    grep -q "$needle" "$idx" || { g3=FAIL; g3_note="$g3_note $needle-not-indexed"; }
  done
  want=$(sed -n 's/^pages=\([0-9]*\).*/\1/p' "$manifest")
  have=$(grep -c '^- \[\[scale-' "$idx" || true)
  [ "$have" = "$want" ] || { g3=FAIL; g3_note="$g3_note filler-entries:$have/$want"; }
else
  g3=FAIL; g3_note=" index-or-manifest-missing"
fi

echo "G1 scale-parity (green at $smallest stays green at $largest): $g1$g1_note"
echo "G2 reads-budget (max reads at $largest <= 12): $g2 (max=${max_large:-?})"
echo "G3 index-integrity at $largest: $g3$g3_note"
echo ""
echo "Per-size reports: $WORK/s<N>.report.md — holdout stays --holdout-only, never run here."
exit 0
