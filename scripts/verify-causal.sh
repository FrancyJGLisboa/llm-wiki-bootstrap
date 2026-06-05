#!/usr/bin/env bash
# scripts/verify-causal.sh — deterministic oracle for the causal-relationships
# capability (no LLM, no API key). This is the first half of the /goal condition
# in .scratch/causal-relationships/GOAL.md.
#
# Checks:
#   C2  — wiki-lint-causal: good fixture=0, bad fixture≠0 (3 synonyms named), wiki/=0
#   C3a — wiki-to-kg.py --causal-only: exact frozen tuple set on the good fixture,
#         0 causal triples on the bad fixture (input-sensitivity)
#   C3b — wiki-to-kg.py is stdlib-only (sys.stdlib_module_names)
#   G1  — AGENTS.md schema version stays 2 (no bump)
#   G2  — wiki-ingest.md does NOT auto-emit _kg.jsonl
#   G3  — wiki/, body-hash.sh, eval-common.sh byte-unchanged + no stray sidecars
#
# Exit 0 iff every check passes.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

GOOD="tests/canary/causal-fixture"
BAD="tests/canary/causal-fixture-bad"
KG="scripts/wiki-to-kg.py"
LINT="scripts/wiki-lint-causal.sh"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=; GREEN=; DIM=; RESET=
fi
section() { printf "\n%s== %s ==%s\n" "$DIM" "$1" "$RESET"; }
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; }
failures=0
record_fail() { fail "$1"; failures=$((failures + 1)); }

# ──── C2: causal lint ────
section "C2 — causal lint (good=0, bad≠0 w/ synonyms, wiki/=0)"
if "$LINT" "$GOOD" >/dev/null 2>&1; then ok "good fixture passes"; else record_fail "good fixture should pass"; fi
bad_err=$("$LINT" "$BAD" 2>&1 1>/dev/null); bad_rc=$?
if [ "$bad_rc" -ne 0 ]; then ok "bad fixture rejected (exit $bad_rc)"; else record_fail "bad fixture should be rejected"; fi
for pair in "results-in.*causes" "due-to.*caused-by" "enabled-by.*caused-by"; do
  if printf '%s\n' "$bad_err" | grep -qE "$pair"; then ok "names synonym: $pair"; else record_fail "missing synonym suggestion: $pair"; fi
done
if "$LINT" wiki/ >/dev/null 2>&1; then ok "wiki/ clean"; else record_fail "wiki/ has non-canonical causal verbs"; fi

# ──── C3a: KG exact tuple set + input sensitivity ────
section "C3a — KG materializes exactly the frozen causal tuples"
if python3 - "$KG" "$GOOD" "$BAD" <<'PY'
import json, subprocess, sys
kg, good, bad = sys.argv[1], sys.argv[2], sys.argv[3]
def triples(path):
    out = subprocess.run([sys.executable, kg, "--causal-only", path],
                         capture_output=True, text=True)
    return {(d["source"], d["verb"], d["target"])
            for d in map(json.loads, out.stdout.splitlines())}
want = {("drought", "causes", "yield-drop"),
        ("yield-drop", "causes", "price-spike"),
        ("price-spike", "causes", "export-ban")}
g = triples(good)
b = triples(bad)
if g != want:
    print(f"good fixture tuple set mismatch: {g}", file=sys.stderr); sys.exit(1)
if b:
    print(f"bad fixture should yield 0 causal triples, got {b}", file=sys.stderr); sys.exit(1)
PY
then ok "exact 3-tuple set on good; 0 on bad"; else record_fail "C3a tuple/input-sensitivity check"; fi

# ──── C3b: stdlib-only ────
section "C3b — KG builder is stdlib-only"
if python3 -c "import ast,sys; t=ast.parse(open('$KG').read()); mods={(n.module or '').split('.')[0] for n in ast.walk(t) if isinstance(n,ast.ImportFrom)}|{a.name.split('.')[0] for n in ast.walk(t) if isinstance(n,ast.Import) for a in n.names}; sys.exit(1 if (mods - sys.stdlib_module_names - {''}) else 0)"; then
  ok "no third-party imports"; else record_fail "wiki-to-kg.py imports a non-stdlib module"; fi

# ──── G1: schema unchanged ────
section "G1 — schema version stays 2"
if grep -q '\*\*Schema version:\*\* 2' AGENTS.md && ! grep -q '\*\*Schema version:\*\* 3' AGENTS.md; then
  ok "AGENTS.md schema version is 2"; else record_fail "schema version changed (or not 2)"; fi

# ──── G2: no auto _kg at ingest ────
section "G2 — ingest does not auto-emit _kg.jsonl"
if ! grep -q '_kg.jsonl' .claude/commands/wiki-ingest.md; then ok "wiki-ingest.md has no _kg.jsonl"; else record_fail "wiki-ingest.md references _kg.jsonl (must stay out of the body-hash path)"; fi

# ──── G3: protected content unchanged ────
section "G3 — protected content byte-unchanged"
porcelain=$(git status --porcelain wiki/ scripts/body-hash.sh scripts/lib/eval-common.sh)
if [ -z "$porcelain" ]; then ok "wiki/, body-hash.sh, eval-common.sh clean"; else record_fail "protected files changed: $porcelain"; fi

# ──── summary ────
section "summary"
if [ "$failures" = 0 ]; then ok "verify-causal: all checks passed"; exit 0; else fail "verify-causal: $failures check(s) failed"; exit 1; fi
