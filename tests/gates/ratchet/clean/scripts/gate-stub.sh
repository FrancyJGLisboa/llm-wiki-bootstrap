#!/usr/bin/env bash
# Fixture stub for scripts/gate-ratchet.sh. Not a real gate — it reports a
# fixed, known tally so the ratchet's comparison logic is what is under test,
# not some other gate's detection logic.
#
# Reports 2 violations and 1 suppression. The clean baseline records exactly
# that pair, so the ratchet must pass: at-baseline is not an increase.
set -uo pipefail
case "${1:-}" in
  --count) printf '2\t1\n'; exit 0 ;;
  *) printf 'gate-stub: 2 violation(s), 1 suppression(s)\n' >&2; exit 1 ;;
esac
