#!/usr/bin/env bash
# scripts/auto-commit-wiki.sh — reliability: auto-commit the wiki after a turn.
#
# Invoked by the Stop hook in .claude/settings.json. Closes the "zero
# uncommitted-work window" gap: every turn that mutated raw/, wiki/, or log.md
# is committed automatically, so a wiki is never left as an unsaved working tree
# (the failure that left a real 2-week wiki at 0 commits).
#
# Commit-only — it NEVER pushes. Pushing is a separate, secret-scanned step,
# because a push to a remote is the irreversible/exposure boundary.
#
# No-ops cleanly: outside a git repo, or when raw/wiki/log.md are unchanged.
# Always exits 0 so it can never block the turn.

set -uo pipefail

# Not a git repo → nothing to do.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 0

# Only act when the wiki layers actually changed (cheap; pure-conversation turns
# exit here).
if [ -z "$(git status --porcelain -- raw wiki log.md 2>/dev/null)" ]; then
  exit 0
fi

# Commit message: newest '## ' header in log.md (the operation that just ran),
# else a generic snapshot. Strip quotes defensively.
msg=""
if [ -f log.md ]; then
  msg="$(grep -m1 '^## ' log.md 2>/dev/null | sed 's/^##[[:space:]]*//')"
fi
[ -n "$msg" ] || msg="wiki snapshot"
msg="${msg//\"/}"

git add -A
# -c commit.gpgsign=false: a Stop hook can't answer a GPG passphrase prompt;
# an unsigned auto-snapshot is the right trade for never hanging the turn.
git -c commit.gpgsign=false commit -q -m "auto: $msg" >/dev/null 2>&1 || true

exit 0
