#!/usr/bin/env bash
# scripts/eval-retrieval.sh — cross-modality, point-in-time retrieval eval.
#
# Turns "can a bootstrapped wiki retrieve accurate, point-in-time info about
# anything?" into five numbers. Everything runs against a wiki built by the REAL
# installer (create-llm-wiki.sh) and populated through the REAL /ctx-extract →
# /ctx-compile path, so a failure here is a failure a user would hit — not a
# fixture artifact. No pre-built wiki fixture is used on purpose: the modality
# gaps this eval exists to find (tabular truncation, thread flattening) live in
# extract and ingest, and a hand-authored fixture would paper over exactly them.
#
# Loss function — 10 binary checks (approved):
#   R1  needle retrieval    per modality (csv / email / report), planted past
#                           each extractor's truncation boundary
#   R2  point-in-time       as-of and current answers, both correct in ONE run
#   R3  refusal on absence  a question the corpus cannot answer is declined,
#                           not fabricated
#   R4  citation locus      some cited passage both CONTAINS the fact and spans
#                           <= max-span lines (provenance that is real AND tight)
#   R5  stale evidence      after a raw body is mutated post-ingest, the answer
#                           flags it instead of serving the stale claim
#   M1  multi-valued answer a question whose corpus support is genuinely
#                           two-valued (disjoint scopes) surfaces BOTH figures
#                           with their scopes, instead of picking one
#   M2  supersession        "what replaced X" is answered correctly AND the
#                           succession is machine-readable: wiki-to-kg.py emits
#                           a supersedes edge inferred with no prose cue
#   M4  clarify-on-ambiguity an underspecified question gets a clarification or
#                           an enumeration of candidate readings, never a
#                           confident single pick (anti-reflex control: holdout)
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
SCALE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --holdout) HOLDOUT=1; GEN_MODE=--holdout
               QUESTIONS="$REPO_ROOT/tests/eval/retrieval-questions-holdout.md" ;;
    --work=*)  WORK="${arg#--work=}" ;;
    --scale=*) SCALE="${arg#--scale=}"
               case "$SCALE" in ''|*[!0-9]*)
                 echo "error: --scale needs an integer" >&2; exit 2 ;; esac ;;
    *) echo "usage: eval-retrieval.sh [--dry-run] [--holdout] [--work=DIR] [--scale=N]" >&2; exit 2 ;;
  esac
done
FILLER_GEN="$REPO_ROOT/tests/eval/retrieval-corpus/gen-scale-filler.sh"
QUERY_TRACE="$SCRIPT_DIR/lib/query-trace.py"

for f in "$GEN" "$QUESTIONS" "$CITE_SPAN" "$INSTALLER" "$LIB"; do
  [ -e "$f" ] || { echo "error: missing $f" >&2; exit 1; }
done
# shellcheck source=scripts/lib/eval-common.sh
. "$LIB"
# shellcheck source=scripts/lib/commitment.sh
. "$SCRIPT_DIR/lib/commitment.sh"
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
  echo "would run: create-llm-wiki.sh → /ctx-extract (all sources) → /ctx-compile"
  echo "           → /ctx-query per question → mutate raw → /ctx-query (R5)"
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

# ── Scale filler: pre-populate the wiki BEFORE the real extract/ingest, so the
# librarian meets a big index and retrieval must discriminate among distractors.
if [ "$SCALE" -gt 0 ]; then
  if staged filler; then
    echo "[retr] skip scale filler (done)" >&2
  else
    echo "[retr] injecting $SCALE deterministic filler pages" >&2
    "$FILLER_GEN" "$WIKI" "$SCALE" >&2 \
      || { echo "error: scale filler generation failed" >&2; exit 1; }
    mark_done filler
  fi
fi

