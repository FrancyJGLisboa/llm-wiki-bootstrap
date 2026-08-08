#!/usr/bin/env bash
# scripts/gate-context-root.sh — gate CTX-ROOT-COMPAT.
#
# RULE: the compiled-context root resolves for all three layouts a package can
# have — context/ with the compat symlink, context/ alone, and legacy wiki/ —
# and the symlink, when present, is a symlink to context and not a divergent copy.
#
# WHY THIS GATE EXISTS: schema v5 renamed the compiled root wiki/ -> context/ and
# kept a committed `wiki -> context` symlink so the ~65 scripts that hardcode
# wiki/ would not need rewriting. That decision buys a lot and costs one thing:
# the compatibility now depends on a symlink, and a symlink is exactly the kind
# of artifact that silently degrades. Three ways it goes wrong, all of them quiet:
#
#   1. It becomes a real directory. Someone deletes the link and mkdirs wiki/,
#      or a Windows checkout without core.symlinks materialises it as a text
#      file. Now wiki/ and context/ drift, and the same page has two versions —
#      the one the lints read and the one the user edits.
#   2. It points somewhere else. wiki -> ../other-repo/context resolves, reads
#      plausibly, and silently sources pages from outside the package.
#   3. It is absent AND nothing notices, because every script that would have
#      complained hardcodes wiki/ and simply finds no files — which several of
#      them treat as "no pages, nothing to check" rather than as an error.
#
# Legacy wiki/-only packages must keep working forever: bundles already
# delivered cannot be migrated, and a recipient verifying one is checking an
# artifact they were given, not upgrading it.
#
# DETECTION: build the three layouts in a temp tree and require ctx_root() to
# name the right directory for each. Then, against the real repo, assert the
# link's type and target rather than merely that the path resolves.
#
# FAILURE MODES — the honest ones:
#   - It proves ctx_root() resolves. It does NOT prove the ~65 scripts that
#     hardcode wiki/ actually work, because they bypass ctx_root() entirely.
#     Their coverage is the rest of the suite running against a symlinked tree.
#   - On a checkout with no symlink support, `wiki` is a small text file. This
#     gate reports that as a violation (correctly — compatibility is broken
#     there), which makes it noisy on Windows rather than silent. That is the
#     intended direction, and the installer prints a hint when it happens.
#   - It does not detect content divergence between wiki/ and context/ if wiki/
#     were a real directory with the same file names. It only detects that it is
#     not a symlink, which is the cause rather than the symptom.
#
# SCOPE: scripts/lib/ctx-root.sh, and the repo root's `wiki` entry.
#
# EXIT: 0 = all three layouts resolve and the link is sound · 1 = a layout
#       resolves wrongly or the link is not a symlink to context · 2 = the gate
#       itself failed (ctx-root.sh missing, mktemp failed).
#
# MODES:
#   (default)   check this repository
#   --repo <d>  check the tree at <d>
#   --count     print "<violations>TAB<suppressions>" and exit 0
#
# RUNTIME: bash 3.2+. No LLM, no network, no key.
# WIRED AT: scripts/smoke-all.sh (R40) → CI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate-lib.sh
. "$SCRIPT_DIR/lib/gate-lib.sh" || { printf 'gate-context-root: cannot source lib/gate-lib.sh\n' >&2; exit 2; }
gate_init "gate-context-root" "CTX-ROOT-COMPAT"

LIB="$SCRIPT_DIR/lib/ctx-root.sh"
[ -r "$LIB" ] || gate_die "cannot read $LIB — the resolver under test is missing"
# shellcheck source=lib/ctx-root.sh
. "$LIB" || gate_die "sourcing $LIB failed"
command -v ctx_root >/dev/null 2>&1 || gate_die "ctx_root not defined after sourcing $LIB"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  ROOT="${2:-}"; [ -n "$ROOT" ] || gate_die "--repo needs a directory"; shift 2 ;;
    --count) GATE_COUNT_MODE=1; shift ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || gate_die "not a directory: $ROOT"

tmp="$(mktemp -d)" || gate_die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# ── 1. the three layouts ──
mkdir -p "$tmp/both/context" && ln -s context "$tmp/both/wiki" 2>/dev/null \
  || gate_die "cannot create a symlink in $tmp — the gate cannot test what it exists to test"
mkdir -p "$tmp/ctxonly/context"
mkdir -p "$tmp/legacy/wiki"
mkdir -p "$tmp/neither"

expect() {  # expect <layout-dir> <expected-name> <why>
  _got="$(ctx_root "$tmp/$1" 2>/dev/null)" || _got="<none>"
  [ "$_got" = "$2" ] && return 0
  gate_violation "scripts/lib/ctx-root.sh:1" \
"ctx_root() returned '$_got' for the $1 layout, expected '$2'. $3"
}
expect both    context "A package with both must prefer the real directory, never the link — resolving through the symlink makes every derived path depend on it."
expect ctxonly context "A checkout without symlink support has context/ and no wiki/ at all; that is the layout ctx_root() exists to handle."
expect legacy  wiki    "Bundles delivered before schema v5 have only wiki/ and must keep verifying forever — they cannot be migrated."

# `neither` must fail, and must fail by returning non-zero rather than printing
# a default. A resolver that guesses 'context' for an empty tree would send
# every caller to a directory that does not exist.
if ctx_root "$tmp/neither" >/dev/null 2>&1; then
  gate_violation "scripts/lib/ctx-root.sh:1" \
"ctx_root() succeeded on a tree with neither context/ nor wiki/. It must return
       non-zero so callers can decide whether that is exit 1 or exit 2 for them,
       rather than being handed a path that does not exist."
fi

# ── 2. the real repo's link ──
if [ -e "$ROOT/context" ]; then
  if [ -e "$ROOT/wiki" ]; then
    if [ ! -L "$ROOT/wiki" ]; then
      gate_violation "wiki:1" \
"\`wiki\` exists next to context/ but is NOT a symlink. If it is a real
       directory the two will drift and the same page gets two versions — the
       one the lints read and the one you edit. If it is a text file, this is a
       checkout without symlink support.
       FIX: rm -rf wiki && ln -s context wiki"
    else
      _t="$(readlink "$ROOT/wiki")"
      [ "$_t" = "context" ] || gate_violation "wiki:1" \
"\`wiki\` is a symlink to '$_t', not to 'context'. A link pointing outside the
       package silently sources pages from somewhere else.
       FIX: rm wiki && ln -s context wiki"
    fi
  fi
fi

gate_verdict "clean — all three root layouts resolve; the compat link is a symlink to context."
