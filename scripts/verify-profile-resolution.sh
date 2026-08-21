#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$REPO_ROOT/tests/profiles"
fail() { echo "profile resolution: FAIL — $*" >&2; exit 1; }

generic="$(python3 "$SCRIPT_DIR/profile-resolve.py" --root "$FIXTURES/generic" --json)" || fail "generic resolution returned non-zero"
printf '%s' "$generic" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["profile"]=="generic" and d["active"] is False and d["source"]=="default"' \
  || fail "missing config did not resolve to generic"

configured="$(python3 "$SCRIPT_DIR/profile-resolve.py" --root "$FIXTURES/configured" --json)" || fail "configured resolution returned non-zero"
printf '%s' "$configured" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["profile"]=="client-decision" and d["profile_version"]==1 and d["source"]=="config"' \
  || fail "valid config did not resolve"

override="$(python3 "$SCRIPT_DIR/profile-resolve.py" --root "$FIXTURES/override" --profile client-decision --json)" || fail "override returned non-zero"
printf '%s' "$override" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["profile"]=="client-decision" and d["source"]=="override"' \
  || fail "explicit override did not win"
generic_override="$(python3 "$SCRIPT_DIR/profile-resolve.py" --root "$FIXTURES/configured" --profile generic --json)" || fail "generic override returned non-zero"
printf '%s' "$generic_override" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["profile"]=="generic" and d["active"] is False and d["source"]=="override"' \
  || fail "explicit generic override did not disable the configured profile"

for fixture in malformed missing-profile unknown-profile bad-manifest version-mismatch mismatch traversal; do
  err="$(mktemp)"
  if python3 "$SCRIPT_DIR/profile-resolve.py" --root "$FIXTURES/$fixture" --json >/dev/null 2>"$err"; then
    rm -f "$err"; fail "$fixture was accepted"
  else
    rc=$?
  fi
  [ "$rc" -eq 2 ] || { rm -f "$err"; fail "$fixture exited $rc, expected 2"; }
  grep -q 'profile setup error:' "$err" || { rm -f "$err"; fail "$fixture lacked actionable setup output"; }
  rm -f "$err"
done
echo "invalid profile rejected"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/profiles"
cp -R "$FIXTURES/configured/profiles/client-decision" "$work/profiles/"
bash "$SCRIPT_DIR/use-profile.sh" client-decision --root "$work" >/dev/null
python3 "$SCRIPT_DIR/profile-resolve.py" --root "$work" --json | python3 -c 'import json,sys; assert json.load(sys.stdin)["profile"]=="client-decision"' \
  || fail "use-profile did not activate the validated profile"
bash "$SCRIPT_DIR/use-profile.sh" --clear --root "$work" >/dev/null
[ ! -e "$work/context-profile.json" ] || fail "--clear left context-profile.json behind"

grep -qx 'scripts/profile-resolve.py' "$REPO_ROOT/scripts/installer-skeleton-manifest.txt" \
  || fail "fresh installer omits profile resolver"
grep -qx 'scripts/use-profile.sh' "$REPO_ROOT/scripts/installer-skeleton-manifest.txt" \
  || fail "fresh installer omits profile selector"
grep -qx 'scripts/client-context.py' "$REPO_ROOT/scripts/installer-skeleton-manifest.txt" \
  || fail "fresh installer omits client workflow runtime"
grep -qx 'profiles/client-decision/profile.json' "$REPO_ROOT/scripts/installer-skeleton-manifest.txt" \
  || fail "fresh installer omits the client-decision profile"
grep -qx '.claude/commands/ctx-client-brief.md' "$REPO_ROOT/scripts/installer-skeleton-manifest.txt" \
  || fail "fresh installer omits client workflow commands"
grep -qx 'scripts/verify-client-workflows.sh' "$REPO_ROOT/scripts/installer-skeleton-manifest.txt" \
  || fail "fresh installer omits client workflow verification"
if grep -qx 'context-profile.json' "$REPO_ROOT/scripts/installer-skeleton-manifest.txt"; then
  fail "fresh installer activates a profile instead of remaining generic"
fi
grep -q '^copy_if profiles$' "$REPO_ROOT/scripts/package-wiki.sh" \
  || fail "bundle packaging omits profile definitions"
grep -q 'client-context.py' "$REPO_ROOT/scripts/package-wiki.sh" \
  || fail "bundle packaging omits client workflow runtime"

echo "profile resolution: PASS"
