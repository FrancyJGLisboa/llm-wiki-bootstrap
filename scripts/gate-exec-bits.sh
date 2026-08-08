#!/usr/bin/env bash
# scripts/gate-exec-bits.sh — gate EXEC-BIT-PRESERVED.
#
# RULE: every file git records with mode 100755 is executable in the working
# tree.
#
# WHY THIS GATE EXISTS (deterministic-gates §7, continuous harvest). The
# /wiki-* -> /ctx-* rename rewrote 128 files with the shell idiom
#
#     perl rewrite.pl "$f" > "$f.__new" && mv "$f.__new" "$f"
#
# `mv` replaces the inode. The new file is created with the process umask, so
# 55 scripts silently dropped their executable bit while git's index still
# recorded 100755. The next suite run produced 20 red checks — preflight,
# body-hash, installer, synthesize, discover, bundle round-trip, hash-drift,
# and more — none of which named the cause. Every one of them said "regression"
# about its own subject. The actual message, "you chmod'd 55 files to 644",
# appeared nowhere.
#
# That is what this gate is for. The suite already DETECTS the fault; what it
# cannot do is NAME it. Twenty unrelated-looking failures cost far more to
# diagnose than one line pointing at the real cause, and the redirect-and-move
# idiom is common enough that this will happen again.
#
# DETECTION: git's index is the authority, not a heuristic. For each tracked
# path whose recorded mode is 100755, test the working-tree file with -x. No
# guessing, no false positives — git already knows the intended mode.
#
# NOT CHECKED, deliberately: the converse ("a file with a #! shebang should be
# executable"). It is wrong here. scripts/lib/commitment.sh, lib/eval-common.sh
# and lib/gate-lib.sh all carry shebangs and are correctly mode 644 — they are
# sourced, never executed, and the shebang is there to tell editors and linters
# which language they are. A shebang-implies-executable rule would fire on all
# three on every run, and a gate that cries wolf gets suppressed.
#
# FAILURE MODES — the honest ones:
#   - Only tracked files are checked. A brand-new script that was never `git
#     add`ed has no recorded mode, so losing its +x is invisible here.
#   - The reverse drift is not checked: a file git records as 100644 that has
#     become executable on disk. Harmless in this repo, and checking it would
#     fire on anything a user chmod'd for a local reason.
#   - It compares against the INDEX, not against HEAD. Staging a mode change
#     makes the index agree with the working tree, so a deliberate `chmod -x` +
#     `git add` passes. That is correct — at that point it is a decision, and
#     the diff shows it.
#
# SCOPE: every tracked file in the repository. Not restricted to scripts/ —
# the bug was in a bulk rewrite, and a bulk rewrite does not respect
# directories.
#
# EXIT: 0 = every 100755 file is executable · 1 = at least one lost its bit
#       · 2 = the gate itself failed (no git, not a repository).
#
# MODES:
#   (default)        check this repository via `git ls-files -s`
#   --index <file>   read the mode listing from a file instead of git — fixture
#                    mode, so the gate can be proven without constructing a repo
#                    whose index deliberately disagrees with its worktree
#   --repo <dir>     check the tree at <dir>
#   --count          print "<violations>TAB<suppressions>" and exit 0
#
# RUNTIME: bash 3.2+ + git (unless --index). No LLM, no network, no key.
# WIRED AT: scripts/smoke-all.sh (R38) → CI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate-lib.sh
. "$SCRIPT_DIR/lib/gate-lib.sh" || { printf 'gate-exec-bits: cannot source lib/gate-lib.sh\n' >&2; exit 2; }
gate_init "gate-exec-bits" "EXEC-BIT-PRESERVED"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INDEX_FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  ROOT="${2:-}";       [ -n "$ROOT" ]       || gate_die "--repo needs a directory";  shift 2 ;;
    --index) INDEX_FILE="${2:-}"; [ -n "$INDEX_FILE" ] || gate_die "--index needs a file";      shift 2 ;;
    --count) GATE_COUNT_MODE=1; shift ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || gate_die "not a directory: $ROOT"

# Resolve the index file before cd, so a relative --index still works.
if [ -n "$INDEX_FILE" ]; then
  case "$INDEX_FILE" in
    /*) : ;;
    *) INDEX_FILE="$PWD/$INDEX_FILE" ;;
  esac
  [ -r "$INDEX_FILE" ] || gate_die "cannot read index listing: $INDEX_FILE"
fi

cd "$ROOT" || gate_die "cannot cd to $ROOT"

tmp="$(mktemp -d)" || gate_die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# ── the recorded modes ──
# Format either way: "<mode> <object> <stage>TAB<path>" (git ls-files -s).
if [ -n "$INDEX_FILE" ]; then
  cat "$INDEX_FILE" > "$tmp/index" || gate_die "reading $INDEX_FILE failed"
else
  gate_need git
  git rev-parse --git-dir >/dev/null 2>&1 || gate_die "$ROOT is not a git repository (nothing records the intended modes, so there is nothing to compare against)"
  git ls-files -s > "$tmp/index" 2>"$tmp/err" || gate_die "git ls-files failed: $(head -1 "$tmp/err")"
fi
[ -s "$tmp/index" ] || gate_die "the mode listing is empty — the gate is inspecting nothing"

# ── compare ──
checked=0
while IFS= read -r line; do
  case "$line" in '') continue ;; esac
  mode="${line%% *}"
  [ "$mode" = "100755" ] || continue
  # path is everything after the first tab
  path="${line#*$(printf '\t')}"
  [ -n "$path" ] || continue
  # A tracked-but-deleted file is a different problem, not this one.
  [ -e "$path" ] || continue
  checked=$((checked + 1))
  [ -x "$path" ] && continue
  gate_violation "$path:1" \
"git records this file as mode 100755 but it is not executable in the working
       tree. Usually a redirect-and-move rewrite (\`cmd f > f.new && mv f.new f\`),
       which replaces the inode and applies your umask.
       FIX: chmod +x '$path'
       Restore every one at once with:
         git ls-files -s | awk '\$1==\"100755\"{print \$4}' | while read -r f; do
           [ -f \"\$f\" ] && [ ! -x \"\$f\" ] && chmod +x \"\$f\"; done"
done < "$tmp/index"

[ "$checked" -gt 0 ] || gate_die "no files recorded as 100755 — either the listing is malformed or this repo has no executables, and both mean the gate is checking nothing"

gate_verdict "clean — all $checked executable file(s) still carry their +x bit."
