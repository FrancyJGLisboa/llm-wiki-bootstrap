#!/usr/bin/env bash
# scripts/verify-bundle.sh — buyer-side integrity + citation-integrity check
# for a packaged wiki bundle (made by scripts/package-wiki.sh). Ships INSIDE
# the bundle so verification needs nothing from the seller.
#
# What it proves: citations RESOLVE (every claim links to a real raw anchor)
# and every claim-bearing page is COVERED (carries a citation). It does NOT
# re-prove semantic entailment (the C3 judge — that each cited passage truly
# supports its claim): that needs an LLM and is a write-time guarantee the
# seller attests to, not reproducible offline. So this is CITATION INTEGRITY,
# not "faithfulness".
#
# Checks:
#   B1  MANIFEST present and every listed file exists with a matching SHA-256
#   B2  no extra files beyond the MANIFEST (tamper/addition detection;
#       buyer-added content is expected after first use — see --post-use)
#   B3  wiki root shape: raw/, wiki/, AGENTS.md, log.md
#   B4  every citation resolves to a real raw anchor (citation-audit C1+C2)
#   B5  every claim-bearing page is sourced (citation-audit --coverage)
#
# Authenticity: if MANIFEST.sig + MANIFEST.pubkey are present (seller signed),
# the signature is verified. If absent, the bundle is UNSIGNED — integrity is
# self-referential (proves intact-since-packaging, NOT authenticity).
#
# Usage:
#   ./scripts/verify-bundle.sh [<bundle-root>] [--post-use]
#
#   <bundle-root>  defaults to the parent of scripts/ (run it in place)
#   --post-use     relax the "no unmanifested files" assertion (B2) — after
#                  the buyer starts extending the wiki, new files are expected.
#                  B1 still verifies the ORIGINAL files are intact, and B4+B5
#                  still run over the FULL current tree (new pages must still
#                  resolve their citations and be sourced).
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

# Reject symlinks: a packaged bundle never contains them (packaging refuses
# them). One under the bundle root means tampering or a non-portable asset
# that resolves to host paths — fail before trusting any hash.
sym="$(find . -type l ! -path './.git/*' | head -10)"
[ -z "$sym" ] || { echo "✗ symlink(s) under bundle root — not a portable bundle:" >&2; printf '%s\n' "$sym" | sed 's/^/  /' >&2; exit 1; }

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

# ── Authenticity (optional): verify the seller's signature if present ───────
# A bare MANIFEST proves "intact since packaging" but not WHO packaged it
# (tamper + regenerate is undetectable). If the seller signed it, prove it;
# otherwise say plainly that integrity is self-referential.
if [ -f MANIFEST.sig ] && [ -f MANIFEST.pubkey ]; then
  if ! command -v gpg >/dev/null 2>&1; then
    warn "MANIFEST.sig present but gpg not installed — authenticity unverified (install gpg to check)"
  else
    gpgtmp="$(mktemp -d "${TMPDIR:-/tmp}/verify-bundle-gpg.XXXXXX")"
    if gpg --homedir "$gpgtmp" --batch --quiet --import MANIFEST.pubkey >/dev/null 2>&1 \
       && gpg --homedir "$gpgtmp" --batch --quiet --verify MANIFEST.sig MANIFEST >/dev/null 2>&1; then
      ok "authenticity: MANIFEST signature verifies against the bundled public key"
    else
      bad "authenticity: MANIFEST signature does NOT verify — bundle may be forged or tampered"
    fi
    rm -rf "$gpgtmp"
  fi
else
  warn "UNSIGNED: no MANIFEST.sig — integrity is self-referential (intact since packaging, NOT proof of authenticity)"
fi

# ── B2: no unmanifested files (skip after the buyer starts extending) ───────
if [ "$POST_USE" -eq 1 ]; then
  warn "B2 skipped (--post-use): buyer-added files are expected"
else
  extras=$(find . -type f ! -name MANIFEST ! -name MANIFEST.sig ! -name MANIFEST.pubkey ! -path './.git/*' | sed 's|^\./||' \
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

# ── B4/B5: citations resolve + every claim-bearing page is sourced ──────────
# Missing python3 or citation-audit.py is a HARD setup error, not a pass:
# "verified" must never mean "zero citations were actually checked". B4 and B5
# run over the full current tree, so under --post-use new pages must still
# resolve their citations (B4) and be sourced (B5) — only B2 is relaxed.
PYBIN="$(command -v python3 || command -v python || true)"
[ -n "$PYBIN" ] || { echo "✗ python3 not found — cannot audit citations; 'verified' would mean nothing was checked" >&2; exit 2; }
[ -f scripts/citation-audit.py ] || { echo "✗ scripts/citation-audit.py not in bundle — cannot audit citations" >&2; exit 2; }

if "$PYBIN" scripts/citation-audit.py wiki --raw raw >/dev/null 2>&1; then
  ok "B4 citations: every citation resolves to a real raw anchor"
else
  bad "B4 citations: broken citations found (run: python3 scripts/citation-audit.py wiki --raw raw)"
fi

if "$PYBIN" scripts/citation-audit.py wiki --raw raw --coverage >/dev/null 2>&1; then
  ok "B5 coverage: every claim-bearing page carries a resolving citation"
else
  bad "B5 coverage: claim-bearing page(s) carry no citation (run: python3 scripts/citation-audit.py wiki --raw raw --coverage)"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Bundle verified. The content matches what the seller packaged."
  exit 0
fi
echo "$failures check(s) FAILED — this bundle is not what the seller packaged." >&2
exit 1
