#!/usr/bin/env bash
# scripts/wiki-flows.sh [<wiki-root>] — the wiki as stocks and flows.
#
# Meadows' information-flow leverage point, applied to the wiki itself: log.md
# is already a dated record of every ingest / promote / lint-apply, but nobody
# reads it as a time series. This prints the STOCKS (pages, sources, open
# questions, tensions) and the FLOWS (log entries per month), so "is the wiki
# degrading?" is a trend, not a vibe. Read-only, deterministic, no LLM.

set -uo pipefail
ROOT="${1:-.}"
[ -d "$ROOT/wiki" ] || { echo "error: $ROOT/wiki not found (run from the wiki root)" >&2; exit 1; }

pages=$(find "$ROOT/wiki" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
raws=$(find "$ROOT/raw" -type f 2>/dev/null | wc -l | tr -d ' ')
# grep -c prints 0 AND exits 1 on no-match; a `|| echo 0` fallback would emit a
# second line. Capture whatever grep printed, default only when truly empty.
openq=$(grep -c '^- ' "$ROOT/wiki/open-questions-dashboard.md" 2>/dev/null); openq=${openq:-0}
tensions=$(grep -cE '^- |^## ' "$ROOT/wiki/tensions.md" 2>/dev/null); tensions=${tensions:-0}

echo "== stocks =="
echo "wiki pages: $pages   raw sources: $raws   open questions: $openq   tension items: $tensions"
echo ""
echo "== flows (log.md entries per month, oldest first) =="
if [ -f "$ROOT/log.md" ]; then
  grep -oE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$ROOT/log.md" \
    | cut -c4-10 | sort | uniq -c | awk '{ printf "%s: %s entr%s\n", $2, $1, ($1 == 1 ? "y" : "ies") }'
  total=$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$ROOT/log.md" || true)
  echo ""
  echo "total logged operations: ${total:-0}"
  [ "${total:-0}" -eq 0 ] && echo "note: log.md has no dated entries — either a fresh wiki or the log discipline lapsed."
else
  echo "log.md missing — the flow record does not exist."
fi
