#!/usr/bin/env bash
# scripts/body-hash.sh — canonical body hash for an llm-wiki-bootstrap raw source.
#
# This is the ONE allowed way to compute `ingested_hash`. The slash commands
# `/wiki-ingest` and `/wiki-lint` MUST use this script; do not reinvent the
# hashing logic inline, or idempotence will break across runs.
#
# Definition of "body":
#   Everything after the closing `---` of the YAML frontmatter, as it appears
#   on disk, including blank lines. Frontmatter itself (including the opening
#   and closing `---` lines) is excluded.
#
# Algorithm: SHA-256, lowercase hex, no leading/trailing whitespace.
#
# Usage:
#   scripts/body-hash.sh <path-to-raw-file>
#
# Example:
#   scripts/body-hash.sh raw/karpathy-llm-wiki-video-transcript.md
#   # -> 3054546faf0d367042739f090547e4714d47ea2caf82fd9fcf98cb17e40d612e

set -euo pipefail

file="${1:?usage: body-hash.sh <path-to-file>}"

if [[ ! -f "$file" ]]; then
  echo "error: not a file: $file" >&2
  exit 1
fi

# Frontmatter must open with --- on line 1 and have a closing --- delimiter.
# Without this guard a missing closing --- yields the empty-string SHA (exit 0),
# which /wiki-ingest would stamp as a valid hash and then skip forever — silent
# data loss. Body horizontal-rule (---) lines are fine: count >= 2 still holds.
delim_count=$(grep -c '^---$' "$file" || true)
if [[ "$(head -n1 "$file")" != "---" ]] || (( delim_count < 2 )); then
  echo "error: malformed frontmatter in $file (expected opening '---' on line 1 and a closing '---')" >&2
  exit 1
fi

awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$file" \
  | openssl dgst -sha256 \
  | awk '{print $NF}'
