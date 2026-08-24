#!/usr/bin/env bash
# scripts/verify-create-context-compiler.sh — oracle for the installer.
#
# Runs scripts/create-context-compiler.sh against a fresh temp target under
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

# Counted, not narrated. The banner used to print a hardcoded "All 7 installer
# checks green", so adding I8 left it still claiming 7 — and REMOVING a check
# would have left it claiming 7 too. A suite that reports a literal instead of
# its own tally can lose coverage without the number ever moving.
passes=0
ok()   { passes=$((passes + 1)); printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; }
note() { printf "%s%s%s\n"   "$DIM"   "$1" "$RESET" >&2; }

# Auto-clean prior red-run debris (do not touch .gitignore).
note "[verifier] cleaning prior $OUTPUT_DIR/* …"
find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 ! -name '.gitignore' -exec rm -rf {} + 2>/dev/null || true

# Pre-flight: manifest + installer + templates must exist.
[ -f "$MANIFEST" ] || { fail "manifest missing: $MANIFEST"; exit 1; }
[ -x "scripts/create-context-compiler.sh" ] || { fail "installer missing or not executable"; exit 1; }
[ -f templates/README-fresh.md ] || { fail "templates/README-fresh.md missing"; exit 1; }
[ -f context/index-FRESH.md ] || { fail "context/index-FRESH.md missing"; exit 1; }

# Create temp target.
TS="$(date +%Y%m%d-%H%M%S)"
TARGET_PARENT="$OUTPUT_DIR/$TS"
mkdir -p "$TARGET_PARENT"
TGT="$TARGET_PARENT/freshrepo"

note "[verifier] target: $TGT"

# I2 — installer succeeds
if ! ./scripts/create-context-compiler.sh "$TGT" > "$TARGET_PARENT/install.log" 2>&1; then
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
# This verifier now ships (so a generated compiler can spawn another), and it
# carries the two needles below as literals. Exclude itself from its own scan —
# otherwise the tripwire fires on the search pattern rather than on leaked
# content. Any OTHER file matching is still a real failure.
tripwire="$(grep -r -l -E 'Quortex|Phase Coherence' "$TGT" 2>/dev/null \
            | grep -v '/scripts/verify-create-context-compiler\.sh$' || true)"
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
if ! cmp -s "$TGT/context/index.md" "context/index-FRESH.md"; then
  fail "I4(d) target context/index.md does not match context/index-FRESH.md"
  diff "context/index-FRESH.md" "$TGT/context/index.md" | head -20 | sed 's/^/    /' >&2
  substitution_ok=no
fi
if [ "$substitution_ok" = yes ]; then
  ok "I4(d) target README.md and wiki/index.md match FRESH templates exactly"
else
  failures=$((failures + 1))
fi

# I4(c) — wiki/index.md frontmatter has type + source + updated.
if awk '/^---$/{n++} n==1 && /^type:/{t=1} n==1 && /^source:/{s=1} n==1 && /^updated:/{u=1} END{exit !(t&&s&&u)}' "$TGT/context/index.md"; then
  ok "I4(c) target context/index.md frontmatter has type + source + updated"
else
  fail "I4(c) target context/index.md missing one of: type, source, updated"
  failures=$((failures + 1))
fi

# I8 — the wiki -> context compat symlink shipped and resolves.
# I4(a) compares `find -type f` against the manifest, and a symlink is type l —
# so it is invisible to that check and would ship (or fail to ship) unnoticed.
# ~65 shipped scripts reference wiki/ by name; without this link every one of
# them breaks in a fresh install, which is exactly the class of failure the
# installer oracle exists to catch before a user does.
if [ -L "$TGT/wiki" ] && [ -d "$TGT/wiki" ] && [ -f "$TGT/wiki/index.md" ]; then
  ok "I8 wiki -> context compat symlink present and resolving"
else
  fail "I8 wiki -> context compat symlink missing or broken in target"
  failures=$((failures + 1))
fi

# I5 — target's preflight exits 0.
if ( cd "$TGT" && ./scripts/preflight.sh > /dev/null 2>&1 ); then
  ok "I5 target preflight.sh exits 0"
else
  fail "I5 target preflight.sh exited non-zero"
  failures=$((failures + 1))
fi

