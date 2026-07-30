#!/usr/bin/env bash
# scripts/wiki-metrics.sh — record integrity numbers for a REAL operation.
#
# The eval harness measures commitment rate and citation resolution on every
# question it asks; a real `/wiki-query` or `/wiki-ingest` measured nothing, so
# the failures the harness catches were invisible in actual use. Observed: an
# ingest wrote correct, correctly-cited pages and silently skipped the raw/
# frontmatter commitment step — every citation into those bodies became
# unverifiable and no user would ever have known.
#
# This turns monitoring from pull (a human runs /wiki-lint) into passive record
# (every operation leaves a machine-readable line), which is what gives
# scripts/wiki-flows.sh an actual time series to trend.
#
# The numbers are computed HERE, by code, never narrated by the model — a line
# the agent wrote from memory is an assertion, not a measurement.
#
# Usage:
#   wiki-metrics.sh ingest [<wiki-root>]
#   wiki-metrics.sh query <answer-file> [<wiki-root>]
#
# Appends one line to log.md, inside a per-day `## <date> — metrics` section
# (created at the top, newest-at-top, if today's does not exist yet):
#
#   - metrics: op=ingest date=2026-07-30 sources=11 pages=25 committed=11/11
#   - metrics: op=query date=2026-07-30 cites=6/7 via=wiki
#
# NEVER touches raw/ (hard rule 1) and never rewrites existing log.md content:
# it is an insert, so every prior byte survives verbatim.
# Pure CommonMark (hard rule 3): the record is a list item.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OP="${1:-}"
case "$OP" in
  ingest) ROOT="${2:-.}" ;;
  query)  ANSWER="${2:-}"; ROOT="${3:-.}"
          [ -n "$ANSWER" ] || { echo "usage: wiki-metrics.sh query <answer-file> [<wiki-root>]" >&2; exit 2; } ;;
  *) echo "usage: wiki-metrics.sh ingest|query [args]" >&2; exit 2 ;;
esac

[ -d "$ROOT/wiki" ] || { echo "wiki-metrics: $ROOT/wiki not found (run from the wiki root)" >&2; exit 1; }
LOG="$ROOT/log.md"
# The date is genuinely wanted here (this is a log, not a fixture); the override
# exists so the oracle can assert on a fixed date without stubbing the clock.
DATE="${WIKI_METRICS_DATE:-$(date +%F)}"

# ── compute ───────────────────────────────────────────────────────────────────
record=

if [ "$OP" = ingest ]; then
  pages=$(find "$ROOT/wiki" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
  committed=0; total=0
  while IFS= read -r f; do
    base=$(basename "$f")
    case "$base" in .*) continue ;; esac
    # A sidecar keeps its commitment with its parent (a .csv's hash lives on
    # the parsed <name>.md beside it), so count the pair once.
    case "$f" in *.md) [ -f "${f%.md}" ] && continue ;; esac
    total=$((total + 1))
    if grep -q 'ingested_hash: "[0-9a-f]' "$f" 2>/dev/null \
       || grep -q 'ingested_hash: "[0-9a-f]' "$f.md" 2>/dev/null; then
      committed=$((committed + 1))
    fi
  done < <(find "$ROOT/raw" -type f 2>/dev/null | sort)
  record="- metrics: op=ingest date=$DATE sources=$total pages=$pages committed=$committed/$total"

else
  [ -f "$ANSWER" ] || { echo "wiki-metrics: answer file not found: $ANSWER" >&2; exit 1; }
  # Canonical citation grammar, and each `source: raw/<target>` counted on its
  # own — models legitimately pack two receipts into one parenthetical.
  targets=$(grep -oE 'source:[[:space:]]*raw/[^),;[:space:]]+' "$ANSWER" 2>/dev/null \
            | sed -e 's/^source:[[:space:]]*//' | sort -u)
  cite_total=0; cite_ok=0; resolver=1
  [ -f "$SCRIPT_DIR/cite-span.py" ] && command -v python3 >/dev/null 2>&1 || resolver=0
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    cite_total=$((cite_total + 1))
    if [ "$resolver" -eq 1 ] && python3 "$SCRIPT_DIR/cite-span.py" "$ROOT/raw" "$t" >/dev/null 2>&1; then
      cite_ok=$((cite_ok + 1))
    fi
  done <<EOF
$targets
EOF
  # Degrade honestly: with no resolver the count is unknown, not zero. A "0/7"
  # that actually means "could not check" is a fabricated defect.
  if [ "$resolver" -eq 0 ] && [ "$cite_total" -gt 0 ]; then ok_field="?"; else ok_field="$cite_ok"; fi
  if grep -qE '^- Wiki: *\(none' "$ANSWER" 2>/dev/null; then via=raw-only
  elif grep -qE '^- Wiki: *[^(]' "$ANSWER" 2>/dev/null; then via=wiki
  else via=unknown; fi
  record="- metrics: op=query date=$DATE cites=$ok_field/$cite_total via=$via"
fi

# ── append (insert into today's section, or open one at the top) ───────────────
[ -f "$LOG" ] || printf '# log.md\n\n' > "$LOG"
heading="## $DATE — metrics"
tmp="$LOG.metrics.$$"

if grep -qF "$heading" "$LOG"; then
  # Append inside today's existing metrics section, after its last record.
  awk -v h="$heading" -v rec="$record" '
    { lines[NR] = $0 }
    $0 == h { inseg = 1; last = NR; next }
    inseg && /^## / { inseg = 0 }
    inseg && /^- metrics: / { last = NR }
    END {
      for (i = 1; i <= NR; i++) { print lines[i]; if (i == last) print rec }
    }
  ' "$LOG" > "$tmp"
else
  # New day: open a section above the newest existing entry (newest at top).
  awk -v h="$heading" -v rec="$record" '
    !done && /^## / { print h; print ""; print rec; print ""; done = 1 }
    { print }
    END { if (!done) { print h; print ""; print rec } }
  ' "$LOG" > "$tmp"
fi

mv "$tmp" "$LOG"
echo "wiki-metrics: recorded ${record#- metrics: }" >&2
