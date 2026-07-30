#!/usr/bin/env bash
# scripts/verify-metrics.sh — oracle for the passive-record monitoring path
# (scripts/wiki-metrics.sh + the integrity trend in scripts/wiki-flows.sh).
# No LLM, no spend. P1–P5 plus the irregular-log control, all must pass.
#
#   P1 ingest-record  : committed=N/M matches an INDEPENDENT filesystem recount
#   P2 query-record   : cites=ok/total is real — an unresolvable citation must
#                       show ok<total, so a bad run cannot be logged as clean
#   P3 trend-readable : every month appears with its own rates, and a decline
#                       is named (one current number is not a trend)
#   P4 append-only    : prior log.md bytes survive verbatim
#   P5 raw untouched  : the metrics path never writes raw/ (hard rule 1)
#   P6 irregular log  : hand-written entries, missing metrics lines and a
#                       zero-op month neither crash the parser nor invent zeros

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS="$SCRIPT_DIR/wiki-metrics.sh"
FLOWS="$SCRIPT_DIR/wiki-flows.sh"

fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }
tmp="$(mktemp -d -t verify-metrics.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

# A wiki with 3 sources: two committed, one not (the observed failure), plus a
# .csv whose commitment lives on its parsed .md sidecar, plus scaffolding.
W="$tmp/w"; mkdir -p "$W/wiki" "$W/raw"
printf -- '---\ningested_hash: "abc12345"\n---\nbody\n' > "$W/raw/committed-a.md"
printf -- '---\ningested_hash: ""\n---\nbody\n'         > "$W/raw/skipped-b.md"
printf 'a,b\n1,2\n'                                      > "$W/raw/data.csv"
printf -- '---\ningested_hash: "cafe9999"\n---\nparsed\n' > "$W/raw/data.csv.md"
: > "$W/raw/.gitkeep"
printf 'x\n' > "$W/wiki/index.md"; printf 'x\n' > "$W/wiki/page-a.md"
printf '# log.md\n\nAppend-only log. Newest at top.\n\n## 2026-06-01 — hand-written entry\n\nprose\n' > "$W/log.md"
raw_before=$(find "$W/raw" -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}')
log_before=$(cat "$W/log.md")

echo "P1: ingest record matches an independent recount"
WIKI_METRICS_DATE=2026-06-15 "$METRICS" ingest "$W" >/dev/null 2>&1 \
  || fail "wiki-metrics.sh ingest failed"
rec=$(grep -m1 '^- metrics: op=ingest' "$W/log.md")
[ -n "$rec" ] && ok "record written: ${rec#- metrics: }" || fail "no ingest record in log.md"
# Recount here, independently of the script's own loop.
exp_total=3   # committed-a, skipped-b, data.csv (sidecar folds into its parent)
exp_ok=2      # committed-a + data.csv via its sidecar
case "$rec" in
  *"committed=$exp_ok/$exp_total"*) ok "committed=$exp_ok/$exp_total matches the recount" ;;
  *) fail "commitment count wrong — want committed=$exp_ok/$exp_total, got: $rec" ;;
esac
case "$rec" in *"pages=2"*) ok "page count correct" ;; *) fail "page count wrong: $rec" ;; esac

echo "P2: query record counts REAL resolution, so a bad run cannot log clean"
printf 'Answer.\n\n- Wiki: [[page-a]]\n\nSee (source: raw/committed-a.md) and (source: raw/nope-missing.md#L2).\n' \
  > "$tmp/ans.md"
WIKI_METRICS_DATE=2026-06-15 "$METRICS" query "$tmp/ans.md" "$W" >/dev/null 2>&1 \
  || fail "wiki-metrics.sh query failed"
qrec=$(grep -m1 '^- metrics: op=query' "$W/log.md")
[ -n "$qrec" ] && ok "record written: ${qrec#- metrics: }" || fail "no query record in log.md"
case "$qrec" in
  *"cites=1/2"*) ok "cites=1/2 — the unresolvable target is counted, not hidden" ;;
  *"cites=?/2"*) ok "resolver unavailable, reported as unknown rather than zero" ;;
  *) fail "citation count wrong (want 1/2 or ?/2): $qrec" ;;