# I6 — every shipped script RUNS in the installed skeleton, rather than merely
# existing in it. The manifest is a hand-maintained list, so it happily ships a
# script while leaving the module that script imports behind: four core scripts
# (citation-audit.py, wiki-to-kg.py, asserted-at-audit.py, wiki-to-okf.py) all
# import scripts/lib/wikitext.py, which was never listed — so `/ctx-lint` and
# `/ctx-discover` crashed on import in EVERY fresh install while the file-level
# manifest check stayed green. Exit codes alone can't catch it either: a Python
# ModuleNotFoundError exits 1, which is indistinguishable from "the lint found
# issues". So this asserts a real verdict — bounded exit code AND stderr free of
# crash markers.
CRASH_MARKERS='Traceback|ModuleNotFoundError|ImportError|No such file or directory|command not found|cannot open'
i6=0
i6_probe() {  # <label> <command...> — run in the target, demand a verdict
  local label="$1"; shift
  local err rc
  err="$REPO_ROOT/$TGT/.probe.err"
  # `set -e` is active: a bare subshell returning non-zero would kill the
  # verifier before rc is read, and these lints exit 1 BY DESIGN when they find
  # issues. Capture the status without letting it abort the run.
  ( cd "$TGT" && "$@" >/dev/null 2>"$err" ) && rc=0 || rc=$?
  if [ "$rc" -gt 1 ] || grep -qE "$CRASH_MARKERS" "$err" 2>/dev/null; then
    fail "I6 $label did not return a verdict (exit $rc): $(head -1 "$err" 2>/dev/null)"
    i6=1
  fi
}
# `gate-*.sh` is in the glob too: a shipped gate that crashes on a fresh install
# is worse than no gate, and this loop previously covered only wiki-lint-*, so a
# newly shipped gate could pass the manifest check while never once being run.
for lint in "$TGT"/scripts/wiki-lint-*.sh "$TGT"/scripts/ctx-lint-*.sh "$TGT"/scripts/gate-*.sh; do
  [ -f "$lint" ] || continue
  # No argument on purpose: each lint has its own default target (raw/ for the
  # drift lint, the wiki root for the commitment lint), and the default path is
  # the one a user actually hits. Passing a blanket `raw/` tested a call nobody
  # makes and failed the lint whose contract differs.
  i6_probe "$(basename "$lint")" bash "scripts/$(basename "$lint")"
done
if command -v python3 >/dev/null 2>&1; then
  for py in citation-audit.py wiki-to-kg.py asserted-at-audit.py wiki-to-okf.py; do
    [ -f "$TGT/scripts/$py" ] || continue
    i6_probe "$py (import)" python3 -c "import importlib.util,sys,os
sys.path.insert(0, os.path.join('scripts','lib'))
spec = importlib.util.spec_from_file_location('probe', os.path.join('scripts','$py'))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)"
  done
fi
rm -f "$TGT/.probe.err"
[ "$i6" -eq 0 ] && ok "I6 every shipped lint and python module runs in the installed skeleton" \
  || failures=$((failures + 1))

# I7 — the negative control for I6. A check that cannot go red proves nothing,
# so break the skeleton on purpose (hide the shared module) and require I6's
# probe to notice. Restored immediately either way.
if command -v python3 >/dev/null 2>&1 && [ -f "$TGT/scripts/lib/wikitext.py" ]; then
  mv "$TGT/scripts/lib/wikitext.py" "$TGT/scripts/lib/.wikitext.hidden"
  if ( cd "$TGT" && python3 scripts/citation-audit.py wiki/ ) >/dev/null 2>"$REPO_ROOT/$TGT/.neg.err" \
     && ! grep -qE "$CRASH_MARKERS" "$REPO_ROOT/$TGT/.neg.err"; then
    fail "I7 removing scripts/lib/wikitext.py did NOT break citation-audit.py — I6 cannot detect a missing dependency"
    failures=$((failures + 1))
  else
    ok "I7 negative control: a missing shared module is detected, not silently tolerated"
  fi
  mv "$TGT/scripts/lib/.wikitext.hidden" "$TGT/scripts/lib/wikitext.py"
  rm -f "$REPO_ROOT/$TGT/.neg.err"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d installer check(s) red.\n" "$RED" "$RESET" "$failures"
  printf "%sTarget left at: %s for inspection.%s\n" "$YELLOW" "$TGT" "$RESET"
  exit 1
fi

printf "%sPassed.%s All %d installer checks green.\n" "$GREEN" "$RESET" "$passes"
# Cleanup temp target on green.
rm -rf "$TARGET_PARENT"
exit 0
