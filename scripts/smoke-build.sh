#!/usr/bin/env bash
# scripts/smoke-build.sh — LLM-driven, idempotent build phase of the end-to-end smoke.
#
# Drives `claude -p` to:
#   1. ingest tests/smoke/smoke-source.md as raw/smoke-source.md
#   2. ask the wiki the question in tests/smoke/expected-query.md
#   3. capture the answer to tests/smoke/output/last-answer.md
#
# Idempotent: skips the LLM work when raw/smoke-source.md's ingested_hash
# already matches the body-hash of the fixture (the source hasn't changed
# since the last successful ingest).
#
# Refuses to run if state looks polluted (raw/ + wiki/ inconsistent with
# the captured baseline manifest) — prints reset instructions and exits 1.
#
# Spec: .scratch/plug-and-play-curator-smoke/GOAL.md §5 build-phase algorithm.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

FIXTURE="tests/smoke/smoke-source.md"
QUERY_FILE="tests/smoke/expected-query.md"
OUTPUT_DIR="tests/smoke/output"
BASELINE="$OUTPUT_DIR/baseline-wiki.txt"
LAST_ANSWER="$OUTPUT_DIR/last-answer.md"
BUILD_LOG="$OUTPUT_DIR/build.log"
RAW="raw/smoke-source.md"

# TTY-aware coloring (best-effort; doesn't affect anything piped).
if [ -t 1 ]; then
  YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  YELLOW=; RED=; GREEN=; DIM=; RESET=
fi

log() { printf "%s[smoke-build]%s %s\n" "$DIM" "$RESET" "$1" >&2; }
die() { printf "%s[smoke-build] error: %s%s\n" "$RED" "$1" "$RESET" >&2; exit 1; }

