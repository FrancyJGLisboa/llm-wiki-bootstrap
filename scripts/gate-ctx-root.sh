#!/usr/bin/env bash
# scripts/gate-ctx-root.sh — gate CTX-ROOT-ADOPTION.
#
# RULE: new code resolves the compiled-context root with ctx_root() from
# scripts/lib/ctx-root.sh instead of hardcoding `wiki/`. Existing hardcoded
# paths are not required to be fixed — the recorded count may not GO UP.
#
# WHY THIS GATE EXISTS: schema v5 renamed the compiled root `wiki/` -> `context/`
# and kept a committed `wiki -> context` symlink so the scripts that hardcode
# `wiki/` would not need rewriting. AGENTS.md states the resulting rule plainly:
# "New code should resolve the root with ctx_root() from scripts/lib/ctx-root.sh
# rather than hardcoding either name."
#
# That rule was enforced by a paragraph. Measured adoption on the day this gate
# was written: 4 files called ctx_root(), 41 files hardcoded `wiki/` on 80
# non-comment lines. Every one of those lines is a path that resolves only
# through the symlink — and docs/deterministic-gates.md §1 is explicit that a
# deterministic rule left in prose is the failure mode, not the baseline.
#
# The cost of the omission is not hypothetical. scripts/lib/ctx-root.sh names it
# already: a Windows checkout without core.symlinks materialises `wiki` as a text
# file containing the word "context", and every hardcoded path fails there while
# ctx_root() keeps working. Each new hardcoded line widens a platform gap the
# project has already decided it does not want to widen.
#
# This is a RATCHET, not a migration order. The existing 80 lines are recorded in
# gates/baseline.tsv and stay legal. AGENTS.md argues directly against rewriting
# them in bulk — they are the oracles that constitute this repo's safety net —
# and this gate deliberately does not create pressure to. New hardcoding raises a
# watched number; opportunistic migration lowers it silently.
#
# DETECTION: for every *.sh and *.py under scripts/, count lines that are not
# comments and that contain a `wiki/` path token. scripts/lib/ctx-root.sh is
# excluded: it is the definition of the alternative and must name both roots.
#
# FAILURE MODES — the honest ones, and there are more than three:
#   1. A path assembled at runtime is invisible. `d="wi"; d="${d}ki/"` or
#      os.path.join("wiki", p) never matches the literal, so a determined
#      author can hardcode the root without moving the number. The gate raises
#      the cost of doing it accidentally, which is the only failure mode it is
#      designed for.
#   2. A `wiki/` inside a user-facing string counts as a violation. An echo that
#      says "see wiki/index.md" is prose in code and harms nothing, but it is
#      indistinguishable from a path operation without parsing the shell. The
#      gate over-counts here rather than guess, and the ratchet absorbs it.
#   3. An inline trailing comment counts. Only lines whose FIRST non-blank
#      character is `#` are treated as comments, so `foo wiki/x  # note` counts
#      once — correctly, since the code half is real — but `code  # see wiki/`
#      also counts, wrongly.
#   4. It counts LINES, not occurrences. Two hardcoded paths on one line move
#      the number by one, so collapsing two lines into one reads as progress.
#   5. It says nothing about correctness. A file that calls ctx_root() and then
#      ignores the result passes cleanly; adoption is not the same as use.
#
# SCOPE: scripts/**/*.sh and scripts/**/*.py. Not docs (prose SHOULD say wiki/
# when discussing history), not .claude/commands/ (agent-facing prose), not
# tests/ fixtures (they deliberately pin legacy layouts), not the compiled
# context itself.
#
# EXIT: 0 = at or below baseline · 1 = a hardcoded path in new code
#       · 2 = the gate itself failed (no scripts/ directory, no grep).
#
# MODES:
#   (default)      check this repository
#   --repo <dir>   check the tree at <dir> — fixture mode
#   --count        print "<violations>TAB<suppressions>" and exit 0
#
# RUNTIME: bash 3.2+ + grep + find. No LLM, no network, no key.
# WIRED AT: scripts/smoke-all.sh (R41) → CI. Ratcheted by gates/baseline.tsv.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate-lib.sh
. "$SCRIPT_DIR/lib/gate-lib.sh" || { printf 'gate-ctx-root: cannot source lib/gate-lib.sh\n' >&2; exit 2; }
gate_init "gate-ctx-root" "CTX-ROOT-ADOPTION"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  ROOT="${2:-}"; [ -n "$ROOT" ] || gate_die "--repo needs a directory"; shift 2 ;;
    --count) GATE_COUNT_MODE=1; shift ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || gate_die "not a directory: $ROOT"
