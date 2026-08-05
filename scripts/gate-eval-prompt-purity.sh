#!/usr/bin/env bash
# scripts/gate-eval-prompt-purity.sh — gate EVAL-NO-METADATA-IN-PROMPT.
#
# RULE: no author-side metadata field from a question fixture may survive into
# the question text that is sent to the model.
#
# WHY THIS GATE EXISTS: `retr_parse_questions` (scripts/lib/eval-common.sh)
# matches known fields and appends EVERYTHING ELSE to the question. Three
# separate fields have leaked through that catch-all — `requires:`, `change:`,
# and `cite-file-matches:` — each found only after it had already corrupted a
# measured run. The last one put the ERE naming the correct source file's date
# prefix into 54 of 66 prompts, and the check it feeds is precisely "did you
# cite a source of the right date". The eval was handing over its own answer.
#
# DETECTION: differential, not static. Run the real parser, then check that no
# `^field: ` line of the INPUT survives verbatim in the emitted question text.
# An allowlist gate ("the field must be in the known list") is the exact
# assumption that failed three times — it cannot know about field #4. This
# needs no list: any new field is caught the day it is added.
#
# PARSER RESOLUTION. eval-common.sh defines two parsers with the same catch-all
# shape — retr_parse_questions and eval_parse_questions — and the fixture->parser
# binding is not discoverable from the call graph: two of the four grain-corpus
# question files are passed to eval-corpus.sh by hand via `--questions`, so no
# script names them. A hand-maintained map would go stale the day someone adds a
# fixture, and checking every fixture under BOTH parsers is not conservative but
# simply wrong — a retr-format fixture reports nine "leaks" under the multi-hop
# parser for nine fields that parser legitimately never sees.
#
# So the gate resolves the parser empirically:
#   0 parsers can read the fixture -> exit 1 (dead fixture; nothing is checked)
#   1 parser  can read it          -> use it
#   2+ can read it                 -> the fixture MUST declare which, via
#                                     `<!-- gate-parser: <name> -->`, else exit 1
# Guessing is the one thing it will not do, and a new fixture cannot slip
# through unchecked: it either resolves or it fails.
#
# SCOPE: files matching tests/eval/**/*question*.md — every question fixture.
# Excludes `.questions.tsv` run outputs (already-parsed artifacts, not inputs)
# and the fenced ```FORMAT``` blocks inside the fixtures (the parsers skip
# fences; so does this).
#
# EXIT: 0 = clean · 1 = leak found · 2 = the gate itself failed.
#
# RUNTIME: bash + awk + grep. No LLM, no network, no key.
# WIRED AT: scripts/smoke-all.sh (R29) → CI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RULE_ID="EVAL-NO-METADATA-IN-PROMPT"

die2() { printf 'gate-eval-prompt-purity: %s\n' "$1" >&2; exit 2; }

COMMON="$SCRIPT_DIR/lib/eval-common.sh"
[ -r "$COMMON" ] || die2 "cannot read $COMMON (the parser under test is missing)"
# shellcheck source=/dev/null
. "$COMMON" || die2 "sourcing $COMMON failed"

# The parsers under test. Question column differs per parser: retr emits
# qid<TAB>question<TAB>… and eval emits qid<TAB>question<TAB>… — both put the
# model-visible text in column 2.
PARSERS="retr_parse_questions eval_parse_questions"
for p in $PARSERS; do
  command -v "$p" >/dev/null 2>&1 || die2 "$p not defined after sourcing $COMMON"
done

FILES=()
if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  # Default scope: every question fixture in the repo. `mapfile` is bash 4+;
  # macOS ships bash 3.2, so read the list the portable way.
  while IFS= read -r _f; do
    FILES+=("$_f")
  done < <(find "$REPO_ROOT/tests/eval" -type f -name '*question*.md' 2>/dev/null | sort)
  [ "${#FILES[@]}" -gt 0 ] || die2 "no question fixtures found under tests/eval"
fi

tmp="$(mktemp -d)" || die2 "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

leaks=0
scanned=0

