#!/usr/bin/env bash
# scripts/ingest-watchdog.sh — kill ingest turns that outlive their budget.
#
# ingest-corpus.sh has its own deadline, but it did not hold: turns of 2182s,
# 3397s and 2876s all ran to completion under a 1200s setting and were recorded
# as FAIL rather than TIMEOUT, so the deadline branch never fired. Rather than
# keep patching bookkeeping inside the loop that is already misbehaving, this
# watches from outside and does one thing.
#
# It tracks ages itself — one file per PID under a state dir — instead of
# parsing `ps`. macOS ps has no `etimes` (it answers with its keyword list), and
# `etime` needs [[DD-]HH:]MM:SS parsing that is easy to get subtly wrong. First
# sighting is good enough: a turn the watchdog first saw N seconds ago has run
# at least N seconds, which is exactly the bound wanted.
#
# Usage: scripts/ingest-watchdog.sh [--max SECONDS] [--pattern PATTERN]
# Defaults: --max 1200, --pattern 'claude -p /ctx-compile'
#
# Run it in the background beside the driver; Ctrl-C or kill to stop.

set -uo pipefail

MAX=1200
PATTERN='claude -p /ctx-compile'
while [ $# -gt 0 ]; do
  case "$1" in
    --max)     MAX="${2:-1200}"; shift 2 ;;
    --pattern) PATTERN="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "usage: ingest-watchdog.sh [--max SECONDS] [--pattern PATTERN]" >&2; exit 2 ;;
  esac
done

STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT
echo "[watchdog] max=${MAX}s pattern='$PATTERN' state=$STATE" >&2

while true; do
  now=$(date +%s)
  for pid in $(pgrep -f "$PATTERN" 2>/dev/null); do
    f="$STATE/$pid"
    [ -f "$f" ] || printf '%s\n' "$now" > "$f"
    first=$(cat "$f" 2>/dev/null || echo "$now")
    age=$(( now - first ))
    if [ "$age" -gt "$MAX" ]; then
      echo "[watchdog] killing pid $pid after ~${age}s (budget ${MAX}s)" >&2
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      kill -KILL "$pid" 2>/dev/null
      rm -f "$f"
    fi
  done
  # Forget PIDs that have exited, so the ids can't be confused when reused.
  for f in "$STATE"/*; do
    [ -e "$f" ] || continue
    kill -0 "$(basename "$f")" 2>/dev/null || rm -f "$f"
  done
  sleep 20
done
