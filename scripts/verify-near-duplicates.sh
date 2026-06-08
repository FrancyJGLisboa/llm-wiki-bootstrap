#!/usr/bin/env bash
# scripts/verify-near-duplicates.sh — oracle for the near-duplicate detector.
#
# Asserts scripts/wiki-near-duplicates.py discriminates: it flags a reworded
# pair (same facts, different wording) and does NOT flag a distinct page, and is
# stdlib-only. Intentionally lean (no color/section boilerplate) so it adds no
# cross-file duplication to the quality gate.
#
# Exit 0 iff all checks pass.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

DET="scripts/wiki-near-duplicates.py"
FIX="tests/canary/near-dup-fixture"
fails=0

out="$(python3 "$DET" "$FIX")"

# N1 — the reworded pair is flagged.
if printf '%s\n' "$out" | grep -q 'pronaf-a.md <-> pronaf-b.md'; then
  echo "N1 ok: reworded pair flagged"
else
  echo "N1 FAIL: reworded pair not flagged"; fails=$((fails + 1))
fi

# N2 — the distinct page is not paired with anything.
if printf '%s\n' "$out" | grep -q 'embrapa.md'; then
  echo "N2 FAIL: distinct page flagged as a near-duplicate"; fails=$((fails + 1))
else
  echo "N2 ok: distinct page not flagged"
fi

# N3 — detector is stdlib-only.
if python3 -c "import ast,sys; t=ast.parse(open('$DET').read()); mods={(n.module or '').split('.')[0] for n in ast.walk(t) if isinstance(n,ast.ImportFrom)}|{a.name.split('.')[0] for n in ast.walk(t) if isinstance(n,ast.Import) for a in n.names}; sys.exit(1 if (mods - sys.stdlib_module_names - {''}) else 0)"; then
  echo "N3 ok: detector is stdlib-only"
else
  echo "N3 FAIL: detector imports a non-stdlib module"; fails=$((fails + 1))
fi

if [ "$fails" -eq 0 ]; then
  echo "verify-near-duplicates: all checks passed"; exit 0
fi
echo "verify-near-duplicates: $fails check(s) failed"; exit 1
