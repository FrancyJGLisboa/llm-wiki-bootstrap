#!/usr/bin/env bash
# Re-measure the gold A1 figures against the FIXED parser (commit 1aa649c).
#
# Every prior A1 number on this corpus was produced while retr_parse_questions
# folded `cite-file-matches:` into the question text — so each question carried
# `cite-file-matches: ^2020-09-16-`, the date prefix of its own correct source,
# while the A1 leg being scored is "did you cite a source of the right date".
# 54 of the 66 gold questions were affected. Those figures are not usable.
#
# Two sets, both fresh (no cached answers from any leaked run):
#   gold-questions-scoreable.md  (28) — the questions whose cited source was
#       actually ingested; the rest cite content the stalled ingest never
#       delivered and would fail for reasons unrelated to retrieval.
#   holdout-scoreable.md          (7) — the sealed anti-Goodhart control.
#
# Prompt is the COMMITTED wiki-query.md (no temporal router — that was measured
# as a null result and not merged), so this measures what main actually ships.
set -uo pipefail

R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$R/../../../.." && pwd)"
WIKI=/Users/francylisboacharuto/grain-wiki-assessment
G="$REPO/tests/eval/grain-corpus"

log() { echo "$(date +%H:%M:%S) $*" >> "$R/remeasure.log"; }
: > "$R/remeasure.log"

log "gold-scoreable start (28 questions, fixed parser)"
"$REPO/scripts/eval-corpus.sh" --wiki "$WIKI" --questions "$G/gold-questions-scoreable.md" \
  --work "$R/work-gold-remeasure" --label gold-fixed > "$R/gold-fixed.txt" 2>&1
log "gold-scoreable done rc=$?"

log "holdout start (7 questions, sealed control)"
"$REPO/scripts/eval-corpus.sh" --wiki "$WIKI" --questions "$G/holdout-scoreable.md" \
  --work "$R/work-holdout-remeasure" --label holdout-fixed > "$R/holdout-fixed.txt" 2>&1
log "holdout done rc=$?"

log "REMEASURE COMPLETE"
