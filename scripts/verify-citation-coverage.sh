#!/usr/bin/env bash
# scripts/verify-citation-coverage.sh — assert the --coverage gate (vision
# check #5) flags claim-bearing pages with no resolving citation, and exempts
# the two ways a page may legitimately carry none:
#   type: navigation   — structural pages (index/dashboard) point inward
#   provenance: none   — explicit "this page makes no external claims" knob
#
# Builds a throwaway wiki with four pages and asserts the gate flags exactly
# the uncited claim page. Exit 0 iff the gate behaves correctly.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/citation-audit.py"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

command -v python3 >/dev/null 2>&1 || { fail "python3 required"; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/cov.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/raw" "$TMP/wiki"

printf '%s\n' '---' 'title: Src' '---' '# Heading One' 'Some evidence text here.' > "$TMP/raw/src.md"
printf '%s\n' '---' 'title: Cited' 'type: concept' '---' 'A claim with provenance (source: raw/src.md#heading-one).' > "$TMP/wiki/cited.md"
printf '%s\n' '---' 'title: Uncited' 'type: concept' '---' 'A bold claim with no source whatsoever.' > "$TMP/wiki/uncited.md"
printf '%s\n' '---' 'title: Index' 'type: navigation' '---' 'Links: [[cited]] [[uncited]].' > "$TMP/wiki/nav.md"
printf '%s\n' '---' 'title: Meta' 'type: concept' 'provenance: none' '---' 'Project design note, no external claims.' > "$TMP/wiki/meta.md"

report="$(python3 "$AUDIT" "$TMP/wiki" --raw "$TMP/raw" --coverage 2>&1)"; rc=$?

[ "$rc" -ne 0 ] && ok "gate exits non-zero (an uncited claim page exists)" \
                || fail "gate exited 0 — uncited claim page not detected"

printf '%s' "$report" | grep -q 'uncited.md' \
  && ok "flags the uncited claim page" \
  || fail "did not flag uncited.md"

if printf '%s' "$report" | grep -qE '✗ (cited|nav|meta)\.md'; then
  fail "false positive: a cited / navigation / provenance:none page was flagged"
else
  ok "exempts cited page, type:navigation, and provenance:none — no false positives"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s).\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s Coverage gate flags uncited claims and honors both exemptions.\n" "$GREEN" "$RESET"
exit 0
