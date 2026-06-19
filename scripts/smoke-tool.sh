#!/usr/bin/env bash
# scripts/smoke-tool.sh — tool-agnostic e2e smoke for the BYO-agent claim.
#
# Drives ONE agentic-coding CLI through the core loop — ingest a known fixture,
# then query the fact back — in a throwaway wiki, and asserts the agent actually
# (a) authored a wiki page citing the raw source and (b) recalled the planted
# fact. This is how a "documented, not e2e-verified" tool earns "verified":
# run it green on your machine.
#
#   ./scripts/smoke-tool.sh <claude|codex|gemini|copilot>
#
# Exit: 0 verified · 1 failed (tool ran but loop broke) · 3 skipped (CLI absent).
#
# The per-tool headless invocation is a REGISTRY below. claude is the validated
# reference; the others are best-effort templates (the prompt is natural-language
# and references AGENTS.md + .claude/commands, which every shim points to) — if a
# CLI's flags differ on your version, fix the one line in the registry.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

tool="${1:-}"
[ -n "$tool" ] || { echo "usage: smoke-tool.sh <claude|codex|gemini|copilot>" >&2; exit 2; }

# ── Registry: how to run a one-shot headless prompt with each CLI ──
# RUN is an array; the prompt is appended as the final argument.
case "$tool" in
  claude)  RUN=(claude -p) ;;                 # validated reference
  codex)   RUN=(codex exec) ;;                # best-effort
  gemini)  RUN=(gemini -p) ;;                 # best-effort
  copilot) RUN=(copilot -p) ;;               # best-effort
  *) echo "unknown tool: $tool" >&2; exit 2 ;;
esac

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'; else RED=; GREEN=; YEL=; DIM=; RESET=; fi
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
bad()  { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }
log()  { printf "%s[smoke-tool:%s]%s %s\n" "$DIM" "$tool" "$RESET" "$1" >&2; }
failures=0

if ! command -v "$tool" >/dev/null 2>&1; then
  printf "%sSKIP%s %s CLI not installed. Install + authenticate it, then re-run to verify this tool.\n" "$YEL" "$RESET" "$tool"
  exit 3
fi
command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 2; }
FIX="$REPO_ROOT/tests/smoke-tool/source.md"
[ -f "$FIX" ] || { echo "fixture missing: $FIX" >&2; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/raw" "$WORK/wiki/journal"
cp -r "$REPO_ROOT/.claude" "$WORK/"; cp "$REPO_ROOT/AGENTS.md" "$WORK/"
cp -r "$REPO_ROOT/scripts" "$WORK/"; cp -r "$REPO_ROOT/templates" "$WORK/"
printf '# index\n\n' > "$WORK/wiki/index.md"; printf '# log.md\n\n' > "$WORK/log.md"
cp "$FIX" "$WORK/raw/borealis.md"

# Drive each tool by its BEST invocation: claude has real slash commands; the
# others invoke the same workflows by natural language (per their shims).
if [ "$tool" = claude ]; then
  INGEST='/wiki-ingest raw/borealis.md'
  QUERY='/wiki-query "what did the Borealis composite index close at in the 2029 review?"'
else
  INGEST="Ingest raw/borealis.md into this wiki by following the procedure in .claude/commands/wiki-ingest.md and AGENTS.md: write the summary + concept pages with (source: raw/borealis.md#...) citations and update wiki/index.md. Do the work; don't just describe it."
  QUERY="Following .claude/commands/wiki-query.md, answer from this wiki only: what did the Borealis composite index close at in the 2029 review? Cite the source page."
fi

log "ingest via: ${RUN[*]} \"<prompt>\""
( cd "$WORK" && "${RUN[@]}" "$INGEST" ) > "$WORK/ingest.log" 2>&1 \
  || { log "ingest invocation returned non-zero (see ingest.log)"; }

# T1 — agent authored a wiki page that cites the raw source AND carries the fact
if grep -rl '4417' "$WORK/wiki/" 2>/dev/null | xargs grep -lF 'raw/borealis.md' 2>/dev/null | grep -q .; then
  ok "T1 ingest: a wiki page carries the fact (4417) and cites raw/borealis.md"
else
  bad "T1 ingest: no wiki page with the fact + citation (agent didn't complete the loop)"
fi

# Remove the raw source before querying: a true answer must now come from the
# WIKI the agent built, not from re-reading the file.
rm -f "$WORK/raw/borealis.md"

log "query via: ${RUN[*]} \"<prompt>\""
( cd "$WORK" && "${RUN[@]}" "$QUERY" ) > "$WORK/answer.txt" 2>"$WORK/query.log" \
  || { log "query invocation returned non-zero (see query.log)"; }

# T2 — the answer recalls the planted fact (un-hand-authorable)
if grep -qF '4417' "$WORK/answer.txt"; then
  ok "T2 query: answer recalls the planted fact (4417)"
else
  bad "T2 query: answer missing the planted fact — see answer.txt"
fi

if [ "$failures" -ne 0 ]; then
  KEEP="$REPO_ROOT/tests/smoke-tool/last-$tool"; mkdir -p "$KEEP"
  cp -rf "$WORK/wiki" "$KEEP/" 2>/dev/null || true
  cp -f "$WORK/answer.txt" "$WORK/ingest.log" "$KEEP/" 2>/dev/null || true
  log "artifacts copied to tests/smoke-tool/last-$tool/"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %s ran but the extract→ingest→query loop broke (%d check(s)).\n" "$RED" "$RESET" "$tool" "$failures"; exit 1
fi
printf "%sVerified.%s %s drove ingest→query end-to-end — this tool earns an e2e-verified row.\n" "$GREEN" "$RESET" "$tool"
exit 0