esac
case "$qrec" in *via=wiki*) ok "answer layer recorded (via=wiki)" ;; *) fail "via not recorded: $qrec" ;; esac
# Both records must sit in ONE per-day section, not two — log.md stays readable
# after twenty queries in a day.
n_head=$(grep -c '^## 2026-06-15 — metrics' "$W/log.md" || true)
[ "$n_head" -eq 1 ] && ok "both records share one dated section" || fail "expected 1 metrics heading, got $n_head"

echo "P4: prior log.md content survives verbatim"
if printf '%s' "$(cat "$W/log.md")" | grep -qF "$(printf '%s' "$log_before" | tail -3)"; then
  ok "hand-written entry preserved"
else
  fail "existing log content was altered"
fi
grep -q '^## 2026-06-01 — hand-written entry' "$W/log.md" \
  && ok "original heading intact" || fail "original heading lost"

echo "P5: raw/ never written"
raw_after=$(find "$W/raw" -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}')
[ "$raw_before" = "$raw_after" ] && ok "raw/ byte-identical (hard rule 1 held)" \
  || fail "raw/ changed during the metrics path"

echo "P3: trend shows every month with its own rates, and names a decline"
cat > "$W/log.md" <<'LOG'
# log.md

## 2026-05-02 — metrics

- metrics: op=ingest date=2026-05-02 sources=4 pages=9 committed=4/4
- metrics: op=query date=2026-05-02 cites=8/8 via=wiki

## 2026-06-03 — metrics

- metrics: op=ingest date=2026-06-03 sources=4 pages=12 committed=3/4
- metrics: op=query date=2026-06-03 cites=6/8 via=wiki

## 2026-07-04 — metrics

- metrics: op=ingest date=2026-07-04 sources=4 pages=15 committed=1/4
- metrics: op=query date=2026-07-04 cites=2/8 via=wiki
LOG
out=$("$FLOWS" "$W" 2>&1)
for m in 2026-05 2026-06 2026-07; do
  printf '%s\n' "$out" | grep -q "^$m: " && ok "$m present in the series" || fail "$m missing from the trend"
done
printf '%s\n' "$out" | grep -q '2026-05:.*commitment 4/4 (100%)' \
  && ok "first month rate computed" || fail "2026-05 rate wrong: $(printf '%s' "$out" | grep '^2026-05')"
printf '%s\n' "$out" | grep -q '2026-07:.*commitment 1/4 (25%)' \
  && ok "last month rate computed" || fail "2026-07 rate wrong: $(printf '%s' "$out" | grep '^2026-07')"
printf '%s\n' "$out" | grep -q 'DEGRADED vs the preceding month' \
  && ok "decline is named, not left for the reader to spot" || fail "no degradation flagged on a 100%→25% slide"

echo "P6: irregular log — no crash, no invented zeros (the held-out shape)"
cat > "$W/log.md" <<'LOG'
# log.md

## 2026-07-09 — prose only, no metrics line

Someone wrote this by hand and never ran the recorder.

## 2026-06-01 — metrics

- metrics: op=query date=2026-06-01 cites=?/3 via=unknown
LOG
out2=$("$FLOWS" "$W" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "parser exits 0 on an irregular log" || fail "parser exited $rc"
printf '%s\n' "$out2" | grep -q '2026-06: 1 op' \
  && ok "the one real record is counted" || fail "record miscounted: $out2"
printf '%s\n' "$out2" | grep -q 'citation(s) unchecked' \
  && ok "unknown counts reported as unchecked, not as 0%" || fail "unknown citations became a fabricated rate: $out2"
printf '%s\n' "$out2" | grep -q 'citations 0/3' \
  && { fail "unknown count invented a 0% citation rate"; } || ok "no fabricated 0% rate"

echo ""
if [ "$fails" -eq 0 ]; then
  echo "verify-metrics: P1–P6 all green — records are measured, append-only, and trendable."
  exit 0
fi
echo "verify-metrics: $fails failure(s)" >&2
exit 1