for f in "${FILES[@]}"; do
  [ -r "$f" ] || die2 "cannot read $f"
  scanned=$((scanned + 1))

  # Candidate metadata lines from the INPUT: `^token: value` outside fences.
  # `emit()` joins body lines with a single space, so a leaked field appears
  # verbatim as a substring of some question.
  awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^### / { next }
    /^[a-z][a-z0-9-]*:[[:space:]]*[^[:space:]]/ { print FILENAME ":" FNR "\t" $0 }
  ' "$f" > "$tmp/fields.txt"

  # ── resolve the parser ──
  # A parser that emits zero questions cannot read this fixture (its header
  # pattern doesn't match: eval_parse_questions requires `### Q<n>`,
  # retr_parse_questions accepts any `### `).
  candidates=
  n_cand=0
  for p in $PARSERS; do
    "$p" "$f" "$tmp/probe.tsv" || die2 "$p failed on $f"
    if [ -s "$tmp/probe.tsv" ]; then
      candidates="$candidates $p"
      n_cand=$((n_cand + 1))
    fi
  done

  declared="$(sed -n 's/.*<!--[[:space:]]*gate-parser:[[:space:]]*\([a-z_]*\).*/\1/p' "$f" | head -1)"

  if [ "$n_cand" -eq 0 ]; then
    printf '%s: %s\n' "$f" "$RULE_ID" >&2
    printf '  no parser in eval-common.sh can read this fixture — it parses to zero\n' >&2
    printf '  questions, so nothing here is checked (and no eval can run it either).\n' >&2
    printf '  FIX: give each question a `### <qid>` header, or delete the dead fixture.\n' >&2
    leaks=$((leaks + 1))
    continue
  elif [ "$n_cand" -eq 1 ]; then
    parser="$(echo "$candidates" | tr -d ' ')"
  elif [ -n "$declared" ]; then
    case " $candidates " in
      *" $declared "*) parser="$declared" ;;
      *) printf '%s: %s\n' "$f" "$RULE_ID" >&2
         printf '  declares `gate-parser: %s`, but that parser cannot read this fixture.\n' "$declared" >&2
         printf '  FIX: declare one of:%s\n' "$candidates" >&2
         leaks=$((leaks + 1)); continue ;;
    esac
  else
    printf '%s: %s\n' "$f" "$RULE_ID" >&2
    printf '  ambiguous — %d parsers can read this fixture (%s), and they have\n' "$n_cand" "$(echo "$candidates" | sed 's/^ //')" >&2
    printf '  different field lists, so which one runs decides what leaks.\n' >&2
    printf '  FIX: add `<!-- gate-parser: <name> -->` naming the parser the eval\n' >&2
    printf '  that consumes this fixture actually calls.\n' >&2
    leaks=$((leaks + 1))
    continue
  fi

  # ── check for leaks under the resolved parser ──
  "$parser" "$f" "$tmp/parsed.tsv" || die2 "$parser failed on $f"
  # Column 2 is the question text — the only thing the model ever sees.
  cut -f2 "$tmp/parsed.tsv" > "$tmp/questions.txt"

  while IFS=$'\t' read -r loc line; do
    [ -n "$line" ] || continue
    if grep -qF -- "$line" "$tmp/questions.txt"; then
      field="${line%%:*}"
      printf '%s: %s (%s)\n' "$loc" "$RULE_ID" "$parser" >&2
      printf '  `%s:` is not in %s'"'"' field list, so the catch-all\n' "$field" "$parser" >&2
      printf '  folded it into the question text sent to the model:\n' >&2
      printf '    %s\n' "$line" >&2
      printf '  FIX: add `/^%s:/ { next }` to %s in\n' "$field" "$parser" >&2
      printf '  scripts/lib/eval-common.sh, next to the existing skips.\n' >&2
      leaks=$((leaks + 1))
    fi
  done < "$tmp/fields.txt"
done

if [ "$leaks" -gt 0 ]; then
  printf 'gate-eval-prompt-purity: %d leak(s) across %d fixture(s) — %s\n' \
    "$leaks" "$scanned" "$RULE_ID" >&2
  exit 1
fi

printf 'gate-eval-prompt-purity: clean — %d fixture(s), no author-side metadata reaches the model.\n' "$scanned"
exit 0
