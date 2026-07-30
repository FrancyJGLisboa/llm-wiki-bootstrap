#!/usr/bin/env bash
# scripts/eval-corpus.sh — score retrieval against a REAL corpus.
#
# eval-retrieval.sh answers "can a bootstrapped wiki retrieve from a corpus we
# built to be retrievable?" — synthetic needles absent from pretraining, planted
# past each extractor's truncation boundary, cleanly separated from distractors.
# This answers the harder question: can it retrieve from content that already
# exists, where every source overlaps every other source, the subject matter IS
# in pretraining, and the author contradicts himself across years.
#
# It is a separate driver rather than a flag on eval-retrieval.sh because that
# script is wired end-to-end to its generated corpus — needle planting, the R5
# mutation of capacity-report-q1.md, M2/M5 legs on named fixture pages — and
# almost none of it is meaningful against real content. The GRADERS are the part
# worth reusing, and they are reused wholesale from scripts/lib/eval-common.sh.
#
# Two checks (approved, eval/grain_checks.yaml):
#   A1  dated-opinion retrieval — the answer carries the author's position AND
#       cites a resolving, tight passage IN A SOURCE OF THE RIGHT DATE
#   A2  temporal contradiction  — both legs of a reversal: the as-of question
#       returns the position held then, the unqualified question surfaces BOTH
#
# A1 adds one field to the question format, `cite-file-matches:` — an ERE the
# cited raw filename must match. Staged filenames are date-prefixed
# (YYYY-MM-DD-slug-videoid.md), so "cited a source from April 2023" is a
# deterministic string test. This is what stops a right-sounding answer citing
# the wrong episode from scoring as retrieval.
#
# --control runs the same questions against an EMPTY wiki and reports which ones
# it answered anyway. Those are parametric — answerable from pretraining without
# the corpus — and must be discarded before A1 means anything. On a corpus about
# public grain markets this is not a formality; it is the whole basis for
# believing the number.
#
# Usage:
#   scripts/eval-corpus.sh --wiki DIR --questions FILE [--work DIR]
#                          [--raw DIR] [--control] [--label NAME]
#
# --work makes the run resumable: answers persist and are re-graded for free, so
# a grader change can be scored without re-querying.
#
# Exit 0 if the harness COMPLETED, whatever the score — the deliverable is the
# measurement. Non-zero only on setup failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/eval-common.sh"
CITE_SPAN="$SCRIPT_DIR/cite-span.py"
QUERY_TRACE="$SCRIPT_DIR/lib/query-trace.py"

WIKI=; QUESTIONS=; WORK=; RAW=; CONTROL=0; LABEL=corpus
while [ $# -gt 0 ]; do
  case "$1" in
    --wiki)      WIKI="${2:-}"; shift 2 ;;
    --questions) QUESTIONS="${2:-}"; shift 2 ;;
    --work)      WORK="${2:-}"; shift 2 ;;
    --raw)       RAW="${2:-}"; shift 2 ;;
    --label)     LABEL="${2:-}"; shift 2 ;;
    --control)   CONTROL=1; shift ;;
    -h|--help)   sed -n '2,45p' "$0"; exit 0 ;;
    *) echo "usage: eval-corpus.sh --wiki DIR --questions FILE [--work DIR] [--raw DIR] [--control] [--label NAME]" >&2; exit 2 ;;
  esac
done

[ -n "$WIKI" ] && [ -n "$QUESTIONS" ] || {
  echo "usage: eval-corpus.sh --wiki DIR --questions FILE [--work DIR] [--raw DIR] [--control] [--label NAME]" >&2; exit 2; }
[ -d "$WIKI" ] || { echo "error: no such wiki dir: $WIKI" >&2; exit 2; }
[ -f "$QUESTIONS" ] || { echo "error: no such questions file: $QUESTIONS" >&2; exit 2; }
for f in "$LIB" "$CITE_SPAN" "$QUERY_TRACE"; do
  [ -f "$f" ] || { echo "error: missing $f" >&2; exit 2; }
done
command -v python3 >/dev/null 2>&1 || { echo "error: python3 not on PATH" >&2; exit 2; }
[ "$CONTROL" -eq 1 ] || command -v claude >/dev/null 2>&1 || {
  echo "error: claude not on PATH" >&2; exit 2; }

# shellcheck source=lib/eval-common.sh
. "$LIB"

WIKI="$(cd "$WIKI" && pwd)"
[ -n "$RAW" ] || RAW="$WIKI/raw"
if [ -z "$WORK" ]; then
  WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
else
  mkdir -p "$WORK"
