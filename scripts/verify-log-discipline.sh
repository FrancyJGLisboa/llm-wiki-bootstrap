#!/usr/bin/env bash
# scripts/verify-log-discipline.sh — advisory: flag a commit that changed
# wiki/*.md without recording a log.md entry.
#
# The log is the keystone of the trust+transparency model: every other soft rule
# (don't-edit-raw/, use-body-hash.sh) is only *auditable after the fact* because
# log.md records what changed, when, and why. A wiki/ mutation with no log entry
# silently removes that net. This surfaces it.
#
# WARN, not block (exit 0 always): legitimate non-logged wiki/ edits exist —
# scaffolding, a bulk reorganization, a manual typo fix. Exempt a commit on
# purpose with `[skip-log]` anywhere in its message.
#
# Range:
#   (no arg)        scan HEAD (the tip commit) — the CI/default case
#   <a>..<b>        scan every commit in the range (e.g. main..HEAD for a PR)
#
# Output: one line per flagged commit; a clean line if none. Exit 0 regardless.

set -uo pipefail

RANGE="${1:-HEAD}"

if printf '%s' "$RANGE" | grep -q '\.\.'; then
  commits="$(git rev-list "$RANGE" 2>/dev/null || true)"
else
  commits="$(git rev-list -n 1 "$RANGE" 2>/dev/null || true)"
fi

if [ -z "$commits" ]; then
  echo "log-discipline: no commits in range '$RANGE' — skipping"
  exit 0
fi

flagged=0
while IFS= read -r c; do
  [ -n "$c" ] || continue
  files="$(git show --name-only --format= "$c" 2>/dev/null)"
  # Only commits that touch a wiki page are in scope.
  printf '%s\n' "$files" | grep -qE '^wiki/.*\.md$' || continue
  # A log.md change in the same commit satisfies the rule.
  printf '%s\n' "$files" | grep -qx 'log.md' && continue
  # An explicit [skip-log] in the message exempts the commit.
  git log -1 --format='%B' "$c" 2>/dev/null | grep -qF '[skip-log]' && continue
  echo "log-discipline: ! $(git log -1 --format='%h %s' "$c") — changed wiki/ without a log.md entry (add one, or [skip-log] if intentional)"
  flagged=$((flagged + 1))
done <<EOF
$commits
EOF

if [ "$flagged" -eq 0 ]; then
  echo "log-discipline: wiki/ changes in '$RANGE' are logged (or [skip-log]-exempt)"
fi
exit 0
