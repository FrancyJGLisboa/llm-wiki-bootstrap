#!/usr/bin/env bash
# scripts/wiki-lint-causal.sh — lint `## Related` causal verbs against the
# canonical causal vocabulary.
#
# Causal discovery only works if cause→effect is encoded with ONE canonical
# verb per relation. Authors (and agents) reach for synonyms — "results-in",
# "due-to", "enabled-by". This lint REJECTS those synonyms and names the
# canonical verb to use instead, so the causal subgraph (wiki-to-kg --causal-only)
# stays clean and traversable.
#
# It is additive to wiki-lint-typed-relations.sh: that lint validates verb
# SHAPE; this one validates causal SEMANTICS (canonical, not a synonym).
# Non-causal verbs (located-in, related-to, …) are not its business and pass.
#
#   templates/causal-vocab.txt     — the canonical causal verbs (accepted)
#   templates/causal-synonyms.txt  — <synonym> <canonical> (rejected w/ suggestion)
#
# Exit: 0 — no causal-synonym misuse. 1 — ≥1 synonym used (each named on stderr).
# Usage: scripts/wiki-lint-causal.sh [<path>...]   (default: wiki/)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SYN="$REPO_ROOT/templates/causal-synonyms.txt"

paths=("$@"); [ ${#paths[@]} -eq 0 ] && paths=("$REPO_ROOT/wiki/")
[ -f "$SYN" ] || { echo "wiki-lint-causal: missing $SYN" >&2; exit 2; }

files=()
for p in "${paths[@]}"; do
  if [ -d "$p" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$p" -type f -name '*.md' | sort)
  elif [ -f "$p" ]; then files+=("$p"); fi
done
[ ${#files[@]} -eq 0 ] && { echo "wiki-lint-causal: no .md files in: ${paths[*]}" >&2; exit 0; }

bad=0
for file in "${files[@]}"; do
  out=$(LC_ALL=C awk -v file="$file" -v synfile="$SYN" '
    BEGIN {
      while ((getline line < synfile) > 0) {
        if (line ~ /^#/ || line ~ /^[[:space:]]*$/) continue
        n = split(line, a, /[[:space:]]+/)
        if (n >= 2) canon[a[1]] = a[2]
      }
      in_related = 0
    }
    /^## Related[[:space:]]*$/ { in_related = 1; next }
    /^## / && !/^## Related/   { in_related = 0 }
    !in_related { next }
    !/^[[:space:]]*-[[:space:]]+\[\[/ { next }
    {
      # Single-target lines only (multi-link lines are implicit related-to).
      n = 0; tmp = $0
      while (match(tmp, /\[\[[a-z][a-z0-9-]*\]\]/)) { n++; tmp = substr(tmp, RSTART + RLENGTH) }
      if (n != 1) next
      ai = index($0, "]]"); if (ai == 0) next
      after = substr($0, ai + 2); sub(/^[[:space:]]+/, "", after)
      em = sprintf("%c%c%c", 226, 128, 148)
      ep = index(after, em); dp = index(after, "--"); cut = 0
      if (ep > 0 && (dp == 0 || ep < dp)) cut = ep; else if (dp > 0) cut = dp
      if (cut > 0) after = substr(after, 1, cut - 1)
      sub(/[[:space:]]+$/, "", after)
      verb = after
      if (match(verb, /[[:space:]]/)) verb = substr(verb, 1, RSTART - 1)
      if (verb in canon) {
        printf("%s:%d: non-canonical causal verb \"%s\" — use \"%s\"\n", file, NR, verb, canon[verb]) > "/dev/stderr"
        print "BAD"
      }
    }
  ' "$file") || true
  bad=$((bad + $(printf '%s\n' "$out" | grep -c '^BAD' || true)))
done

if [ "$bad" -gt 0 ]; then
  echo "wiki-lint-causal: $bad non-canonical causal verb(s) — see suggestions above." >&2
  exit 1
fi
exit 0
