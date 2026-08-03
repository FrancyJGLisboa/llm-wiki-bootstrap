#!/usr/bin/env bash
# scripts/lib/eval-common.sh — shared harness for the eval-multi-hop* trio
# (eval-multi-hop.sh, -sparse.sh, -sealed.sh). Extracts the logic those three
# scripts copy verbatim; the per-variant differences stay in the callers.
#
# SOURCE it, do not exec it:
#   . "$SCRIPT_DIR/lib/eval-common.sh"
#
# The lib sets NO `set` options — it inherits the caller's `set -uo pipefail`.
#
# What stays in the caller (the things that genuinely differ, per variant):
#   - QUESTIONS / FIXTURE_DIR / KG_GENERATOR paths and the report heading
#   - which strip flag to pass (verbs only vs verbs+tags)
#   - which grader to pass (substring vs word-boundary numeric)
#   - the improvement delta threshold (>=2 vs >=3)
#   - any CLI modes (e.g. sealed's --dry-run-baseline)

# eval_build_variant <variant> <work> <repo_root> <fixture_dir>
# Build one self-contained working wiki (schema + commands + fixture content).
# Does NOT strip — callers strip the baseline afterward with eval_strip_related.
eval_build_variant() {
  local variant="$1" work="$2" repo_root="$3" fixture_dir="$4"
  local vdir="$work/$variant"
  mkdir -p "$vdir/raw" "$vdir/wiki/journal"
  cp -r "$repo_root/.claude" "$vdir/"
  cp "$repo_root/AGENTS.md" "$vdir/"
  rm -f "$vdir/wiki/"*.md
  cp -r "$fixture_dir"/*.md "$vdir/wiki/"
  : > "$vdir/wiki/journal/.gitkeep"
  printf '# log.md\n\n' > "$vdir/log.md"
}

# eval_strip_related <file> <strip_tags 0|1>
# Strip the verb (and, with strip_tags=1, the numeric attr) from single-target
# `## Related` lines, in place. strip_tags=1 also drops `tags:` lines entirely.
# strip_tags=0 reproduces the old strip_verbs_from_file; strip_tags=1 reproduces
# the old sealed_strip_file — byte for byte.
eval_strip_related() {
  local file="$1" strip_tags="$2"
  awk -v strip_tags="$strip_tags" '
    BEGIN { in_related = 0 }
    strip_tags == 1 && /^tags:[[:space:]]/ { next }
    /^## Related[[:space:]]*$/ { in_related = 1; print; next }
    /^## / && !/^## Related/  { in_related = 0; print; next }
    {
      if (in_related && match($0, /^[[:space:]]*-[[:space:]]+\[\[[a-z][a-z0-9-]*\]\]/)) {
        n = 0; tmp = $0
        while (match(tmp, /\[\[[a-z][a-z0-9-]*\]\]/)) {
          n++
          tmp = substr(tmp, RSTART + RLENGTH)
        }
        if (n == 1) {
          close_idx = index($0, "]]")
          prefix = substr($0, 1, close_idx + 1)
          rest = substr($0, close_idx + 2)
          em = sprintf("%c%c%c", 226, 128, 148)
          em_pos = index(rest, em)
          dh_pos = index(rest, "--")
          cut = 0
          if (em_pos > 0 && (dh_pos == 0 || em_pos < dh_pos)) cut = em_pos
          else if (dh_pos > 0) cut = dh_pos
          if (cut > 0) {
            tail = substr(rest, cut)
            print prefix " " tail
            next
          }
        }
      }
      print
    }
  ' "$file" > "$file.stripped" && mv "$file.stripped" "$file"
}

# eval_gen_kg_sidecar <work> <kg_generator> <prefix>
# If the KG generator exists, build wiki/_kg.jsonl in the TYPED variant only
# (never baseline). No-op (with a log line) when the generator is absent.
eval_gen_kg_sidecar() {
  local work="$1" kg_generator="$2" prefix="$3"
  if [ -f "$kg_generator" ]; then
    echo "[$prefix] generating wiki/_kg.jsonl in typed variant only" >&2
    python3 "$kg_generator" "$work/typed/wiki/" > "$work/typed/wiki/_kg.jsonl" \
      || { echo "error: $kg_generator failed" >&2; return 1; }
    echo "[$prefix] typed wiki/_kg.jsonl: $(wc -l < "$work/typed/wiki/_kg.jsonl" | tr -d ' ') lines" >&2
  else
    echo "[$prefix] KG generator absent; both variants sidecar-less" >&2
  fi
}

# eval_parse_questions <questions_file> <out_tsv>
# Parse the questions markdown into qid<TAB>question<TAB>expects<TAB>absent rows.
# `hops:` lines are skipped (harmless for files that have none).
eval_parse_questions() {
  local questions="$1" out_tsv="$2"
  awk '
    function emit() {
      if (qid != "") {
        gsub(/\t/, " ", question); gsub(/\t/, " ", expects); gsub(/\t/, " ", absent)
        printf "%s\t%s\t%s\t%s\n", qid, question, expects, absent
      }
    }
    /^### Q[0-9]+/ {
      emit()
      qid = $0; sub(/^### /, "", qid)
      question = ""; expects = ""; absent = ""
      next
    }
    /^expects:/        { expects = $0; sub(/^expects:[[:space:]]*/, "", expects); next }
    /^baseline-absent:/ { absent  = $0; sub(/^baseline-absent:[[:space:]]*/, "", absent); next }
    /^hops:/           { next }
    /^##/  { next }
    /^$/   { next }
    /^```/ { next }
    /^- /  { next }
    {
      if (qid != "") {
        if (question == "") question = $0
        else question = question " " $0
      }
    }
    END { emit() }
  ' "$questions" > "$out_tsv"
}

# Graders: each takes <token> <file> and returns 0 (match) / non-zero (miss).
# eval_grade_substring   — case-insensitive substring (multi-hop, sparse).
eval_grade_substring() {
  grep -q -F -i "$1" "$2"
}
# eval_grade_numeric_wordboundary — word-boundary match for pure-numeric tokens,
# substring otherwise (sealed; avoids "page 12" false-passing expects: 12).
eval_grade_numeric_wordboundary() {
  local token="$1" file="$2"
  if [[ "$token" =~ ^[0-9]+$ ]]; then
    grep -qE "(^|[^0-9])${token}([^0-9]|$)" "$file"
  else
    grep -q -F -i "$token" "$file"
  fi
}

# eval_run_questions <tsv> <work> <results_md> <prefix> <grader_fn>
# Run every question against the baseline and typed variants, grade with
# <grader_fn>, append per-question detail to <results_md>, and set the globals
# EVAL_BASELINE_PASS / EVAL_TYPED_PASS for the caller.
eval_run_questions() {
  local tsv="$1" work="$2" results_md="$3" prefix="$4" grader="$5"
  EVAL_BASELINE_PASS=0
  EVAL_TYPED_PASS=0
  : > "$results_md"

  local qid question expects absent
  while IFS=$'\t' read -r qid question expects absent; do
    [ -z "$qid" ] && continue
    echo "[$prefix] $qid: $question" >&2

    {
      echo "### $qid"; echo ""
      echo "Question: $question"
      echo "Expects: $expects"
      echo "baseline-absent: $absent"; echo ""
    } >> "$results_md"

    local variant answer_file pass token token_trim verdict_tag OLD_IFS
    for variant in baseline typed; do
      answer_file="$work/$variant.$qid.md"
      ( cd "$work/$variant" && \
        claude -p "/wiki-query \"$question\" --no-promote" \
          > "$answer_file" 2>"$work/$variant.$qid.err" ) || true

      pass=1
      OLD_IFS="$IFS"
      IFS=','
      for token in $expects; do
        token_trim=$(printf '%s' "$token" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [ -z "$token_trim" ]; then continue; fi
        if ! "$grader" "$token_trim" "$answer_file"; then
          pass=0
          break
        fi
      done
      IFS="$OLD_IFS"

      if [ "$pass" -eq 1 ]; then
        [ "$variant" = "baseline" ] && EVAL_BASELINE_PASS=$((EVAL_BASELINE_PASS + 1))
        [ "$variant" = "typed"    ] && EVAL_TYPED_PASS=$((EVAL_TYPED_PASS + 1))
        verdict_tag="PASS"
      else
        verdict_tag="FAIL"
      fi
      echo "[$prefix]   $variant: $verdict_tag" >&2
      echo "- $variant: $verdict_tag" >> "$results_md"
    done
    echo "" >> "$results_md"
  done < "$tsv"
}

# eval_verdict <typed_pass> <baseline_pass> <improve_threshold>
# Echo improvement | no-improvement | null-result.
eval_verdict() {
  local delta=$(( $1 - $2 ))
  if [ "$delta" -ge "$3" ]; then
    echo "improvement"
  elif [ "$delta" -le -1 ]; then
    echo "no-improvement"
  else
    echo "null-result"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Retrieval eval (scripts/eval-retrieval.sh) — parsing + graders.
#
# Kept here, not in the eval script, so scripts/verify-retrieval-eval.sh can
# source and exercise them against synthetic answers with no LLM and no spend.
# An eval whose graders are themselves unverified measures nothing: a grader
# that always returns PASS produces a perfect score on a broken system.
# ─────────────────────────────────────────────────────────────────────────────

# Phrases that count as declining to answer. Deliberately narrow: "not in the
# wiki" is a refusal, "not clear" is hedging inside an answer.
RETR_REFUSAL_MARKERS='not in the wiki|no answer in|not found in the wiki|nothing in the wiki|is not covered|no .{0,20}(figure|report|data|record) (for|in) |cannot answer|can'"'"'t answer|no such (figure|report|record)|not present in the wiki|the wiki does not'
# Second family of acknowledgements, added after a textbook refusal graded FAIL:
# "No Q2 2026 sustained throughput figure exists in this wiki" matched none of
# the above (they all require "for"/"in" immediately after the noun). Broadening
# the acknowledgement side is safe because the teeth of a refusal check are the
# forbids-pattern — the answer still fails if it states a number it cannot know.
#
# Kept free of nested bounded quantifiers on purpose: an earlier version used
# `no .{0,40}(figure|report)[^.]{0,30}exist` and hung BSD grep by backtracking.
RETR_REFUSAL_MARKERS="$RETR_REFUSAL_MARKERS"'|(figure|report|record|data) exists|does not exist|no report|will not (interpolate|fabricate|guess|invent)'

# Markers for `refusal: clarify` (M4): an underspecified question must be met
# with a clarification or an explicit ambiguity call-out, never a confident
# single pick. An answer that ENUMERATES all candidate readings ("depends on
# which system: ...") is as good as asking — the markers accept both shapes.
# Bounded quantifiers only (see the backtracking incident above).
RETR_CLARIFY_MARKERS='do you mean|which .{0,40}\?|ambiguous|could (refer|mean)|more than one|multiple .{0,30}(polic|figure|period|retention|reading)|depends on (which|whether|what|the)|clarify|specify which|underspecified'
# The strongest shape an answer can take on an underspecified question is to
# COUNT the readings and refuse the single pick outright — "There are three
# retention periods, not one" — which matched none of the markers above and so
# graded FAIL on the best answer in the run. Broadening the acknowledgement
# side stays safe for the same reason it does for refusals: the teeth are
# elsewhere. `expects` still requires every candidate reading to be named, and
# the H4 holdout still fails an answer that hedges when one reading is
# overwhelmingly likely, so "clarify on everything" cannot pass by phrasing.
RETR_CLARIFY_MARKERS="$RETR_CLARIFY_MARKERS"'|, not (just )?one|not one but|there are (two|three|four|five|[2-9]) |(two|three|four|[2-9]) (different |distinct |separate )?(retention |backup )?(polic|period|figure|window|answer)'
# Hyphenation is a style choice, not a semantic one: "under-specified" and
# "underspecified" mean the same thing and one of them graded FAIL.
RETR_CLARIFY_MARKERS="$RETR_CLARIFY_MARKERS"'|under.?specified|no single|not a single (retention|figure|value|answer)|which (one|of these)'

# retr_parse_questions <questions_file> <out_tsv>
# Emit: qid<TAB>question<TAB>modality<TAB>expects<TAB>cite_contains<TAB>max_span<TAB>forbids<TAB>refusal
#
# Absent fields are emitted as `-`, never as an empty string: tab is IFS
# whitespace, so bash `read` collapses consecutive tabs and every field after an
# empty one shifts left. Consumers normalise `-` back to "" via retr_field.
retr_parse_questions() {
  awk '
    function dash(s) { return (s == "" ? "-" : s) }
    function emit() {
      if (qid != "") {
        gsub(/\t/, " ", question)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
               qid, dash(question), dash(modality), dash(expects),
               dash(cite), dash(span), dash(forbids), dash(refusal)
      }
    }
    # The per-question FORMAT block is a fenced example that looks exactly like a
    # question. Skip fenced regions entirely or the template parses as a question.
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^### / {
      emit()
      qid = $0; sub(/^### /, "", qid)
      question = ""; modality = ""; expects = ""; cite = ""
      span = ""; forbids = ""; refusal = "false"
      next
    }
    qid == "" { next }
    /^modality:/        { modality = $0; sub(/^modality:[[:space:]]*/, "", modality); next }
    /^expects:/         { expects  = $0; sub(/^expects:[[:space:]]*/, "", expects); next }
    /^cite-contains:/   { cite     = $0; sub(/^cite-contains:[[:space:]]*/, "", cite); next }
    /^max-span:/        { span     = $0; sub(/^max-span:[[:space:]]*/, "", span); next }
    /^forbids-pattern:/ { forbids  = $0; sub(/^forbids-pattern:[[:space:]]*/, "", forbids); next }
    /^refusal:/         { refusal  = $0; sub(/^refusal:[[:space:]]*/, "", refusal); next }
    # Author-side metadata that must NEVER reach the model. `requires:` names the
    # exact source files the answer needs; `change:` states the answer outright.
    # Both are consumed by scoring and analysis, not by the question. Without
    # these two skips the catch-all below folds them into the question text and
    # the eval hands the model the evidence AND the label — scoring near 100%
    # while measuring nothing. Unknown-field-becomes-question is a silent
    # failure mode: the run looks healthy and the number is worthless.
    /^requires:/        { next }
    /^change:/          { next }
    # cite-file-matches is graded by eval-corpus.sh, which reads it separately
    # because it is not in this field list. True — but the
    # catch-all below then folded it into the QUESTION, so 54 of the 66 gold
    # questions were asking the model the question plus `cite-file-matches:
    # ^2020-09-16-`. That ERE names the date prefix of the correct source, and
    # the A1 leg it feeds is precisely "did you cite a source of the right date".
    # Every A1 figure measured before this line was added had the answer to its
    # own citation check pasted into the prompt.
    /^cite-file-matches:/ { next }
    /^```/ { next }
    /^#/   { next }
    /^$/   { next }
    { question = (question == "" ? $0 : question " " $0) }
    END { emit() }
  ' "$1" > "$2"
}

# retr_field <value> — echo "" for the `-` placeholder, the value otherwise.
retr_field() { [ "$1" = "-" ] && echo "" || echo "$1"; }

# retr_grade_answer <answer_file> <expects_csv> <forbids_ere> <refusal true|false>
# 0 = PASS. Scores the R1/R2/R3 bit: did the answer carry the fact (or decline
# when it should have), without matching the fabrication pattern.
#
# `expects` is a document-wide substring search, which is NOT enough on its own:
# an as-of answer once led with the wrong figure and still passed because the
# right one appeared further down in a caveat explaining why the headline was
# suspect. Scoping `expects` to the first N lines was tried and is worse — it
# fails answers that open with a preamble while still passing that same buried
# case. The working guard is per-question: a question with a plausible wrong
# answer carries a `forbids-pattern` that matches the wrong answer in headline
# position. Location is the question author's problem, not the grader's.
# retr_answer_broken <answer_file> — true when the file holds no answer at all:
# a transient API/network error, or nothing. Such a file must be reported
# INCONCLUSIVE, never graded: a dropped connection scored as FAIL is
# indistinguishable in the report from a real capability gap, and that is how a
# network blip becomes a bug report against the system. Observed — an ENOTFOUND
# mid-run scored R5 as FAIL on a run where the drift logic was never invoked.
RETR_BROKEN_MARKERS='^API Error|Unable to connect to API|^error: |Overloaded|session limit|usage limit|rate limit|quota exceeded|Please run /login|credit balance'
# Uppercase transport codes live in their OWN list, matched case-SENSITIVELY and
# word-bounded. Case-insensitive substring matching on `ENOTFOUND` classified a
# complete, correct answer as "no answer reached us" because the answer
# mentioned `ModuleNotFoundError` — which contains the letters e-n-o-t-f-o-u-n-d.
# An error CODE is a token, not a phrase; never fold its case into prose.
RETR_BROKEN_CODES='ENOTFOUND|ECONNRESET|ECONNREFUSED|ETIMEDOUT|EAI_AGAIN'
# Model-cap phrasing is NOT stable across releases and every miss is expensive:
# an unmatched cap message is graded as a wrong ANSWER, so a run that never
# reached the model reads in the report as a capability collapse. Observed — a
# 500-page scale run scored 0/21 on "You've reached your <Model> limit. Run
# /usage-credits ...", which matched none of the markers above ("usage limit"
# and "rate limit" are both absent from that string). Match the SHAPE (reached
# a limit / the remedy the CLI offers), not one release's wording.
RETR_BROKEN_MARKERS="$RETR_BROKEN_MARKERS"'|reached your .{0,40}limit|/usage-credits|switch models with|upgrade to continue'
retr_answer_broken() {
  [ -f "$1" ] || return 0
  [ -s "$1" ] || return 0
  grep -qiE "$RETR_BROKEN_MARKERS" "$1" && return 0
  grep -qE "(^|[^A-Za-z])($RETR_BROKEN_CODES)([^A-Za-z]|$)" "$1" && return 0
  return 1
}


# retr_grade_answer normalises markdown emphasis before ANY matching, then
# delegates. Emphasis is the single most common reason a correct answer grades
# FAIL: the model writes "the wiki holds **three** retention windows" and every
# prose marker looking for `three retention window` misses, because the literal
# bytes are `three** retention`. Same trap for an expects token — `**7**
# attempts` does not contain `7 attempts`. Answers are prose written for humans;
# the grader has to read them as prose. Headline-anchored forbids-patterns keep
# working (they allow leading punctuation), and stripping emphasis only makes
# their anchors more reliable.
retr_grade_answer() {
  local answer="$1" norm rc
  [ -f "$answer" ] || return 1
  norm=$(mktemp) || return 1
  sed 's/[*_`]//g' "$answer" > "$norm" 2>/dev/null || cp "$answer" "$norm"
  retr_grade_answer_raw "$norm" "$2" "$3" "$4"; rc=$?
  rm -f "$norm"
  return "$rc"
}

