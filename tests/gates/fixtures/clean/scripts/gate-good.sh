#!/usr/bin/env bash
# Fixture stub: exits with whatever code its argument names.
set -uo pipefail
case "${1:-}" in
  dirty) exit "${STUB_DIRTY:-1}" ;;
  clean) exit "${STUB_CLEAN:-0}" ;;
  *) exit 2 ;;
esac
