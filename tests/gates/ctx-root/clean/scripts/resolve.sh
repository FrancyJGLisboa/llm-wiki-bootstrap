#!/usr/bin/env bash
# Clean fixture: resolves the compiled root through ctx_root() instead of
# naming it. This is the shape AGENTS.md asks new code to take.
#
# This tree also carries the gate's NEGATIVE CONTROLS. They live here, not in
# the dirty tree, and that placement is the whole point: gate-fixtures.sh
# compares exit codes only, so a control planted in a tree that already exits 1
# proves nothing — an over-counting gate would still exit 1 and look correct.
# Planted here, each one turns an over-count into a RED clean fixture.
#
# Control 1 — whole-line comments are stripped before matching. If that strip is
# removed, the next line counts and this fixture fails:
#   for f in wiki/*.md; do :; done
#
# Control 2 — `wiki/` must be a path token, not a substring. If the pattern
# loses its left boundary guard, the three names below start matching and this
# fixture fails.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/ctx-root.sh" || exit 2
CTXDIR="$(ctx_root "$SCRIPT_DIR/..")" || exit 2
printf 'pages live under %s\n' "$CTXDIR"
printf 'unrelated paths: %s %s %s\n' meta-wiki/a.md llm-wiki/b.md my-wiki/c.md
