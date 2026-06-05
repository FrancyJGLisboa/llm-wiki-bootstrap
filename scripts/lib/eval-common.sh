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
