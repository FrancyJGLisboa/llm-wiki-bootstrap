#!/usr/bin/env bash
# scripts/eval-entities.sh — measure entity extraction against a planted gold set.
#
# Reads a wiki that has already been built and ingested (by scripts/eval-retrieval.sh
# or by hand) and scores the `## Entities` sections that /wiki-ingest step 3.5 is
# supposed to produce. Deterministic: no LLM, no spend. The LLM work happened at
# ingest; this only grades it, so it can re-grade a wiki as often as needed for free.
#
# Loss function — 3 binary checks (approved):
#
#   E1 recall     >= 80% of the planted gold entities appear
#       false_pass: emit every capitalized token in the corpus — trivially 100%
#       mitigation: E2's precision floor on a planted decoy set. E1 and E2 are
#                   each other's mitigation; neither is meaningful alone, which
#                   is why they are never reported separately.
#
#   E2 precision  <= 20% of the planted DECOYS appear (section headings and
#                 metric names — Title Case that is formatting, not a name)
#       false_pass: emit only the two most obvious entities — perfect precision
#       mitigation: E1's recall floor.
#
#   E3 provenance every captured entity carries a resolvable (source: raw/...)
#                 anchor spanning <= 10 lines that CONTAINS the entity string
#       false_pass: cite the whole file for every entity — always "resolves"
#       mitigation: the span cap plus the containment requirement, resolved
#                   through cite-span.py (the same machinery R4 uses), so a
#                   gesture at a document cannot pass as a locus.
#
# holdout: the gold set here is drawn from the MAIN corpus only. The held-out
# modality (weekly-sync-notes.txt, via gen-corpus.sh --holdout) has its own
# entity — a person named ONLY by initialism — and is never scored here. See
# tests/eval/retrieval-questions-holdout.md.
#
# Usage: ./scripts/eval-entities.sh <wiki-dir>
# Exit:  0 the harness completed (whatever the score) — the deliverable is the
#        measurement; 1 setup failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CITE_SPAN="$SCRIPT_DIR/cite-span.py"

WIKI="${1:-}"
[ -n "$WIKI" ] || { echo "usage: eval-entities.sh <wiki-dir>" >&2; exit 1; }
[ -d "$WIKI/wiki" ] || { echo "error: no $WIKI/wiki — not an ingested wiki" >&2; exit 1; }
[ -d "$WIKI/raw" ]  || { echo "error: no $WIKI/raw" >&2; exit 1; }
[ -x "$CITE_SPAN" ] || { echo "error: missing $CITE_SPAN" >&2; exit 1; }

# Planted gold: the five people who actually author messages in the email thread.
# Unambiguous — each appears in a `From:` header, so "is this a named person"
# needs no judgement call.
GOLD=("Priya Raman" "Dan Okafor" "Mei Sato" "Tomas Vela" "Ada Bekele")

# Planted decoys: Title Case section headings from field-report.md. Every one is
# formatting, not a name. An extractor that pattern-matches capitalization
# swallows these; one that reasons about what an entity IS does not.
DECOYS=("Instrumentation Debt" "Capacity Headroom" "Schema Evolution" \
        "Replication Lag" "Cold Start" "Batch Window")

MAX_SPAN=10

