#!/usr/bin/env bash
# scripts/verify-body-hash.sh — assert body-hash.sh's frontmatter validation.
#
# body-hash.sh is the ONE canonical hash for `ingested_hash`. A raw file with
# malformed frontmatter (missing the closing ---) must FAIL CLOSED, not return
# the empty-string SHA — otherwise /wiki-ingest stamps a placeholder hash and
# idempotence silently skips the file forever (lost content). This verifier
# pins that behavior against the fixtures in tests/canary/frontmatter-fixture/.
#
# Self-contained: no LLM, no network. Exit 0 iff every assertion holds.
#
# Usage:
#   ./scripts/verify-body-hash.sh
#
# Exit codes:
#   0 — all assertions passed
#   1 — at least one assertion failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

BODY_HASH="$SCRIPT_DIR/body-hash.sh"
FIXTURE_DIR="tests/canary/frontmatter-fixture"
EMPTY_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  RED=; GREEN=; RESET=
fi

failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

[ -x "$BODY_HASH" ] || { fail "body-hash.sh missing or not executable"; exit 1; }

# 1. good.md → exit 0, non-empty hash that is NOT the empty-string SHA.
if hash_out="$("$BODY_HASH" "$FIXTURE_DIR/good.md" 2>/dev/null)"; then
  if [ -n "$hash_out" ] && [ "$hash_out" != "$EMPTY_SHA" ]; then
    ok "good.md → valid hash ${hash_out:0:16}…"
  else
    fail "good.md → unexpected empty/placeholder hash '$hash_out'"
  fi
else
  fail "good.md → exited non-zero (expected 0)"
fi

# 2. good-with-hr.md → exit 0, non-empty hash (body --- horizontal rule allowed).
if hash_out="$("$BODY_HASH" "$FIXTURE_DIR/good-with-hr.md" 2>/dev/null)"; then
  if [ -n "$hash_out" ] && [ "$hash_out" != "$EMPTY_SHA" ]; then
    ok "good-with-hr.md → valid hash (HR rule did not trip the guard)"
  else
    fail "good-with-hr.md → unexpected empty/placeholder hash '$hash_out'"
  fi
else
  fail "good-with-hr.md → exited non-zero (HR rule wrongly rejected)"
fi

# 3. malformed-no-close.md → exit 1, stderr mentions 'malformed frontmatter'.
if err_out="$("$BODY_HASH" "$FIXTURE_DIR/malformed-no-close.md" 2>&1)"; then
  fail "malformed-no-close.md → exited 0 (expected 1 — silent-data-loss bug!)"
else
  if printf '%s' "$err_out" | grep -q "malformed frontmatter"; then
    ok "malformed-no-close.md → exit 1 with 'malformed frontmatter' message"
  else
    fail "malformed-no-close.md → exit 1 but message lacked 'malformed frontmatter': $err_out"
  fi
fi

# 4. no-frontmatter.md → exit 1.
if "$BODY_HASH" "$FIXTURE_DIR/no-frontmatter.md" >/dev/null 2>&1; then
  fail "no-frontmatter.md → exited 0 (expected 1)"
else
  ok "no-frontmatter.md → exit 1"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d assertion(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s body-hash.sh frontmatter validation is correct.\n" "$GREEN" "$RESET"
exit 0
