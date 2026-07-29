#!/usr/bin/env bash
# scripts/verify-hash-drift.sh — oracle for the hash-drift lint
# (wiki-lint-hash-drift.sh). Fixtures are built in a temp dir; no agent, no key.
#
#   H1 committed source clean : body matches ingested_hash → exit 0
#   H2 drift caught           : body edited after ingest → exit≠0 AND stderr names
#                               the file AND the ingested_pages now at risk
#                               (a lint that only counts fails this)
#   H3 never-ingested skipped : ingested_hash: "" → exit 0 (that's /wiki-ingest's
#                               job, not drift — noise here would train users to
#                               ignore the lint)
#   H4 unhashable not silent  : recorded hash + malformed frontmatter → exit≠0
#                               (an unverifiable commitment must not pass green)
#   H5 real raw/ clean        : the repo's own sources still match their commitments
#
# Usage: ./scripts/verify-hash-drift.sh   Exit: 0 all green, 1 a check failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

LINT="scripts/wiki-lint-hash-drift.sh"
HASHER="scripts/body-hash.sh"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/raw"; mkdir -p "$FIX"

# A raw source with a correct commitment: write body first, hash it, stamp it.
make_source() { # $1 name, $2 ingested_pages, $3 body
  local f="$FIX/$1"
  printf -- '---\ningested_hash: PLACEHOLDER\ningested_pages: [%s]\n---\n%s\n' "$2" "$3" > "$f"
  local h; h=$("$HASHER" "$f")
  LC_ALL=C sed "s/PLACEHOLDER/$h/" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

make_source clean.md 'wiki/clean-page.md' 'The committed body.'
make_source drifted.md 'wiki/alpha.md, wiki/beta.md' 'The committed body.'
printf -- '---\ningested_hash: ""\ningested_pages: []\n---\nNot ingested yet.\n' > "$FIX/fresh.md"

# H1 — a clean committed source passes
if "$LINT" "$FIX/clean.md" >/dev/null 2>&1; then ok "H1 committed source with matching body accepted"
else fail "H1 clean source flagged (body matches ingested_hash — should pass)"; fi

# H2 — edit the body after ingest; drift must be caught AND attributed
printf 'The body changed after ingest.\n' >> "$FIX/drifted.md"
err=$("$LINT" "$FIX/drifted.md" 2>&1 >/dev/null); rc=$?
miss=0
printf '%s' "$err" | grep -q 'drifted.md'   || { fail "H2 stderr does not name the drifted file"; miss=1; }
printf '%s' "$err" | grep -q 'wiki/alpha.md' || { fail "H2 stderr does not name the at-risk wiki pages"; miss=1; }
if [ "$rc" -ne 0 ] && [ "$miss" -eq 0 ]; then ok "H2 post-ingest body edit rejected; file + at-risk pages named"
elif [ "$rc" -eq 0 ]; then fail "H2 drifted source wrongly accepted (exit 0)"; fi

# H3 — never-ingested is not drift
if "$LINT" "$FIX/fresh.md" >/dev/null 2>&1; then ok "H3 never-ingested source skipped (not reported as drift)"
else fail "H3 never-ingested source flagged (ingested_hash is empty — /wiki-ingest's job)"; fi

# H4 — a commitment that cannot be recomputed must not pass green
printf -- '---\ningested_hash: deadbeefdeadbeef\nbody with no closing delimiter\n' > "$FIX/broken.md"
err=$("$LINT" "$FIX/broken.md" 2>&1 >/dev/null); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$err" | grep -q 'unhashable'; then
  ok "H4 unhashable body with a recorded hash rejected (commitment unverifiable)"
else fail "H4 unhashable body passed or was not named (rc=$rc)"; fi

# H5 — the repo's own raw sources still match their commitments
if "$LINT" raw/ >/dev/null 2>&1; then ok "H5 raw/ matches every recorded ingest commitment"
else fail "H5 raw/ has drifted sources (wiki claims cite text that changed)"; fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d hash-drift check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s H1-H5 green — drift caught and attributed, clean/never-ingested pass.\n" "$GREEN" "$RESET"
exit 0
