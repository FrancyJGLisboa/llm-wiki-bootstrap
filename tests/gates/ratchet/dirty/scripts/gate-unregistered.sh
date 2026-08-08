#!/usr/bin/env bash
# Fixture stub with NO row in gates/baseline.tsv.
#
# This is the escape hatch the converse check closes: a gate nobody registered
# has its count watched by nothing, so shipping a permissive gate and never
# adding it to the baseline would be a silent way to grow violations. Being
# unregistered is itself the violation.
set -uo pipefail
case "${1:-}" in
  --count) printf '0\t0\n'; exit 0 ;;
  *) printf 'gate-unregistered: clean\n'; exit 0 ;;
esac
