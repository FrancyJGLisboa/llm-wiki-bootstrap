#!/usr/bin/env bash
# Fixture stub for scripts/gate-ratchet.sh — the violating side.
# Identical to the clean stub: reports 2 violations and 1 suppression. What
# differs is the baseline, which records 0 and 0. Both numbers went up.
set -uo pipefail
case "${1:-}" in
  --count) printf '2\t1\n'; exit 0 ;;
  *) printf 'gate-stub: 2 violation(s), 1 suppression(s)\n' >&2; exit 1 ;;
esac
