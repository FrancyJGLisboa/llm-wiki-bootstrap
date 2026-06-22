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

# --- Regression fixtures (adversarial gaps) -------------------------------
# Each builds its own throwaway wiki/raw so the cases stay isolated.

run_cov() { python3 "$AUDIT" "$1/wiki" --raw "$1/raw" --coverage 2>&1; }

# R1 — FRONTMATTER-CITATION LEAK: a citation in a frontmatter value must NOT
# satisfy coverage while the body stays uncited.
T1="$(mktemp -d "${TMPDIR:-/tmp}/cov1.XXXXXX")"
mkdir -p "$T1/raw" "$T1/wiki"
printf '%s\n' '---' 'title: Src' '---' '# Heading One' 'Evidence.' > "$T1/raw/src.md"
printf '%s\n' '---' 'title: Leak' 'type: concept' 'source: (source: raw/src.md#heading-one)' '---' \
  'A bold body claim with no inline source.' > "$T1/wiki/leak.md"
r1="$(run_cov "$T1")"
printf '%s' "$r1" | grep -q 'leak.md' \
  && ok "frontmatter-citation leak: body still flagged (cite in frontmatter ignored)" \
  || fail "frontmatter-citation leak: a frontmatter citation falsely satisfied coverage"
rm -rf "$T1"

# R2 — UNCLOSED-FENCE SELF-EXEMPT: an author opens `---` + type:navigation and
# never closes it; that must NOT exempt the page.
T2="$(mktemp -d "${TMPDIR:-/tmp}/cov2.XXXXXX")"
mkdir -p "$T2/raw" "$T2/wiki"
printf '%s\n' '---' 'title: Src' '---' '# Heading One' 'Evidence.' > "$T2/raw/src.md"
printf '%s\n' '---' 'type: navigation' 'A claim smuggled under an unclosed fence.' > "$T2/wiki/sneaky.md"
r2="$(run_cov "$T2")"
printf '%s' "$r2" | grep -q 'sneaky.md' \
  && ok "unclosed-fence self-exempt: page flagged (no closing --- → not exempt)" \
  || fail "unclosed-fence self-exempt: an unclosed type:navigation exempted the page"
rm -rf "$T2"

# R3 — ANCHORLESS-ONLY page: a bare whole-file cite `(source: raw/x.md)` must
# NOT earn coverage on its own (needs at least one ANCHORED resolving cite).
T3="$(mktemp -d "${TMPDIR:-/tmp}/cov3.XXXXXX")"
mkdir -p "$T3/raw" "$T3/wiki"
printf '%s\n' '---' 'title: Src' '---' '# Heading One' 'Evidence.' > "$T3/raw/src.md"
printf '%s\n' '---' 'title: Bare' 'type: concept' '---' \
  'A claim resting only on a whole-file cite (source: raw/src.md).' > "$T3/wiki/bare.md"
printf '%s\n' '---' 'title: Anchored' 'type: concept' '---' \
  'A claim with an anchored cite (source: raw/src.md#heading-one).' > "$T3/wiki/anchored.md"
r3="$(run_cov "$T3")"
printf '%s' "$r3" | grep -q 'bare.md' \
  && ok "anchorless-only page: flagged (whole-file cite does not earn coverage)" \
  || fail "anchorless-only page: a bare file cite falsely satisfied coverage"
printf '%s' "$r3" | grep -q '✗ anchored.md' \
  && fail "anchorless fix regressed: an anchored cite was flagged" \
  || ok "anchored cite still earns coverage (anchorless fix is surgical)"
rm -rf "$T3"

# R4 — JOURNAL EXEMPTION: type:journal is user-owned free-form (AGENTS.md) and
# must be exempt like type:navigation.
T4="$(mktemp -d "${TMPDIR:-/tmp}/cov4.XXXXXX")"
mkdir -p "$T4/raw" "$T4/wiki"
printf '%s\n' '---' 'title: Diary' 'type: journal' '---' 'Today I wrote a free-form note.' > "$T4/wiki/diary.md"
r4="$(run_cov "$T4")"; rc4=$?
[ "$rc4" -eq 0 ] && ok "journal exemption: type:journal page is exempt (no claims to cite)" \
                 || fail "journal exemption: a type:journal page was flagged: $r4"
rm -rf "$T4"

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s).\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s Coverage gate flags uncited claims and honors both exemptions.\n" "$GREEN" "$RESET"
exit 0
