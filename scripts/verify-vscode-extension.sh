#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
EXT="$ROOT/extensions/context-workspace"

for required in \
  docs/VSCODE-EXTENSION-SPEC.md docs/VSCODE-EXTENSION.md \
  extensions/context-workspace/package.json extensions/context-workspace/extension.js \
  extensions/context-workspace/src/core.js extensions/context-workspace/media/context.svg \
  scripts/package-vscode-extension.sh scripts/normalize-vsix.py scripts/verify-vsix.py tests/vscode-extension/core.test.js; do
  [ -s "$ROOT/$required" ] || { echo "missing extension asset: $required" >&2; exit 1; }
done

node --test "$ROOT"/tests/vscode-extension/*.test.js
python3 "$ROOT/tests/ai-workspace/test_add_evidence.py"

python3 - "$ROOT" <<'PY'
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
extension = root / "extensions/context-workspace"
manifest = json.loads((extension / "package.json").read_text())
source = (extension / "extension.js").read_text()
core = (extension / "src/core.js").read_text()
spec = (root / "docs/VSCODE-EXTENSION-SPEC.md").read_text()
guide = (root / "docs/VSCODE-EXTENSION.md").read_text()

for section in ("Required journeys", "Usability contract", "Architecture and trust boundary", "Privacy and enterprise controls", "Failure behavior", "Non-goals"):
    assert f"## {section}" in spec, section
assert manifest["capabilities"]["untrustedWorkspaces"]["supported"] is False
assert manifest["capabilities"]["virtualWorkspaces"]["supported"] is False

declared = {item["command"] for item in manifest["contributes"]["commands"]}
registered = set(re.findall(r'register\("([^"]+)"', source))
assert declared == registered, f"command mismatch declared-only={declared-registered} registered-only={registered-declared}"
for command in ("addEvidence", "prepareBrief", "showChanges", "explainWhy", "historicalState", "reviewExceptions", "checkHealth"):
    assert f"contextWorkspace.{command}" in declared, command

combined = source + core
for forbidden in ("axios", "fetch(", "https.request", "telemetry", "apiKey", "accessToken", "shell: true"):
    assert forbidden not in combined, forbidden
assert "shell: false" in core
assert "showWarningMessage" in source and "modal: true" in source
assert "--text-stdin" in core
assert "code --install-extension" in guide and "Intune" in guide and "Jamf" in guide
print("specification: PASS")
print("daily workflows: PASS")
print("security boundary: PASS")
PY

bash "$ROOT/scripts/package-vscode-extension.sh"
archive="$ROOT/dist/context-workspace-0.1.0.vsix"
first_hash=$(python3 - "$archive" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
)
bash "$ROOT/scripts/package-vscode-extension.sh" >/dev/null
second_hash=$(python3 - "$archive" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
)
[ "$first_hash" = "$second_hash" ] || { echo "VSIX builds are not byte-identical" >&2; exit 1; }
echo "reproducible VSIX: PASS ($first_hash)"

if command -v code >/dev/null; then
  install_root=$(mktemp -d "${TMPDIR:-/tmp}/context-extension-install.XXXXXX")
  trap 'rm -rf "$install_root"' EXIT
  code --extensions-dir "$install_root" --install-extension "$archive" --force >/dev/null
  code --extensions-dir "$install_root" --list-extensions --show-versions | grep -qx 'context-compiler.context-workspace@0.1.0'
  echo "VS Code install: PASS"
fi
echo "VS Code extension: PASS"
