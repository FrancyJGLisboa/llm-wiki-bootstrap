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
#   wiki-metrics.sh query <answer-file> [<wiki-root>] [--temporal]
#
# `--temporal` additionally GATES the answer: exit 4 unless its resolving
# citations span >= 2 distinct `asserted_at` dates. For change-over-time
# questions only — see the temporal traversal section of wiki-query.md.
#
# Appends one line to log.md, inside a per-day `## <date> — metrics` section
# (created at the top, newest-at-top, if today's does not exist yet):
#
#   - metrics: op=ingest date=2026-07-30 sources=11 pages=25 committed=11/11
#   - metrics: op=query date=2026-07-30 cites=6/7 dates=3 via=wiki
#
# NEVER touches raw/ (hard rule 1) and never rewrites existing log.md content:
# it is an insert, so every prior byte survives verbatim.
# Pure CommonMark (hard rule 3): the record is a list item.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --temporal turns the query record into a GATE: a change-over-time answer must
# rest on at least two DIFFERENTLY DATED sources. Measured: every such answer
# that succeeded opened 1-3 files; every one that failed opened zero and
# narrated a trajectory out of the synthesis artifacts. Counting distinct
# `asserted_at` values across the answer's resolving citations is the cheapest
# thing that is false exactly when that happened.
#
# Position-independent so `query ans.md --temporal` and
# `query ans.md /root --temporal` both work.
TEMPORAL=0
args=()
for a in "$@"; do
  case "$a" in
    --temporal) TEMPORAL=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- ${args[@]+"${args[@]}"}

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
  # Commitment is measured over CITED sources, because that is what a commitment
  # is FOR: `ingested_hash` is the promise "the pages citing this were written
  # against this body", so a source nothing cites has no citations at risk, while
  # a heavily-cited source without one leaves every citation into it unverifiable.
  # Counting all of raw/ blurred both directions at once — the shipped demo wiki
  # read 2/7 while the real defect was four sources carrying 61 citations between
  # them and no commitment at all.
  #
  # Note this denominator is STRICTER, not laxer: uncited files cannot pad the
  # rate, and they are reported separately rather than dropped silently.
  committed=0; cited_total=0; uncited=0
  while IFS= read -r f; do
    base=$(basename "$f")
    case "$base" in .*) continue ;; esac
    # A sidecar keeps its commitment with its parent (a .csv's hash lives on
    # the parsed <name>.md beside it), so count the pair once — and treat a
    # citation to EITHER path as citing the pair.
    case "$f" in *.md) [ -f "${f%.md}" ] && continue ;; esac
    n_cite=$(grep -ro "(source: raw/$base" "$ROOT/wiki" 2>/dev/null | wc -l | tr -d ' ')
    n_side=$(grep -ro "(source: raw/$base.md" "$ROOT/wiki" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$((n_cite + n_side))" -eq 0 ]; then uncited=$((uncited + 1)); continue; fi
    cited_total=$((cited_total + 1))
    if grep -q 'ingested_hash: "[0-9a-f]' "$f" 2>/dev/null \
       || grep -q 'ingested_hash: "[0-9a-f]' "$f.md" 2>/dev/null; then
      committed=$((committed + 1))
    fi
  done < <(find "$ROOT/raw" -type f 2>/dev/null | sort)
  record="- metrics: op=ingest date=$DATE sources=$((cited_total + uncited)) pages=$pages committed=$committed/$cited_total uncited=$uncited"

else
  [ -f "$ANSWER" ] || { echo "wiki-metrics: answer file not found: $ANSWER" >&2; exit 1; }
  # Canonical citation grammar, and each `source: raw/<target>` counted on its
  # own — models legitimately pack two receipts into one parenthetical.
  targets=$(grep -oE 'source:[[:space:]]*raw/[^),;[:space:]]+' "$ANSWER" 2>/dev/null \
            | sed -e 's/^source:[[:space:]]*//' | sort -u)
  cite_total=0; cite_ok=0; resolver=1; dates=
  [ -f "$SCRIPT_DIR/cite-span.py" ] && command -v python3 >/dev/null 2>&1 || resolver=0
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    cite_total=$((cite_total + 1))
    if [ "$resolver" -eq 1 ] && python3 "$SCRIPT_DIR/cite-span.py" "$ROOT/raw" "$t" >/dev/null 2>&1; then
      cite_ok=$((cite_ok + 1))
      # Valid time only, read off the cited file's own frontmatter. Deliberately
      # NOT fetched_at: that is when WE snapshotted the source, so a corpus
      # ingested in one afternoon would show a dozen "distinct dates" and the
      # floor would pass on a single day's worth of evidence.
      #
      # Only RESOLVING citations earn a date — otherwise an answer could clear
      # the floor by naming two dated files it never opened.
      d=$(sed -n '/^asserted_at:/{s/^asserted_at:[[:space:]]*//;p;q;}' "$ROOT/${t%%#*}" 2>/dev/null)
      case "$d" in ''|unknown) ;; *) dates="$dates$d
" ;; esac
    fi
  done <<EOF
$targets
EOF
  # `grep -c` already prints the count; its exit-1-on-no-match is not an error
  # here, so swallow the status WITHOUT emitting a second value. `|| echo 0`
  # appended a line to grep's own "0" and made date_n a two-line string, which
  # embedded a newline in the log record and corrupted the insertion.
  date_n=$(printf '%s' "$dates" | sort -u | grep -c . 2>/dev/null || true)
  # Degrade honestly: with no resolver the count is unknown, not zero. A "0/7"
  # that actually means "could not check" is a fabricated defect.
  if [ "$resolver" -eq 0 ] && [ "$cite_total" -gt 0 ]; then ok_field="?"; else ok_field="$cite_ok"; fi
  if grep -qE '^- Wiki: *\(none' "$ANSWER" 2>/dev/null; then via=raw-only
  elif grep -qE '^- Wiki: *[^(]' "$ANSWER" 2>/dev/null; then via=wiki
  else via=unknown; fi
  record="- metrics: op=query date=$DATE cites=$ok_field/$cite_total dates=$date_n via=$via"

  # The gate. Blocks BEFORE the record is written: a blocked answer is not a
  # measurement of the wiki, it is an answer that never should have been given,
  # and logging it would trend the wrong thing.
  if [ "$TEMPORAL" -eq 1 ]; then
    if [ "$resolver" -eq 0 ]; then
      echo "wiki-metrics: --temporal cannot verify without python3 + cite-span.py (failing closed)" >&2
      exit 4
    fi
    if [ "$date_n" -lt 2 ]; then
      echo "wiki-metrics: TEMPORAL FLOOR FAILED — $date_n distinct asserted_at date(s) among $cite_ok resolving citation(s); need >= 2." >&2
      echo "  A change-over-time answer must rest on sources from at least two different dates." >&2
      echo "  Run: python3 $SCRIPT_DIR/wiki-timeline.py --topic \"<terms>\"   then read and cite two dated rows." >&2
      echo "  If the wiki genuinely holds only one date on this topic, say THAT — do not imply a trajectory." >&2
      exit 4
    fi
  fi
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
