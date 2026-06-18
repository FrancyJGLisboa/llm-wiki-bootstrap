#!/usr/bin/env bash
# scripts/verify-discover.sh — deterministic oracle for wiki-discover.py. No key.
#
#   D1 chains : the report surfaces the multi-hop causal chain
#   D2 hubs   : the most-connected concept is identified
#   D3 bridge : the widest-connection (diameter) path spans the graph (≥4 hops)
#   D4 stdlib-only
#
# Usage: ./scripts/verify-discover.sh   Exit: 0 all green, 1 a check failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

KG="scripts/wiki-to-kg.py"
DISC="scripts/wiki-discover.py"
GOOD="tests/canary/causal-fixture"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

REPORT=$(python3 "$KG" "$GOOD" | python3 "$DISC")

# D1 — multi-hop causal chain present
if grep -q 'drought → crop-failure → price-spike → export-ban' <<<"$REPORT"; then
  ok "D1 causal chain surfaced"
else fail "D1 causal chain missing from report"; fi

# D2 — crop-failure is the (or a) top hub (degree 3 in the fixture)
if grep -A6 '## Most-connected' <<<"$REPORT" | grep -q 'crop-failure'; then
  ok "D2 most-connected concept identified (crop-failure)"
else fail "D2 hub crop-failure not surfaced"; fi

# D3 — widest connection spans the graph (≥4 hops = ≥5 nodes on the path)
wide=$(grep -A2 '## Widest connection' <<<"$REPORT" | grep '→' | head -1)
hops=$(grep -oE '[0-9]+ hops apart' <<<"$wide" | grep -oE '[0-9]+' || echo 0)
if [ "${hops:-0}" -ge 4 ]; then ok "D3 widest connection bridges $hops hops: ${wide#- }"
else fail "D3 widest connection too short (hops=${hops:-?})"; fi

# D4 — stdlib-only
if python3 - "$DISC" <<'PY'
import ast, sys
t = ast.parse(open(sys.argv[1]).read())
mods = {(n.module or "").split(".")[0] for n in ast.walk(t) if isinstance(n, ast.ImportFrom)}
mods |= {a.name.split(".")[0] for n in ast.walk(t) if isinstance(n, ast.Import) for a in n.names}
sys.exit(1 if (mods - set(sys.stdlib_module_names) - {""}) else 0)
PY
then ok "D4 wiki-discover.py is stdlib-only"
else fail "D4 wiki-discover.py imports a non-stdlib module"; fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d discovery check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s D1-D4 green — discovery surfaces chains, hubs, and the widest bridge.\n" "$GREEN" "$RESET"
exit 0