retr_grade_answer_raw() {
  local answer="$1" expects="$2" forbids="$3" refusal="$4" token OLD_IFS
  [ -f "$answer" ] || return 1

  if [ -n "$forbids" ] && grep -qE "$forbids" "$answer"; then
    return 1
  fi

  if [ "$refusal" = "true" ]; then
    grep -qiE "$RETR_REFUSAL_MARKERS" "$answer" || return 1
    return 0
  fi

  # clarify: the ambiguity must be surfaced, AND the expects tokens (every
  # candidate reading) must still appear — fall through to the expects loop.
  if [ "$refusal" = "clarify" ]; then
    grep -qiE "$RETR_CLARIFY_MARKERS" "$answer" || return 1
  fi

  OLD_IFS="$IFS"; IFS=','
  for token in $expects; do
    token=$(printf '%s' "$token" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -z "$token" ] && continue
    if ! grep -q -F -i "$token" "$answer"; then IFS="$OLD_IFS"; return 1; fi
  done
  IFS="$OLD_IFS"
  return 0
}

# retr_citations <answer_file>
# Print every `raw/<file>[#anchor]` target cited in the answer, one per line.
#
# Match each `source: raw/<target>` on its own rather than the enclosing
# parenthetical: models legitimately pack two receipts into one paren —
# `(source: raw/a.md#L26, source: raw/a.md#L22)` — and grabbing everything up
# to the closing `)` yielded ONE target with a comma and a second "source:"
# inside it, which resolves to nothing. That fabricated two citation failures
# out of correct answers on M6's first run.
retr_citations() {
  grep -oE 'source:[[:space:]]*raw/[^),;[:space:]]+' "$1" 2>/dev/null \
    | sed -e 's/^source:[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | sort -u
}

