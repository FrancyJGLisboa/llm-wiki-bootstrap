#!/usr/bin/env bash
# scripts/ingest-corpus.sh — sharded, resumable, timed ingest of a staged corpus.
#
# `/wiki-ingest` with no argument walks all of raw/ in ONE agent turn
# (.claude/commands/wiki-ingest.md), which cannot hold a large corpus in a
# single context. This shards it: one `claude -p "/wiki-ingest raw/<file>"` per
# source, resumable, so a usage cap or a kill costs one source and not the run.
#
# It also records what the scale claim actually needs. Per-source elapsed time is
# logged in ingest ORDER, because the interesting number is not the mean — it is
# the TREND. Ingest Step 4 rewrites existing pages and Step 6 rewrites
# wiki/index.md, both of which grow with the corpus, so cost per source measured
# into a near-empty wiki systematically understates cost per source at N. A mean
# taken from the first few sources is the most flattering number available and
# the least honest one.
#
# After every source it re-reads `wiki-metrics.sh ingest` and stops if the
# commitment rate falls below 100%. That is the already-recorded failure mode:
# at 100 filler pages ingest silently wrote an empty ingested_hash
# (eval-retrieval.sh:420-423), which breaks idempotence and makes every citation
# into that body unverifiable. Discovering it at source 140 is worth more than
# discovering it in the final report.
#
# Usage:
#   scripts/ingest-corpus.sh <wiki-root> [--log FILE] [--limit N] [--no-halt]
#
# Exit: 0 all sources ingested (or already done), 1 halted on a commitment drop
#       or an ingest failure, 2 setup error.

set -uo pipefail

WIKI=; LOG=; LIMIT=0; HALT=1
while [ $# -gt 0 ]; do
  case "$1" in
    --log)     LOG="${2:-}"; shift 2 ;;
    --limit)   LIMIT="${2:-0}"; shift 2 ;;
    --no-halt) HALT=0; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -*) echo "usage: ingest-corpus.sh <wiki-root> [--log FILE] [--limit N] [--no-halt]" >&2; exit 2 ;;
    *)  WIKI="$1"; shift ;;
  esac
done

[ -n "$WIKI" ] || { echo "usage: ingest-corpus.sh <wiki-root> [--log FILE] [--limit N] [--no-halt]" >&2; exit 2; }
[ -d "$WIKI/raw" ] || { echo "error: no raw/ under $WIKI" >&2; exit 2; }
command -v claude >/dev/null 2>&1 || { echo "error: claude not on PATH" >&2; exit 2; }
WIKI="$(cd "$WIKI" && pwd)"
[ -n "$LOG" ] || LOG="$WIKI/.ingest-timing.tsv"

[ -f "$LOG" ] || printf '# idx\tsource\twords\tseconds\tstatus\tpages_after\tcommitted\n' > "$LOG"

# A source is done when its frontmatter carries a non-empty ingested_hash. That
# is the same signal /wiki-ingest itself uses to skip, so a resumed run agrees
# with the pipeline instead of second-guessing it.
committed_hash() {
  awk '/^ingested_hash:/ { gsub(/[" ]/, "", $2); print $2; exit }' "$1"
}

idx=0; done_n=0; failed=0
for src in "$WIKI"/raw/*.md; do
  [ -f "$src" ] || continue
  idx=$((idx + 1))
  [ "$LIMIT" -gt 0 ] && [ "$idx" -gt "$LIMIT" ] && break
  rel="raw/$(basename "$src")"

  if [ -n "$(committed_hash "$src")" ]; then
    echo "[ingest] $idx $rel — already committed, skipping" >&2
    done_n=$((done_n + 1))
    continue
  fi

  words=$(wc -w < "$src" | tr -d ' ')
  start=$(date +%s)
  # stdin pinned to /dev/null: without it `claude -p` waits 3s per call for input
  # that never comes. Same trap verify-retrieval-eval.sh E7 pins at all 3 sites.
  if ( cd "$WIKI" && claude -p "/wiki-ingest $rel" </dev/null ) >"$WIKI/.ingest-last.log" 2>&1; then
    status=ok
  else
    status="FAIL"
    failed=$((failed + 1))
  fi
  elapsed=$(( $(date +%s) - start ))

  pages=$(find "$WIKI/wiki" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  metrics=$(cd "$WIKI" && bash scripts/wiki-metrics.sh ingest . 2>/dev/null | tail -1)
  committed=$(printf '%s' "$metrics" | sed -n 's/.*committed=\([0-9]*\/[0-9]*\).*/\1/p')
  [ -n "$committed" ] || committed="?"

  printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$idx" "$(basename "$src")" "$words" "$elapsed" "$status" "$pages" "$committed" >> "$LOG"
  echo "[ingest] $idx $rel  ${words}w  ${elapsed}s  $status  pages=$pages  committed=$committed" >&2

  if [ "$status" = FAIL ]; then
    echo "[ingest] !! ingest failed on $rel — see $WIKI/.ingest-last.log" >&2
    [ "$HALT" -eq 1 ] && { echo "[ingest] halting (--no-halt to continue)" >&2; exit 1; }
  fi

  # Commitment is the early warning for the silent-hash failure. Compare the two
  # sides of committed=N/M rather than trusting a rate: the denominator counts
  # only CITED raw sources, so a shrinking denominator hides a growing gap.
  if [ "$committed" != "?" ] && [ "$HALT" -eq 1 ]; then
    have=${committed%%/*}; want=${committed##*/}
    if [ "$have" -lt "$want" ]; then
      echo "[ingest] !! commitment dropped to $committed at source $idx ($rel)" >&2
      echo "[ingest]    this is the silent ingested_hash failure — halting." >&2
      exit 1
    fi
  fi
  done_n=$((done_n + 1))
done

echo
echo "ingested $done_n source(s), $failed failure(s); timing log: $LOG"
awk -F'\t' '
  /^#/ { next }
  $4 ~ /^[0-9]+$/ { t[++n] = $4; sum += $4 }
  END {
    if (n == 0) { print "no timing rows"; exit }
    q = int(n / 4); if (q < 1) q = 1
    for (i = 1; i <= q; i++)      first += t[i]
    for (i = n - q + 1; i <= n; i++) last += t[i]
    printf "mean %.0fs/source over %d source(s)\n", sum / n, n
    printf "first quartile mean %.0fs -> last quartile mean %.0fs", first / q, last / q
    if (first > 0) printf "  (%.2fx)", (last / q) / (first / q)
    printf "\n"
    printf "projected serial for 1138 at the LAST-quartile rate: %.1fh\n", (last / q) * 1138 / 3600
  }
' "$LOG"
[ "$failed" -eq 0 ]
