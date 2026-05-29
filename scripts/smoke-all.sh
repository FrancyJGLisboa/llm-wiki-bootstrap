#!/usr/bin/env bash
# scripts/smoke-all.sh — umbrella verifier for the end-to-end smoke.
#
# Composes the build phase (LLM-driven, idempotent), the smoke checks
# (C1–C5), and the regression guards (R1–R5) into a single exit-code-
# driven test. This script IS the /goal completion condition for
# .scratch/plug-and-play-curator-smoke/GOAL.md.
#
# Exit 0 iff all 10 checks pass.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

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

# ──── BUILD PHASE ────
section "Build phase (LLM, idempotent)"
if ! "$SCRIPT_DIR/smoke-build.sh"; then
  record_fail "smoke-build.sh failed (see tests/smoke/output/build.log)"
  printf "\n%sAborting: build phase did not complete.%s\n" "$RED" "$RESET"
  exit 1
fi

# ──── SMOKE CHECKS C1–C5 ────
section "Smoke checks (C1–C5)"
if ! "$SCRIPT_DIR/smoke-check.sh"; then
  record_fail "smoke-check.sh reported one or more C1–C5 failures"
fi

# ──── REGRESSION GUARDS R1–R5 ────
section "Regression guards (R1–R5)"

# R1 — preflight stays green
if "$SCRIPT_DIR/preflight.sh" >/dev/null 2>&1; then
  ok "R1 preflight.sh exits 0"
else
  record_fail "R1 preflight.sh exits non-zero (baseline regression)"
fi

# R2 — anki verifier stays green
if "$SCRIPT_DIR/verify-wiki-to-anki.sh" >/dev/null 2>&1; then
  ok "R2 verify-wiki-to-anki.sh exits 0"
else
  record_fail "R2 verify-wiki-to-anki.sh exits non-zero (baseline regression)"
fi

# R3 — no Obsidian-flavored markdown in non-smoke content
# Patterns live in scripts/r3-obsidian-patterns.txt (avoids shell-quoting
# hazards from inlining backticked regexes).
R3_HITS="$(grep -rE -f "$SCRIPT_DIR/r3-obsidian-patterns.txt" \
            wiki/ tests/canary/ templates/ docs/ 2>/dev/null || true)"
if [ -z "$R3_HITS" ]; then
  ok "R3 no Obsidian-flavored markdown in wiki/ tests/canary/ templates/ docs/"
else
  record_fail "R3 found Obsidian-flavored markdown:"
  printf '%s\n' "$R3_HITS" | sed 's/^/    /'
fi

# R4 — schema and core-script purity stay stable
r4_ok=yes
if ! grep -q '\*\*Schema version:\*\* 2' AGENTS.md; then
  r4_ok=no
  record_fail "R4 AGENTS.md schema version is not 2"
fi
if ! grep -qE '^- .type. — .concept.*entity.*summary.*analysis.*navigation.*journal' AGENTS.md; then
  r4_ok=no
  record_fail "R4 type enum line in AGENTS.md missing one or more expected values"
fi
for f in scripts/body-hash.sh scripts/preflight.sh scripts/verify-extract.sh \
         scripts/verify-wiki-to-anki.sh scripts/wiki-to-anki.sh; do
  if ! head -1 "$f" | grep -q '^#!/usr/bin/env bash'; then
    r4_ok=no
    record_fail "R4 core script $f does not start with '#!/usr/bin/env bash'"
  fi
done
if [ "$r4_ok" = yes ]; then
  ok "R4 schema version + type enum + core-script shebangs intact"
fi

# R5 — multi-wiki factory deterministic oracle (M1–M3) stays green
if "$SCRIPT_DIR/verify-multi-wiki.sh" >/dev/null 2>&1; then
  ok "R5 verify-multi-wiki.sh (factory M1–M3) exits 0"
else
  record_fail "R5 verify-multi-wiki.sh exits non-zero (factory regression)"
fi

# ──── SUMMARY ────
section "Summary"
if [ "$failures" -eq 0 ]; then
  printf "%sAll 10 checks green.%s\n" "$GREEN" "$RESET"
  exit 0
fi
printf "%s%d check(s) failed.%s See diagnostics above.\n" "$RED" "$failures" "$RESET"
exit 1
