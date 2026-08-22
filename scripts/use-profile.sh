#!/usr/bin/env bash
# Activate a validated context-compiler profile for one repository.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE=""
CLEAR=0

usage() {
  echo "usage: scripts/use-profile.sh <profile> [--root <dir>] | --clear [--root <dir>]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      ROOT="$2"; shift 2 ;;
    --clear) CLEAR=1; shift ;;
    -*) usage; exit 2 ;;
    *)
      [ -z "$PROFILE" ] || { usage; exit 2; }
      PROFILE="$1"; shift ;;
  esac
done

ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "profile setup error: root not found: $ROOT" >&2; exit 2; }
CONFIG="$ROOT/context-profile.json"

if [ "$CLEAR" -eq 1 ]; then
  [ -z "$PROFILE" ] || { usage; exit 2; }
  rm -f "$CONFIG"
  echo "profile: generic (context-profile.json removed)"
  exit 0
fi

[ -n "$PROFILE" ] || { usage; exit 2; }
resolved="$(python3 "$SCRIPT_DIR/profile-resolve.py" --root "$ROOT" --profile "$PROFILE" --json)" || exit $?
if python3 - "$ROOT/profiles/$PROFILE/profile.json" <<'PY'
import json, sys
try:
    manifest = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)
raise SystemExit(0 if "self_service" in manifest else 1)
PY
then
  python3 "$SCRIPT_DIR/profile-readiness.py" --root "$ROOT" --profile "$PROFILE" >/dev/null || {
    echo "profile setup error: $PROFILE is not ready; review REVIEWS/$PROFILE-readiness.md or run profile-readiness.py --write" >&2
    exit 1
  }
fi
version="$(printf '%s\n' "$resolved" | python3 -c 'import json,sys; print(json.load(sys.stdin)["profile_version"])')"
tmp="$(mktemp "$ROOT/.context-profile.json.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
printf '{\n  "profile": "%s",\n  "profile_version": %s\n}\n' "$PROFILE" "$version" > "$tmp"
mv "$tmp" "$CONFIG"
trap - EXIT
echo "profile: $PROFILE (version $version)"