# Collect every `## Entities` bullet across the wiki.
entity_lines=$(awk '
  /^## Entities/ { inside = 1; next }
  /^## / { inside = 0 }
  inside && /^[[:space:]]*-[[:space:]]/ { print FILENAME "\t" $0 }
' "$WIKI"/wiki/*.md 2>/dev/null)

if [ -z "$entity_lines" ]; then
  echo "# entity eval — NO ENTITIES CAPTURED"
  echo ""
  echo "No wiki page carries an \`## Entities\` section, so there is nothing to score."
  echo "Either /wiki-ingest step 3.5 did not run, or this wiki predates it."
  echo "This is reported as a distinct outcome, NOT as E1 0% — a missing section and"
  echo "an empty one fail for different reasons and need different fixes."
  exit 0
fi

n_lines=$(printf '%s\n' "$entity_lines" | wc -l | tr -d ' ')

# ── E1 recall ─────────────────────────────────────────────────────────────────
gold_found=0; missing=()
for g in "${GOLD[@]}"; do
  if printf '%s\n' "$entity_lines" | grep -q -F "$g"; then
    gold_found=$((gold_found + 1))
  else
    missing+=("$g")
  fi
done
recall=$(( gold_found * 100 / ${#GOLD[@]} ))

# ── E2 precision (decoy rejection) ────────────────────────────────────────────
decoys_found=0; caught=()
for d in "${DECOYS[@]}"; do
  if printf '%s\n' "$entity_lines" | grep -q -F "$d"; then
    decoys_found=$((decoys_found + 1)); caught+=("$d")
  fi
done
decoy_rate=$(( decoys_found * 100 / ${#DECOYS[@]} ))

# ── E3 provenance ─────────────────────────────────────────────────────────────
cited=0; uncited=0; loose=0; unresolved=0
while IFS=$'\t' read -r _page line; do
  [ -z "$line" ] && continue
  target=$(printf '%s' "$line" | grep -oE '\(source:[[:space:]]*raw/[^)]+\)' | head -1 \
           | sed -e 's/^(source:[[:space:]]*//' -e 's/)$//')
  if [ -z "$target" ]; then uncited=$((uncited + 1)); continue; fi
  # The entity name is the text before the first em-dash / double-hyphen.
  # Parameter expansion, not sed: BSD sed has no `\|` alternation (that is a GNU
  # extension), so `s/\(—\|--\).*//` silently matches nothing on macOS and the
  # "name" ends up being the whole bullet, including its own citation. Every
  # containment check then fails and E3 reports 0% on correct data.
  name=${line#*- }
  name=${name%%—*}
  name=${name%%--*}
  name=${name%"${name##*[![:space:]]}"}   # rtrim
  passage=$("$CITE_SPAN" "$WIKI/raw" "$target" 2>"$WIKI/.espan" ) || { unresolved=$((unresolved + 1)); continue; }
  span=$(grep -oE '[0-9]+' "$WIKI/.espan" 2>/dev/null | head -1)
  span=${span:-999}
  if [ "$span" -gt "$MAX_SPAN" ]; then loose=$((loose + 1)); continue; fi
  if printf '%s' "$passage" | grep -q -F "$name"; then
    cited=$((cited + 1))
  else
    loose=$((loose + 1))
  fi
done <<< "$entity_lines"
rm -f "$WIKI/.espan"
prov=$(( n_lines > 0 ? cited * 100 / n_lines : 0 ))

e1=FAIL; [ "$recall" -ge 80 ] && e1=PASS
e2=FAIL; [ "$decoy_rate" -le 20 ] && e2=PASS
e3=FAIL; [ "$prov" -ge 80 ] && e3=PASS
passed=0
for v in "$e1" "$e2" "$e3"; do [ "$v" = PASS ] && passed=$((passed + 1)); done

cat <<EOF
# entity eval report

Wiki: $WIKI
Entities captured: $n_lines across $(printf '%s\n' "$entity_lines" | cut -f1 | sort -u | wc -l | tr -d ' ') page(s)

E1 recall:      $e1  ($gold_found/${#GOLD[@]} gold = ${recall}%, floor 80%)
E2 precision:   $e2  ($decoys_found/${#DECOYS[@]} decoys captured = ${decoy_rate}%, ceiling 20%)
E3 provenance:  $e3  ($cited/$n_lines cited to a containing passage <= ${MAX_SPAN} lines = ${prov}%, floor 80%)

entity score: $passed/3
EOF

[ ${#missing[@]} -gt 0 ] && printf 'missed gold: %s\n' "$(printf '%s; ' "${missing[@]}")"
[ ${#caught[@]} -gt 0 ]  && printf 'decoys wrongly captured: %s\n' "$(printf '%s; ' "${caught[@]}")"
[ "$uncited" -gt 0 ]     && printf 'uncited entity lines: %s\n' "$uncited"
[ "$unresolved" -gt 0 ]  && printf 'entity citations that do not resolve: %s\n' "$unresolved"
[ "$loose" -gt 0 ]       && printf 'citations too wide or not containing the name: %s\n' "$loose"

echo ""
echo "E1 and E2 are each other's mitigation: recall alone is gamed by emitting every"
echo "capitalized token, precision alone by emitting only the obvious two. Read them"
echo "together or not at all."
exit 0
