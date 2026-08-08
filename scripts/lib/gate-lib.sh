#!/usr/bin/env bash
# scripts/lib/gate-lib.sh — shared helpers for deterministic gates.
#
# WHY THIS EXISTS: every gate in this repo re-implements the same three things —
# a die-with-2 helper, a dependency check, and a violation line carrying
# path:line + rule id + how to fix. Re-implementing them is how one of them ends
# up collapsing exit 2 into exit 0, which deterministic-gates §4 names as the
# detail almost everyone forgets ("a gate that dies from a broken dependency and
# returns 0 is worse than no gate at all").
#
# This file is sourced, never executed. It sets no options and defines no state
# beyond the functions below, so sourcing it cannot change a gate's control flow.
#
# DELIBERATELY NOT HERE: a `trap ... ERR` handler. Every gate in this repo runs
# under `set -uo pipefail` WITHOUT `-e` — counters like `fails=$((fails + 1))`
# and greps that legitimately return 1 are load-bearing. An ERR trap without -e
# fires inconsistently and would read as protection that is not there.
#
# USAGE:
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/gate-lib.sh" || { echo "..." >&2; exit 2; }
#   gate_init "gate-my-rule" "MY-RULE"
#   gate_need git
#   gate_violation "path/to/file.md:14" "how to fix it"
#   gate_verdict "clean — all N inputs compliant."
#
# RUNTIME: bash 3.2+. No LLM, no network, no key.

# gate_init <script-label> <rule-id>
# Sets the two names every message needs. Call once, before anything else.
gate_init() {
  GATE_LABEL="${1:?gate_init needs a script label}"
  GATE_RULE_ID="${2:?gate_init needs a rule id}"
  GATE_VIOLATIONS=0
  GATE_SUPPRESSIONS=0
  GATE_COUNT_MODE=0
}

# gate_die <message>
# The gate itself failed: missing dependency, parse error, unreadable input.
# ALWAYS exit 2. Never 1 (that means "the code under test is wrong") and never
# 0 (that means "all clear", which is a lie a broken gate must not be able to
# tell).
gate_die() {
  printf '%s: %s\n' "${GATE_LABEL:-gate}" "$1" >&2
  exit 2
}

# gate_need <command> [<command> ...]
# A missing dependency is a gate failure, not a pass.
gate_need() {
  for _c in "$@"; do
    command -v "$_c" >/dev/null 2>&1 || gate_die "missing dependency: $_c"
  done
  unset _c
}

# gate_violation <path:line> <fix>
# One violation. Format is fixed across every gate so failure output is
# greppable and so a reader always gets told what to DO, not only what is wrong.
gate_violation() {
  GATE_VIOLATIONS=$((GATE_VIOLATIONS + 1))
  [ "${GATE_COUNT_MODE:-0}" = 1 ] && return 0
  printf '%s: %s\n' "$1" "${GATE_RULE_ID}" >&2
  printf '  FIX: %s\n' "$2" >&2
}

# gate_suppression <what> <reason>
# A declared exclusion — nolint pragma, standalone declaration, scope carve-out.
# Counted in the ratchet exactly like a violation, per deterministic-gates §6:
# "If suppression does not enter the ratchet, you will route around the gate
# instead of obeying it." Printed on every run so it is never silent.
gate_suppression() {
  GATE_SUPPRESSIONS=$((GATE_SUPPRESSIONS + 1))
  [ "${GATE_COUNT_MODE:-0}" = 1 ] && return 0
  printf '  suppressed: %s — %s\n' "$1" "$2"
}

# gate_count_mode
# True when --count was passed. In count mode a gate prints ONLY the tally line
# and exits 0 even when violations exist — the ratchet, not the gate, decides
# whether that number is acceptable. A gate that cannot run still exits 2.
gate_count_mode() { [ "${GATE_COUNT_MODE:-0}" = 1 ]; }

# gate_verdict <clean-message>
# The single exit point. Honours count mode, then reports.
gate_verdict() {
  if gate_count_mode; then
    printf '%d\t%d\n' "$GATE_VIOLATIONS" "$GATE_SUPPRESSIONS"
    exit 0
  fi
  if [ "$GATE_SUPPRESSIONS" -gt 0 ]; then
    printf '%s: %d suppression(s) — these count as violations in the ratchet.\n' \
      "$GATE_LABEL" "$GATE_SUPPRESSIONS"
  fi
  if [ "$GATE_VIOLATIONS" -gt 0 ]; then
    printf '%s: %d violation(s) — %s\n' "$GATE_LABEL" "$GATE_VIOLATIONS" "$GATE_RULE_ID" >&2
    exit 1
  fi
  printf '%s: %s\n' "$GATE_LABEL" "$1"
  exit 0
}
