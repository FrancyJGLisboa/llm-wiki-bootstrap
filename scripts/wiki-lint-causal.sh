#!/usr/bin/env bash
# scripts/wiki-lint-causal.sh — validate causal verbs in `## Related` against the
# canonical causal vocabulary (templates/causal-vocab.txt).
#
# Spec: AGENTS.md → "Typed relations" (causal vocabulary).
#   - A CANONICAL causal verb (causes, caused-by, enables, prevents,
#     contributes-to) passes.
#   - A KNOWN causal SYNONYM that is not canonical (leads-to, results-in,
#     due-to, because-of, cause, prevent, enable, enabled-by, contributes) is
#     flagged with its canonical form. This forces a real synonym map rather
#     than a one-string grep.
#   - Any other open verb (e.g. founded-by, located-in) is ignored — it is not
#     a causal edge; the open-vocabulary shape check is wiki-lint-typed-relations.sh.
#
# Exit code:
#   0 — no non-canonical causal verbs.
#   1 — at least one non-canonical causal synonym found.
#
# Usage:
#   scripts/wiki-lint-causal.sh [<path>...]   (default: wiki/)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOCAB="${CAUSAL_VOCAB:-$SCRIPT_DIR/../templates/causal-vocab.txt}"

if [ ! -f "$VOCAB" ]; then
  echo "wiki-lint-causal: canonical vocab missing: $VOCAB" >&2
  exit 2
fi

paths=("$@")
if [ ${#paths[@]} -eq 0 ]; then
  paths=(wiki/)
fi

files=()
for p in "${paths[@]}"; do
  if [ -d "$p" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$p" -type f -name '*.md' | sort)
  elif [ -f "$p" ]; then
    files+=("$p")
  else
    printf 'wiki-lint-causal: warning: %s does not exist\n' "$p" >&2
  fi
done

if [ ${#files[@]} -eq 0 ]; then
  echo "wiki-lint-causal: no .md files found in: ${paths[*]}" >&2
  exit 0
fi

canonical="$(tr '\n' ' ' < "$VOCAB")"
total_bad=0

# LC_ALL=C so sprintf("%c",226) yields the raw em-dash byte (matches the
# byte-oriented cut used in wiki-lint-typed-relations.sh).
for file in "${files[@]}"; do
  bad=$(LC_ALL=C awk -v file="$file" -v canonical="$canonical" '
    BEGIN {
      in_related = 0; bad = 0
      n = split(canonical, c, " ")
      for (i = 1; i <= n; i++) if (c[i] != "") canon[c[i]] = 1
      # known non-canonical causal synonyms -> canonical form
      syn["leads-to"]   = "causes";        syn["results-in"] = "causes"
      syn["cause"]      = "causes";        syn["due-to"]     = "caused-by"
      syn["because-of"] = "caused-by";     syn["enabled-by"] = "caused-by"
      syn["prevent"]    = "prevents";      syn["enable"]     = "enables"
      syn["contributes"] = "contributes-to"
    }
    /^## Related[[:space:]]*$/ { in_related = 1; next }
    /^## / && !/^## Related/   { in_related = 0 }
    !in_related { next }
    !/^[[:space:]]*-[[:space:]]+\[\[/ { next }
    {
      # only single-target lines carry a verb
      m = 0; tmp = $0
      while (match(tmp, /\[\[[a-z][a-z0-9-]*\]\]/)) { m++; tmp = substr(tmp, RSTART + RLENGTH) }
      if (m != 1) next

      after_idx = index($0, "]]"); if (after_idx == 0) next
      after = substr($0, after_idx + 2); sub(/^[[:space:]]+/, "", after)
      em = sprintf("%c%c%c", 226, 128, 148); em_pos = index(after, em); dh_pos = index(after, "--")
      cut = 0
      if (em_pos > 0 && (dh_pos == 0 || em_pos < dh_pos)) cut = em_pos
      else if (dh_pos > 0) cut = dh_pos
      if (cut > 0) after = substr(after, 1, cut - 1)
      sub(/[[:space:]]+$/, "", after)
      if (after == "") next

      verb = after; if (match(verb, /[[:space:]]/)) verb = substr(verb, 1, RSTART - 1)
      if (verb in canon) next                 # canonical causal verb: OK
      if (verb in syn) {                       # known non-canonical synonym: flag
        printf("%s:%d: non-canonical causal verb [%s] -> use canonical [%s]\n",
               file, NR, verb, syn[verb]) > "/dev/stderr"
        bad++
      }
      # else: open non-causal verb, ignored
    }
    END { print bad }
  ' "$file")
  total_bad=$((total_bad + bad))
done

if [ "$total_bad" -gt 0 ]; then
  exit 1
fi
exit 0
