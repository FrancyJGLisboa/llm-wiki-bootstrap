#!/usr/bin/env bash
# scripts/ingest-batch.sh — ingest K sources per agent turn instead of one.
#
# This is F6's recommendation under test, not a convenience wrapper.
#
# The per-source path hit a wall: at 82 pages / 1.12 MB of wiki, four
# consecutive turns exceeded a 20-minute budget while the backend answered a
# probe in 6s. The cost is not the model being slow, it is that EVERY source
# pays the same O(corpus) tax — read wiki/index.md, sweep existing pages for
# entity dedup (Step 4), rewrite wiki/index.md (Step 6) — and that tax grows
# with the wiki while the work it protects stays constant.
#
# The sibling repo ~/wiki-factory compiles the same corpus at 59-299 s/source
# by putting the WHOLE corpus in one session, and its Phase-0 spike separately
# falsified a per-source process fan-out (auth races, 529s, 4/5 sources failed).
# Batching amortises the fixed tax across K sources and keeps the wiki's page
# list warm in one context instead of re-reading it K times from cold.
#
# Batching is the ONLY change: same /ctx-compile command, same faithfulness gate
# run by the harness afterward, same commitment via body-hash.sh. If throughput
# improves, F6's recommendation is demonstrated rather than asserted. If it does
# not, that is equally a result and the report says so.
#
# Usage:
#   scripts/ingest-batch.sh <wiki-root> [--size K] [--timeout S] [--log FILE]
# Defaults: --size 5, --timeout 2400.
#
# Exit: 0 completed, 2 setup error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMIT="$SCRIPT_DIR/commit-source.py"

WIKI=; SIZE=5; TIMEOUT_S=2400; LOG=
while [ $# -gt 0 ]; do
  case "$1" in
    --size)    SIZE="${2:-5}"; shift 2 ;;
    --timeout) TIMEOUT_S="${2:-2400}"; shift 2 ;;
    --log)     LOG="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) WIKI="$1"; shift ;;
  esac
done
[ -n "$WIKI" ] && [ -d "$WIKI/raw" ] || { echo "usage: ingest-batch.sh <wiki-root> [--size K] [--timeout S] [--log FILE]" >&2; exit 2; }
[ -f "$COMMIT" ] || { echo "error: missing $COMMIT" >&2; exit 2; }
command -v claude >/dev/null 2>&1 || { echo "error: claude not on PATH" >&2; exit 2; }
WIKI="$(cd "$WIKI" && pwd)"
[ -n "$LOG" ] || LOG="$WIKI/.batch-timing.tsv"
[ -f "$LOG" ] || printf '# batch\tsources\twords\tseconds\tstatus\tcommitted_delta\tpages_after\ts_per_source\n' > "$LOG"

CLAUDE_DIR="$(dirname "$(command -v claude)")"
FLOOR_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF "$CLAUDE_DIR" | paste -sd: -)"

