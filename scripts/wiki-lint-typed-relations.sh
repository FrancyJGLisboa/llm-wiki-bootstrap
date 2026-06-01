#!/usr/bin/env bash
# scripts/wiki-lint-typed-relations.sh — lint `## Related` sections for the typed-link form.
#
# Spec: AGENTS.md → "Typed relations".
#   - [[<target>]] <verb> [<attr>] — <prose>
#   - <verb> matches [a-z][a-z0-9-]*
#   - Lines without a verb (just `- [[target]] — desc`) are implicit `related-to`.
#   - Lines containing >1 `[[…]]` token are always implicit `related-to` (no verb applies).
#
# Exit code:
#   0 — every single-target Related line either has a valid verb or is implicit.
#   1 — at least one single-target Related line has a malformed verb token.
#
# Usage:
#   scripts/wiki-lint-typed-relations.sh [<path>...]   (default: wiki/)

set -uo pipefail

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
    printf 'lint-typed-relations: warning: %s does not exist\n' "$p" >&2
  fi
done

if [ ${#files[@]} -eq 0 ]; then
  echo "lint-typed-relations: no .md files found in: ${paths[*]}" >&2
  exit 0
fi

total_typed=0
total_implicit=0
total_multi=0
total_bad=0

# One awk pass per file. Awk prints:
#   one BAD line per malformed verb (to stderr)
#   one summary line per file to stdout: "<file> typed N implicit N multi N bad N"
for file in "${files[@]}"; do
  # LC_ALL=C forces byte-oriented awk so sprintf("%c", 226) yields the raw
  # em-dash byte (0xE2), not a UTF-8 codepoint. Without it, gawk/mawk under a
  # UTF-8 locale (e.g. Ubuntu CI) emit multi-byte chars and the em-dash index()
  # below never matches — silently miscounting typed/bad verbs.
  out=$(LC_ALL=C awk -v file="$file" '
    BEGIN { in_related = 0; typed = 0; implicit = 0; multi = 0; bad = 0 }

    /^## Related[[:space:]]*$/ { in_related = 1; next }
    /^## / && !/^## Related/ { in_related = 0 }

    !in_related { next }
    !/^[[:space:]]*-[[:space:]]+\[\[/ { next }

    {
      # Count slug-shaped [[…]] tokens on this line.
      n = 0; tmp = $0
      while (match(tmp, /\[\[[a-z][a-z0-9-]*\]\]/)) {
        n++
        tmp = substr(tmp, RSTART + RLENGTH)
      }

      if (n == 0) next        # no slug-shaped link; broken-link lint handles this elsewhere
      if (n >= 2) { multi++; next }

      after_idx = index($0, "]]")
      if (after_idx == 0) next
      after = substr($0, after_idx + 2)
      sub(/^[[:space:]]+/, "", after)

      em = sprintf("%c%c%c", 226, 128, 148)   # UTF-8 em-dash
      em_pos = index(after, em)
      dh_pos = index(after, "--")
      cut = 0
      if (em_pos > 0 && (dh_pos == 0 || em_pos < dh_pos)) cut = em_pos
      else if (dh_pos > 0) cut = dh_pos
      if (cut > 0) after = substr(after, 1, cut - 1)
      sub(/[[:space:]]+$/, "", after)

      if (after == "") { implicit++; next }

      verb = after
      if (match(verb, /[[:space:]]/)) verb = substr(verb, 1, RSTART - 1)

      if (verb ~ /^[a-z][a-z0-9-]*$/) {
        typed++
      } else {
        bad++
        printf("%s:%d: malformed verb token: %s\n", file, NR, verb) > "/dev/stderr"
      }
    }

    END { printf("%s typed %d implicit %d multi %d bad %d\n", file, typed, implicit, multi, bad) }
  ' "$file") || true

  # Parse the summary line.
  set -- $out
  # $1 file $2 "typed" $3 N $4 "implicit" $5 N $6 "multi" $7 N $8 "bad" $9 N
  if [ "${#out}" -gt 0 ] && [ "$2" = "typed" ]; then
    total_typed=$((total_typed + $3))
    total_implicit=$((total_implicit + $5))
    total_multi=$((total_multi + $7))
    total_bad=$((total_bad + $9))
    printf '%s — typed:%d implicit:%d multi:%d bad:%d\n' "$1" "$3" "$5" "$7" "$9"
  fi
done

printf 'totals — typed:%d implicit:%d multi:%d bad:%d (files:%d)\n' \
  "$total_typed" "$total_implicit" "$total_multi" "$total_bad" "${#files[@]}"

if [ "$total_bad" -gt 0 ]; then
  exit 1
fi
exit 0
