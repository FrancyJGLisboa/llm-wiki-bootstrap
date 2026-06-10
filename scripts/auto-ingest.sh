#!/usr/bin/env bash
# scripts/auto-ingest.sh — unattended inbox → extract → ingest, for cron/launchd.
#
# The manual loop is: drop a file somewhere, run /wiki-extract, run /wiki-ingest.
# This script automates exactly that and nothing more: if inbox/ contains files,
# drive the headless AI tool (`claude -p`, same driver as scripts/smoke-build.sh)
# to extract each one and then ingest. Files that extracted successfully are
# moved to inbox/processed/ so the next run is a no-op.
#
# Deliberately NOT a daemon: no fswatch, no polling loop, no config file. Run it
# from cron. Example crontab (every 30 min, plus a nightly lint):
#
#   */30 * * * *  cd /path/to/my-wiki && ./scripts/auto-ingest.sh >> .auto-ingest.log 2>&1
#   0 6 * * *     cd /path/to/my-wiki && claude -p "/wiki-lint" >> .auto-ingest.log 2>&1
#
# Usage:
#   ./scripts/auto-ingest.sh [--inbox <dir>] [--dry-run]
#
#   --inbox <dir>  inbox directory (default: inbox/ at the wiki root; created
#                  on first run)
#   --dry-run      report what would be processed; run nothing
#
# Exit codes:
#   0  nothing to do, or all inbox files extracted+ingested
#   1  one or more files failed (left in inbox/ for the next run; see log)
#   2  setup problem (not a wiki root, no claude CLI, lock held)
#
# Concurrency: a lock directory prevents overlapping cron runs. A crashed run's
# stale lock is reclaimed after 2 hours.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$WIKI_ROOT" || exit 2

INBOX="inbox"
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --inbox) INBOX="${2:?--inbox needs a directory}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "error: unknown argument: $1 (usage: auto-ingest.sh [--inbox <dir>] [--dry-run])" >&2; exit 2 ;;
  esac
done

log() { printf '[auto-ingest %s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }

# Wiki-root sanity — same guard as the slash commands.
if [ ! -d raw ] || [ ! -d wiki ]; then
  log "error: $WIKI_ROOT is not a wiki root (no raw/ + wiki/). Run /wiki-init first."
  exit 2
fi

mkdir -p "$INBOX"

# Collect pending files (top level only; ignore dotfiles and processed/).
pending=()
while IFS= read -r f; do
  pending+=("$f")
done < <(find "$INBOX" -maxdepth 1 -type f ! -name '.*' | sort)

if [ "${#pending[@]}" -eq 0 ]; then
  log "inbox empty — nothing to do."
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  log "error: claude CLI not on PATH — cannot run unattended. Install Claude Code, or extract manually with /wiki-extract."
  exit 2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "dry run — would process ${#pending[@]} file(s):"
  printf '  %s\n' "${pending[@]}"
  exit 0
fi

# Lock against overlapping cron runs; reclaim stale locks (>2h, crashed run).
LOCK="$INBOX/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +120 2>/dev/null)" ]; then
    log "reclaiming stale lock (older than 2h)."
  else
    log "another run holds $LOCK — exiting."
    exit 2
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

mkdir -p "$INBOX/processed"

failures=0
for f in "${pending[@]}"; do
  log "extracting: $f"
  if claude -p "/wiki-extract \"$f\"" >/dev/null 2>&1; then
    mv "$f" "$INBOX/processed/"
    log "ok: $f → $INBOX/processed/"
  else
    failures=$((failures + 1))
    log "FAILED: $f — left in inbox for the next run."
  fi
done

processed=$(( ${#pending[@]} - failures ))
if [ "$processed" -gt 0 ]; then
  log "ingesting $processed extracted source(s)…"
  if claude -p "/wiki-ingest" >/dev/null 2>&1; then
    log "ingest complete."
  else
    failures=$((failures + 1))
    log "FAILED: /wiki-ingest — sources are in raw/ with ingested_at: never; next run (or a manual /wiki-ingest) will pick them up."
  fi
fi

if [ "$failures" -gt 0 ]; then
  log "done with $failures failure(s)."
  exit 1
fi
log "done: $processed file(s) extracted and ingested."
exit 0