pending() {
  for f in "$WIKI"/raw/*.md; do
    [ -f "$f" ] || continue
    python3 "$COMMIT" "$f" --check >/dev/null 2>&1 || printf '%s\n' "$f"
  done
}

batch=0
while :; do
  # macOS ships bash 3.2, which has no `mapfile` — using it silently left todo
  # empty and the loop reported "nothing pending" with 29 sources outstanding.
  # The repo already pins this constraint elsewhere ("Portable to bash 3.2").
  todo=()
  while IFS= read -r line; do
    [ -n "$line" ] && todo[${#todo[@]}]="$line"
  done < <(pending | head -n "$SIZE")
  [ "${#todo[@]}" -gt 0 ] || { echo "[batch] nothing pending"; break; }
  batch=$((batch + 1))

  rels=""; words=0
  for f in "${todo[@]}"; do
    rels="$rels raw/$(basename "$f")"
    words=$(( words + $(wc -w < "$f" | tr -d ' ') ))
  done

  before=$(pending | wc -l | tr -d ' ')
  find "$WIKI/wiki" -name '*.md' -print0 2>/dev/null | sort -z > "$WIKI/.pages-before"

  list=""
  for f in "${todo[@]}"; do list="$list
- raw/$(basename "$f")"; done

  prompt="/ctx-compile

Ingest these ${#todo[@]} sources in THIS single turn, one after another:$list

Process them sequentially and completely: for each source do Steps 1-4 (extract,
write its summary page, update entity and concept pages) and Step 5
(contradictions). Read wiki/index.md ONCE at the start and rewrite it ONCE at
the very end covering all ${#todo[@]} sources, rather than per source.

Skip Step 5.5 (the faithfulness gate) entirely: the harness runs it to
completion immediately after this turn, in a shell that can wait for it.

Do complete Step 7's ingested_hash commitment consideration for each source, but
note the harness also writes the commitment fields, so prioritise finishing the
page authoring for every listed source over bookkeeping."

  echo "[batch] $batch: ${#todo[@]} source(s), ${words}w" >&2
  start=$(date +%s)
  ( cd "$WIKI" && claude -p "$prompt" </dev/null ) >"$WIKI/.batch-last.log" 2>&1 &
  cpid=$!
  deadline=$(( start + TIMEOUT_S ))
  while kill -0 "$cpid" 2>/dev/null && [ "$(date +%s)" -lt "$deadline" ]; do sleep 10; done
  if kill -0 "$cpid" 2>/dev/null; then
    kill -TERM "$cpid" 2>/dev/null; sleep 3; kill -KILL "$cpid" 2>/dev/null
    pkill -f 'claude -p /ctx-compile' 2>/dev/null
    status=TIMEOUT
  elif wait "$cpid"; then status=ok; else status=FAIL; fi
  elapsed=$(( $(date +%s) - start ))

  changed=$(find "$WIKI/wiki" -name '*.md' -newer "$WIKI/.pages-before" 2>/dev/null | tr '\n' ' ')
  if [ -n "$changed" ]; then
    # shellcheck disable=SC2086
    ( cd "$WIKI" && PATH="$FLOOR_PATH" bash scripts/wiki-faithfulness-gate.sh \
        --mode ingest --allow-unjudged $changed </dev/null ) >"$WIKI/.gate-last.log" 2>&1
  fi

  # Commit every source in the batch whose pages actually landed. A source with
  # no page written stays pending rather than being falsely marked done.
  for f in "${todo[@]}"; do
    rel="raw/$(basename "$f")"
    stem="$(basename "$f" .md)"
    if grep -rqlF "$(basename "$f")" "$WIKI/wiki" 2>/dev/null || [ -f "$WIKI/wiki/$stem-summary.md" ]; then
      h=$(cd "$WIKI" && bash scripts/body-hash.sh "$rel" 2>/dev/null | awk '{print $1}')
      [ -n "$h" ] && python3 "$COMMIT" "$f" --hash "$h" --at "$(date '+%Y-%m-%d %H:%M')" \
                       --pages "$(printf '%s' "$changed" | tr ' ' '\n' | sed "s|^$WIKI/||" | paste -sd, -)" \
                       >/dev/null 2>&1
    fi
  done

  after=$(pending | wc -l | tr -d ' ')
  delta=$(( before - after ))
  pages=$(find "$WIKI/wiki" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  per=$([ "$delta" -gt 0 ] && echo $(( elapsed / delta )) || echo 0)
  printf '%d\t%d\t%d\t%d\t%s\t%d\t%d\t%d\n' \
    "$batch" "${#todo[@]}" "$words" "$elapsed" "$status" "$delta" "$pages" "$per" >> "$LOG"
  echo "[batch] $batch: ${elapsed}s $status, committed +$delta, pages=$pages, ${per}s/source" >&2

  [ "$delta" -eq 0 ] && { echo "[batch] no progress this round — stopping" >&2; break; }
done

echo
awk -F'\t' '/^#/{next} $6>0 {s+=$4; n+=$6} END{ if(n) printf "batched: %d source(s), %.0fs/source overall\n", n, s/n }' "$LOG"
