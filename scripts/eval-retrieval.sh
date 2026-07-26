#!/usr/bin/env bash
# scripts/eval-retrieval.sh — cross-modality, point-in-time retrieval eval.
#
# Turns "can a bootstrapped wiki retrieve accurate, point-in-time info about
# anything?" into five numbers. Everything runs against a wiki built by the REAL
# installer (create-llm-wiki.sh) and populated through the REAL /wiki-extract →
# /wiki-ingest path, so a failure here is a failure a user would hit — not a
# fixture artifact. No pre-built wiki fixture is used on purpose: the modality
# gaps this eval exists to find (tabular truncation, thread flattening) live in
# extract and ingest, and a hand-authored fixture would paper over exactly them.
#
# Loss function — 5 binary checks (approved):
#   R1  needle retrieval    per modality (csv / email / report), planted past
#                           each extractor's truncation boundary
#   R2  point-in-time       as-of and current answers, both correct in ONE run
#   R3  refusal on absence  a question the corpus cannot answer is declined,
#                           not fabricated
#   R4  citation locus      some cited passage both CONTAINS the fact and spans
#                           <= max-span lines (provenance that is real AND tight)
#   R5  stale evidence      after a raw body is mutated post-ingest, the answer
#                           flags it instead of serving the stale claim
#
# retrieval score = passed / total, reported per check and per modality.
#
# Held out: --holdout runs tests/eval/retrieval-questions-holdout.md against a
# modality never used above. It is never part of the default score.
#
# Cost: drives `claude -p` for extract, ingest, and every question. Use
# --dry-run to build the corpus and print the plan without spending anything.
#
# --work=DIR makes the run RESUMABLE: state persists there instead of a temp
# dir, and install / extract / ingest / each question are skipped if already
# complete. Re-invoke with the same DIR after a kill to continue rather than
# repay for the slow stages. Answers already on disk are re-graded for free,
# so grader changes can be scored without re-querying.
#
# Exit 0 if the harness COMPLETED, whatever the score — the deliverable is the
# measurement. Non-zero only on setup failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GEN="$REPO_ROOT/tests/eval/retrieval-corpus/gen-corpus.sh"
QUESTIONS="$REPO_ROOT/tests/eval/retrieval-questions.md"
CITE_SPAN="$SCRIPT_DIR/cite-span.py"
INSTALLER="$SCRIPT_DIR/create-llm-wiki.sh"
DRIFT_LINT="$SCRIPT_DIR/wiki-lint-hash-drift.sh"
LIB="$SCRIPT_DIR/lib/eval-common.sh"

DRY_RUN=0
HOLDOUT=0
GEN_MODE=main
WORK=
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --holdout) HOLDOUT=1; GEN_MODE=--holdout
               QUESTIONS="$REPO_ROOT/tests/eval/retrieval-questions-holdout.md" ;;
    --work=*)  WORK="${arg#--work=}" ;;
    *) echo "usage: eval-retrieval.sh [--dry-run] [--holdout] [--work=DIR]" >&2; exit 2 ;;
  esac
done

for f in "$GEN" "$QUESTIONS" "$CITE_SPAN" "$INSTALLER" "$LIB"; do
  [ -e "$f" ] || { echo "error: missing $f" >&2; exit 1; }
done
# shellcheck source=scripts/lib/eval-common.sh
. "$LIB"
command -v python3 >/dev/null 2>&1 || { echo "error: python3 not on PATH" >&2; exit 1; }
if [ "$DRY_RUN" -eq 0 ] && ! command -v claude >/dev/null 2>&1; then
  echo "error: claude CLI not on PATH (use --dry-run to build the corpus only)" >&2
  exit 1
fi

if [ -n "$WORK" ]; then
  # Resumable mode: no cleanup trap, and each stage below is guarded by a marker
  # file. Every stage past corpus generation spends real money on nested
  # `claude -p` calls, so a Ctrl-C or an OOM must not discard an hour of
  # extract+ingest. Re-invoke with the same --work=DIR to pick up where it died.
  mkdir -p "$WORK" || { echo "error: cannot create $WORK" >&2; exit 1; }
  # A run killed during R5 leaves raw/ corrupted. Resuming on top of that
  # re-ingests the mutated body, commits ingested_hash over it, and makes R5
  # unscoreable while silently changing the as-of answer — a scored report built
  # on a poisoned corpus. Force the expensive-but-correct path instead.
  if [ -f "$WORK/.mutated" ]; then
    echo "[retr] work dir was left mid-R5 with a mutated raw body — discarding" \
         "extract/ingest so the corpus is rebuilt clean" >&2
    rm -f "$WORK/.done-extract" "$WORK/.done-ingest" "$WORK/.mutated" \
          "$WORK/.r5-pristine" "$WORK"/R*.answer.md
    rm -rf "$WORK/wiki"; rm -f "$WORK/.done-install"
  fi
