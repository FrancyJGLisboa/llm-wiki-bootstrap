#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

bash scripts/verify-ai-workspace.sh
bash scripts/guided-workspace-regression.sh

echo "ai workspace regression: PASS"
