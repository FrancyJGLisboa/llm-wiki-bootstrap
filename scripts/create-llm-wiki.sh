#!/usr/bin/env bash
# scripts/create-llm-wiki.sh — deprecated name for create-context-compiler.sh.
#
# The project was renamed from llm-wiki-bootstrap to context-compiler-bootstrap.
# This forwarder stays because the old path is baked into README snippets people
# have already copied, into blog posts, and into shell history. It is not
# scheduled for removal.
#
# Exit codes, stdout and stderr are whatever create-context-compiler.sh returns —
# `exec` replaces this process, so nothing here can mask a failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/create-context-compiler.sh"

[ -x "$TARGET" ] || {
  printf 'create-llm-wiki.sh: cannot find %s\n' "$TARGET" >&2
  exit 2
}

printf 'note: create-llm-wiki.sh is now create-context-compiler.sh (this alias still works)\n' >&2
exec "$TARGET" "$@"