cd "$ROOT" || gate_die "cannot cd to $ROOT"

gate_need grep find

# A missing scripts/ is a gate failure, not a clean bill of health. Reporting
# "no hardcoded paths" for a tree that has no code to check is the exact lie
# deterministic-gates §4 warns about.
[ -d scripts ] || gate_die "no scripts/ directory under $ROOT — there is no code to check, which is not the same as the code being clean"

# Two exclusions, both for the same reason: a file whose subject IS this rule
# has to write the forbidden token to define it, so counting it would mean the
# number can never reach zero no matter how much code migrates.
#   - lib/ctx-root.sh  is the alternative being recommended.
#   - this gate        states the pattern and prints it in its own fix message.
# Nothing else may be added here. An exclusion that is not self-reference is a
# suppression, and suppressions belong in the ratchet where they are counted.
is_excluded() {
  case "$1" in
    scripts/lib/ctx-root.sh|scripts/gate-ctx-root.sh) return 0 ;;
    *) return 1 ;;
  esac
}

# `wiki/` as a path token: not preceded by a character that would make it part
# of a longer word or an unrelated path (meta-wiki/, my-wiki/, llm-wiki/).
PATTERN='(^|[^a-zA-Z0-9_./-])wiki/'

files_scanned=0
for f in $(find scripts -type f \( -name '*.sh' -o -name '*.py' \) 2>/dev/null | LC_ALL=C sort); do
  is_excluded "$f" && continue
  files_scanned=$((files_scanned + 1))

  # Strip whole-line comments, then match. LC_ALL=C keeps this byte-oriented so
  # the count cannot differ between a macOS author and Ubuntu CI — the failure
  # LEARNINGS.md records for wiki-lint-typed-relations.sh.
  hits="$(LC_ALL=C grep -nvE '^[[:space:]]*#' "$f" 2>/dev/null | LC_ALL=C grep -cE "$PATTERN" 2>/dev/null)" || hits=0
  [ "$hits" -gt 0 ] 2>/dev/null || continue

  # Report the first offending line so the message points at something real.
  line="$(LC_ALL=C grep -nE "$PATTERN" "$f" 2>/dev/null | LC_ALL=C grep -vE '^[0-9]+:[[:space:]]*#' | head -1 | cut -d: -f1)"
  [ -n "$line" ] || line=1

  i=0
  while [ "$i" -lt "$hits" ]; do
    gate_violation "$f:$line" \
"this file hardcodes the compiled-context root as \`wiki/\` ($hits line(s)).
       AGENTS.md: new code resolves it with ctx_root() from scripts/lib/ctx-root.sh,
       because a checkout without symlink support has context/ and no wiki/ at all.
         . \"\$SCRIPT_DIR/lib/ctx-root.sh\" || exit 2
         CTXDIR=\"\$(ctx_root \"\$ROOT\")\" || exit 2
       Existing lines are recorded in gates/baseline.tsv and need not be fixed —
       this fires because the count went UP. See scripts/package-wiki.sh:72 for a
       worked example."
    i=$((i + 1))
  done
done

[ "$files_scanned" -gt 0 ] || gate_die "scripts/ contains no .sh or .py files under $ROOT — nothing was inspected, so a clean verdict would be meaningless"

gate_verdict "clean — $files_scanned script(s) scanned, hardcoded \`wiki/\` at or below baseline."
