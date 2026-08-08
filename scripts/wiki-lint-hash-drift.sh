#!/usr/bin/env bash
# scripts/wiki-lint-hash-drift.sh — detect raw sources whose body changed since
# the ingest that produced the wiki claims citing them.
#
# `ingested_hash` is a commitment: "the wiki pages listed in `ingested_pages`
# were written against THIS body." Re-extract the same URL (or hand-edit a
# sidecar) and the body moves while every `(source: raw/<file>#<anchor>)`
# citation keeps pointing at it — the citation still resolves, but to text that
# no longer says what the wiki claims it says. Nothing else catches this:
# `/ctx-lint` check 4 is about page age, check 7 about frontmatter fields, and
# citation-audit.py only proves the target file/anchor EXISTS.
#
# This lint recomputes the canonical body hash (scripts/body-hash.sh — the ONE
# allowed way, per AGENTS.md) and flags any raw whose current hash differs from
# the hash recorded at last ingest, naming the wiki pages now at risk.
#
# Not-yet-ingested sources (`ingested_hash: ""`) are NOT drift — they are
# /ctx-compile's job — and are skipped silently.
#
# Exit: 0 — every ingested raw still hashes to its recorded commitment.
#       1 — ≥1 drifted or unhashable raw (each named on stderr).
# Usage: scripts/wiki-lint-hash-drift.sh [<path>...]   (default: raw/)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HASHER="$SCRIPT_DIR/body-hash.sh"

paths=("$@"); [ ${#paths[@]} -eq 0 ] && paths=("$REPO_ROOT/raw/")
[ -x "$HASHER" ] || { echo "wiki-lint-hash-drift: missing or non-executable $HASHER" >&2; exit 2; }

files=()
for p in "${paths[@]}"; do
  if [ -d "$p" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$p" -type f | sort)
  elif [ -f "$p" ]; then files+=("$p"); fi
done
[ ${#files[@]} -eq 0 ] && { echo "wiki-lint-hash-drift: no files in: ${paths[*]}" >&2; exit 0; }

# Read one frontmatter scalar (lines between the opening --- on line 1 and the
# closing ---). Binaries and body `---` rules are excluded by the line-1 guard
# and the second-delimiter stop.
fm_field() {
  LC_ALL=C awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR == 1 { next }
    /^---$/ { exit }
    index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
      gsub(/^["'\'']|["'\'']$/, "", v)
      print v; exit
    }
  ' "$1"
}

drift=0
for file in "${files[@]}"; do
  recorded=$(fm_field "$file" ingested_hash)
  [ -z "$recorded" ] && continue          # no frontmatter, or never ingested

  rel="${file#"$REPO_ROOT"/}"
  if ! current=$("$HASHER" "$file" 2>/dev/null); then
    echo "$rel: recorded ingested_hash ${recorded:0:8} but body is unhashable (malformed frontmatter) — commitment unverifiable" >&2
    drift=$((drift + 1))
    continue
  fi

  [ "$current" = "$recorded" ] && continue

  pages=$(fm_field "$file" ingested_pages)
  [ -z "$pages" ] && pages="(none recorded)"
  echo "$rel: body changed since ingest — recorded ${recorded:0:8}, now ${current:0:8}; citations in $pages point at text that moved" >&2
  drift=$((drift + 1))
done

if [ "$drift" -gt 0 ]; then
  echo "wiki-lint-hash-drift: $drift raw source(s) no longer match their ingest commitment — re-run /ctx-compile on each to re-derive the claims." >&2
  exit 1
fi
exit 0
