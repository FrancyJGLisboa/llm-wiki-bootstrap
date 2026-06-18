#!/usr/bin/env bash
# scripts/verify-graph-walk.sh — deterministic floor for causal/connection
# traversal (wiki-graph-walk.py over wiki-to-kg.py). No agent, no key — this is
# the reframed C5 "traversal-correctness" floor: the runtime path answers the
# sealed questions correctly without claude.
#
#   W1 causes-of : upstream causal chain of a terminal effect (multi-hop)
#   W2 effects-of: downstream causal chain of a root cause (multi-hop)
#   W3 path      : connection path across a NEGATIVE (prevents) edge (undirected)
#   W4 stdlib-only
#
# Usage: ./scripts/verify-graph-walk.sh   Exit: 0 all green, 1 a check failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

KG="scripts/wiki-to-kg.py"
WALK="scripts/wiki-graph-walk.py"
GOOD="tests/canary/causal-fixture"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

causal() { python3 "$KG" --causal-only "$GOOD"; }   # causal subgraph
full()   { python3 "$KG" "$GOOD"; }                 # full graph (for --path)

# W1 — what ultimately caused export-ban? expect drought → crop-failure → price-spike → export-ban
w1=$(causal | python3 "$WALK" --causes-of export-ban)
if grep -q 'drought → crop-failure → price-spike → export-ban' <<<"$w1"; then
  ok "W1 causes-of export-ban: $w1"
else fail "W1 wrong causal chain: $w1"; fi

# W2 — what does drought cause downstream? expect drought → crop-failure → price-spike → export-ban
w2=$(causal | python3 "$WALK" --effects-of drought)
if grep -q 'drought → crop-failure → price-spike → export-ban' <<<"$w2"; then
  ok "W2 effects-of drought: $w2"
else fail "W2 wrong effect chain: $w2"; fi

# W3 — connection from subsidy to crop-failure crosses the negative prevents edge
#      (subsidy enables irrigation; irrigation prevents crop-failure) → undirected path
w3=$(full | python3 "$WALK" --path subsidy crop-failure)
if grep -q 'subsidy → irrigation → crop-failure' <<<"$w3"; then
  ok "W3 path subsidy↔crop-failure: $w3"
else fail "W3 wrong/absent path: $w3"; fi

# W4 — stdlib-only
if python3 - "$WALK" <<'PY'
import ast, sys
t = ast.parse(open(sys.argv[1]).read())
mods = {(n.module or "").split(".")[0] for n in ast.walk(t) if isinstance(n, ast.ImportFrom)}
mods |= {a.name.split(".")[0] for n in ast.walk(t) if isinstance(n, ast.Import) for a in n.names}
sys.exit(1 if (mods - set(sys.stdlib_module_names) - {""}) else 0)
PY
then ok "W4 wiki-graph-walk.py is stdlib-only"
else fail "W4 wiki-graph-walk.py imports a non-stdlib module"; fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d graph-walk check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s W1-W4 green — causal chains + connection paths traverse correctly (no LLM).\n" "$GREEN" "$RESET"
exit 0
