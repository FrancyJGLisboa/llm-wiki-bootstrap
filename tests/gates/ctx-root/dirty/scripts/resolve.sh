#!/usr/bin/env bash
# Dirty fixture: hardcodes the compiled root. Exactly one violating line, so the
# pair tests the detection and not an accumulation.
#
# The comment below must NOT count -- whole-line comments are stripped before
# matching, and a fixture that passed because of a commented path would prove
# the wrong thing:
#   for f in wiki/*.md; do :; done
set -uo pipefail
for f in wiki/*.md; do printf '%s\n' "$f"; done