# retr_cite_integrity <answer_file> <raw_dir> <cite_span_py>
# 0 = every citation in the answer resolves to a real file and, where it carries
# an anchor, a real anchor. Sets RETR_CITE_TOTAL / RETR_CITE_BAD / RETR_CITE_BAD_LIST.
#
# R4 asks "is there ONE good citation?" — this asks "is any citation a lie?".
# They are different failures and the second is the worse one: an unresolvable
# target is a hallucinated receipt, and a receipt that cannot be checked is more
# corrosive than a missing one, because it *looks* verifiable. Observed — an
# answer cited `field-report.md#instrumentation-debt`, an anchor that does not
# exist in that file, while passing every other check on the question.
#
# Answers with no citations set RETR_CITE_TOTAL=0 and return 0: "cite nothing"
# must not be a way to pass this, and it isn't a way to pass R4 either, which is
# what actually forces a citation to exist.
retr_cite_integrity() {
  local answer="$1" raw_dir="$2" py="$3" target
  RETR_CITE_TOTAL=0; RETR_CITE_BAD=0; RETR_CITE_BAD_LIST=""
  [ -f "$answer" ] || return 0
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    RETR_CITE_TOTAL=$((RETR_CITE_TOTAL + 1))
    if ! python3 "$py" "$raw_dir" "$target" >/dev/null 2>&1; then
      RETR_CITE_BAD=$((RETR_CITE_BAD + 1))
      RETR_CITE_BAD_LIST="$RETR_CITE_BAD_LIST $target"
    fi
  done < <(retr_citations "$answer")
  [ "$RETR_CITE_BAD" -eq 0 ]
}

# retr_grade_citation <answer_file> <raw_dir> <cite_contains> <max_span> <cite_span_py>
# 0 = PASS. Scores the R4 bit: at least ONE cited passage both CONTAINS the fact
# and spans <= max_span lines. Containment alone is not enough — a whole-file
# cite "contains" everything; span alone is not enough — a tight cite of the
# wrong lines proves nothing. Both, on the same citation, or it fails.
retr_grade_citation() {
  local answer="$1" raw_dir="$2" needle="$3" max_span="$4" py="$5"
  local target evidence span
  [ -n "$needle" ] || return 0

  while IFS= read -r target; do
    [ -z "$target" ] && continue
    evidence=$(python3 "$py" "$raw_dir" "$target" 2>"$answer.span") || continue
    span=$(sed -n 's/^span: \([0-9]*\) lines$/\1/p' "$answer.span")
    [ -z "$span" ] && continue
    if [ "$span" -le "$max_span" ] && printf '%s' "$evidence" | grep -q -F -i "$needle"; then
      rm -f "$answer.span"
      return 0
    fi
  done < <(retr_citations "$answer")
  rm -f "$answer.span"
  return 1
}
