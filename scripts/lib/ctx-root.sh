#!/usr/bin/env bash
# scripts/lib/ctx-root.sh — resolve the compiled-context root directory.
#
# The compiled root was renamed `wiki/` -> `context/` in schema v5, because the
# output stopped being a wiki: it carries provenance, typed relations, valid
# time, rules and gates.
#
# A committed symlink `wiki -> context` keeps every existing path working, so
# the ~65 scripts that hardcode `wiki/` were NOT rewritten. That is deliberate:
# a 65-file sed across the oracles that constitute this repo's entire safety net
# would risk far more than the inconsistency it removes. They migrate
# opportunistically. NEW code should call ctx_root().
#
# Why a symlink is safe here, verified rather than assumed:
#   - `find` and `grep -r` do NOT descend into symlinked directories, so
#     recursive scans do not double-count. (`grep -R` and `find -L` DO follow;
#     neither appears anywhere in scripts/.)
#   - pathlib's rglob() does not follow directory symlinks either.
#   - `wiki/*.md` globs and `[ -d wiki ]` still work, which is what the
#     hardcoded paths rely on.
#
# Known limitation, stated rather than papered over: a Windows checkout without
# `core.symlinks=true` gets a plain text file named `wiki` containing the word
# "context". ctx_root() is unaffected — it prefers `context/`, which is a real
# directory — but a script hardcoding `wiki/` will fail there. That is the cost
# of not rewriting 65 files, and it is why new code should use this function.
#
# This file is sourced, never executed.

# ctx_root [<repo-root>]
# Prints the compiled-context directory name relative to <repo-root> (default:
# the current directory). Prefers `context`; falls back to `wiki` for a package
# built before v5. Prints nothing and returns 1 if neither exists — callers
# decide whether that is exit 1 or exit 2 for them.
ctx_root() {
  _cr_base="${1:-.}"
  if [ -d "$_cr_base/context" ]; then
    printf 'context\n'; unset _cr_base; return 0
  fi
  if [ -d "$_cr_base/wiki" ]; then
    printf 'wiki\n'; unset _cr_base; return 0
  fi
  unset _cr_base
  return 1
}

# ctx_root_path [<repo-root>]
# Same, but prints the full path.
ctx_root_path() {
  _crp_base="${1:-.}"
  _crp_name="$(ctx_root "$_crp_base")" || { unset _crp_base _crp_name; return 1; }
  printf '%s/%s\n' "$_crp_base" "$_crp_name"
  unset _crp_base _crp_name
}
