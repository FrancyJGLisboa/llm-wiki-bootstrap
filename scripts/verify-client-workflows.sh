#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

python3 -m unittest discover -s tests/client-workflows -p 'test_*.py' >/dev/null
python3 -m py_compile scripts/client-context.py

for command in brief delta decisions assumptions why review lint; do
  test -f ".claude/commands/ctx-client-${command}.md"
  test -f ".claude/commands/client-${command}.md"
  grep -q 'profile-resolve.py' ".claude/commands/ctx-client-${command}.md"
done

grep -q 'qualified-agreement' tests/client-workflows/test_client_context.py
grep -q '"SUPERSEDED"' tests/client-workflows/test_client_context.py
grep -q '"UNKNOWN"' tests/client-workflows/test_client_context.py
grep -qx 'scripts/client-context.py' scripts/installer-skeleton-manifest.txt
grep -qx 'tests/client-workflows/test_client_context.py' scripts/installer-skeleton-manifest.txt
grep -q 'client-context.py' scripts/package-wiki.sh

echo "brief: PASS"
echo "delta: PASS"
echo "why/history: PASS"
echo "unknown/review: PASS"
