#!/usr/bin/env bash
# Create a local rollback point containing only compiler-owned context paths.
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "checkpoint: skipped (not a Git workspace)"
  exit 0
}
cd "$ROOT" || exit 0

message="context update"
if [ "${1:-}" = "--message" ]; then
  [ -n "${2:-}" ] || { echo "checkpoint: warning (--message needs text)" >&2; exit 0; }
  message=$2
  shift 2
fi
[ "$#" -eq 0 ] || { echo "checkpoint: warning (unexpected arguments)" >&2; exit 0; }

owned=()
for candidate in raw context BRIEFS REVIEWS log.md; do
  [ -e "$candidate" ] || [ -L "$candidate" ] || continue
  owned+=("$candidate")
done
[ "${#owned[@]}" -gt 0 ] || { echo "checkpoint: no compiler-owned paths"; exit 0; }

changed=()
for candidate in "${owned[@]}"; do
  [ -n "$(git status --porcelain -- "$candidate" 2>/dev/null)" ] && changed+=("$candidate")
done
if [ "${#changed[@]}" -eq 0 ]; then
  echo "checkpoint: no changes"
  exit 0
fi

# Stage only compiler-owned paths. `commit --only` ensures unrelated files that a
# user already staged remain staged but are not included in this checkpoint.
if ! git add -A -- "${changed[@]}"; then
  echo "checkpoint: warning (could not stage compiler-owned paths; context is still saved locally)" >&2
  exit 0
fi

if git -c commit.gpgsign=false commit --only -q -m "auto: $message" -- "${changed[@]}"; then
  short=$(git rev-parse --short HEAD 2>/dev/null || true)
  echo "checkpoint: created ${short:-local commit}"
else
  echo "checkpoint: warning (could not create Git checkpoint; configure user.name and user.email, then retry)" >&2
fi
exit 0