print_reset_instructions() {
  cat >&2 <<EOF
${YELLOW}RESET REQUIRED.${RESET} The repo state is inconsistent with the smoke baseline.
Run, in order:

  rm -f raw/smoke-source.md tests/smoke/output/baseline-wiki.txt \\
        tests/smoke/output/last-answer.md tests/smoke/output/build.log
  # Then manually delete any smoke-derived wiki pages (anything that
  # contains 'Quortex' and wasn't in the prior commit):
  for f in \$(grep -lF 'Quortex' wiki/*.md 2>/dev/null); do
    git rev-parse --quiet --verify HEAD:"\$f" >/dev/null 2>&1 || rm -f "\$f"
  done
  ./scripts/smoke-all.sh         # re-run from scratch
EOF
}

# Step 0: preconditions
[ -f "$FIXTURE" ] || die "fixture missing: $FIXTURE"
[ -f "$QUERY_FILE" ] || die "expected-query missing: $QUERY_FILE"
[ -x "$SCRIPT_DIR/body-hash.sh" ] || die "body-hash.sh missing or not executable"
command -v claude >/dev/null 2>&1 || die "claude CLI not on PATH (install Claude Code)"

mkdir -p "$OUTPUT_DIR"

# Step 1: compute the fixture body-hash. This is the ONE canonical hash —
# do not re-implement inline (per CLAUDE.md hard rule).
FIXTURE_HASH="$("$SCRIPT_DIR/body-hash.sh" "$FIXTURE")"
log "fixture body-hash: ${FIXTURE_HASH:0:16}…"

# Step 2: read raw/smoke-source.md's ingested_hash, if present.
get_raw_ingested_hash() {
  if [ ! -f "$RAW" ]; then echo ""; return; fi
  awk -F': ' '/^ingested_hash:/ { val = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); print val; exit }' "$RAW"
}

RAW_HASH_RAW="$(get_raw_ingested_hash || true)"
# Strip optional "sha256:" prefix and surrounding quotes for comparison.
RAW_HASH="${RAW_HASH_RAW#sha256:}"
RAW_HASH="${RAW_HASH#\"}"
RAW_HASH="${RAW_HASH%\"}"

# Step 3: pollution / reset check.
# If raw/ exists but doesn't match the fixture, refuse and explain.
if [ -f "$RAW" ] && [ -n "$RAW_HASH" ] && [ "$RAW_HASH" != "$FIXTURE_HASH" ]; then
  log "raw/smoke-source.md ingested_hash != fixture body-hash"
  log "  raw: $RAW_HASH"
  log "  fix: $FIXTURE_HASH"
  print_reset_instructions
  exit 1
fi

# Step 4: idempotence branch.
# If raw/ matches the fixture, the slow LLM work is done. We may still need
# to redrive the query if last-answer.md is missing.
if [ -f "$RAW" ] && [ "$RAW_HASH" = "$FIXTURE_HASH" ]; then
  if [ -s "$LAST_ANSWER" ]; then
    log "${GREEN}skip${RESET}: raw + last-answer in sync with fixture; nothing to do"
    exit 0
  fi
  log "raw in sync, but last-answer.md missing — redrive query only"
  : > "$BUILD_LOG"
  if ! claude -p "/wiki-query \"$(cat "$QUERY_FILE")\"" \
        > "$LAST_ANSWER" 2>> "$BUILD_LOG"; then
    die "claude -p '/wiki-query …' failed; see $BUILD_LOG"
  fi
  exit 0
fi

# Step 5: clean state. raw/smoke-source.md does NOT exist.
# Capture baseline manifest BEFORE ingest changes wiki/.
if [ -f "$BASELINE" ]; then
  log "baseline manifest already present (stale state without raw/) — refusing"
  print_reset_instructions
  exit 1
fi
log "clean state — capturing baseline manifest"
( ls wiki/*.md 2>/dev/null | sort ) > "$BASELINE"

# Step 6: copy fixture body to raw/ with proper raw-source frontmatter.
# Extract the body of the fixture (everything after the closing `---` of
# its own frontmatter), then prepend canonical raw-source frontmatter with
# ingested_hash left empty (the slash command populates it).
FIXTURE_BODY="$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$FIXTURE")"
TODAY="$(date -u +%Y-%m-%d)"

cat > "$RAW" <<EOF
---
source_url: n/a (local smoke fixture)
source_type: article
source_title: "Phase Coherence Engineering — A Primer"
source_author: "Smoke test fixture (fictional)"
fetched_at: $TODAY
ingested_hash: ""
ingested_at: never
ingested_pages: []
extraction_method: passthrough
notes: |
  This file is the end-to-end smoke fixture for llm-wiki-bootstrap. Body
  copied verbatim from tests/smoke/smoke-source.md by scripts/smoke-build.sh.
  Do not edit the body here — edit the fixture and rerun.
---
$FIXTURE_BODY
EOF

# Sanity check: hashes must agree now (body is identical).
COPIED_HASH="$("$SCRIPT_DIR/body-hash.sh" "$RAW")"
if [ "$COPIED_HASH" != "$FIXTURE_HASH" ]; then
  die "body-hash mismatch after copy (fixture=$FIXTURE_HASH copied=$COPIED_HASH)"
fi
log "raw/smoke-source.md written; body-hash matches fixture"

# Step 7: drive /wiki-ingest then /wiki-query.
: > "$BUILD_LOG"

log "running claude -p '/wiki-ingest raw/smoke-source.md' …"
if ! claude -p "/wiki-ingest raw/smoke-source.md" >> "$BUILD_LOG" 2>&1; then
  die "claude -p '/wiki-ingest …' failed; see $BUILD_LOG"
fi

log "running claude -p '/wiki-query …' …"
if ! claude -p "/wiki-query \"$(cat "$QUERY_FILE")\"" \
      > "$LAST_ANSWER" 2>> "$BUILD_LOG"; then
  die "claude -p '/wiki-query …' failed; see $BUILD_LOG"
fi

log "${GREEN}build complete${RESET}"
log "  raw:         $RAW"
log "  last answer: $LAST_ANSWER"
log "  build log:   $BUILD_LOG"
