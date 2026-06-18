#!/usr/bin/env bash
# scripts/smoke-causal.sh — LLM-gated acceptance for causal authoring (slice 4).
#
# Scaffolds a THROWAWAY wiki, drives `claude -p /wiki-ingest` on a source with an
# explicit causal chain, and asserts the agent ENCODED cause→effect as canonical
# causal edges that actually traverse:
#
#   A1 author : ≥1 produced wiki page has a canonical causal `## Related` edge
#               (causes|caused-by|enables|prevents|contributes-to), not related-to
#   A2 clean  : wiki-lint-causal passes on the produced wiki (no synonyms authored)
#   A3 traverse (the payoff, deterministic): the causal KG built from the agent's
#               OWN wiki contains a ≥2-hop causal chain (multi-hop, not one lump)
#
# Needs the `claude` CLI + python3. Exit 0 iff A1-A3 pass. Never touches the repo.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; RESET=$'\033[0m'; else RED=; GREEN=; DIM=; RESET=; fi
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }
log()  { printf "%s[smoke-causal]%s %s\n" "$DIM" "$RESET" "$1" >&2; }
failures=0

command -v claude  >/dev/null 2>&1 || { echo "claude CLI not on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 2; }
FIX="$REPO_ROOT/tests/causal-ingest/source.md"
[ -f "$FIX" ] || { echo "fixture missing: $FIX" >&2; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/raw" "$WORK/wiki/journal"
cp -r "$REPO_ROOT/.claude" "$WORK/"
cp "$REPO_ROOT/AGENTS.md" "$WORK/"
cp -r "$REPO_ROOT/scripts" "$WORK/"
cp -r "$REPO_ROOT/templates" "$WORK/"
printf '# index\n\n' > "$WORK/wiki/index.md"
printf '# log.md\n\n'  > "$WORK/log.md"
cp "$FIX" "$WORK/raw/causal-source.md"

log "claude -p /wiki-ingest …"
( cd "$WORK" && claude -p "/wiki-ingest raw/causal-source.md" ) > "$WORK/ingest.log" 2>&1 \
  || { echo "ingest run failed; tail:" >&2; tail -20 "$WORK/ingest.log" >&2; }

CANON='^- \[\[[a-z0-9-]+\]\] (causes|caused-by|enables|prevents|contributes-to)( |$)'

# A1 — at least one canonical causal edge authored
if grep -rEl "$CANON" "$WORK/wiki/" >/dev/null 2>&1; then
  n=$(grep -rEh "$CANON" "$WORK/wiki/" | wc -l | tr -d ' ')
  ok "A1 agent authored $n canonical causal edge(s)"
else
  fail "A1 no canonical causal edge in produced wiki (agent flattened cause→effect)"
fi

# A2 — produced wiki passes the causal lint (no synonyms slipped in)
if ( cd "$WORK" && ./scripts/wiki-lint-causal.sh wiki/ ) >/dev/null 2>&1; then
  ok "A2 produced wiki passes wiki-lint-causal (canonical verbs only)"
else
  fail "A2 produced wiki has non-canonical causal synonyms"
fi

# A3 — the agent's own wiki materializes a ≥2-hop causal chain
python3 "$REPO_ROOT/scripts/wiki-to-kg.py" --causal-only "$WORK/wiki" > "$WORK/kg.jsonl" 2>/dev/null
hops=$(python3 - "$WORK/kg.jsonl" <<'PY'
import json, sys
from collections import defaultdict
FWD={"causes","contributes-to","enables"}; REV={"caused-by"}
fwd=defaultdict(set)
for ln in open(sys.argv[1]):
    ln=ln.strip()
    if not ln: continue
    o=json.loads(ln); s,v,t=o["source"],o["verb"],o["target"]
    if v in FWD: fwd[s].add(t)
    elif v in REV: fwd[t].add(s)
# longest path length (#nodes) in the cause→effect DAG, cycle-safe
best=1
def dfs(n,seen):
    global best
    seen=seen|{n}; best=max(best,len(seen))
    for m in fwd.get(n,()):
        if m not in seen: dfs(m,seen)
for n in list(fwd): dfs(n,set())
print(best)
PY
)
if [ "${hops:-0}" -ge 3 ]; then
  ok "A3 causal KG from agent wiki has a ≥2-hop chain (longest = $hops nodes)"
else
  fail "A3 no multi-hop causal chain materialized (longest = ${hops:-?} nodes)"
fi

# Keep artifacts on failure.
if [ "$failures" -ne 0 ]; then
  KEEP="$REPO_ROOT/tests/causal-ingest/last-smoke"; mkdir -p "$KEEP"
  cp -rf "$WORK/wiki" "$KEEP/" 2>/dev/null || true
  cp -f "$WORK/kg.jsonl" "$WORK/ingest.log" "$KEEP/" 2>/dev/null || true
  log "artifacts copied to tests/causal-ingest/last-smoke/"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d causal-authoring check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s A1-A3 green — agent encodes canonical causal edges that traverse multi-hop.\n" "$GREEN" "$RESET"
exit 0
