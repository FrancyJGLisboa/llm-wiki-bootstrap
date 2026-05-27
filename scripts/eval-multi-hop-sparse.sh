#!/usr/bin/env bash
# scripts/eval-multi-hop-sparse.sh — sparse-fixture variant of eval-multi-hop.sh.
#
# Reads tests/eval/sparse-multi-hop-questions.md. For each question:
#   1. Runs the question through `claude -p '/wiki-query "<Q>" --no-promote'`
#      against the *typed* sparse-fixture copy (with `## Related` verbs intact,
#      and — if scripts/wiki-to-kg.py exists — with a generated wiki/_kg.jsonl
#      sidecar so /wiki-query can read typed triples for multi-hop reasoning).
#   2. Runs the same question against a *baseline* copy of the sparse fixture
#      where single-target `## Related` verbs are stripped. The baseline
#      variant NEVER gets a _kg.jsonl sidecar — it is the verb-stripped,
#      KG-less control.
#   3. Grades each answer by case-insensitive substring match on every
#      `expects:` token. All tokens present ⇒ PASS, else FAIL.
#
# Stdout: a markdown report.
#   baseline: X/N
#   typed: Y/N
#   verdict: improvement | no-improvement | null-result
#
# Verdict rule:
#   typed - baseline >= 2  → improvement
#   typed - baseline <= -1 → no-improvement
#   otherwise              → null-result
#
# Exit 0 if the harness COMPLETED. Non-zero only on setup failures.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

QUESTIONS="$REPO_ROOT/tests/eval/sparse-multi-hop-questions.md"
FIXTURE_DIR="$REPO_ROOT/tests/eval/sparse-fixture"
KG_GENERATOR="$REPO_ROOT/scripts/wiki-to-kg.py"

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

WORK="$(mktemp -d -t eval-sparse.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# --- Build the typed and baseline working wikis --------------------------------

for variant in typed baseline; do
  vdir="$WORK/$variant"
  mkdir -p "$vdir/raw" "$vdir/wiki/journal"
  cp -r "$REPO_ROOT/.claude" "$vdir/"
  cp "$REPO_ROOT/AGENTS.md" "$vdir/"
  rm -f "$vdir/wiki/"*.md
  cp -r "$FIXTURE_DIR"/*.md "$vdir/wiki/"
  : > "$vdir/wiki/journal/.gitkeep"
  printf '# log.md\n\n' > "$vdir/log.md"
done

# --- Strip verbs from baseline wiki's ## Related sections ---------------------

strip_verbs_from_file() {
  local file="$1"
  awk '
    BEGIN { in_related = 0 }
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

for f in "$WORK/baseline/wiki/"*.md; do
  strip_verbs_from_file "$f"
done

# --- (Phase-2b only) Generate KG sidecar in the typed work dir, NEVER baseline -

if [ -f "$KG_GENERATOR" ]; then
  echo "[eval-sparse] generating wiki/_kg.jsonl in typed variant only" >&2
  python3 "$KG_GENERATOR" "$WORK/typed/wiki/" > "$WORK/typed/wiki/_kg.jsonl" \
    || { echo "error: $KG_GENERATOR failed" >&2; exit 1; }
  echo "[eval-sparse] typed wiki/_kg.jsonl: $(wc -l < "$WORK/typed/wiki/_kg.jsonl" | tr -d ' ') lines" >&2
else
  echo "[eval-sparse] KG generator absent (Phase-2a / C5-gate run); both variants sidecar-less" >&2
fi

# --- Parse the questions file --------------------------------------------------

tmp_q="$WORK/parsed-questions.tsv"
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
' "$QUESTIONS" > "$tmp_q"

n_questions=$(wc -l < "$tmp_q" | tr -d ' ')
if [ "$n_questions" -lt 1 ]; then
  echo "error: no questions parsed from $QUESTIONS" >&2
  exit 1
fi

# --- Run each question against both variants -----------------------------------

baseline_pass=0
typed_pass=0
results_md="$WORK/per-question.md"
: > "$results_md"

while IFS=$'\t' read -r qid question expects absent; do
  [ -z "$qid" ] && continue
  echo "[eval-sparse] $qid: $question" >&2

  echo "### $qid" >> "$results_md"
  echo "" >> "$results_md"
  echo "Question: $question" >> "$results_md"
  echo "Expects: $expects" >> "$results_md"
  echo "baseline-absent: $absent" >> "$results_md"
  echo "" >> "$results_md"

  for variant in baseline typed; do
    answer_file="$WORK/$variant.$qid.md"
    ( cd "$WORK/$variant" && \
      claude -p "/wiki-query \"$question\" --no-promote" \
        > "$answer_file" 2>"$WORK/$variant.$qid.err" ) || true

    pass=1
    OLD_IFS="$IFS"
    IFS=','
    for token in $expects; do
      token_trim=$(printf '%s' "$token" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      if [ -z "$token_trim" ]; then continue; fi
      if ! grep -q -F -i "$token_trim" "$answer_file"; then
        pass=0
        break
      fi
    done
    IFS="$OLD_IFS"

    if [ "$pass" -eq 1 ]; then
      [ "$variant" = "baseline" ] && baseline_pass=$((baseline_pass + 1))
      [ "$variant" = "typed"    ] && typed_pass=$((typed_pass + 1))
      verdict_tag="PASS"
    else
      verdict_tag="FAIL"
    fi
    echo "[eval-sparse]   $variant: $verdict_tag" >&2
    echo "- $variant: $verdict_tag" >> "$results_md"
  done
  echo "" >> "$results_md"
done < "$tmp_q"

# --- Verdict + report ----------------------------------------------------------

delta=$((typed_pass - baseline_pass))
if [ "$delta" -ge 2 ]; then
  verdict="improvement"
elif [ "$delta" -le -1 ]; then
  verdict="no-improvement"
else
  verdict="null-result"
fi

cat <<EOF
# sparse multi-hop eval report

Fixture: tests/eval/sparse-fixture/ (7 pages, fictional supply-chain entities)
Questions: tests/eval/sparse-multi-hop-questions.md ($n_questions questions)

baseline: $baseline_pass/$n_questions
typed: $typed_pass/$n_questions
delta: $delta
verdict: $verdict

## Per-question detail

EOF
cat "$results_md"

exit 0
