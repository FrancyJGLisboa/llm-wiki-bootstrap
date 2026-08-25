#!/usr/bin/env bash
# scripts/gate-definition-consistent.sh — gate DEFINITION-CONSISTENT.
#
# RULE: the project describes itself with ONE sentence, and that sentence appears
# verbatim on every primary surface. No surface may call the product a "second
# brain" except the passage that explicitly denies the label.
#
# WHY THIS GATE EXISTS: on 2026-08-25 an audit of every explanation surface found
# SIX competing framings of what this project is, two of them contradictory:
#
#   context compiler      docs/CONTEXT-COMPILER.md, AGENTS.md
#   build system          docs/EXPLAIN.md ("make for your understanding")
#   factory / starter kit README.md, site/index.html
#   AI workspace          START-HERE.md
#   second brain          docs/SELLING.md — titled "the productized second brain"
#   LLM-wiki knowledge base  AGENTS.md, two sentences after it said "compiler"
#
# docs/CONTEXT-COMPILER.md carries a section headed "Not a second brain" while a
# sibling doc used that exact label in its TITLE. AGENTS.md contradicted itself
# within one paragraph. None of this broke a test, because prose that disagrees
# with prose produces no red — the same reason gate-doc-claims.sh had to exist for
# numbers and gate-doc-paths.sh for paths.
#
# A reader who meets three framings concludes the authors do not know what they
# built. That is the failure this prevents.
#
# DETECTION: extract the canonical sentence from the first bolded line of the
# reference doc, then require it (whitespace-normalised, so line wrapping and HTML
# markup do not matter) in every surface. Then scan for the forbidden label.
#
# FAILURE MODES — the honest ones:
#   - It proves the sentence is PRESENT, not that the surrounding prose agrees
#     with it. A page can carry the sentence and still argue something else.
#   - Only the listed surfaces are checked. A seventh framing invented in a new
#     file is invisible until that file is added here.
#   - "second brain" is matched literally; a synonym ("personal knowledge base")
#     passes. The literal is what actually rotted, so that is what is pinned.
#
# RUNTIME: bash 3.2+, grep, tr. No LLM, no network, no key.
#
# Usage:
#   scripts/gate-definition-consistent.sh [--repo DIR] [--count]
#
# Exit: 0 clean · 1 violations · 2 the gate could not run.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/gate-lib.sh"
gate_init "gate-definition-consistent" "DEFINITION-CONSISTENT"
gate_need grep tr git

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

REF="docs/WHAT-IS-THIS.md"
[ -f "$REF" ] || gate_die "no reference definition at $REPO/$REF"

# Whitespace-normalised text, so a wrapped line and an HTML paragraph compare equal.
flat() { tr '\n' ' ' < "$1" | tr -s '[:space:]' ' '; }

# The canonical sentence is the first bolded line of the reference doc.
DEF="$(flat "$REF" | sed -e 's/^.*\*\*A context compiler turns/A context compiler turns/' -e 's/\*\*.*$//')"
DEF="$(printf '%s' "$DEF" | sed -e 's/^ *//' -e 's/ *$//')"
case "$DEF" in
  "A context compiler turns"*) : ;;
  *) gate_die "could not extract the canonical sentence from $REF — expected a bolded line starting 'A context compiler turns'" ;;
esac

for surface in README.md START-HERE.md AGENTS.md site/index.html; do
  [ -f "$surface" ] || { gate_violation "$surface:1" "primary surface is missing entirely."; continue; }
  case "$(flat "$surface")" in
    *"$DEF"*) : ;;
    *) gate_violation "$surface:1" \
         "does not carry the canonical definition from $REF. Six competing framings is what this gate exists to prevent — paste the sentence verbatim, or change $REF and every surface together." ;;
  esac
done

# The label the essay explicitly denies. Three exemptions, each for a reason:
#   - the two docs that DENY the label are supposed to contain it;
#   - this gate names it to search for it;
#   - log.md and LEARNINGS.md are dated history, and rewriting an accurate record
#     of what the project used to call itself would be falsifying it. Same carve-out
#     scripts/gate-doc-paths.sh makes, for the same reason.
# Tracked files only, so build output under dist/ never enters the scan.
allowed() {
  case "$1" in
    docs/CONTEXT-COMPILER.md|docs/WHAT-IS-THIS.md) return 0 ;;
    scripts/gate-definition-consistent.sh)         return 0 ;;
    log.md|LEARNINGS.md)                           return 0 ;;
  esac
  return 1
}
# Prefer git so .gitignore keeps build output out of the scan; fall back to a
# walk so a fixture tree does not need a nested .git (a nested repo inside tests/
# becomes a gitlink in the parent and is worse than the problem it solves).
_files="$(git ls-files '*.md' '*.html' 2>/dev/null)"
[ -n "$_files" ] || _files="$(find . -type f \( -name '*.md' -o -name '*.html' \) \
  -not -path './.git/*' -not -path './node_modules/*' 2>/dev/null | sed 's|^\./||')"
for f in $_files; do
  [ -f "$f" ] || continue
  allowed "$f" && continue
  grep -qi 'second brain' "$f" 2>/dev/null || continue
  line="$(grep -ni 'second brain' "$f" | head -1 | cut -d: -f1)"
  gate_violation "$f:${line:-1}" \
    "calls the product a \"second brain\", which docs/CONTEXT-COMPILER.md explicitly denies in its \"Not a second brain\" section. Pick one."
done

gate_verdict "clean — one definition, carried verbatim by every primary surface."
