#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for required in \
  START-HERE.md ADVANCED.md AI-WORKSPACE.code-workspace \
  .claude/commands/ctx-add.md .claude/commands/add.md \
  scripts/add-evidence.py tests/ai-workspace/test_add_evidence.py; do
  [ -f "$ROOT/$required" ] || { echo "missing AI workspace asset: $required" >&2; exit 1; }
done

python3 "$ROOT/tests/ai-workspace/test_add_evidence.py"

python3 - "$ROOT" <<'PY'
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
workspace = json.loads((root / "AI-WORKSPACE.code-workspace").read_text())
assert workspace["folders"] == [{"name": "My Context Workspace", "path": "."}]
excluded = workspace["settings"]["files.exclude"]
for name in ("scripts", "profiles", "tests", "raw", "context", ".claude"):
    assert excluded[f"**/{name}"] is True, name
for visible in ("START-HERE.md", "ADVANCED.md", "EVIDENCE-INBOX", "BRIEFS", "REVIEWS"):
    assert f"**/{visible}" not in excluded, visible

start = (root / "START-HERE.md").read_text()
for phrase in (
    "Add this evidence and update my context",
    "Prepare me for the Northstar meeting",
    # Was "What changed since August 1". Pinned a literal date, which collided
    # with the demo corpus's own June dates and made the onboarding eval's C2
    # ("one unambiguous start-here") fail on contradictory example queries. The
    # check's intent is that the guide shows a DELTA-shaped request, not which
    # date it names — START-HERE now says "since <your date>".
    "What changed since",
    "Show me only what needs my judgment",
    "UNKNOWN",
):
    assert phrase in start, phrase
assert not re.search(r"/ctx-(extract|inbox|compile)", start), "first-run guide exposes internal intake commands"

add = (root / ".claude/commands/ctx-add.md").read_text()
for contract in ("scripts/add-evidence.py", "/ctx-inbox", "/ctx-extract", "/ctx-compile"):
    assert contract in add, contract
assert "single user-facing evidence intake" in add

fresh = (root / "templates/README-fresh.md").read_text()
assert "AI-WORKSPACE.code-workspace" in fresh
first_run = fresh.split("## Advanced compiler controls", 1)[0]
assert "/ctx-extract" not in first_run and "/ctx-inbox" not in first_run
print("contracts: PASS")
PY

bash "$ROOT/scripts/gate-command-aliases.sh" >/dev/null

tmp=$(mktemp -d "${TMPDIR:-/tmp}/ai-workspace.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
bash "$ROOT/scripts/create-context-compiler.sh" "$tmp/compiler" >/dev/null
for required in AI-WORKSPACE.code-workspace START-HERE.md ADVANCED.md scripts/add-evidence.py .claude/commands/ctx-add.md; do
  [ -f "$tmp/compiler/$required" ] || { echo "fresh compiler missing: $required" >&2; exit 1; }
done

echo "single intake: PASS"
echo "friendly workspace: PASS"
echo "plain language: PASS"
echo "AI workspace: PASS"
