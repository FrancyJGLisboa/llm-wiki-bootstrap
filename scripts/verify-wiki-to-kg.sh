#!/usr/bin/env bash
# scripts/verify-wiki-to-kg.sh — deterministic oracle for the KG materializer
# (scripts/wiki-to-kg.py), the shared substrate for connection + causal
# discovery. No agent, no key. Proves:
#
#   K1 exact triples : --causal-only on the good fixture == the frozen causal
#                      DAG (the EXACT (source,verb,target) set, not a count)
#   K2 input-sensitive: --causal-only on the bad fixture (synonyms only) == 0
#                       triples (a constant-output builder fails this)
#   K3 causal ⊂ full : the full graph includes a non-causal `related-to` edge
#                       that --causal-only correctly drops (filter really filters)
#   K4 stdlib-only   : wiki-to-kg.py imports nothing outside the stdlib
#   K5 read-only     : running the builder does not mutate the wiki fixtures
#   K6 causal receipt: every causal edge carries an additive boolean `sourced`;
#                      a causal edge from a page WITH a raw citation is
#                      sourced:true, one from an UNCITED page is sourced:false,
#                      and non-causal (related-to) edges carry no such flag.
#                      This is the receipts gate — an uncited causal assertion
#                      must be distinguishable from a sourced one downstream.
#
# Usage: ./scripts/verify-wiki-to-kg.sh   Exit: 0 all green, 1 a check failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

KG="scripts/wiki-to-kg.py"
GOOD="tests/canary/causal-fixture"
BAD="tests/canary/causal-fixture-bad"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 2; }

# The frozen causal topology the good fixture encodes (source,verb,target).
read -r -d '' FROZEN <<'PY' || true
FROZEN = {
    ("drought", "causes", "crop-failure"),
    ("crop-failure", "causes", "price-spike"),
    ("crop-failure", "caused-by", "drought"),
    ("price-spike", "contributes-to", "export-ban"),
    ("irrigation", "prevents", "crop-failure"),
    ("subsidy", "enables", "irrigation"),
}
PY

# --- K1: exact causal triple set ---------------------------------------------
if python3 - "$KG" "$GOOD" <<PY
import json, subprocess, sys
$FROZEN
kg, good = sys.argv[1], sys.argv[2]
out = subprocess.run([sys.executable, kg, "--causal-only", good],
                     capture_output=True, text=True)
got = {(o["source"], o["verb"], o["target"])
       for o in (json.loads(l) for l in out.stdout.splitlines() if l.strip())}
sys.exit(0 if got == FROZEN else 1)
PY
then ok "K1 --causal-only good fixture == frozen causal DAG (exact set)"
else fail "K1 causal triple set mismatch (run: python3 $KG --causal-only $GOOD)"; fi

# --- K2: input sensitivity (synonyms → 0 causal triples) ---------------------
nbad=$(python3 "$KG" --causal-only "$BAD" | grep -c . || true)
if [ "$nbad" -eq 0 ]; then ok "K2 bad fixture (synonyms only) → 0 causal triples"
else fail "K2 expected 0 causal triples from synonym fixture, got $nbad"; fi

# --- K3: causal ⊂ full (filter really filters) -------------------------------
nfull=$(python3 "$KG" "$GOOD" | grep -c . || true)
ncausal=$(python3 "$KG" --causal-only "$GOOD" | grep -c . || true)
has_relto=$(python3 "$KG" "$GOOD" | grep -c '"verb": "related-to"' || true)
if [ "$nfull" -gt "$ncausal" ] && [ "$has_relto" -ge 1 ]; then
  ok "K3 full graph ($nfull) ⊃ causal ($ncausal); --causal-only drops related-to"
else fail "K3 expected full>causal and ≥1 related-to edge (full=$nfull causal=$ncausal relto=$has_relto)"; fi

# --- K4: stdlib-only ---------------------------------------------------------
if python3 - "$KG" <<'PY'
import ast, sys
t = ast.parse(open(sys.argv[1]).read())
mods = {(n.module or "").split(".")[0] for n in ast.walk(t) if isinstance(n, ast.ImportFrom)}
mods |= {a.name.split(".")[0] for n in ast.walk(t) if isinstance(n, ast.Import) for a in n.names}
extra = mods - set(sys.stdlib_module_names) - {""}
sys.exit(1 if extra else 0)
PY
then ok "K4 wiki-to-kg.py is stdlib-only"
else fail "K4 wiki-to-kg.py imports a non-stdlib module"; fi

# --- K5: read-only (builder does not mutate the wiki fixtures) ---------------
snap() { find "$GOOD" "$BAD" -type f | sort | xargs shasum 2>/dev/null | shasum | awk '{print $1}'; }
before=$(snap)
python3 "$KG" --causal-only "$GOOD" >/dev/null
python3 "$KG" "$GOOD" >/dev/null
python3 "$KG" --causal-only "$BAD" >/dev/null
after=$(snap)
if [ "$before" = "$after" ]; then ok "K5 read-only (fixtures byte-unchanged after build)"
else fail "K5 builder mutated fixture content (read-only violated)"; fi

# --- K6: causal edges carry a receipt flag that discriminates ----------------
# The good fixture's drought.md carries a (source: raw/...) citation; every
# other causal source page is uncited. So drought's causal edge must be
# sourced:true, the rest sourced:false, all causal edges must carry the flag,
# and non-causal related-to edges must NOT carry it.
if python3 - "$KG" "$GOOD" <<'PY'
import json, subprocess, sys
kg, good = sys.argv[1], sys.argv[2]
causal = [json.loads(l) for l in
          subprocess.run([sys.executable, kg, "--causal-only", good],
                         capture_output=True, text=True).stdout.splitlines() if l.strip()]
full = [json.loads(l) for l in
        subprocess.run([sys.executable, kg, good],
                       capture_output=True, text=True).stdout.splitlines() if l.strip()]
# Every causal edge carries the boolean flag.
if not all("sourced" in e and isinstance(e["sourced"], bool) for e in causal):
    sys.exit(1)
# The cited page (drought) is sourced:true; at least one uncited page is false.
by_src = {(e["source"], e["verb"], e["target"]): e["sourced"] for e in causal}
if by_src.get(("drought", "causes", "crop-failure")) is not True:
    sys.exit(1)
if not any(v is False for v in by_src.values()):
    sys.exit(1)
# Non-causal related-to edges must NOT carry the flag (additive, causal-only).
relto = [e for e in full if e["verb"] == "related-to"]
if not relto or any("sourced" in e for e in relto):
    sys.exit(1)
sys.exit(0)
PY
then ok "K6 causal edges carry sourced flag (cited→true, uncited→false); related-to unflagged"
else fail "K6 causal receipt flag missing/wrong (run: python3 $KG --causal-only $GOOD)"; fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d KG-materializer check(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s K1-K6 green — KG materializer is exact, input-sensitive, stdlib-only, read-only, receipt-flagged.\n" "$GREEN" "$RESET"
exit 0
