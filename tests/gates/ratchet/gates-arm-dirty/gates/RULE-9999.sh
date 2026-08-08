#!/usr/bin/env bash
# Fixture stub with NO row in gates/baseline.tsv, placed under gates/ rather
# than scripts/. The single defect this tree exists to plant.
#
# gates/ is where /ctx-gate writes every gate it builds (scripts/new-gate.sh),
# so it is the path a newly generated gate takes — exactly the case the
# registration requirement exists for. Until 2026-08-08 the converse check
# scanned only scripts/gate-*.sh and context/gates/*.sh, so the first gate the
# compiler ever built for itself was exempt from the ratchet.
#
# Being unregistered is itself the violation, so this stub reports clean: the
# ratchet must fail on its ABSENCE from the baseline, not on anything it says.
set -uo pipefail
case "${1:-}" in
  --count) printf '0\t0\n'; exit 0 ;;
  *) printf 'RULE-9999: clean\n'; exit 0 ;;
esac
