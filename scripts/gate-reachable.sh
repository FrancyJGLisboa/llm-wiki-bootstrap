#!/usr/bin/env bash
# scripts/gate-reachable.sh — gate GATE-REACHABLE.
#
# RULE: every oracle in this repo (`scripts/verify-*.sh`, `scripts/gate-*.sh`)
# must be reachable from a CI entry point, or be listed as a declared standalone
# with a reason.
#
# WHY THIS GATE EXISTS: an unwired gate reads as coverage and never fires — the
# core failure the deterministic-gates discipline is built around ("a gate that
# never fires is indistinguishable from a broken gate, and that is how most of
# them are born"). `scripts/verify-scale-eval.sh` is named in README.md as one
# of the three oracles that "verify every grader — an eval nobody checks
# measures nothing", and no runner invokes it. The README sentence is true about
# the file's existence and false about its effect.
#
# DETECTION: transitive reachability, computed as a fixed point. Roots are the
# CI workflows (`.github/workflows/*.yml`). A script is reached if its basename
# appears literally in the text of an already-reached file. Iterate until the
# set stops growing. Any verify-*/gate-* script outside the closure is a
# violation unless declared in the standalone list.
#
# FAILURE MODES — the honest ones:
#   - Reachability is computed from literal basenames, so a script invoked via a
#     constructed path ("$DIR/verify-$name.sh") reads as unreachable. Verified
#     absent from this repo at build time; if that pattern appears, switch to
#     the runtime variant — have smoke-all.sh emit the oracles it actually
#     executed and diff that against the file list. That one is immune to
#     dispatch style.
#   - Whole-line comments are stripped before matching, because a script named
#     only in a comment is described, not run. An INLINE trailing comment
#     (`foo   # see verify-x.sh`) still counts as a call and fails OPEN. Caught
#     the hard way: the first fixtures for this gate passed because their own
#     header comments named the scripts, so mutations that severed every real
#     call still came back green.
#
# ANTI-BYPASS: declared standalones are printed and counted as suppressions on
# every run, per deterministic-gates §6. Routing around the gate by appending to
# the list is possible but never silent.
#
# SCOPE: scripts/verify-*.sh and scripts/gate-*.sh — the oracles. Library
# scripts (lib/, wiki-*.sh, eval-*.sh) are tools, not gates; whether they run is
# a question about features, not about coverage.
#
# EXIT: 0 = every oracle reachable (or declared) · 1 = orphan found
#       · 2 = the gate itself failed (no roots, unreadable tree).
#
# MODES:
#   (default)      check this repository
#   --repo <dir>   check the tree at <dir> — fixture mode
#
# RUNTIME: bash + grep + find. No LLM, no network, no key, no git.
# WIRED AT: scripts/smoke-all.sh (R32) → CI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULE_ID="GATE-REACHABLE"

die2() { printf 'gate-reachable: %s\n' "$1" >&2; exit 2; }

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) ROOT="${2:-}"; [ -n "$ROOT" ] || die2 "--repo needs a directory"; shift 2 ;;
    *) die2 "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || die2 "not a directory: $ROOT"
cd "$ROOT" || die2 "cannot cd to $ROOT"

STANDALONE_LIST="scripts/gate-standalone.txt"

tmp="$(mktemp -d)" || die2 "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# ── roots ──
find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) \
  > "$tmp/reached" 2>/dev/null
[ -s "$tmp/reached" ] || die2 "no CI workflow files under .github/workflows — nothing is a root, so every oracle would read as unreachable"

# ── every script that could be reached ──
find scripts -type f \( -name '*.sh' -o -name '*.py' \) 2>/dev/null | sort > "$tmp/all"
[ -s "$tmp/all" ] || die2 "no scripts found under scripts/"

# ── fixed point ──
# Bounded by the number of scripts: each pass either adds one or terminates.
max_passes=$(wc -l < "$tmp/all")
pass=0
while [ "$pass" -le "$max_passes" ]; do
  pass=$((pass + 1))
  before=$(wc -l < "$tmp/reached")
  while IFS= read -r cand; do
    grep -qxF "$cand" "$tmp/reached" && continue
    base="$(basename "$cand")"
    # Is this basename INVOKED anywhere in the already-reached set? Whole-line
    # comments are stripped first: both `.sh` and `.yml` use `#`, and a script
    # named only in a comment is described, not run. Without this strip a
    # header comment like "calls verify-beta.sh" keeps an orphan alive — which
    # is how the fixtures for this gate first passed for the wrong reason.
    found=0
    while IFS= read -r reached_file; do
      [ -f "$reached_file" ] || continue
      if grep -v '^[[:space:]]*#' "$reached_file" 2>/dev/null | grep -qF -- "$base"; then
        found=1; break
      fi
    done < "$tmp/reached"
    [ "$found" = 1 ] && echo "$cand" >> "$tmp/reached"
  done < "$tmp/all"
  after=$(wc -l < "$tmp/reached")
  [ "$before" = "$after" ] && break
done
[ "$pass" -gt "$max_passes" ] && die2 "reachability did not converge in $max_passes passes"

# ── declared standalones ──
: > "$tmp/standalone"
suppressions=0
if [ -f "$STANDALONE_LIST" ]; then
  grep -vE '^[[:space:]]*(#|$)' "$STANDALONE_LIST" > "$tmp/standalone" 2>/dev/null
  suppressions=$(wc -l < "$tmp/standalone" | tr -d ' ')
fi

# ── verdict ──
orphans=0
checked=0
for f in scripts/verify-*.sh scripts/gate-*.sh; do
  [ -f "$f" ] || continue
  checked=$((checked + 1))
  grep -qxF "$f" "$tmp/reached" && continue
  base="$(basename "$f")"
  if grep -qE "^${base}[[:space:]]" "$tmp/standalone" 2>/dev/null; then
    reason="$(grep -E "^${base}[[:space:]]" "$tmp/standalone" | head -1 | sed "s|^${base}[[:space:]]*||")"
    printf '  suppressed: %s — %s\n' "$base" "$reason"
    continue
  fi
  printf '%s: %s\n' "$f" "$RULE_ID" >&2
  printf '  no CI entry point reaches this oracle. It exists, it is never run, and\n' >&2
  printf '  a gate that never fires is indistinguishable from a broken one.\n' >&2
  printf '  FIX: wire it into scripts/smoke-all.sh as a numbered guard, or add a\n' >&2
  printf '  line to %s:  %s  <reason it cannot be wired>\n' "$STANDALONE_LIST" "$base" >&2
  orphans=$((orphans + 1))
done

[ "$checked" -gt 0 ] || die2 "no verify-*/gate-* oracles found under scripts/ — the gate is inspecting nothing"

if [ "$suppressions" -gt 0 ]; then
  printf 'gate-reachable: %d declared standalone(s) — these count as suppressions.\n' "$suppressions"
fi

if [ "$orphans" -gt 0 ]; then
  printf 'gate-reachable: %d orphan oracle(s) of %d — %s\n' "$orphans" "$checked" "$RULE_ID" >&2
  exit 1
fi

printf 'gate-reachable: clean — all %d oracles reachable from CI (%d declared standalone).\n' \
  "$checked" "$suppressions"
exit 0
