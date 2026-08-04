#!/usr/bin/env bash
# Full two-arm run: 30 cross-temporal questions, treatment (unconditional router
# + read floor) vs baseline (the wiki-query.md from git HEAD, before any of it).
#
# The ONLY difference between arms is .claude/commands/wiki-query.md inside the
# target wiki — eval-corpus.sh does `cd "$WIKI" && claude -p`, so swapping that
# file swaps the arm. Same wiki, same raw/, same questions, same grader.
#
# Arms run SEQUENTIALLY and must not overlap: they share one wiki directory and
# would clobber each other's command file.
#
# Outputs live under this directory (in the repo) rather than the session
# scratchpad, which is wiped when the session ends — that is how the first
# pilot's baseline arm was lost.
set -uo pipefail

R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$R/../../../.." && pwd)"
WIKI=/Users/francylisboacharuto/grain-wiki-assessment
Q="$REPO/tests/eval/grain-corpus/temporal-questions.md"
CMD="$WIKI/.claude/commands/wiki-query.md"

log() { echo "$(date +%H:%M:%S) $*" >> "$R/full.log"; }
: > "$R/full.log"

# ── treatment ────────────────────────────────────────────────────────────────
cp "$REPO/.claude/commands/wiki-query.md" "$CMD"
log "treatment start (unconditional router)"
"$REPO/scripts/eval-corpus.sh" --wiki "$WIKI" --questions "$Q" \
  --work "$R/work-treatment" --label treatment-full > "$R/treatment-full.txt" 2>&1
log "treatment done rc=$?"

# ── baseline ─────────────────────────────────────────────────────────────────
cp "$R/baseline-wiki-query.md" "$CMD"
log "baseline start (git HEAD prompt, no router)"
"$REPO/scripts/eval-corpus.sh" --wiki "$WIKI" --questions "$Q" \
  --work "$R/work-baseline" --label baseline-full > "$R/baseline-full.txt" 2>&1
log "baseline done rc=$?"

# Leave the wiki on the treatment command so it is not silently reverted.
cp "$REPO/.claude/commands/wiki-query.md" "$CMD"
log "FULL RUN COMPLETE"
