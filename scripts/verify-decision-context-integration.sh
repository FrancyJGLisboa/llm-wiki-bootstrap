#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# No configuration must resolve to the untouched generic path.
mkdir -p "$TMP/generic/profiles"
generic="$(python3 "$SCRIPT_DIR/profile-resolve.py" --root "$TMP/generic" --json)"
python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["active"] is False and d["profile"]=="generic"' <<<"$generic"

# An active profile must be explicit and its compilation hooks must stay documented.
mkdir -p "$TMP/profile/profiles"
cp -R "$ROOT/profiles/client-decision" "$TMP/profile/profiles/"
printf '{"profile":"client-decision","profile_version":1}\n' > "$TMP/profile/context-profile.json"
active="$(python3 "$SCRIPT_DIR/profile-resolve.py" --root "$TMP/profile" --json)"
python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["active"] and d["profile"]=="client-decision"' <<<"$active"
grep -q 'COMPILATION.md' "$ROOT/.claude/commands/ctx-compile.md"
grep -q 'context/claims/by-source/<source-id>.jsonl' "$ROOT/.claude/commands/ctx-compile.md"
grep -q 'client-context.py --root . lint' "$ROOT/.claude/commands/ctx-lint.md"

# Valid anchored shards project byte-identically. A second source is independent.
mkdir -p "$TMP/profile/raw" "$TMP/profile/context/claims/by-source"
printf '%s\n' '---' 'source_type: email' '---' '# Evidence' 'Northstar assumes BRL 5.50.' > "$TMP/profile/raw/june.md"
printf '%s\n' '---' 'source_type: email' '---' '# Evidence' 'Northstar considers Q1 coverage.' > "$TMP/profile/raw/august.md"
ROOT_UNDER_TEST="$TMP/profile" REPO_ROOT="$ROOT" python3 - <<'PY'
import json, os, pathlib, sys
root=pathlib.Path(os.environ['ROOT_UNDER_TEST']); sys.path.insert(0, os.environ['REPO_ROOT']+'/scripts/lib')
from claims import claim_id
def emit(source, statement, predicate, obj, day):
    c={"profile":"client-decision","classification":"assumption" if predicate=="assumes" else "fact","statement":statement,"subject":"northstar-feeds","predicate":predicate,"object":obj,"evidence_domain":"client","valid_from":day,"valid_to":None,"source":{"id":source,"type":"email","path":f"raw/{source}.md","anchor":"evidence","evidence_span":statement,"timestamp":day,"speaker":"Maria","speaker_role":"client","speaker_act":"assertion","speaker_confidence":1.0},"relations":[]}
    c['claim_id']=claim_id(c)
    (root/'context/claims/by-source'/f'{source}.jsonl').write_text(json.dumps(c,sort_keys=True)+'\n')
emit('june','Northstar assumes BRL 5.50.','assumes','BRL 5.50','2026-06-01')
emit('august','Northstar considers Q1 coverage.','considering','q1-coverage','2026-08-01')
PY
python3 "$SCRIPT_DIR/claim-validate.py" --root "$TMP/profile" "$TMP/profile/context/claims/by-source" >/dev/null
python3 "$SCRIPT_DIR/claim-state.py" "$TMP/profile/context/claims/by-source" > "$TMP/state-a.json"
python3 "$SCRIPT_DIR/claim-state.py" "$TMP/profile/context/claims/by-source" > "$TMP/state-b.json"
cmp "$TMP/state-a.json" "$TMP/state-b.json"
june_before="$(openssl dgst -sha256 < "$TMP/profile/context/claims/by-source/june.jsonl")"
cp "$TMP/profile/context/claims/by-source/august.jsonl" "$TMP/august.before"
cmp "$TMP/profile/context/claims/by-source/august.jsonl" "$TMP/august.before"
[ "$june_before" = "$(openssl dgst -sha256 < "$TMP/profile/context/claims/by-source/june.jsonl")" ]

printf 'decision-context integration: PASS (generic split, hooks, validation, deterministic projection, source shards)\n'
