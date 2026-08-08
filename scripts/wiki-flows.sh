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

  # ── integrity trend, from the records scripts/wiki-metrics.sh appends ────────
  #
  # Rates PER MONTH, oldest first — the point is the shape, not the latest
  # value. A single current number cannot answer "has this wiki degraded since
  # March?", which is the only question a monitoring surface owes you.
  # Unknown counts (`cites=?/7`, written when no resolver was available) are
  # excluded from the rate rather than counted as zero: a fabricated defect is
  # worse than a gap.
  echo ""
  echo "== integrity trend (per month, oldest first) =="
  if grep -q '^- metrics: ' "$ROOT/log.md"; then
    grep '^- metrics: ' "$ROOT/log.md" | awk '
      {
        month = ""; op = ""; com_ok = com_tot = cit_ok = cit_tot = -1
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^date=/)      { d = substr($i, 6); month = substr(d, 1, 7) }
          else if ($i ~ /^op=/)   { op = substr($i, 4) }
          else if ($i ~ /^committed=/) { split(substr($i, 11), a, "/"); com_ok = a[1]; com_tot = a[2] }
          else if ($i ~ /^cites=/)     { split(substr($i, 7), b, "/"); cit_ok = b[1]; cit_tot = b[2] }
        }
        if (month == "") next
        ops[month]++
        if (com_tot > 0) { c_ok[month] += com_ok; c_tot[month] += com_tot }
        if (cit_tot > 0 && cit_ok != "?") { q_ok[month] += cit_ok; q_tot[month] += cit_tot }
        else if (cit_tot > 0) { q_unknown[month] += cit_tot }
        seen[month] = 1
      }
      END {
        n = 0
        for (m in seen) months[++n] = m
        for (i = 1; i < n; i++) for (j = i + 1; j <= n; j++)
          if (months[i] > months[j]) { t = months[i]; months[i] = months[j]; months[j] = t }
        for (i = 1; i <= n; i++) {
          m = months[i]
          line = m ": " ops[m] " op(s)"
          if (c_tot[m] > 0) line = line sprintf("  commitment %d/%d (%.0f%%)", c_ok[m], c_tot[m], 100 * c_ok[m] / c_tot[m])
          if (q_tot[m] > 0) line = line sprintf("  citations %d/%d (%.0f%%)", q_ok[m], q_tot[m], 100 * q_ok[m] / q_tot[m])
          if (q_unknown[m] > 0) line = line sprintf("  [%d citation(s) unchecked]", q_unknown[m])
          print line
          if (c_tot[m] > 0) { rate = 100 * c_ok[m] / c_tot[m]; if (prev_c != "" && rate < prev_c) degraded = degraded " commitment(" m ")" ; prev_c = rate }
          if (q_tot[m] > 0) { rate = 100 * q_ok[m] / q_tot[m]; if (prev_q != "" && rate < prev_q) degraded = degraded " citations(" m ")" ; prev_q = rate }
        }
        if (degraded != "") print "\nDEGRADED vs the preceding month:" degraded
      }'
  else
    echo "no metrics records yet — /ctx-compile and /ctx-query append them via"
    echo "scripts/wiki-metrics.sh; without those lines this stays a page count,"
    echo "not a trend."
  fi
else
  echo "log.md missing — the flow record does not exist."
fi
