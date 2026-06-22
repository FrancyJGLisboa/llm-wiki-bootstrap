#!/usr/bin/env bash
# scripts/verify-no-bare-urls.sh — assert the non-raw-citation guard
# (citation-audit.py --no-bare-urls) flags ANY `(source: X)` whose target isn't
# on the allowlist (raw/<file> or 'analysis') in wiki/, and passes the legal forms.
#
# The vision ships with receipts: a web source must be SNAPSHOTTED into raw/
# before citing, so the claim becomes raw-backed, coverage-counted, and
# entailment-checkable. A non-raw `(source: ...)` dodges all of that and is a
# rot-prone, never-entailment-checked external receipt — this guard makes it a
# deterministic VIOLATION. The check is an ALLOWLIST (only raw/<file> or
# 'analysis' pass), so EVERY web form is caught by construction — scheme://,
# www., bare host, uppercase, protocol-less path — with no URL parsing.
#
# Crafts a throwaway wiki covering the web variants that must ALL be flagged:
#   scheme URL       (source: https://x)              — MUST be flagged
#   uppercase WWW    (source: WWW.x/y)                — MUST be flagged
#   bare host        (source: cnn.com/madeup-story)   — MUST be flagged
#   bare domain      (source: example.com)            — MUST be flagged
#   protocol-less    (source: docs.python.org/3/x)    — MUST be flagged
# and the legal forms that must NOT be flagged:
#   raw + anchor     (source: raw/snap.md#anchor)     — MUST pass
#   raw whole-file   (source: raw/other.md)           — MUST pass
#   analysis marker  (source: analysis)               — MUST NOT be flagged
#   fenced code      ```(source: https://x)```        — MUST NOT be flagged
# and asserts: flagged page => exit 1; clean page (raw + analysis + fenced) => exit 0.
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

# Page carrying every non-raw web variant — all MUST be flagged. Each is on its
# own line so the per-line assertions below can pin the exact line number.
cat > "$tmp/wiki/bare.md" <<'EOF'
---
type: concept
---
A scheme URL claim (source: https://x).
An uppercase WWW host claim (source: WWW.x/y).
A bare-host claim (source: cnn.com/madeup-story).
A bare-domain claim (source: example.com).
A protocol-less path claim (source: docs.python.org/3/x).
EOF

# Clean page: every LEGAL form — raw+anchor, raw whole-file, analysis marker,
# and a fenced-code (source: https://x) (showing syntax, not citing) — must NOT
# be flagged.
cat > "$tmp/wiki/clean.md" <<'EOF'
---
type: concept
---
A snapshotted claim (source: raw/snap.md#anchor).
A whole-file cite (source: raw/other.md).
An interpretation note (source: analysis).

Example of a bad cite to avoid:
```
The model uses RoPE (source: https://x).
```
EOF

# 1. The mixed wiki (bare + clean) is flagged (exit 1).
report="$(python3 "$AUDIT" "$tmp/wiki" --no-bare-urls 2>&1)"; rc=$?
[ "$rc" -eq 1 ] \
  && ok "non-raw-citation guard exits 1 when a non-raw web citation is present" \
  || fail "non-raw-citation guard exited $rc (expected 1) on a page with a non-raw web URL"

# 2. EVERY web variant is reported, on its exact line.
printf '%s' "$report" | grep -q 'bare.md:4 -> (source: https://x)' \
  && ok "flags the scheme:// citation" \
  || fail "did not flag the scheme:// citation"
printf '%s' "$report" | grep -q 'bare.md:5 -> (source: WWW.x/y)' \
  && ok "flags the uppercase WWW. citation" \
  || fail "did not flag the uppercase WWW. citation"
printf '%s' "$report" | grep -q 'bare.md:6 -> (source: cnn.com/madeup-story)' \
  && ok "flags the bare-host citation" \
  || fail "did not flag the bare-host citation"
printf '%s' "$report" | grep -q 'bare.md:7 -> (source: example.com)' \
  && ok "flags the bare-domain citation" \
  || fail "did not flag the bare-domain citation"
printf '%s' "$report" | grep -q 'bare.md:8 -> (source: docs.python.org/3/x)' \
  && ok "flags the protocol-less path citation" \
  || fail "did not flag the protocol-less path citation"

# 3. No legal form (raw+anchor, raw whole-file, analysis, fenced) is flagged.
if printf '%s' "$report" | grep -qE 'raw/snap\.md|raw/other\.md|source: analysis|clean\.md'; then
  fail "false-positive: a raw/ snapshot, (source: analysis), or fenced cite was flagged"
else
  ok "raw/ cites (anchor + whole-file), (source: analysis), and fenced code are NOT flagged"
fi

# 4. Remove the bare page: the clean-only wiki (raw + analysis + fenced) passes (exit 0).
rm "$tmp/wiki/bare.md"
python3 "$AUDIT" "$tmp/wiki" --no-bare-urls >/dev/null 2>&1 \
  && ok "clean wiki (raw + analysis + fenced only) passes the guard (exit 0)" \
  || fail "guard flagged a clean wiki with no non-raw citations"

# 5. The repo's REAL wiki carries zero non-raw cites (must stay exit 0).
python3 "$AUDIT" wiki --raw raw --no-bare-urls >/dev/null 2>&1 \
  && ok "real wiki/ has zero non-raw citations" \
  || fail "real wiki/ carries a non-raw citation (snapshot it into raw/ or use 'analysis')"

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s).\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s Non-raw-citation guard flags every web form and passes raw snapshots + analysis.\n" "$GREEN" "$RESET"
exit 0
