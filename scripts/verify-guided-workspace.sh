#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for path in \
  START-HERE.md ADVANCED.md AI-WORKSPACE.code-workspace EVIDENCE-INBOX/README.md BRIEFS/README.md REVIEWS/README.md \
  .vscode/extensions.json .vscode/tasks.json \
  .claude/commands/ctx-start.md .claude/commands/ctx-inbox.md \
  .claude/commands/ctx-create-profile.md scripts/inbox.py scripts/profile-check.py \
  scripts/profile-scaffold.py scripts/profile-readiness.py; do
  [ -f "$ROOT/$path" ] || { echo "missing guided workspace asset: $path" >&2; exit 1; }
done

python3 - "$ROOT" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
extensions = json.loads((root / ".vscode/extensions.json").read_text())
tasks = json.loads((root / ".vscode/tasks.json").read_text())
assert extensions["recommendations"], "at least one VS Code AI recommendation is required"
labels = {task["label"] for task in tasks["tasks"]}
assert labels == {
    "Context: Check setup",
    "Context: Show inbox status",
    "Context: Activate client-decision",
    "Context: Verify guided workspace",
}
start = (root / "START-HERE.md").read_text()
for phrase in ("Add this evidence", "Prepare me for", "What changed", "Why do we think", "needs my judgment"):
    assert phrase in start, phrase
for folder in ("EVIDENCE-INBOX", "BRIEFS", "REVIEWS"):
    assert folder in start
print("workspace assets: PASS")
PY

python3 "$ROOT/tests/guided-workspace/test_inbox_import.py"
python3 "$ROOT/tests/guided-workspace/test_profile_check.py"
python3 "$ROOT/tests/guided-workspace/test_profile_scaffold.py"
python3 "$ROOT/tests/guided-workspace/test_profile_readiness.py"
python3 "$ROOT/scripts/profile-check.py" --root "$ROOT" --profile client-decision >/dev/null
bash "$ROOT/scripts/gate-command-aliases.sh" >/dev/null

if [ -x "$ROOT/scripts/create-context-compiler.sh" ]; then
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/guided-workspace.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
  bash "$ROOT/scripts/create-context-compiler.sh" "$tmp/compiler" >/dev/null
  for path in START-HERE.md ADVANCED.md AI-WORKSPACE.code-workspace EVIDENCE-INBOX/README.md BRIEFS/README.md REVIEWS/README.md .vscode/tasks.json scripts/inbox.py scripts/profile-check.py scripts/profile-scaffold.py scripts/profile-readiness.py; do
    [ -f "$tmp/compiler/$path" ] || { echo "fresh compiler missing: $path" >&2; exit 1; }
  done
  [ "$(python3 "$tmp/compiler/scripts/profile-resolve.py" --root "$tmp/compiler")" = generic ]
  python3 "$tmp/compiler/scripts/profile-check.py" --root "$tmp/compiler" --profile client-decision >/dev/null
fi

echo "daily routing: PASS"
echo "guided workspace: PASS"
