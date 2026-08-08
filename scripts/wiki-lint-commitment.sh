#!/usr/bin/env bash
# scripts/wiki-lint-commitment.sh — find raw sources the wiki CITES but never
# committed to.
#
# `ingested_hash` is the promise "the pages citing this source were written
# against THIS body". Without it, `scripts/wiki-lint-hash-drift.sh` has no
# baseline to compare against, so the body can change and every citation into
# it keeps resolving — to text that no longer says what the wiki claims.
# Drift detection is silently disabled for exactly those sources.
#
# Uncited sources are NOT flagged: nothing depends on their stability yet. They
# are counted and named separately so the exemption stays visible rather than
# becoming a quiet way to look clean.
#
# Exit: 0 — every cited source carries a commitment.
#       1 — >=1 cited source has none (each named, with its citation count).
# Usage: scripts/wiki-lint-commitment.sh [<wiki-root>]

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/commitment.sh
. "$SCRIPT_DIR/lib/commitment.sh"

ROOT="${1:-.}"
[ -d "$ROOT/wiki" ] || { echo "wiki-lint-commitment: $ROOT/wiki not found" >&2; exit 2; }
[ -d "$ROOT/raw" ]  || { echo "wiki-lint-commitment: $ROOT/raw not found" >&2; exit 2; }

offenders=0; cited=0; uncited=0; uncited_names=""

while IFS= read -r f; do
  base=$(basename "$f")
  case "$base" in .*) continue ;; esac
  # Sidecar folds into its parent: one source, one commitment, citations to
  # either path count for the pair.
  case "$f" in *.md) [ -f "${f%.md}" ] && continue ;; esac

  n=$(( $(grep -ro "(source: raw/$base" "$ROOT/wiki" 2>/dev/null | wc -l | tr -d ' ') ))
  if [ "$n" -eq 0 ]; then
    uncited=$((uncited + 1)); uncited_names="$uncited_names $base"; continue
  fi
  cited=$((cited + 1))

  if has_commitment "$f"; then
    continue
  fi
  echo "raw/$base: cited $n time(s) by wiki pages but carries no ingested_hash — those citations rest on a body nobody committed to, so drift has no baseline to detect against" >&2
  offenders=$((offenders + 1))
done < <(find "$ROOT/raw" -type f 2>/dev/null | sort)

if [ "$uncited" -gt 0 ]; then
  echo "wiki-lint-commitment: $uncited uncited source(s) not checked (nothing cites them yet):$uncited_names" >&2
fi

if [ "$offenders" -gt 0 ]; then
  echo "wiki-lint-commitment: $offenders of $cited cited source(s) lack an ingest commitment. Re-run /ctx-compile on each so it records ingested_hash + ingested_pages; do NOT hand-write the hash — a commitment nobody derived is a fabricated receipt." >&2
  exit 1
fi
echo "wiki-lint-commitment: all $cited cited source(s) carry an ingest commitment." >&2
exit 0
