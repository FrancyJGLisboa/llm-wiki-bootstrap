#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/checkpoint-context.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.email test@example.com
git -C "$fixture" config user.name "Checkpoint Test"
mkdir -p "$fixture/raw" "$fixture/context" "$fixture/BRIEFS" "$fixture/REVIEWS"
mkdir -p "$fixture/profiles/project-decision"
printf 'base\n' > "$fixture/log.md"
git -C "$fixture" add log.md
git -C "$fixture" commit -qm base

printf 'evidence\n' > "$fixture/raw/source.txt"
printf 'compiled\n' > "$fixture/context/page.md"
printf 'profile\n' > "$fixture/profiles/project-decision/README.md"
printf '{"profile":"project-decision"}\n' > "$fixture/context-profile.json"
printf 'unrelated\n' > "$fixture/private.txt"
git -C "$fixture" add private.txt

output=$(cd "$fixture" && bash "$ROOT/scripts/checkpoint-context.sh" --message "test update")
echo "$output" | grep -q '^checkpoint: created '
changed=$(git -C "$fixture" show --name-only --format='' HEAD | LC_ALL=C sort)
[ "$changed" = $'context-profile.json\ncontext/page.md\nprofiles/project-decision/README.md\nraw/source.txt' ]
[ "$(git -C "$fixture" status --short private.txt)" = "A  private.txt" ]
[ "$(cd "$fixture" && bash "$ROOT/scripts/checkpoint-context.sh")" = "checkpoint: no changes" ]

echo "scoped checkpoint: PASS"
