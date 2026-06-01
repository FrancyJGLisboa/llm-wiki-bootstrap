#!/usr/bin/env bash
# scripts/verify-create-llm-wiki.sh — oracle for the installer.
#
# Runs scripts/create-llm-wiki.sh against a fresh temp target under
# tests/installer-output/<timestamp>/freshrepo, then asserts:
#
#   I3       — target has every file listed in installer-skeleton-manifest.txt
#   I4(a)    — target's tree shape EQUALS the manifest, byte-identical when sorted
#              (catches both missing AND extra files; closes the wholesale-cp gaming hole)
#   I4(b)    — content tripwire: no Quortex / karpathy / Phase Coherence strings leak
#   I4(c)    — wiki/index.md frontmatter has type + source + updated
#   I5       — target's own preflight.sh exits 0
#
# Cleans any prior tests/installer-output/* before running so red-run debris
# does not accumulate. Deletes the temp target on green; leaves it on red
# (with a printed inspection path).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

MANIFEST="scripts/installer-skeleton-manifest.txt"
OUTPUT_DIR="tests/installer-output"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=; GREEN=; YELLOW=; DIM=; RESET=
fi

ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; }
note() { printf "%s%s%s\n"   "$DIM"   "$1" "$RESET" >&2; }

# Auto-clean prior red-run debris (do not touch .gitignore).
note "[verifier] cleaning prior $OUTPUT_DIR/* …"
find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 ! -name '.gitignore' -exec rm -rf {} + 2>/dev/null || true

# Pre-flight: manifest + installer + templates must exist.
[ -f "$MANIFEST" ] || { fail "manifest missing: $MANIFEST"; exit 1; }
[ -x "scripts/create-llm-wiki.sh" ] || { fail "installer missing or not executable"; exit 1; }
[ -f templates/README-fresh.md ] || { fail "templates/README-fresh.md missing"; exit 1; }
[ -f wiki/index-FRESH.md ] || { fail "wiki/index-FRESH.md missing"; exit 1; }

# Create temp target.
TS="$(date +%Y%m%d-%H%M%S)"
TARGET_PARENT="$OUTPUT_DIR/$TS"
mkdir -p "$TARGET_PARENT"
TGT="$TARGET_PARENT/freshrepo"

note "[verifier] target: $TGT"

# I2 — installer succeeds
if ! ./scripts/create-llm-wiki.sh "$TGT" > "$TARGET_PARENT/install.log" 2>&1; then
  fail "I2 installer exited non-zero — see $TARGET_PARENT/install.log"
  exit 1
fi
ok "I2 installer ran successfully (target: $TGT)"

failures=0

# I3 — target has every file in the manifest.
missing=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if [ ! -e "$TGT/$p" ]; then
    missing="${missing}  $p\n"
  fi
done < "$MANIFEST"
if [ -z "$missing" ]; then
  ok "I3 every manifest entry exists in target"
else
  fail "I3 manifest entries missing in target:"
  printf "$missing" >&2
  failures=$((failures + 1))
fi

# I4(a) — target tree shape EQUALS the manifest (catches extras AND missing in one shot).
expected="$(sort < "$MANIFEST" | sed '/^$/d')"
# Target's tracked file list, relative paths, no .git/.
actual="$(cd "$TGT" && find . -type f -not -path './.git/*' 2>/dev/null | sed 's|^\./||' | sort)"
if [ "$expected" = "$actual" ]; then
  ok "I4(a) target tree shape matches manifest exactly"
else
  fail "I4(a) target tree shape DIFFERS from manifest:"
  diff <(echo "$expected") <(echo "$actual") | sed 's/^/    /' >&2
  failures=$((failures + 1))
fi

# I4(b) — content tripwire: no smoke-specific identifier strings leak.
# (Narrowed from {Quortex,karpathy,Phase Coherence} to {Quortex,Phase Coherence}:
#  "karpathy" is a legitimate reference in dev-side docs to Andrej Karpathy as the
#  originator of the LLM-wiki pattern — appears in AGENTS.md, docs/EXPLAIN.md,
#  docs/QUICKSTART.md, scripts/body-hash.sh usage example. Those files SHOULD ship
#  in the fresh skeleton. The smoke-specific leakage scenarios "karpathy" was meant
#  to catch (dev README.md or wiki/index.md leaking into target) are now caught
#  more directly by I4(d) — template substitution byte-match below.)
tripwire="$(grep -r -l -E 'Quortex|Phase Coherence' "$TGT" 2>/dev/null || true)"
if [ -z "$tripwire" ]; then
  ok "I4(b) no Quortex/Phase Coherence (smoke-specific) strings in target"
else
  fail "I4(b) smoke-specific strings found in target files:"
  printf '%s\n' "$tripwire" | sed 's/^/    /' >&2
  failures=$((failures + 1))
fi

# I4(d) — template substitution: target README.md and wiki/index.md must match
# their FRESH counterparts byte-for-byte. Directly proves the installer used the
# FRESH templates, not the dev versions (the exact leakage scenario "karpathy" in
# I4(b) was a proxy for, now caught cryptographically).
substitution_ok=yes
if ! cmp -s "$TGT/README.md" "templates/README-fresh.md"; then
  fail "I4(d) target README.md does not match templates/README-fresh.md"
  diff "templates/README-fresh.md" "$TGT/README.md" | head -20 | sed 's/^/    /' >&2
  substitution_ok=no
fi
if ! cmp -s "$TGT/wiki/index.md" "wiki/index-FRESH.md"; then
  fail "I4(d) target wiki/index.md does not match wiki/index-FRESH.md"
  diff "wiki/index-FRESH.md" "$TGT/wiki/index.md" | head -20 | sed 's/^/    /' >&2
  substitution_ok=no
fi
if [ "$substitution_ok" = yes ]; then
  ok "I4(d) target README.md and wiki/index.md match FRESH templates exactly"
else
  failures=$((failures + 1))
fi

# I4(c) — wiki/index.md frontmatter has type + source + updated.
if awk '/^---$/{n++} n==1 && /^type:/{t=1} n==1 && /^source:/{s=1} n==1 && /^updated:/{u=1} END{exit !(t&&s&&u)}' "$TGT/wiki/index.md"; then
  ok "I4(c) target wiki/index.md frontmatter has type + source + updated"
else
  fail "I4(c) target wiki/index.md missing one of: type, source, updated"
  failures=$((failures + 1))
fi

# I5 — target's preflight exits 0.
if ( cd "$TGT" && ./scripts/preflight.sh > /dev/null 2>&1 ); then
  ok "I5 target preflight.sh exits 0"
else
  fail "I5 target preflight.sh exited non-zero"
  failures=$((failures + 1))
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d installer check(s) red.\n" "$RED" "$RESET" "$failures"
  printf "%sTarget left at: %s for inspection.%s\n" "$YELLOW" "$TGT" "$RESET"
  exit 1
fi

printf "%sPassed.%s All 5 installer checks green.\n" "$GREEN" "$RESET"
# Cleanup temp target on green.
rm -rf "$TARGET_PARENT"
exit 0
