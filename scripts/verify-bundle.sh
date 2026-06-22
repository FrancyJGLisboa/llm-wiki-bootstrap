#!/usr/bin/env bash
# scripts/verify-bundle.sh — buyer-side integrity + faithfulness check for a
# packaged wiki bundle (made by scripts/package-wiki.sh). Ships INSIDE the
# bundle so verification needs nothing from the seller.
#
# Checks:
#   B1  MANIFEST present and every listed file exists with a matching SHA-256
#   B2  no extra files beyond the MANIFEST (tamper/addition detection;
#       buyer-added content is expected after first use — see --post-use)
#   B3  wiki root shape: raw/, wiki/, AGENTS.md, log.md
#   B4  every citation resolves to a real raw anchor (citation-audit C1+C2;
#       skipped with a warning if python3 is absent)
#
# Usage:
#   ./scripts/verify-bundle.sh [<bundle-root>] [--post-use]
#
#   <bundle-root>  defaults to the parent of scripts/ (run it in place)
#   --post-use     skip B2 — after the buyer starts extending the wiki,
#                  new files are expected; hashes of ORIGINAL files (B1)
#                  still verify the purchased content is intact
#
# Exit codes: 0 all checks pass, 1 a check failed, 2 setup error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
POST_USE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --post-use) POST_USE=1; shift ;;
    -*) echo "error: unknown flag: $1 (usage: verify-bundle.sh [<bundle-root>] [--post-use])" >&2; exit 2 ;;
    *) ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "error: no such directory: $1" >&2; exit 2; }; shift ;;
  esac
done

failures=0
ok()   { printf '✓ %s\n' "$1"; }
bad()  { printf '✗ %s\n' "$1" >&2; failures=$((failures + 1)); }
warn() { printf '⚠ %s\n' "$1"; }

cd "$ROOT" || exit 2
[ -f MANIFEST ] || { echo "✗ no MANIFEST at $ROOT — not a packaged bundle (or it was removed)" >&2; exit 1; }

# ── B1: every manifested file exists and hashes match ───────────────────────
b1_bad=0
checked=0
while IFS= read -r line; do
  case "$line" in \#*|"") continue ;; esac
  hash="${line%%  *}"; path="${line#*  }"
  if [ ! -f "$path" ]; then
    echo "  missing: $path" >&2; b1_bad=$((b1_bad + 1)); continue
  fi
  actual="$(openssl dgst -sha256 < "$path" | awk '{print $NF}')"
  if [ "$actual" != "$hash" ]; then
    echo "  modified: $path" >&2; b1_bad=$((b1_bad + 1))
  fi
  checked=$((checked + 1))
done < MANIFEST
if [ "$b1_bad" -eq 0 ]; then ok "B1 integrity: $checked files match the MANIFEST"
else bad "B1 integrity: $b1_bad file(s) missing or modified since packaging"; fi

# ── B2: no unmanifested files (skip after the buyer starts extending) ───────
if [ "$POST_USE" -eq 1 ]; then
  warn "B2 skipped (--post-use): buyer-added files are expected"
else
  extras=$(find . -type f ! -name MANIFEST ! -path './.git/*' | sed 's|^\./||' \
    | LC_ALL=C sort | comm -23 - <(grep -v '^#' MANIFEST | sed 's/^[^ ]*  //' | LC_ALL=C sort) | head -10)
  if [ -z "$extras" ]; then ok "B2 completeness: no files beyond the MANIFEST"
  else bad "B2 completeness: unmanifested files present (first 10):"; printf '%s\n' "$extras" | sed 's/^/  /' >&2; fi
fi

# ── B3: wiki root shape ─────────────────────────────────────────────────────
if [ -d raw ] && [ -d wiki ] && [ -f AGENTS.md ] && [ -f log.md ]; then
  ok "B3 shape: raw/ wiki/ AGENTS.md log.md present"
else
  bad "B3 shape: not a complete wiki root"
fi

# ── B4: citations resolve ───────────────────────────────────────────────────
PYBIN="$(command -v python3 || command -v python || true)"
if [ -z "$PYBIN" ]; then
  warn "B4 skipped: python3 not found (install it to audit citations)"
elif [ ! -f scripts/citation-audit.py ]; then
  warn "B4 skipped: scripts/citation-audit.py not in bundle"
elif "$PYBIN" scripts/citation-audit.py wiki --raw raw >/dev/null 2>&1; then
  ok "B4 citations: every citation resolves to a real raw anchor"
else
  bad "B4 citations: broken citations found (run: python3 scripts/citation-audit.py wiki --raw raw)"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Bundle verified. The content matches what the seller packaged."
  exit 0
fi
echo "$failures check(s) FAILED — this bundle is not what the seller packaged." >&2
exit 1