fi

# cite_file_matches <answer_file> <ere> — 0 if some citation's raw FILENAME
# matches. Answers cite `raw/<name>[#anchor]`; strip dir and anchor, then test.
cite_file_matches() {
  local answer="$1" ere="$2" target base
  [ -n "$ere" ] || return 0
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    base="${target##*/}"; base="${base%%#*}"
    printf '%s' "$base" | grep -qE "$ere" && return 0
  done < <(retr_citations "$answer")
  return 1
}

tmp_q="$WORK/.questions.tsv"
retr_parse_questions "$QUESTIONS" "$tmp_q"
n_q=$(grep -c . "$tmp_q" 2>/dev/null || echo 0)
[ "$n_q" -ge 1 ] || { echo "error: no questions parsed from $QUESTIONS" >&2; exit 2; }

# `cite-file-matches:` is not in retr_parse_questions' field list, so read it
# separately, keyed by question id. Same fenced-block skip as the parser.
awk '
  /^```/ { in_fence = !in_fence; next }
  in_fence { next }
  /^### / { qid = $0; sub(/^### /, "", qid); next }
  /^cite-file-matches:/ && qid != "" {
    v = $0; sub(/^cite-file-matches:[[:space:]]*/, "", v); print qid "\t" v
  }
' "$QUESTIONS" > "$WORK/.cfm.tsv"

pages=$(find "$WIKI/wiki" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
echo "[$LABEL] wiki=$WIKI pages=$pages questions=$n_q control=$CONTROL" >&2

declare -a detail=()
a1_pass=0; a1_total=0
a2_pass=0; a2_total=0
inconclusive=0; ctrl_parametric=""
all_reads=""
cite_bad_total=0; cite_seen_total=0
declare -a a2_ok=()

while IFS=$'\t' read -r qid question modality expects cite span forbids refusal; do
  [ -z "$qid" ] && continue
  question=$(retr_field "$question"); modality=$(retr_field "$modality")
  expects=$(retr_field "$expects");   cite=$(retr_field "$cite")
  span=$(retr_field "$span");         forbids=$(retr_field "$forbids")
  refusal=$(retr_field "$refusal")
  cfm=$(awk -F'\t' -v q="$qid" '$1==q {print $2; exit}' "$WORK/.cfm.tsv")

  answer="$WORK/$qid.answer.md"
  if [ -s "$answer" ]; then
    echo "[$LABEL] $qid — cached, regrading" >&2
  else
    echo "[$LABEL] $qid" >&2
    ( cd "$WIKI" && claude -p "/wiki-query \"$question\" --no-promote" \
        --output-format stream-json --verbose ) \
      >"$WORK/$qid.stream" 2>"$WORK/$qid.err" </dev/null || true
    python3 "$QUERY_TRACE" "$WORK/$qid.stream" --counts "$WORK/$qid.reads" \
      >"$answer" 2>>"$WORK/$qid.err" || cp "$WORK/$qid.stream" "$answer"
  fi

  reads="?"
  if [ -f "$WORK/$qid.reads" ]; then
    reads=$(awk '{ for (i=1;i<=NF;i++) { split($i,kv,"="); c[kv[1]]=kv[2] }
                   print c["reads_wiki"]+c["reads_raw"] }' "$WORK/$qid.reads")
    [ -n "$reads" ] && all_reads="$all_reads $reads"
  fi

  if retr_answer_broken "$answer"; then
    verdict=INCONC; inconclusive=$((inconclusive + 1))
    echo "[$LABEL]   !! no answer (API/network/cap) — excluded from the score" >&2
  elif retr_grade_answer "$answer" "$expects" "$forbids" "$refusal"; then
    verdict=PASS
  else
    verdict=FAIL
  fi

  # Control arm: an empty wiki cannot cite, so grade the ANSWER only. Anything
  # it gets right is parametric and must leave the gold set.
  if [ "$CONTROL" -eq 1 ]; then
    [ "$verdict" = PASS ] && ctrl_parametric="$ctrl_parametric $qid"
    detail+=("| $qid | $modality | $verdict | $reads |")
    continue
  fi

  cite_v=n/a
  if [ -n "$cite" ]; then
    if retr_grade_citation "$answer" "$RAW" "$cite" "${span:-40}" "$CITE_SPAN"; then
      cite_v=PASS
    else
      cite_v=FAIL
    fi
  fi

  date_v=n/a
  if [ -n "$cfm" ]; then
    if cite_file_matches "$answer" "$cfm"; then date_v=PASS; else date_v=FAIL; fi
  fi

  retr_cite_integrity "$answer" "$RAW" "$CITE_SPAN" || true
  cite_seen_total=$((cite_seen_total + RETR_CITE_TOTAL))
  cite_bad_total=$((cite_bad_total + RETR_CITE_BAD))

  # A question passes only if every leg it declares passes. A right-sounding
  # answer citing the wrong episode is not retrieval.
  full=FAIL
  if [ "$verdict" = INCONC ]; then
    full=INCONC
  elif [ "$verdict" = PASS ] \
    && { [ "$cite_v" = PASS ] || [ "$cite_v" = n/a ]; } \
    && { [ "$date_v" = PASS ] || [ "$date_v" = n/a ]; }; then
    full=PASS
  fi

  case "$qid" in
    A1-*)
      [ "$full" != INCONC ] && a1_total=$((a1_total + 1))
      [ "$full" = PASS ] && a1_pass=$((a1_pass + 1)) ;;
    A2-*)
      [ "$full" = PASS ] && a2_ok+=("$qid") ;;
  esac

  detail+=("| $qid | $modality | $verdict | $cite_v | $date_v | $reads |")
done < "$tmp_q"

# A2 is scored per TOPIC, not per question: a reversal is only handled if BOTH
# legs land. `A2-<topic>-asof` and `A2-<topic>-both` must each pass.
topics=$(awk -F'\t' '$1 ~ /^A2-/ { id=$1; sub(/^A2-/,"",id); sub(/-(asof|both)$/,"",id); print id }' "$tmp_q" | sort -u)
for t in $topics; do
  [ -z "$t" ] && continue
  a2_total=$((a2_total + 1))
  hit=0
  for q in "${a2_ok[@]:-}"; do
    case "$q" in A2-"$t"-asof|A2-"$t"-both) hit=$((hit + 1)) ;; esac
  done
  [ "$hit" -ge 2 ] && a2_pass=$((a2_pass + 1))
done

pct() { [ "$2" -eq 0 ] && { echo "n/a"; return; }; awk -v a="$1" -v b="$2" 'BEGIN{printf "%.0f%%", 100*a/b}'; }
med() { [ -z "$1" ] && { echo "?"; return; }; printf '%s\n' $1 | sort -n | awk '{v[NR]=$1} END{print (NR%2)?v[(NR+1)/2]:int((v[NR/2]+v[NR/2+1])/2)}'; }
mx()  { [ -z "$1" ] && { echo "?"; return; }; printf '%s\n' $1 | sort -n | tail -1; }

echo
echo "# corpus eval — $LABEL"
echo
echo "Wiki: \`$WIKI\` ($pages pages)"
echo "Questions: \`$QUESTIONS\` ($n_q)"
echo

if [ "$CONTROL" -eq 1 ]; then
  n_par=$(printf '%s' "$ctrl_parametric" | wc -w | tr -d ' ')
  echo "## control arm — empty wiki"
  echo
  echo "Questions the EMPTY wiki answered correctly: **$n_par / $n_q**"
  echo
  if [ "$n_par" -gt 0 ]; then
    echo "These are parametric — answerable without the corpus — and MUST be"
    echo "discarded from the gold set before A1/A2 mean anything:"
    echo
    for q in $ctrl_parametric; do echo "- \`$q\`"; done
    echo
  else
    echo "None. The gold set is non-parametric as authored."
    echo
  fi
  echo "| question | modality | answer | reads |"
  echo "|---|---|---|---|"
  printf '%s\n' "${detail[@]:-}"
  echo
  echo "parametric leak: $n_par/$n_q"
  exit 0
fi

echo "## scores"
echo
echo "- **A1** dated-opinion retrieval: **$a1_pass/$a1_total** ($(pct $a1_pass $a1_total)) — target >=80%"
echo "- **A2** temporal contradiction (both legs): **$a2_pass/$a2_total** ($(pct $a2_pass $a2_total)) — target >=75%"
echo "- citation integrity: $((cite_seen_total - cite_bad_total))/$cite_seen_total offered citations resolve"
echo "- reads per answer: median=$(med "$all_reads") max=$(mx "$all_reads") — budget <=12"
[ "$inconclusive" -gt 0 ] && echo "- INCONCLUSIVE (API/cap, excluded): $inconclusive"
echo
echo "## detail"
echo
echo "| question | modality | answer | cite | date | reads |"
echo "|---|---|---|---|---|---|"
printf '%s\n' "${detail[@]:-}"
echo
echo "A1 $a1_pass/$a1_total; A2 $a2_pass/$a2_total"
exit 0
