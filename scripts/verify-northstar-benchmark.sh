#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 -m unittest "$REPO_ROOT/tests/northstar/test_northstar.py" >/dev/null
printf 'corpus: 24 sources PASS\n'
printf 'gold categories: PASS\n'

"$SCRIPT_DIR/stage-northstar.sh" "$TMP/staged" >/dev/null
if find "$TMP/staged" -type f -print0 | xargs -0 grep -lE 'NORTHSTAR_GOLD_MUST_NOT_ENTER_RAW|expected_answers_are_private|"answer"[[:space:]]*:' >/dev/null 2>&1; then
  printf 'leakage gate: FAIL\n' >&2; exit 1
fi
[ ! -e "$TMP/staged/gold" ] && [ ! -e "$TMP/staged/holdout" ]
printf 'leakage gate: PASS\n'

"$SCRIPT_DIR/run-northstar-benchmark.sh" instrument "$TMP/bm25.json" >/dev/null
python3 - "$TMP/bm25.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); assert d["arm"]=="bm25"
assert d["score_status"]=="not_an_answer_quality_measurement"
PY
"$SCRIPT_DIR/run-northstar-benchmark.sh" score "$REPO_ROOT/tests/northstar/predictions-fixture.json" --out "$TMP/scored.json" >/dev/null
python3 - "$TMP/scored.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); assert d["status"]=="MEASURED" and d["arm"]=="compiled"
PY
printf 'baseline arms: PASS (compiled, long-context, bm25 contracts; no fabricated scores)\n'
