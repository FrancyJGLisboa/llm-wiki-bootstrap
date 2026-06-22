#!/usr/bin/env bash
# scripts/verify-no-bare-urls.sh — assert the bare-web-URL guard
# (citation-audit.py --no-bare-urls) flags bare `(source: <url>)` cites in wiki/
# and passes raw-snapshot cites.
#
# The vision ships with receipts: a web source must be SNAPSHOTTED into raw/
# before citing, so the claim becomes raw-backed, coverage-counted, and
# entailment-checkable. A bare `(source: https://...)` dodges all of that and is
# a rot-prone link — this guard makes it a deterministic VIOLATION.
#
# Crafts a throwaway wiki with three cases:
#   bare http URL   (source: https://...)        — MUST be flagged
#   bare www URL    (source: www....)            — MUST be flagged
#   raw snapshot    (source: raw/snap.md#anchor) — MUST pass
#   analysis marker (source: analysis)           — MUST NOT be flagged
# and asserts: flagged page => exit 1; clean page (raw + analysis only) => exit 0.
#
# Exit 0 iff the guard behaves correctly.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

AUDIT="$SCRIPT_DIR/citation-audit.py"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

command -v python3 >/dev/null 2>&1 || { fail "python3 required"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/wiki"

# Page carrying bare web citations (http + www) — must be flagged.
cat > "$tmp/wiki/bare.md" <<'EOF'
---
type: concept
---
The model uses RoPE embeddings (source: https://arxiv.org/abs/2104.09864).
Another claim sourced from a www host (source: www.example.com/page#sec).
EOF

# Clean page: raw-snapshot cite + analysis marker — must NOT be flagged.
cat > "$tmp/wiki/clean.md" <<'EOF'
---
type: concept
---
A snapshotted claim (source: raw/snap.md#anchor).
An interpretation note (source: analysis).
A whole-file cite (source: raw/other.md).
EOF

# 1. The mixed wiki (bare + clean) is flagged (exit 1).
report="$(python3 "$AUDIT" "$tmp/wiki" --no-bare-urls 2>&1)"; rc=$?
[ "$rc" -eq 1 ] \
  && ok "bare-url guard exits 1 when a bare web citation is present" \
  || fail "bare-url guard exited $rc (expected 1) on a page with a bare web URL"

# 2. Both bare URLs are reported, raw/analysis are not.
printf '%s' "$report" | grep -q 'bare.md:4 -> (source: https://arxiv.org' \
  && ok "flags the bare http:// citation" \
  || fail "did not flag the bare http:// citation"
printf '%s' "$report" | grep -q 'bare.md:5 -> (source: www.example.com' \
  && ok "flags the bare www. citation" \
  || fail "did not flag the bare www. citation"
if printf '%s' "$report" | grep -qE 'raw/snap\.md|source: analysis|raw/other\.md'; then
  fail "false-positive: a raw/ snapshot or (source: analysis) was flagged as a bare URL"
else
  ok "raw/ snapshot cites and (source: analysis) are NOT flagged"
fi

# 3. Remove the bare page: the clean-only wiki passes (exit 0).
rm "$tmp/wiki/bare.md"
python3 "$AUDIT" "$tmp/wiki" --no-bare-urls >/dev/null 2>&1 \
  && ok "clean wiki (raw + analysis only) passes the guard (exit 0)" \
  || fail "guard flagged a clean wiki with no bare web URLs"

# 4. The repo's REAL wiki carries zero bare-url cites (must stay exit 0).
python3 "$AUDIT" wiki --raw raw --no-bare-urls >/dev/null 2>&1 \
  && ok "real wiki/ has zero bare web citations" \
  || fail "real wiki/ carries a bare web citation (snapshot it into raw/)"

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s).\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s Bare-web-URL guard flags bare cites and passes raw snapshots.\n" "$GREEN" "$RESET"
exit 0
