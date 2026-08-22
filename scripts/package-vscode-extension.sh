#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
EXT="$ROOT/extensions/context-workspace"
RESOURCE="$EXT/resources/compiler-template"
DIST="$ROOT/dist"
VERSION=$(python3 - "$EXT/package.json" <<'PY' 2>/dev/null || true
import json
import sys
print(json.load(open(sys.argv[1]))["version"])
PY
)

[ -n "$VERSION" ] || { echo "cannot resolve extension version" >&2; exit 2; }
command -v node >/dev/null || { echo "Node.js is required" >&2; exit 2; }
command -v npm >/dev/null || { echo "npm is required" >&2; exit 2; }

case "$RESOURCE" in "$ROOT/extensions/context-workspace/resources/compiler-template") ;; *) echo "unsafe resource path" >&2; exit 2;; esac
case "$DIST" in "$ROOT/dist") ;; *) echo "unsafe dist path" >&2; exit 2;; esac

rm -rf "$RESOURCE"
mkdir -p "$RESOURCE" "$DIST"
temporary=$(mktemp -d "${TMPDIR:-/tmp}/context-workspace-vsix.XXXXXX")
trap 'rm -rf "$temporary" "$RESOURCE"' EXIT

bash "$ROOT/scripts/create-context-compiler.sh" "$temporary/compiler" >/dev/null
find "$temporary/compiler/.git" -type f -delete 2>/dev/null || true
find "$temporary/compiler/.git" -type d -empty -delete 2>/dev/null || true
rm -rf "$temporary/compiler/.git"
if [ -L "$temporary/compiler/wiki" ]; then rm "$temporary/compiler/wiki"; fi
cp -Rp "$temporary/compiler/." "$RESOURCE/"

(cd "$EXT" && npm ci --ignore-scripts --no-audit >/dev/null)
(cd "$EXT" && npx --no-install vsce package --no-dependencies --out "$DIST/context-workspace-$VERSION.vsix" >/dev/null)

python3 "$ROOT/scripts/normalize-vsix.py" "$DIST/context-workspace-$VERSION.vsix"
python3 "$ROOT/scripts/verify-vsix.py" "$DIST/context-workspace-$VERSION.vsix"
printf 'VSIX: %s\n' "$DIST/context-workspace-$VERSION.vsix"
