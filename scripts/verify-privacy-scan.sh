#!/usr/bin/env bash
# scripts/verify-privacy-scan.sh — deterministic oracle for the shared-brain
# privacy guard (no LLM, no API key). Proves the guard is genuinely fail-closed
# at the runtime chokepoint, not merely that the scanner works in isolation.
#
# Checks:
#   P1 — scanner (forced --shared): clean fixture=0, dirty fixture≠0
#   P2 — dirty fixture names all three categories (preference / email / secret)
#   P3 — auto-detect via SKILL.md: shared brain blocks dirty; per-user no-ops (0)
#   P4 — pre-commit HOOK end-to-end: a shared brain refuses a dirty commit and
#        accepts a clean one; `--no-verify` overrides (tested-path == runtime-path)
#   P5 — scaffolder SHIPS the guard: a generated wiki has executable
#        scripts/privacy-scan.sh + scripts/hooks/pre-commit and core.hooksPath set
#
# Exit 0 iff every check passes.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

SCAN="scripts/privacy-scan.sh"
HOOK="scripts/hooks/pre-commit"
CLEAN="tests/canary/privacy-fixture/clean.md"
DIRTY="tests/canary/privacy-fixture/dirty.md"

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

tmps=()
cleanup() { for d in "${tmps[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT
mktmp() { local d; d="$(mktemp -d)"; tmps+=("$d"); printf '%s' "$d"; }

# ──── P1: scanner discriminates (forced --shared) ────
section "P1 — scanner: clean=0, dirty≠0 (forced --shared)"
if "$SCAN" "$CLEAN" --shared >/dev/null 2>&1; then ok "clean fixture passes"; else record_fail "clean fixture should pass"; fi
dirty_err=$("$SCAN" "$DIRTY" --shared 2>&1 1>/dev/null); dirty_rc=$?
if [ "$dirty_rc" -ne 0 ]; then ok "dirty fixture rejected (exit $dirty_rc)"; else record_fail "dirty fixture should be rejected"; fi

# ──── P2: all three categories named ────
section "P2 — dirty fixture names preference / email / secret"
for pair in "preference-tagged" "email address" "secret/credential"; do
  if printf '%s\n' "$dirty_err" | grep -qF "$pair"; then ok "names category: $pair"; else record_fail "missing category: $pair"; fi
done

# ──── P3: auto-detect via SKILL.md ────
section "P3 — auto-detect: shared blocks, per-user no-ops"
d="$(mktmp)"
mkdir -p "$d/wiki"
cp "$DIRTY" "$d/wiki/dirty.md"
printf 'Scope: **shared**.\n' > "$d/SKILL.md"
if ! "$SCAN" --wiki-root "$d" "$d/wiki" >/dev/null 2>&1; then ok "shared SKILL.md → dirty blocked"; else record_fail "shared SKILL.md should block dirty"; fi
printf 'Scope: **per-user**.\n' > "$d/SKILL.md"
if "$SCAN" --wiki-root "$d" "$d/wiki" >/dev/null 2>&1; then ok "per-user SKILL.md → no-op pass"; else record_fail "per-user SKILL.md should no-op (exit 0)"; fi

# ──── P4: pre-commit hook end-to-end ────
section "P4 — pre-commit hook: shared brain blocks dirty, accepts clean"
g="$(mktmp)"
mkdir -p "$g/scripts/hooks" "$g/wiki"
cp "$SCAN" "$g/scripts/privacy-scan.sh"; chmod +x "$g/scripts/privacy-scan.sh"
cp "$HOOK" "$g/scripts/hooks/pre-commit"; chmod +x "$g/scripts/hooks/pre-commit"
printf 'Scope: **shared**.\n' > "$g/SKILL.md"
(
  cd "$g"
  git init -q
  git config core.hooksPath scripts/hooks
  git config user.email "test@example.com"
  git config user.name "Test"
)
git_c() { git -C "$g" -c commit.gpgsign=false "$@"; }

# dirty staged → commit must be refused by the hook
cp "$DIRTY" "$g/wiki/page.md"
git -C "$g" add -A
if git_c commit -q -m "should be blocked" >/dev/null 2>&1; then
  record_fail "hook allowed a dirty commit (privacy leak)"
else
  ok "hook refused dirty commit"
fi
# --no-verify overrides the hook (deliberate user override)
if git_c commit -q --no-verify -m "override" >/dev/null 2>&1; then ok "--no-verify overrides the hook"; else record_fail "--no-verify should bypass the hook"; fi

# clean content → commit must succeed
g2="$(mktmp)"
mkdir -p "$g2/scripts/hooks" "$g2/wiki"
cp "$SCAN" "$g2/scripts/privacy-scan.sh"; chmod +x "$g2/scripts/privacy-scan.sh"
cp "$HOOK" "$g2/scripts/hooks/pre-commit"; chmod +x "$g2/scripts/hooks/pre-commit"
printf 'Scope: **shared**.\n' > "$g2/SKILL.md"
cp "$CLEAN" "$g2/wiki/page.md"
(
  cd "$g2"
  git init -q
  git config core.hooksPath scripts/hooks
  git config user.email "test@example.com"
  git config user.name "Test"
  git add -A
)
if git -C "$g2" -c commit.gpgsign=false commit -q -m "clean" >/dev/null 2>&1; then ok "hook accepts a clean commit"; else record_fail "hook wrongly blocked a clean commit"; fi

# ──── P5: scaffolder ships + wires the guard ────
section "P5 — generated wiki ships scanner + hook + core.hooksPath"
t="$(mktmp)"; tgt="$t/freshrepo"
if ./scripts/create-llm-wiki.sh "$tgt" >/dev/null 2>&1; then
  [ -x "$tgt/scripts/privacy-scan.sh" ] && ok "ships executable scripts/privacy-scan.sh" || record_fail "missing/!exec scripts/privacy-scan.sh in target"
  [ -x "$tgt/scripts/hooks/pre-commit" ] && ok "ships executable scripts/hooks/pre-commit" || record_fail "missing/!exec scripts/hooks/pre-commit in target"
  hp="$(git -C "$tgt" config --local core.hooksPath || true)"
  [ "$hp" = "scripts/hooks" ] && ok "target core.hooksPath = scripts/hooks" || record_fail "target core.hooksPath is '$hp' (want scripts/hooks)"
else
  record_fail "create-llm-wiki.sh failed to scaffold target"
fi

# ──── summary ────
section "summary"
if [ "$failures" = 0 ]; then ok "verify-privacy-scan: all checks passed"; exit 0; else fail "verify-privacy-scan: $failures check(s) failed"; exit 1; fi
