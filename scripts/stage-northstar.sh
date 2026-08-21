#!/usr/bin/env bash
# Stage only public Northstar evidence into an isolated compiler workspace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BENCH="$REPO_ROOT/benchmarks/northstar"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  printf 'usage: %s TARGET_DIR\n' "$0" >&2
  exit 2
fi
case "$TARGET" in
  /|"$REPO_ROOT"|"$BENCH") printf 'stage-northstar: unsafe target: %s\n' "$TARGET" >&2; exit 2 ;;
esac

mkdir -p "$TARGET/raw"
python3 - "$BENCH" "$TARGET" <<'PY'
import json, pathlib, shutil, sys
bench, target = map(pathlib.Path, sys.argv[1:])
manifest = json.loads((bench / "manifest.json").read_text())
for item in manifest["sources"]:
    for key in ("path", "attachment"):
        rel = item.get(key)
        if not rel:
            continue
        src = (bench / rel).resolve()
        if bench.resolve() not in src.parents or "sources" not in src.parts:
            raise SystemExit(f"stage-northstar: source escapes sources/: {rel}")
        dst = target / "raw" / src.name
        shutil.copyfile(src, dst)
(target / "context-profile.json").write_text(
    '{\n  "profile": "client-decision",\n  "profile_version": 1\n}\n')
print(f"staged: {len(manifest['sources'])} synthetic sources -> {target}")
PY

