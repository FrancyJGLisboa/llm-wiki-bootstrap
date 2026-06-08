#!/usr/bin/env bash
# scripts/quality.sh — fallow-equivalent maintainability gate for THIS repo.
#
# fallow (npm) is TypeScript/JavaScript-only; fallow-py is Python-only. This
# repo is ~31 shell scripts + ~131 markdown files + 3 standalone .py — so
# neither sees anything here. This runner aims the same three fallow checks
# (lint, duplication, dead files) at the languages the repo is actually
# written in:
#
#   1. shellcheck   — shell correctness/lint on every tracked *.sh
#   2. jscpd        — cross-file copy-paste detection over scripts/ (shell+py)
#   3. dead-script  — scripts/ entries referenced by nothing else (advisory)
#
# Markdown health (broken links, orphans, contradictions) is already covered
# by /wiki-lint and is intentionally NOT duplicated here.
#
# Exit 0 iff shellcheck (gate 1) and jscpd (gate 2) both pass. The dead-script
# scan is advisory: it reports candidates but does not fail the build, because
# interactive-only entrypoints produce unavoidable false positives.
#
# --ci : skip the local shellcheck step (CI runs shellcheck via the GitHub
#   action for inline annotations); still runs jscpd + dead-script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

CI=0
[ "${1:-}" = "--ci" ] && CI=1

# jscpd is version-PINNED. `npx --yes jscpd` (unpinned) silently tracks the latest
# release, and jscpd's clone-counting changes between majors — so an unpinned gate
# drifts under you (5.0.4 measures ~2.9% where an older jscpd measured ~2.2% on the
# same tree). Pinning makes the metric reproducible; bump deliberately, re-baseline
# the threshold alongside.
JSCPD_VERSION="${JSCPD_VERSION:-5.0.4}"

# Duplication ceiling — scoped to scripts/ (code only; markdown commands are
# 0%-duplicated and owned by /wiki-lint, and would only dilute the metric).
# 2.5% under the pinned jscpd@5.0.4 (measured ~1.9% after the cut-to-core trim
# removed the factory/brain/causal scripts and their sibling oracles). The
# remaining duplication is the accepted per-verify-script reporting boilerplate.
JSCPD_THRESHOLD="${JSCPD_THRESHOLD:-2.5}"
JSCPD_MIN_TOKENS="${JSCPD_MIN_TOKENS:-50}"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=; GREEN=; YELLOW=; DIM=; RESET=
fi

section() { printf "\n%s== %s ==%s\n" "$DIM" "$1" "$RESET"; }
ok()   { printf "%s✓%s %s\n" "$GREEN"  "$RESET" "$1"; }
warn() { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"    "$RESET" "$1"; }

failures=0
record_fail() { fail "$1"; failures=$((failures + 1)); }

# ──── GATE 1: shellcheck ────
if [ "$CI" = 1 ]; then
  section "shellcheck (skipped: --ci, run by GitHub action)"
else
  section "shellcheck (--severity=error)"
  if ! command -v shellcheck >/dev/null 2>&1; then
    record_fail "shellcheck not installed (brew install shellcheck)"
  else
    # shellcheck disable=SC2046  # intentional word-splitting of the file list
    if shellcheck --severity=error $(git ls-files '*.sh'); then
      ok "shellcheck: 0 errors across $(git ls-files '*.sh' | wc -l | tr -d ' ') scripts"
    else
      record_fail "shellcheck reported error-level findings"
    fi
  fi
fi

# ──── GATE 2: jscpd duplication ────
section "jscpd (cross-file copy-paste, threshold ${JSCPD_THRESHOLD}%)"
if ! command -v npx >/dev/null 2>&1; then
  record_fail "npx not available (need Node) — cannot run jscpd"
else
  if npx --yes "jscpd@$JSCPD_VERSION" \
      --min-tokens "$JSCPD_MIN_TOKENS" \
      --threshold "$JSCPD_THRESHOLD" \
      --reporters console \
      scripts/; then
    ok "jscpd: duplication within ${JSCPD_THRESHOLD}%"
  else
    record_fail "jscpd: duplication exceeds ${JSCPD_THRESHOLD}% (see clones above)"
  fi
fi

# ──── ADVISORY: dead-script scan (fallow's "unused files") ────
section "dead-script scan (advisory — does not fail the build)"
dead=0
while IFS= read -r f; do
  base="$(basename "$f")"
  # Referenced anywhere in the tree other than its own file?
  if [ -z "$(git grep -l --fixed-strings -- "$base" ":(exclude)$f" 2>/dev/null)" ]; then
    warn "no references found: $f"
    dead=$((dead + 1))
  fi
done < <(git ls-files 'scripts/*.sh' 'scripts/*.py' 'scripts/**/*.sh' 'scripts/**/*.py')
[ "$dead" = 0 ] && ok "every script under scripts/ is referenced elsewhere"

# ──── SUMMARY ────
section "summary"
printf "%sReminder:%s run /wiki-lint for markdown health (links, orphans, contradictions).\n" "$DIM" "$RESET"
if [ "$failures" = 0 ]; then
  ok "quality gate passed"
  exit 0
else
  fail "quality gate failed ($failures gate(s))"
  exit 1
fi