sources=()
for f in "$CORPUS"/*; do sources+=("$f"); done

if staged extract; then
  echo "[retr] skip /ctx-extract (done)" >&2
else
  echo "[retr] /ctx-extract (${#sources[@]} sources)" >&2
  claude_p "$WORK/extract.log" "/ctx-extract ${sources[*]}"
  mark_done extract
fi

if staged ingest; then
  echo "[retr] skip /ctx-compile (done)" >&2
else
  echo "[retr] /ctx-compile" >&2
  claude_p "$WORK/ingest.log" "/ctx-compile"
  mark_done ingest
fi

extracted=$(find "$WIKI/raw" -type f 2>/dev/null | wc -l | tr -d ' ')
pages=$(find "$WIKI/wiki" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
echo "[retr] raw/: $extracted files, wiki/: $pages pages" >&2

# ── Precondition: refuse to score an unpopulated wiki ─────────────────────────
#
# This gate is the lesson from a void run. With an empty wiki, /ctx-query
# answered every question correctly by reading raw/ directly and said so — so
# R1 scored 3/3 and R2 scored 2/2 while measuring nothing but "an agent can grep
# a file". Passing on raw-only reads is the loss function's biggest false-pass
# route, and a scored report is worse than no report because it looks like
# evidence. Abort loudly instead, and do not spend on queries that cannot
# measure the thing.
# NEVER count commitments with `grep -rlc`: mixing -l and -c makes grep emit a
# line for EVERY file, non-matches included, so the count becomes "how many raw
# files exist" instead of "how many carry a hash". Measured: at 100 filler pages
# it reported 13 while the true number of committed needle sources was 0 — the
# gate cleared and the run was scored on a wiki whose entire provenance layer
# was missing. That is the void-run lesson repeating in a new disguise, so the
# gate now consumes the explicit loop below and nothing else.
# Commitment rate over REAL needle sources. Three false-alarm routes this
# closes, all found the first time the line printed ("22/12" — a numerator
# above its own denominator): filler raws carry hashes by construction;
# `.gitkeep` is scaffolding, not a source; and a binary/tabular source (a .csv)
# keeps its commitment on the parsed `<name>.md` sidecar extract wrote beside
# it, so checking only the .csv reports a gap that isn't one. A sensor that
# cries wolf gets ignored, which is worse than not having it.
committed=0; needle_raws=0
while IFS= read -r f; do
  base=$(basename "$f")
  case "$base" in .*|scale-*) continue ;; esac
  case "$f" in *.md) [ -f "${f%.md}" ] && continue ;; esac  # sidecar counted with its parent
  needle_raws=$((needle_raws + 1))
  if has_commitment "$f"; then
    committed=$((committed + 1))
  fi
done < <(find "$WIKI/raw" -type f 2>/dev/null | sort)
if [ "$pages" -le 1 ] || [ "$committed" -eq 0 ]; then
  {
    echo "# retrieval eval — VOID (not a score)"
    echo ""
    echo "The wiki was never populated, or ingest never committed its sources, so"
    echo "no question here can measure verifiable wiki retrieval."
    echo ""
    echo "- wiki pages:      $pages (need > 1)"
    echo "- committed raw:   $committed of $needle_raws needle sources carry an ingested_hash (need > 0)"
    echo "- ingest log tail: $(tail -3 "$WORK/ingest.log" 2>/dev/null | tr '\n' ' ')"
    echo ""
    echo "With an empty wiki, /ctx-query falls back to reading raw/ directly and"
    echo "needle questions pass for the wrong reason. Fix ingest, then re-run:"
    echo "  scripts/eval-retrieval.sh --work=$WORK"
    echo "(extract is cached; delete \$WORK/.done-ingest to retry just ingest)"
  }
  echo "[retr] VOID: $pages pages, $committed/$needle_raws sources committed — not scoring" >&2
  exit 3
fi

# ── Run the questions ─────────────────────────────────────────────────────────
declare -a detail=()
r1_pass=0; r1_total=0
r2_pass=0; r2_total=0
r3_pass=0; r3_total=0
r4_pass=0; r4_total=0
m1_pass=0; m1_total=0
m4_pass=0; m4_total=0
m6_pass=0; m6_total=0; m6_bad=""; m6_cites=0
m2_answer=MISSING
m5_answer=MISSING
inconclusive=0

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
    # stream-json so the transcript records WHAT the agent read — the scale
    # eval's cost metric. query-trace.py distils answer text + read counts;
    # if the stream is unparseable the raw bytes become the answer so the
    # API-error markers stay visible to retr_answer_broken.
    ( cd "$WIKI" && claude -p "/ctx-query \"$question\" --no-promote" \
        --output-format stream-json --verbose ) \
      >"$WORK/$qid.stream" 2>"$WORK/$qid.err" </dev/null || true
    python3 "$QUERY_TRACE" "$WORK/$qid.stream" --counts "$WORK/$qid.reads" \
      >"$answer" 2>>"$WORK/$qid.err" || cp "$WORK/$qid.stream" "$answer"
  fi
  reads="?"
  if [ -f "$WORK/$qid.reads" ]; then
    reads=$(awk '{ for (i=1;i<=NF;i++) { split($i,kv,"="); c[kv[1]]=kv[2] }
                   printf "%d+g%d", c["reads_wiki"]+c["reads_raw"], c["greps"] }' \
            "$WORK/$qid.reads")
  fi

  if retr_answer_broken "$answer"; then
    # No answer reached us — network/API failure, not a capability result.
    a_verdict=INCONC
    echo "[retr]   !! no answer (API/network) — excluded from the score" >&2
  elif retr_grade_answer "$answer" "$expects" "$forbids" "$refusal"; then
    a_verdict=PASS
  else
    a_verdict=FAIL
  fi

  # M2 is scored after the loop (its verdict is ANDed with a structural check),
  # so stash the answer verdict — including INCONC — instead of bucketing it.
  case "$qid" in
    M2-*) m2_answer="$a_verdict" ;;
    M5-*) m5_answer="$a_verdict" ;;
  esac

  # M6: does every citation this answer offers actually resolve? Scored on any
  # answer that cited anything, independent of whether the question carries a
  # cite-contains — a fabricated target is a defect wherever it appears.
  if [ "$a_verdict" != INCONC ]; then
    if retr_cite_integrity "$answer" "$WIKI/raw" "$CITE_SPAN"; then
      if [ "${RETR_CITE_TOTAL:-0}" -gt 0 ]; then
        m6_total=$((m6_total + 1)); m6_pass=$((m6_pass + 1))
        m6_cites=$((m6_cites + RETR_CITE_TOTAL))
      fi
    else
      m6_total=$((m6_total + 1))
      m6_cites=$((m6_cites + RETR_CITE_TOTAL))
      m6_bad="$m6_bad $qid:${RETR_CITE_BAD}/${RETR_CITE_TOTAL}(${RETR_CITE_BAD_LIST# })"
    fi
  fi

  c_verdict=n/a
  if [ -n "$cite" ] && [ "$a_verdict" != INCONC ]; then
    r4_total=$((r4_total + 1))
    if retr_grade_citation "$answer" "$WIKI/raw" "$cite" "${span:-40}" "$CITE_SPAN"; then
      c_verdict=PASS; r4_pass=$((r4_pass + 1))
    else
      c_verdict=FAIL
    fi
  fi

  if [ "$a_verdict" = INCONC ]; then
    inconclusive=$((inconclusive + 1))
  else
    case "$qid" in
      R1-*|H1-*)  r1_total=$((r1_total + 1)); [ "$a_verdict" = PASS ] && r1_pass=$((r1_pass + 1)) ;;
      R2-*|T2-*)  r2_total=$((r2_total + 1)); [ "$a_verdict" = PASS ] && r2_pass=$((r2_pass + 1)) ;;
      R3-*)       r3_total=$((r3_total + 1)); [ "$a_verdict" = PASS ] && r3_pass=$((r3_pass + 1)) ;;
      M1-*)       m1_total=$((m1_total + 1)); [ "$a_verdict" = PASS ] && m1_pass=$((m1_pass + 1)) ;;
      M4-*|H4-*)  m4_total=$((m4_total + 1)); [ "$a_verdict" = PASS ] && m4_pass=$((m4_pass + 1)) ;;
    esac
  fi

  # Which layer actually answered. A correct answer sourced only from raw/ is
  # the agent grepping files, not the wiki retrieving — it must stay visible in
  # the report even when the wiki is populated, or R1/R2 drift into measuring
  # filesystem access.
  if grep -qE '^- Wiki: *\(none' "$answer" 2>/dev/null; then via=raw-only
  elif grep -qE '^- Wiki: *[^(]' "$answer" 2>/dev/null; then via=wiki
  else via=unknown; fi

  detail+=("$qid|$modality|$a_verdict|$c_verdict|$via|$reads|$(retr_citations "$answer" | tr '\n' ' ')")
  echo "[retr]   answer: $a_verdict  citation: $c_verdict  via: $via  reads: $reads" >&2
done < "$tmp_q"

# Reads summary over answered (non-INCONC) questions with a recorded trace.
reads_summary="n/a (no traces)"
reads_list=$(for row in "${detail[@]}"; do
  IFS='|' read -r _ _ v _ _ r _ <<< "$row"
  [ "$v" != INCONC ] && [ "$r" != "?" ] && printf '%s\n' "${r%%+*}"
done | sort -n)
if [ -n "$reads_list" ]; then
  reads_summary=$(printf '%s\n' "$reads_list" | awk '
    { a[NR] = $1 } END {
      if (NR == 0) { print "n/a"; exit }
      m = (NR % 2) ? a[(NR+1)/2] : a[NR/2]
      printf "median=%d max=%d (wiki+raw file reads per answer)", m, a[NR]
    }')
fi

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
      # No drift detected on a body we just mutated means the precondition is
      # missing, not that the answer was wrong: ingest never committed an
      # `ingested_hash` for this source, so there is no commitment to drift
      # FROM. Scoring that 0/1 blames the answer for a gap in ingest. Exclude
      # it (like an API failure) and let the Commitment line below carry the
      # real signal — observed at 100 filler pages, where capacity-report-q1
      # came back with `ingested_hash: ""` while the same ingest at 0 filler
      # committed it. That degradation is a scale finding worth seeing plainly.
      r5_total=0
      r5_note="inconclusive: no ingest commitment on the mutated source (ingested_hash empty) — drift undetectable, R5 not exercised"
    else
      answer="$WORK/R5.answer.md"
      if [ -s "$answer" ]; then
        echo "[retr] R5 — cached, regrading" >&2
      else
        echo "[retr] R5 (post-mutation re-query)" >&2
        ( cd "$WIKI" && claude -p "/ctx-query \"What was sustained throughput as of 2026-04-15?\" --no-promote" ) \
          >"$answer" 2>"$WORK/R5.err" </dev/null || true
      fi
      if retr_answer_broken "$answer"; then
        r5_total=0
        r5_note="inconclusive: no answer reached us (API/network), drift logic never exercised"
      elif grep -qiE 'drift|stale|changed since|no longer match|re-ingest|out of date' "$answer"; then
        r5_pass=1; r5_note="answer flagged the drifted source"
      else
        r5_note="answer served the claim without flagging the drifted source"
      fi
      detail+=("R5-drift|vintage|$([ "$r5_pass" -eq 1 ] && echo PASS || echo FAIL)|n/a|n/a|?|")
    fi
    # Undo the corruption so this work dir stays resumable.
    if [ -f "$WORK/.r5-pristine" ]; then
      cp "$WORK/.r5-pristine" "$target" && rm -f "$WORK/.mutated"
    fi
  fi
fi

# ── M2: the supersession must be machine-readable, not just answerable ────────
#
# A correct answer to M2-supersede proves date reasoning (the memo pair has no
# relational prose to lean on — E11 enforces that). It does NOT prove the
# succession exists as data: only a supersedes/superseded-by edge in the KG
# does. M2 passes when BOTH legs hold; each leg failing alone is named in the
# note so the report says which capability is missing.
m2_pass=0; m2_total=0; m2_note="skipped (holdout run)"
if [ "$HOLDOUT" -eq 0 ]; then
  if [ "$m2_answer" = INCONC ]; then
    m2_note="inconclusive: no answer reached us (API/network)"
  elif [ "$m2_answer" = MISSING ]; then
    m2_total=1
    m2_note="M2-supersede question never ran (removed from the questions file?)"
  else
    m2_total=1
    kg_out="$WORK/kg.jsonl"
    python3 "$SCRIPT_DIR/wiki-to-kg.py" "$WIKI/wiki/" >"$kg_out" 2>/dev/null || : >"$kg_out"
    if grep -E '"verb": "supersede(s|d-by)"' "$kg_out" | grep -q retry; then
      m2_struct=1
    else
      m2_struct=0
    fi
    if [ "$m2_struct" -eq 1 ] && [ "$m2_answer" = PASS ]; then
      m2_pass=1; m2_note="typed edge in KG and answer named the successor"
    elif [ "$m2_struct" -eq 0 ] && [ "$m2_answer" = PASS ]; then
      m2_note="answer right but NO supersedes edge in the KG — succession lives only in the model's reasoning"
    elif [ "$m2_struct" -eq 1 ]; then
      m2_note="edge exists but the answer failed"
    else
      m2_note="no supersedes edge and the answer failed"
    fi
  fi
fi

# ── M5: the feedback loop must exist as data, not only as narration ───────────
#
# Same two-leg shape as M2, for the same reason. A correct walk of the cycle
# proves the model can compose three separately-dated causal claims; it does
# NOT prove the cycle exists as machine-readable structure. Only a closed cycle
# in the materialised graph does — and closing it requires ingest to have typed
# every leg with a canonical causal verb, which is exactly what the "let loops
# close" instruction asks for. Each failing leg is named in the note.
m5_pass=0; m5_total=0; m5_note="skipped (holdout run)"
if [ "$HOLDOUT" -eq 0 ]; then
  if [ "$m5_answer" = INCONC ]; then
    m5_note="inconclusive: no answer reached us (API/network)"
  elif [ "$m5_answer" = MISSING ]; then
    m5_total=1
    m5_note="M5-loop question never ran (removed from the questions file?)"
  else
    m5_total=1
    loops_out="$WORK/loops.txt"
    python3 "$SCRIPT_DIR/wiki-to-kg.py" "$WIKI/wiki/" 2>/dev/null \
      | python3 "$SCRIPT_DIR/wiki-loops.py" >"$loops_out" 2>/dev/null || : >"$loops_out"
    # Require a REINFORCING cycle touching at least two of the three topics.
    # Slug-agnostic on purpose: the librarian names its own pages, so pinning
    # exact slugs would fail the check for a correct wiki.
    topics=$(grep '^reinforcing:' "$loops_out" 2>/dev/null \
      | grep -oiE 'queue|backlog|pag(er|ing)|mut(e|ed|ing)|silenc' | sort -u | wc -l | tr -d ' ')
    if [ "${topics:-0}" -ge 2 ]; then m5_struct=1; else m5_struct=0; fi
    if [ "$m5_struct" -eq 1 ] && [ "$m5_answer" = PASS ]; then
      m5_pass=1; m5_note="reinforcing cycle closed in the graph and the answer walked it"
    elif [ "$m5_struct" -eq 0 ] && [ "$m5_answer" = PASS ]; then
      m5_note="answer walked the cycle but the graph has NO closed loop — the feedback lives only in the model's reasoning, not in the wiki"
    elif [ "$m5_struct" -eq 1 ]; then
      m5_note="cycle exists in the graph but the answer failed to walk it"
    else
      m5_note="no closed cycle in the graph and the answer failed"
    fi
  fi
fi

# ── Report ────────────────────────────────────────────────────────────────────
total_pass=$((r1_pass + r2_pass + r3_pass + r4_pass + r5_pass + m1_pass + m2_pass + m4_pass + m5_pass + m6_pass))
total=$((r1_total + r2_total + r3_total + r4_total + r5_total + m1_total + m2_total + m4_total + m5_total + m6_total))

cat <<EOF
# retrieval eval report$([ "$HOLDOUT" -eq 1 ] && echo " — HELDOUT")

Corpus: tests/eval/retrieval-corpus/gen-corpus.sh (generated, deterministic)
Questions: $QUESTIONS ($n_q)
Wiki: built by create-llm-wiki.sh, loaded via /ctx-extract + /ctx-compile
Loaded: $extracted raw files, $pages wiki pages$([ "$SCALE" -gt 0 ] && echo " (includes $SCALE scale-filler pages)")
Reads: $reads_summary
Commitment: $committed/$needle_raws needle raw sources carry an ingested_hash$([ "$committed" -lt "$needle_raws" ] && echo "  <- ingest skipped the frontmatter commitment on $((needle_raws - committed)); every citation into those bodies is unverifiable")

R1 needle retrieval:    $r1_pass/$r1_total
R2 point-in-time:       $r2_pass/$r2_total
R3 refusal on absence:  $r3_pass/$r3_total
R4 citation locus:      $r4_pass/$r4_total
R5 stale evidence:      $r5_pass/$r5_total   ($r5_note)
M1 multi-valued answer: $m1_pass/$m1_total
M2 supersession:        $m2_pass/$m2_total   ($m2_note)
M4 clarify-on-ambig:    $m4_pass/$m4_total
M5 feedback loop:       $m5_pass/$m5_total   ($m5_note)
M6 citation integrity:  $m6_pass/$m6_total   ($m6_cites citations offered$([ -n "$m6_bad" ] && echo "; UNRESOLVABLE:$m6_bad" || echo ", all resolve"))

retrieval score: $total_pass/$total$([ "$inconclusive" -gt 0 ] && echo "   ($inconclusive question(s) INCONCLUSIVE — no answer reached us; excluded, not counted as failures)")

## Per-question detail

| question | modality | answer | citation | via | reads | cited |
|---|---|---|---|---|---|---|
EOF
for row in "${detail[@]}"; do
  IFS='|' read -r a b c d e f g <<< "$row"
  printf '| %s | %s | %s | %s | %s | %s | %s |\n' "$a" "$b" "$c" "$d" "$e" "$f" "$g"
done

if [ "$HOLDOUT" -eq 1 ]; then
  echo ""
  echo "This is the held-out control. If the main run is green and this is not,"
  echo "the main checks have been optimised against. Fix the system, not this file."
fi

exit 0
