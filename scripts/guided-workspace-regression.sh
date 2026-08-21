#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

bash scripts/verify-guided-workspace.sh
bash scripts/verify-create-context-compiler.sh
bash scripts/verify-client-profile.sh
bash scripts/verify-claim-core.sh
bash scripts/verify-client-workflows.sh
bash scripts/verify-decision-context-integration.sh
bash scripts/verify-northstar-benchmark.sh
bash scripts/verify-bundle-roundtrip.sh
bash scripts/verify-site-claims.sh
bash scripts/quality.sh --ci
bash scripts/smoke-all.sh --no-build
git diff --check

echo "guided workspace regression: PASS"
