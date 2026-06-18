#!/usr/bin/env bash
# scripts/smoke-segment.sh — agent-driven C6/C7 smoke for long-source tree
# retrieval (.scratch/long-source-tree-retrieval/GOAL.md).
#
# Scaffolds a THROWAWAY wiki (never touches the real repo's raw//wiki/), places
# a pre-segmented Vantel sidecar in raw/, then drives `claude -p` through
# /wiki-ingest and /wiki-query and asserts:
#
#   C6 — the source's summary page is a section TREE whose every
#        (source: raw/<slug>.md#<anchor>) resolves to a real heading in the
#        sidecar (no invented anchors).
#   C7 — a question answerable from ONE section returns that section's needle
#        (Halverson coefficient 0.0473 + throttle temp 71) AND cites the
#        SPECIFIC section anchor (#thermal-limits), not the whole document.
#
# Needs the `claude` CLI and python3. Exit 0 iff C6 and C7 pass.
# Reuses the deterministic segmenter to BUILD the fixture sidecar, so the
# agent is fed exactly the artifact /wiki-extract would have produced.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else RED=; GREEN=; DIM=; RESET=; fi
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }
log()  { printf "%s[smoke-segment]%s %s\n" "$DIM" "$RESET" "$1" >&2; }
failures=0

command -v claude  >/dev/null 2>&1 || { echo "claude CLI not on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 2; }

FIX="$REPO_ROOT/tests/segment/long-source.md"
SEG="$REPO_ROOT/scripts/extract/segment-doc.py"
SLUG="vantel-array"
[ -f "$FIX" ] || { echo "fixture missing: $FIX" >&2; exit 2; }

# Kebab-case slug of a heading TITLE (range already stripped), matching the
# `<section-slug>` rule documented in /wiki-ingest + AGENTS.md.
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
  printf '\n'   # guarantee a trailing newline (BSD sed drops it without one)
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/raw" "$WORK/wiki/journal"
cp -r "$REPO_ROOT/.claude" "$WORK/"
cp "$REPO_ROOT/AGENTS.md" "$WORK/"
cp -r "$REPO_ROOT/scripts" "$WORK/"
printf '# index\n\n' > "$WORK/wiki/index.md"
printf '# log.md\n\n'  > "$WORK/log.md"

# --- Build the segmented sidecar the agent will ingest -----------------------
BODY="$(python3 "$SEG" "$FIX")"
SEGCOUNT="$(printf '%s\n' "$BODY" | grep -cE '^#{1,6} .+\((lines|pages) [0-9]+-[0-9]+\)$')"
TODAY="$(date -u +%Y-%m-%d)"
RAW="$WORK/raw/$SLUG.md"
{
  printf -- '---\n'
  printf 'source_url: n/a (segment smoke fixture)\n'
  printf 'source_type: report\n'
  printf 'source_title: "The Vantel Array"\n'
  printf 'source_author: "Segment smoke (fictional)"\n'
  printf 'fetched_at: %s\n' "$TODAY"
  printf 'ingested_hash: ""\n'
  printf 'ingested_at: never\n'
  printf 'ingested_pages: []\n'
  printf 'extraction_method: passthrough+segment-doc\n'
  printf 'segmented: true\n'
  printf 'segments: %s\n' "$SEGCOUNT"
  printf -- '---\n'
  printf '# The Vantel Array\n\n'
  printf '%s\n' "$BODY"
} > "$RAW"
log "built segmented sidecar with $SEGCOUNT section anchors"

# Build the set of VALID anchor slugs from the sidecar headings.
VALID="$WORK/valid-anchors.txt"
grep -E '^#{1,6} ' "$RAW" \
  | sed -E 's/^#{1,6} //; s/ \((lines|pages) [0-9]+-[0-9]+\)$//' \
  | while IFS= read -r title; do slugify "$title"; done | sort -u > "$VALID"

# --- Drive the agent ---------------------------------------------------------
log "claude -p /wiki-ingest …"
( cd "$WORK" && claude -p "/wiki-ingest raw/$SLUG.md" ) > "$WORK/ingest.log" 2>&1 \
  || { echo "ingest run failed; tail:" >&2; tail -20 "$WORK/ingest.log" >&2; }

QUESTION='What is the Halverson coefficient, and at what junction temperature do Vantel nodes enter throttled sampling? Cite the specific source section.'
log "claude -p /wiki-query …"
( cd "$WORK" && claude -p "/wiki-query \"$QUESTION\" --no-promote" ) > "$WORK/answer.md" 2>"$WORK/query.log" \
  || { echo "query run failed; tail:" >&2; tail -20 "$WORK/query.log" >&2; }

# --- C6: summary tree anchors all resolve ------------------------------------
SUMMARY="$(ls "$WORK"/wiki/${SLUG}-summary.md "$WORK"/wiki/*summary*.md 2>/dev/null | head -1)"
if [ -z "$SUMMARY" ] || [ ! -f "$SUMMARY" ]; then
  fail "C6 no summary page produced for $SLUG (ingest may have failed — see ingest.log)"
else
  cited="$(grep -oE "raw/${SLUG}\.md#[a-z0-9-]+" "$SUMMARY" | sed 's/.*#//' | sort -u)"
  if [ -z "$cited" ]; then
    fail "C6 summary page has no (source: raw/${SLUG}.md#anchor) section citations (not a tree)"
  else
    bad=0; n=0
    while IFS= read -r a; do
      [ -z "$a" ] && continue
      n=$((n + 1))
      grep -qxF "$a" "$VALID" || { fail "C6 cited anchor #$a does not resolve to a sidecar heading"; bad=$((bad + 1)); }
    done <<< "$cited"
    [ "$bad" -eq 0 ] && ok "C6 summary is a section tree; all $n cited anchor(s) resolve to sidecar headings"
  fi
fi

# --- C7: targeted retrieval (needle + section-specific anchor) ----------------
ANS="$WORK/answer.md"
need_a=0; need_b=0; anchor=0
grep -qF '0.0473' "$ANS" && need_a=1
grep -qE '(^|[^0-9])71([^0-9]|$)' "$ANS" && need_b=1
grep -qE "raw/${SLUG}\.md#thermal-limits" "$ANS" && anchor=1
if [ "$need_a" -eq 1 ] && [ "$need_b" -eq 1 ]; then
  ok "C7 recall: answer contains the Thermal-Limits needle (0.0473 + 71)"
else
  fail "C7 recall MISS (0.0473=$need_a, 71=$need_b) — see answer.md"
fi
if [ "$anchor" -eq 1 ]; then
  ok "C7 anti-gaming: answer cites the specific #thermal-limits section anchor"
else
  fail "C7 anti-gaming: answer did not cite raw/${SLUG}.md#thermal-limits (section-specific anchor) — recall alone is hand-authorable"
fi

# Keep artifacts on failure for inspection.
if [ "$failures" -ne 0 ]; then
  KEEP="$REPO_ROOT/tests/segment/last-smoke"
  mkdir -p "$KEEP"
  cp -f "$RAW" "$KEEP/raw-$SLUG.md" 2>/dev/null || true
  cp -f "$ANS" "$KEEP/answer.md" 2>/dev/null || true
  [ -n "${SUMMARY:-}" ] && cp -f "$SUMMARY" "$KEEP/summary.md" 2>/dev/null || true
  cp -f "$WORK/ingest.log" "$KEEP/ingest.log" 2>/dev/null || true
  log "artifacts copied to tests/segment/last-smoke/ for inspection"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d agent-side check(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s C6-C7 green — summary tree resolves; query pulled the right section.\n" "$GREEN" "$RESET"
exit 0
