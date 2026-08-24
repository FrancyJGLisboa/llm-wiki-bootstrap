#!/usr/bin/env bash
# scripts/gate-command-documented.sh — gate COMMAND-DOCUMENTED.
#
# RULE: every command the compiler ships is named in the operator reference
# (ADVANCED.md), and every command the reference names exists.
#
# WHY THIS GATE EXISTS: on 2026-08-24 an inventory found SEVEN of twenty-two
# commands documented nowhere at all — not in README.md, ADVANCED.md,
# START-HERE.md, docs/QUICKSTART.md, or the generated workspace's own README:
#
#   /ctx-start   — the ENTRY POINT. The one command a newcomer is meant to run
#                  first appeared in no document a newcomer would read.
#   /ctx-gate, /ctx-discover, /ctx-client-assumptions, /ctx-client-decisions,
#   /ctx-client-lint, /ctx-client-review
#
# Nothing was broken, which is why it survived: an undocumented command fails
# silently and permanently — the operator simply never learns it exists, and no
# test can notice a capability nobody invoked. scripts/gate-command-aliases.sh
# already proves every alias RESOLVES; that says nothing about whether a human
# could ever find the thing it resolves to.
#
# DETECTION: enumerate the non-alias command files, require each to be named in
# the reference by either its prefixed or short form; then reverse the check so a
# typo in the reference cannot point at a command that does not exist.
#
# FAILURE MODES — the honest ones:
#   - It proves a command is NAMED, not that the description is accurate or that
#     the flags listed are real. A wrong sentence passes.
#   - Alias files are skipped, so an alias that exists but is undocumented is not
#     reported. That is deliberate: aliases are mechanical, and the prefixed form
#     carries the meaning.
#   - The reference path is fixed to ADVANCED.md. Documenting a command somewhere
#     else does not satisfy this gate — one canonical reference is the point.
#
# RUNTIME: bash 3.2+, grep. No LLM, no network, no key.
#
# Usage:
#   scripts/gate-command-documented.sh [--repo DIR] [--count]
#
# Exit: 0 clean · 1 violations · 2 the gate could not run.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/gate-lib.sh"
gate_init "gate-command-documented" "COMMAND-DOCUMENTED"
gate_need grep

REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  REPO="${2:?--repo needs a directory}"; shift 2 ;;
    --count) GATE_COUNT_MODE=1; shift ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$REPO" ] || gate_die "not a directory: $REPO"
cd "$REPO" || gate_die "cannot enter: $REPO"

REF="ADVANCED.md"
CMDDIR=".claude/commands"
[ -d "$CMDDIR" ] || gate_die "no $CMDDIR in $REPO"
[ -f "$REF" ] || gate_die "no operator reference at $REPO/$REF"

# Forward: every non-alias command must be named in the reference.
for f in "$CMDDIR"/*.md; do
  [ -f "$f" ] || continue
  grep -qE "Alias for|Deprecated alias" "$f" && continue
  name="$(basename "$f" .md)"
  short="${name#ctx-}"
  if ! grep -qE "/(${name}|${short})\b" "$REF"; then
    gate_violation "$CMDDIR/$name.md:1" \
      "/$name is shipped but named nowhere in $REF. An undocumented command fails silently forever — the operator never learns it exists. Add a row for it."
  fi
done

# Reverse: a command named in the reference must exist, so a typo cannot invent one.
# Anchored to the backtick form. Commands are always written `/ctx-foo` in the
# reference, while scripts are written `scripts/wiki-metrics.sh` — without the
# anchor the slash inside a PATH matches and the gate reports a command that was
# never claimed to exist.
refd="$(grep -oE '`/(ctx|client|wiki)-[a-z][a-z-]*' "$REF" | sed 's/^.//' | sort -u)"
for c in $refd; do
  c="${c#/}"
  if [ ! -f "$CMDDIR/$c.md" ]; then
    line="$(grep -nE "/${c}\b" "$REF" | head -1 | cut -d: -f1)"
    gate_violation "$REF:${line:-1}" \
      "names /$c, but $CMDDIR/$c.md does not exist. Fix the name or remove the row."
  fi
done

gate_verdict "clean — every shipped command is in $REF, and every command $REF names exists."