else
  WORK="$(mktemp -d -t eval-retrieval.XXXXXX)"
  trap 'rm -rf "$WORK"' EXIT
fi
CORPUS="$WORK/corpus"
WIKI="$WORK/wiki"

# staged <name> — true if that stage already completed in this WORK dir
staged()    { [ -f "$WORK/.done-$1" ]; }
mark_done() { : > "$WORK/.done-$1"; }

echo "[retr] generating corpus" >&2
"$GEN" "$CORPUS" "$GEN_MODE" >/dev/null 2>&1 || { echo "error: corpus generation failed" >&2; exit 1; }

tmp_q="$WORK/questions.tsv"
retr_parse_questions "$QUESTIONS" "$tmp_q"
n_q=$(wc -l < "$tmp_q" | tr -d ' ')
[ "$n_q" -ge 1 ] || { echo "error: no questions parsed from $QUESTIONS" >&2; exit 1; }

if [ "$DRY_RUN" -eq 1 ]; then
  echo "# retrieval eval — dry run (nothing spent)"
  echo ""
  echo "corpus ($(find "$CORPUS" -type f | wc -l | tr -d ' ') sources):"
  for f in "$CORPUS"/*; do
    printf '  %-26s %6s lines  %7s bytes\n' "$(basename "$f")" \
      "$(wc -l < "$f" | tr -d ' ')" "$(wc -c < "$f" | tr -d ' ')"
  done
  echo ""
  echo "questions ($n_q):"
  cut -f1,3 "$tmp_q" | sed 's/^/  /'
  echo ""
  echo "would run: create-llm-wiki.sh → /wiki-extract (all sources) → /wiki-ingest"
  echo "           → /wiki-query per question → mutate raw → /wiki-query (R5)"
  exit 0
fi

# claude_p <logfile> <prompt> — one nested `claude -p`, retried once.
#
# stdin is pinned to /dev/null because the question loop below ends with
# `done < "$tmp_q"`: without this, the nested claude inherits stdin pointed at
# questions.tsv and swallows the remaining eval questions into its own prompt.
# That is not hypothetical — a run scored 6/12 with every later question leaking
# into the first one's args.
#
# The retry exists because a transient `API Error: 529 Overloaded` on the ingest
# step silently produces an empty wiki, which the graders then score as if the
# system had answered honestly. A retried 529 is cheaper than a void run.
claude_p() {
  local log="$1" prompt="$2" attempt
  for attempt in 1 2; do
    ( cd "$WIKI" && claude -p "$prompt" ) >"$log" 2>&1 </dev/null && return 0
    if grep -qE '5[0-9][0-9] |Overloaded|rate.?limit' "$log" 2>/dev/null; then
      echo "[retr]   transient API error, retry $attempt" >&2
      continue
    fi
    return 0   # a non-transient failure is the measurement, not a setup error
  done
  return 0
}

# ── Build a fresh wiki the way a user would, then load the corpus ─────────────
if staged install; then
  echo "[retr] skip install (done)" >&2
else
  echo "[retr] installing fresh wiki" >&2
  rm -rf "$WIKI"   # a half-installed wiki from a killed run is not resumable
  "$INSTALLER" "$WIKI" >"$WORK/install.log" 2>&1 \
    || { echo "error: installer failed (see $WORK/install.log)" >&2; exit 1; }
  mark_done install
fi

sources=()
for f in "$CORPUS"/*; do sources+=("$f"); done

if staged extract; then
  echo "[retr] skip /wiki-extract (done)" >&2
else
  echo "[retr] /wiki-extract (${#sources[@]} sources)" >&2
  claude_p "$WORK/extract.log" "/wiki-extract ${sources[*]}"
  mark_done extract
fi

if staged ingest; then
  echo "[retr] skip /wiki-ingest (done)" >&2
else
  echo "[retr] /wiki-ingest" >&2
  claude_p "$WORK/ingest.log" "/wiki-ingest"
  mark_done ingest
fi

extracted=$(find "$WIKI/raw" -type f 2>/dev/null | wc -l | tr -d ' ')
pages=$(find "$WIKI/wiki" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
echo "[retr] raw/: $extracted files, wiki/: $pages pages" >&2

# ── Precondition: refuse to score an unpopulated wiki ─────────────────────────
#
# This gate is the lesson from a void run. With an empty wiki, /wiki-query
# answered every question correctly by reading raw/ directly and said so — so
# R1 scored 3/3 and R2 scored 2/2 while measuring nothing but "an agent can grep
# a file". Passing on raw-only reads is the loss function's biggest false-pass
# route, and a scored report is worse than no report because it looks like
# evidence. Abort loudly instead, and do not spend on queries that cannot
# measure the thing.
ingested=$(grep -rlc 'ingested_hash: "[0-9a-f]' "$WIKI/raw" 2>/dev/null | wc -l | tr -d ' ')
if [ "$pages" -le 1 ] || [ "$ingested" -eq 0 ]; then
  {
    echo "# retrieval eval — VOID (not a score)"
    echo ""
    echo "The wiki was never populated, so no question can measure wiki retrieval."
    echo ""
    echo "- wiki pages:      $pages (need > 1)"
    echo "- ingested raw:    $ingested of $extracted (need > 0)"
    echo "- ingest log tail: $(tail -3 "$WORK/ingest.log" 2>/dev/null | tr '\n' ' ')"
    echo ""
    echo "With an empty wiki, /wiki-query falls back to reading raw/ directly and"
    echo "needle questions pass for the wrong reason. Fix ingest, then re-run:"
    echo "  scripts/eval-retrieval.sh --work=$WORK"
    echo "(extract is cached; delete \$WORK/.done-ingest to retry just ingest)"
  }
  echo "[retr] VOID: wiki unpopulated ($pages pages, $ingested ingested) — not scoring" >&2
  exit 3
fi

# ── Run the questions ─────────────────────────────────────────────────────────
declare -a detail=()
r1_pass=0; r1_total=0
r2_pass=0; r2_total=0
r3_pass=0; r3_total=0
r4_pass=0; r4_total=0

while IFS=$'\t' read -r qid question modality expects cite span forbids refusal; do
  [ -z "$qid" ] && continue
  question=$(retr_field "$question"); modality=$(retr_field "$modality")
  expects=$(retr_field "$expects");   cite=$(retr_field "$cite")
  span=$(retr_field "$span");         forbids=$(retr_field "$forbids")
  refusal=$(retr_field "$refusal")
  answer="$WORK/$qid.answer.md"
  if [ -s "$answer" ]; then
    echo "[retr] $qid ($modality) — cached, regrading" >&2
  else
    echo "[retr] $qid ($modality)" >&2
    ( cd "$WIKI" && claude -p "/wiki-query \"$question\" --no-promote" ) \
      >"$answer" 2>"$WORK/$qid.err" </dev/null || true
  fi

  if retr_grade_answer "$answer" "$expects" "$forbids" "$refusal"; then
    a_verdict=PASS
  else
    a_verdict=FAIL
  fi

  c_verdict=n/a
  if [ -n "$cite" ]; then
    r4_total=$((r4_total + 1))
    if retr_grade_citation "$answer" "$WIKI/raw" "$cite" "${span:-40}" "$CITE_SPAN"; then
      c_verdict=PASS; r4_pass=$((r4_pass + 1))
    else
      c_verdict=FAIL
    fi
  fi

  case "$qid" in
    R1-*|H1-*) r1_total=$((r1_total + 1)); [ "$a_verdict" = PASS ] && r1_pass=$((r1_pass + 1)) ;;
    R2-*)      r2_total=$((r2_total + 1)); [ "$a_verdict" = PASS ] && r2_pass=$((r2_pass + 1)) ;;
    R3-*)      r3_total=$((r3_total + 1)); [ "$a_verdict" = PASS ] && r3_pass=$((r3_pass + 1)) ;;
  esac

  # Which layer actually answered. A correct answer sourced only from raw/ is
  # the agent grepping files, not the wiki retrieving — it must stay visible in
  # the report even when the wiki is populated, or R1/R2 drift into measuring
  # filesystem access.
  if grep -qE '^- Wiki: *\(none' "$answer" 2>/dev/null; then via=raw-only
  elif grep -qE '^- Wiki: *[^(]' "$answer" 2>/dev/null; then via=wiki
  else via=unknown; fi

  detail+=("$qid|$modality|$a_verdict|$c_verdict|$via|$(retr_citations "$answer" | tr '\n' ' ')")
  echo "[retr]   answer: $a_verdict  citation: $c_verdict  via: $via" >&2
done < "$tmp_q"

# ── R5: mutate a raw body post-ingest; the answer must flag it ────────────────
r5_pass=0; r5_total=0; r5_note="skipped (holdout run)"
if [ "$HOLDOUT" -eq 0 ]; then
  r5_total=1
  target=$(find "$WIKI/raw" -name 'capacity-report-q1*' -type f | head -1)
  if [ -z "$target" ]; then
    r5_note="inconclusive: capacity-report-q1 never reached raw/ (extract failed)"
  else
    # R5 deliberately corrupts a raw body, which makes this work dir unsafe to
    # resume: a later run with `extract` cached would re-ingest the MUTATED text,
    # commit ingested_hash over it, and leave the drift undetectable — R5 becomes
    # structurally unscoreable and the as-of question silently changes answer.
    # That happened. Snapshot before, restore after, and mark the dir either way.
    # No EXIT trap here: in non-resumable mode that slot already holds the
    # temp-dir cleanup. Restore runs inline after R5, and if the run is killed
    # mid-R5 the `.mutated` marker survives and the startup guard blocks the
    # resume — a stuck marker costs one re-extract, a silent one costs the score.
    cp "$target" "$WORK/.r5-pristine" 2>/dev/null || true
    : > "$WORK/.mutated"
    LC_ALL=C sed -i '' 's/412 GB\/day/999 GB\/day/' "$target" 2>/dev/null \
      || LC_ALL=C sed -i 's/412 GB\/day/999 GB\/day/' "$target"
    if "$DRIFT_LINT" "$WIKI/raw" >/dev/null 2>&1; then
      r5_note="inconclusive: drift lint did not fire on a mutated body"
    else
      answer="$WORK/R5.answer.md"
      if [ -s "$answer" ]; then
        echo "[retr] R5 — cached, regrading" >&2
      else
        echo "[retr] R5 (post-mutation re-query)" >&2
        ( cd "$WIKI" && claude -p "/wiki-query \"What was sustained throughput as of 2026-04-15?\" --no-promote" ) \
          >"$answer" 2>"$WORK/R5.err" </dev/null || true
      fi
      if grep -qiE 'drift|stale|changed since|no longer match|re-ingest|out of date' "$answer"; then
        r5_pass=1; r5_note="answer flagged the drifted source"
      else
        r5_note="answer served the claim without flagging the drifted source"
      fi
      detail+=("R5-drift|vintage|$([ "$r5_pass" -eq 1 ] && echo PASS || echo FAIL)|n/a|n/a|")
    fi
    # Undo the corruption so this work dir stays resumable.
    if [ -f "$WORK/.r5-pristine" ]; then
      cp "$WORK/.r5-pristine" "$target" && rm -f "$WORK/.mutated"
    fi
  fi
fi

# ── Report ────────────────────────────────────────────────────────────────────
total_pass=$((r1_pass + r2_pass + r3_pass + r4_pass + r5_pass))
total=$((r1_total + r2_total + r3_total + r4_total + r5_total))

cat <<EOF
# retrieval eval report$([ "$HOLDOUT" -eq 1 ] && echo " — HELDOUT")

Corpus: tests/eval/retrieval-corpus/gen-corpus.sh (generated, deterministic)
Questions: $QUESTIONS ($n_q)
Wiki: built by create-llm-wiki.sh, loaded via /wiki-extract + /wiki-ingest
Loaded: $extracted raw files, $pages wiki pages

R1 needle retrieval:    $r1_pass/$r1_total
R2 point-in-time:       $r2_pass/$r2_total
R3 refusal on absence:  $r3_pass/$r3_total
R4 citation locus:      $r4_pass/$r4_total
R5 stale evidence:      $r5_pass/$r5_total   ($r5_note)

retrieval score: $total_pass/$total

## Per-question detail

| question | modality | answer | citation | via | cited |
|---|---|---|---|---|---|
EOF
for row in "${detail[@]}"; do
  IFS='|' read -r a b c d e f <<< "$row"
  printf '| %s | %s | %s | %s | %s | %s |\n' "$a" "$b" "$c" "$d" "$e" "$f"
done

if [ "$HOLDOUT" -eq 1 ]; then
  echo ""
  echo "This is the held-out control. If the main run is green and this is not,"
  echo "the main checks have been optimised against. Fix the system, not this file."
fi

exit 0
