#!/usr/bin/env bash
# scripts/wiki-lint-asserted-at.sh — enforce the valid-time contract on raw/.
#
# `fetched_at` records when a snapshot entered the wiki (transaction time).
# `asserted_at` records the date the DOCUMENT claims for its own content (valid
# time). Without the second axis an as-of question has nothing to resolve
# against, and the wiki answers "what was true in April" with whatever the file
# says today. Measured: the retrieval eval's as-of leg passes only when the
# corpus happens to state its vintage in prose — remove that sentence and it
# fails, because nothing structured carries the date.
#
# The contract (AGENTS.md → "Valid time vs transaction time"):
#
#   asserted_at: <ISO date>  requires asserted_at_source: <#anchor> into this
#                            file's own body, and the date must appear in the
#                            passage that anchor resolves to.
#   asserted_at: unknown     requires asserted_at_note: <why>.
#   anything else            is a violation, including absence.
#
# `unknown` is a first-class answer, not a failure: plenty of real sources have
# no discoverable date, and a lint that blocked them would push authors to
# fabricate one. What is forbidden is SILENCE — and stamping `fetched_at` as the
# document date, which makes every source look dated while encoding nothing.
# That last one is the reason the anchor is mandatory: a date that must resolve
# to a real passage costs more to fake than to read off the page.
#
# Never-ingested sources (`ingested_hash: ""`) are skipped by default, same as
# the drift lint — in a /ctx-lint pass, frontmatter that /ctx-extract has not
# finished with yet is noise, and noise trains users to ignore the lint.
#
# `--all` audits them too, and is what /ctx-extract uses: right after extract
# every file is by definition never-ingested, so the default mode would skip
# all of them and report a vacuous "clean". That is not hypothetical — it was
# the first thing a real run did, and an extract-time check that silently
# inspects nothing is worse than no check, because it reads as verification.
#
# Usage: ./scripts/wiki-lint-asserted-at.sh [raw-dir] [--all]   (default: raw)
# Exit:  0 every audited source satisfies the contract
#        1 at least one violation (details on stderr)
#        2 usage error

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_DIR=raw
AUDIT_ALL=0
for arg in "$@"; do
  case "$arg" in
    --all) AUDIT_ALL=1 ;;
    -*)    echo "usage: wiki-lint-asserted-at.sh [raw-dir] [--all]" >&2; exit 2 ;;
    *)     RAW_DIR="$arg" ;;
  esac
done
if [ ! -d "$RAW_DIR" ]; then
  echo "error: no such directory: $RAW_DIR" >&2
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo "error: python3 not on PATH" >&2; exit 2; }

if [ "$AUDIT_ALL" -eq 1 ]; then
  exec python3 "$SCRIPT_DIR/asserted-at-audit.py" "$RAW_DIR" --all
fi
exec python3 "$SCRIPT_DIR/asserted-at-audit.py" "$RAW_DIR"
