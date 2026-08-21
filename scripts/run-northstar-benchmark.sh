#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  instrument)
    OUT="${2:-$SCRIPT_DIR/../benchmarks/northstar/runs/bm25-instrument.json}"
    python3 "$SCRIPT_DIR/northstar-benchmark.py" bm25-instrument --out "$OUT"
    ;;
  score)
    [ "$#" -eq 4 ] && [ "$3" = "--out" ] || { printf 'usage: %s score PREDICTIONS --out RESULT\n' "$0" >&2; exit 2; }
    python3 "$SCRIPT_DIR/northstar-benchmark.py" score --predictions "$2" --out "$4"
    ;;
  prepare)
    [ "$#" -ge 4 ] && [ "$3" = "--workspace" ] || { printf 'usage: %s prepare ARM --workspace DIR [--out FILE]\n' "$0" >&2; exit 2; }
    ARM="$2"; WORKSPACE="$4"; OUT="${6:-$SCRIPT_DIR/../benchmarks/northstar/runs/${ARM}-tasks.json}"
    [ "${5:-}" = "--out" ] || [ "$#" -eq 4 ] || { printf 'expected --out FILE\n' >&2; exit 2; }
    python3 "$SCRIPT_DIR/northstar-benchmark.py" prepare --arm "$ARM" --workspace "$WORKSPACE" --out "$OUT"
    ;;
  execute)
    [ "$#" -ge 6 ] && [ "$3" = "--workspace" ] && [ "$5" = "--tool" ] || { printf 'usage: %s execute TASKS --workspace DIR --tool claude|codex [--out FILE]\n' "$0" >&2; exit 2; }
    TASKS="$2"; WORKSPACE="$4"; TOOL="$6"; OUT="${8:-$SCRIPT_DIR/../benchmarks/northstar/runs/predictions.json}"
    [ "$TOOL" = claude ] || [ "$TOOL" = codex ] || { printf 'tool must be claude or codex\n' >&2; exit 2; }
    command -v "$TOOL" >/dev/null || { printf '%s is not installed\n' "$TOOL" >&2; exit 2; }
    python3 - "$TASKS" "$WORKSPACE" "$TOOL" "$OUT" <<'PY'
import datetime,json,pathlib,shutil,subprocess,sys,tempfile,time
tasks,workspace,tool,out=sys.argv[1:]; data=json.loads(pathlib.Path(tasks).read_text()); answers=[]; started=time.monotonic(); compiled_claim_ids=[]
if data['arm']=='compiled':
  for shard in (pathlib.Path(workspace)/'context/claims').rglob('*.jsonl'):
    for line in shard.read_text().splitlines():
      if line.strip():
        claim=json.loads(line); cid=claim.get('claim_id'); compiled_claim_ids.extend([cid] if isinstance(cid,str) else [])
for task in data['tasks']:
  with tempfile.TemporaryDirectory(prefix=f"northstar-{data['arm']}-") as isolated:
    isolated=pathlib.Path(isolated)
    for rel in task['material_files']:
      src=(pathlib.Path(workspace)/rel).resolve()
      if pathlib.Path(workspace).resolve() not in src.parents or not src.is_file(): raise SystemExit(f"missing/unsafe prepared material: {rel}")
      dst=isolated/rel; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(src,dst)
    cmd=[tool,'-p',task['prompt']] if tool=='claude' else [tool,'exec','--skip-git-repo-check','-C',str(isolated),task['prompt']]
    t=time.monotonic(); proc=subprocess.run(cmd,cwd=isolated,text=True,capture_output=True)
    if proc.returncode: raise SystemExit(f"{tool} failed for {task['id']}: {proc.stderr[-500:]}")
    raw=proc.stdout.strip(); parsed=json.loads(raw[raw.find('{'):raw.rfind('}')+1])
    parsed['id']=task['id']; parsed['elapsed_seconds']=round(time.monotonic()-t,3); parsed['isolated_material_count']=len(task['material_files']); answers.append(parsed)
payload={'arm':data['arm'],'model':f'{tool}:installed-default','tool':tool,'generated_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'elapsed_seconds':round(time.monotonic()-started,3),'compiled_claim_ids':sorted(set(compiled_claim_ids)) if data['arm']=='compiled' else [],'answers':answers}
pathlib.Path(out).write_text(json.dumps(payload,indent=2)+'\n')
print(f"executed {len(answers)} tasks with {tool}; predictions: {out}")
PY
    ;;
  *)
    printf 'usage: %s instrument [OUT] | prepare ARM --workspace DIR [--out FILE] | execute TASKS --workspace DIR --tool claude|codex [--out FILE] | score PREDICTIONS --out RESULT\n' "$0" >&2
    printf 'Model execution is external; this script never fabricates model scores.\n' >&2
    exit 2
    ;;
esac
