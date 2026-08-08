#!/usr/bin/env bash
# Fixture stub under gates/ that IS registered in gates/baseline.tsv.
#
# The clean side of the gates/ arm. Without it the pair would only prove that an
# unregistered gates/*.sh fires; it would not prove that a properly registered
# one passes. A check that fired on every gates/*.sh regardless of registration
# would still show green on the dirty fixture — this stub is what rules that out.
#
# Reports 1 violation and 0 suppressions; the clean baseline records that pair
# exactly, so at-baseline must pass.
set -uo pipefail
case "${1:-}" in
  --count) printf '1\t0\n'; exit 0 ;;
  *) printf 'RULE-9999: 1 violation(s)\n' >&2; exit 1 ;;
esac
