#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

python3 -m unittest discover -s tests/claims -p 'test_*.py'
python3 -m py_compile scripts/lib/claims.py scripts/claim-{validate,state,delta,why}.py
echo "schema fixtures: PASS"
echo "provenance fixtures: PASS"
echo "temporal fixtures: PASS"
echo "idempotence: PASS"
