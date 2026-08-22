#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for required in scripts/profile-scaffold.py scripts/profile-readiness.py \
  .claude/commands/ctx-create-profile.md tests/guided-workspace/test_profile_scaffold.py \
  tests/guided-workspace/test_profile_readiness.py; do
  [ -s "$ROOT/$required" ] || { echo "missing self-service asset: $required" >&2; exit 1; }
done

python3 "$ROOT/tests/guided-workspace/test_profile_scaffold.py"
python3 "$ROOT/tests/guided-workspace/test_profile_readiness.py"

python3 - "$ROOT" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
contract = (root / ".claude/commands/ctx-create-profile.md").read_text()
for phrase in (
    "at most five short questions", "profile-scaffold.py", "acceptance.json",
    "observable expected behavior", "profile-readiness.py", "explicit yes",
    "use-profile.sh", "checkpoint-context.sh", "Add your first evidence",
):
    assert phrase in contract, phrase
extension = (root / "extensions/context-workspace/extension.js").read_text()
manifest = json.loads((root / "extensions/context-workspace/package.json").read_text())
declared = {item["command"] for item in manifest["contributes"]["commands"]}
registered = set(re.findall(r'register\("([^"]+)"', extension))
for command in ("contextWorkspace.createSpecialization", "contextWorkspace.checkSpecialization"):
    assert command in declared and command in registered, command
assert "Teach this workspace another kind of work" in extension
assert "Describe the work in ordinary language" in extension
surfaces = {
    "README": (root / "README.md").read_text(),
    "START-HERE": (root / "START-HERE.md").read_text(),
    "fresh README": (root / "templates/README-fresh.md").read_text(),
    "quickstart": (root / "docs/QUICKSTART.md").read_text(),
    "extension guide": (root / "docs/VSCODE-EXTENSION.md").read_text(),
    "GitHub page": (root / "site/index.html").read_text(),
}
for label, text in surfaces.items():
    assert "Create Specialization" in text, label
    assert "approv" in text.lower(), label
print("conversational contract: PASS")
print("VS Code journey: PASS")
PY

tmp=$(mktemp -d "${TMPDIR:-/tmp}/self-service-profile.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
bash "$ROOT/scripts/create-context-compiler.sh" "$tmp/compiler" >/dev/null

python3 "$tmp/compiler/scripts/profile-scaffold.py" --root "$tmp/compiler" \
  --name project-decision --title "Project Decisions" \
  --purpose "Reconstruct evolving project decisions and their evidence." \
  --evidence meetings --evidence "decision records" \
  --concept decision --concept alternative --concept constraint \
  --output brief --output delta \
  --review-trigger contradiction --review-trigger "ambiguous owner" >/dev/null

python3 - "$tmp/compiler/profiles/project-decision/acceptance.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
value = json.loads(path.read_text())
for case in value["cases"]:
    case["expected_behavior"] = f"Return a source-grounded {case['category']} result for the project example."
path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
PY

python3 "$tmp/compiler/scripts/profile-readiness.py" --root "$tmp/compiler" \
  --profile project-decision --approve "Test Domain Owner" --approved-at 2026-08-22 --write >/dev/null
bash "$tmp/compiler/scripts/use-profile.sh" project-decision --root "$tmp/compiler" >/dev/null
printf 'A synthetic project decision was recorded.\n' | python3 "$tmp/compiler/scripts/add-evidence.py" \
  --root "$tmp/compiler" --text-stdin --title "First project evidence" --json >/dev/null

python3 - "$tmp/compiler" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
assert json.loads((root / "context-profile.json").read_text())["profile"] == "project-decision"
assert "READY TO USE" in (root / "REVIEWS/project-decision-readiness.md").read_text()
assert any(path.is_file() for path in (root / "EVIDENCE-INBOX").iterdir() if path.name != "README.md")
for path in ("scripts/profile-scaffold.py", "scripts/profile-readiness.py"):
    assert (root / path).is_file(), path
print("fresh compiler e2e: PASS")
print("distribution and guidance: PASS")
PY

echo "self-service profile: PASS"
