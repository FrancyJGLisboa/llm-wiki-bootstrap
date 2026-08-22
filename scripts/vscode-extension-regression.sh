#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

bash scripts/verify-vscode-extension.sh
bash scripts/verify-ai-workspace.sh
bash scripts/verify-create-context-compiler.sh
bash scripts/smoke-all.sh --no-build --ci

echo "VS Code extension regression: PASS"
