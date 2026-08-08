#!/usr/bin/env bash
set -uo pipefail
gate_die() { printf 'broke: %s\n' "$1" >&2; exit 2; }
command -v awk >/dev/null || gate_die "missing awk"
exit 0
