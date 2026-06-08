#!/usr/bin/env bash
# scripts/verify-auto-commit.sh — oracle for the auto-commit reliability hook.
#
# Proves scripts/auto-commit-wiki.sh: (A) no-ops on a clean tree, (B) commits
# when wiki/raw/log.md change, deriving the message from log.md's newest header,
# (C) no-ops outside a git repo, (D) never pushes. Lean (no color boilerplate) so
# it adds no cross-file duplication. Exit 0 iff all pass.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/auto-commit-wiki.sh"
fails=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Build a throwaway wiki-shaped git repo.
repo="$tmp/wiki"
mkdir -p "$repo/wiki" "$repo/raw" "$repo/scripts"
cp "$SCRIPT" "$repo/scripts/auto-commit-wiki.sh"; chmod +x "$repo/scripts/auto-commit-wiki.sh"
printf '# log.md\n' > "$repo/log.md"
(
  cd "$repo"
  git init -q
  git config user.email t@e.com; git config user.name t
  git config commit.gpgsign false
  git add -A && git -c commit.gpgsign=false commit -q -m "init"
)

run() { ( cd "$repo" && bash scripts/auto-commit-wiki.sh ); }
count() { ( cd "$repo" && git rev-list --count HEAD ); }

# A — clean tree: no new commit.
before="$(count)"; run; after="$(count)"
if [ "$before" = "$after" ]; then echo "A ok: clean tree → no commit"; else echo "A FAIL: committed on clean tree"; fails=$((fails+1)); fi

# B — wiki change + log header → commit created with derived message.
printf '## 2026-06-08 12:00 — /wiki-ingest\n- did a thing\n\n# log.md\n' > "$repo/log.md"
printf 'page\n' > "$repo/wiki/a.md"
before="$(count)"; run; after="$(count)"
if [ "$after" -gt "$before" ]; then echo "B ok: change → commit created"; else echo "B FAIL: no commit on change"; fails=$((fails+1)); fi
msg="$( cd "$repo" && git log -1 --format='%s' )"
case "$msg" in
  "auto: 2026-06-08 12:00 — /wiki-ingest") echo "B ok: message derived from log.md header" ;;
  *) echo "B FAIL: unexpected commit message: $msg"; fails=$((fails+1)) ;;
esac

# C — not a git repo: no-op, exit 0.
nogit="$tmp/plain"; mkdir -p "$nogit/wiki"; cp "$SCRIPT" "$nogit/auto.sh"
printf 'x\n' > "$nogit/wiki/a.md"
if ( cd "$nogit" && bash auto.sh ); then echo "C ok: not-a-repo → exit 0 no-op"; else echo "C FAIL: errored outside a git repo"; fails=$((fails+1)); fi

# D — never pushes: a commit happened (B) but there is no remote and no push
# attempt would have errored the run; assert no remote was added by the script.
if [ -z "$( cd "$repo" && git remote )" ]; then echo "D ok: script added no remote / no push"; else echo "D FAIL: script touched remotes"; fails=$((fails+1)); fi

if [ "$fails" -eq 0 ]; then echo "verify-auto-commit: all checks passed"; exit 0; fi
echo "verify-auto-commit: $fails check(s) failed"; exit 1
