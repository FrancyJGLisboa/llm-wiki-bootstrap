#!/usr/bin/env bash
# scripts/package-wiki.sh — package a wiki into a versioned, verifiable,
# distributable bundle (the "sellable second brain" artifact).
#
# The bundle is built from an INCLUDE list, never an exclude list, so junk
# (.git, sessions, inbox/, dist/, env files) cannot leak in by omission:
#
#   raw/  wiki/  AGENTS.md  log.md                      (the knowledge asset)
#   .claude/commands/  CLAUDE.md  GEMINI.md  .clinerules
#   .cursor/  .github/copilot-instructions.md            (tool shims, if present)
#   scripts/{body-hash,preflight,verify-extract,vtt-to-md,verify-bundle}.sh
#   scripts/citation-audit.py  scripts/lib/  scripts/synthesize/
#   templates/                                           (runtime, if present)
#   + generated: MANIFEST  BUYER-README.md  LICENSE (stub if none exists)
#
# Packaging REFUSES to ship a wiki that fails its own quality gates:
#   G1  every raw file hashes cleanly (catches malformed frontmatter)
#   G2  every wiki page has the required frontmatter keys
#   G3  every citation resolves — citation-audit.py C1+C2, zero BAD
#   G4  every claim-bearing page is sourced — citation-audit.py --coverage
#       (a wiki of uncited claims would otherwise package clean)
#
# The buyer verifies the artifact with the bundled scripts/verify-bundle.sh
# (MANIFEST hash check + the same citation audit), needing no seller infra.
#
# Scope of the integrity claim: the bundle proves citations RESOLVE (G3) and
# every claim-bearing page is COVERED (G4). Semantic entailment — that each
# cited passage actually supports its claim, the C3 judge — is a WRITE-TIME
# guarantee the seller attests to; it needs an LLM and is not reproduced here.
#
# Usage:
#   scripts/package-wiki.sh [<wiki-root>] [--version <v>] [--out <dir>]
#
#   <wiki-root>  defaults to the parent of scripts/ (this wiki)
#   --version    bundle version (default: v<YYYY.MM.DD>)
#   --out        output directory (default: <wiki-root>/dist)
#
# Exit codes:
#   0  bundle written
#   1  quality gate failed — nothing shipped
#   2  setup error (not a wiki root, python3 missing, tar missing)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="v$(date +%Y.%m.%d)"
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:?--version needs a value}"; shift 2 ;;
    --out) OUT="${2:?--out needs a directory}"; shift 2 ;;
    -*) echo "error: unknown flag: $1 (usage: package-wiki.sh [<wiki-root>] [--version <v>] [--out <dir>])" >&2; exit 2 ;;
    *) ROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "error: no such directory: $1" >&2; exit 2; }; shift ;;
  esac
done
OUT="${OUT:-$ROOT/dist}"

fail() { echo "✗ $1" >&2; exit "${2:-1}"; }
ok()   { echo "✓ $1"; }

# ── Setup checks ────────────────────────────────────────────────────────────
[ -d "$ROOT/raw" ] && [ -d "$ROOT/wiki" ] && [ -f "$ROOT/AGENTS.md" ] && [ -f "$ROOT/log.md" ] \
  || fail "$ROOT is not a wiki root (needs raw/, wiki/, AGENTS.md, log.md)" 2
PYBIN="$(command -v python3 || command -v python || true)"
[ -n "$PYBIN" ] || fail "python3 required — packaging will not ship unaudited citations" 2
command -v tar >/dev/null 2>&1 || fail "tar required" 2

# Refuse symlinks: a portable asset must not depend on host paths (a symlink
# like raw/leak.md -> /tmp/secret would resolve on the buyer's machine, not
# ship its target). cp -Rp + tar store symlinks verbatim, so reject up front.
symlinks="$(find "$ROOT" -path "$ROOT/.git" -prune -o -type l -print | head -10)"
[ -z "$symlinks" ] || { printf '  symlink: %s\n' $symlinks >&2; fail "symlinks present — a portable asset must not depend on host paths; remove them before packaging" 2; }

NAME="$(basename "$ROOT" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')"
BUNDLE="${NAME}-${VERSION}"
echo "packaging: $ROOT → $OUT/$BUNDLE.tar.gz"
echo

# ── Gate G1: every raw markdown file hashes cleanly ─────────────────────────
g1_bad=0
for f in "$ROOT"/raw/*.md; do
  [ -e "$f" ] || continue
  "$SCRIPT_DIR/body-hash.sh" "$f" >/dev/null 2>&1 || { echo "  malformed frontmatter: $f" >&2; g1_bad=$((g1_bad + 1)); }
done
[ "$g1_bad" -eq 0 ] || fail "G1 raw frontmatter: $g1_bad file(s) malformed — fix before packaging"
ok "G1 raw frontmatter: all raw files hash cleanly"

# ── Gate G2: wiki pages carry required frontmatter keys ─────────────────────
g2_bad=0
for f in "$ROOT"/wiki/*.md; do
  [ -e "$f" ] || continue
  fm="$(awk '/^---$/{n++; next} n>=2{exit} n==1' "$f")"  # frontmatter block (between the first two ---)
  for key in title type source updated; do
    printf '%s\n' "$fm" | grep -q "^$key:" || { echo "  missing '$key:' in frontmatter: $f" >&2; g2_bad=$((g2_bad + 1)); }
  done
done
[ "$g2_bad" -eq 0 ] || fail "G2 wiki frontmatter: $g2_bad missing key(s) — fix before packaging"
ok "G2 wiki frontmatter: all pages carry title/type/source/updated"

# ── Gate G3: every citation resolves (C1+C2 deterministic floor) ────────────
if ! "$PYBIN" "$SCRIPT_DIR/citation-audit.py" "$ROOT/wiki" --raw "$ROOT/raw" >/dev/null 2>&1; then
  "$PYBIN" "$SCRIPT_DIR/citation-audit.py" "$ROOT/wiki" --raw "$ROOT/raw" 2>&1 | grep -i bad | head -5 >&2
  fail "G3 citations: broken citations found — a buyer would catch this; fix before packaging"
fi
ok "G3 citations: every citation resolves to a real raw anchor"

# ── Gate G4: every claim-bearing page is sourced (coverage) ─────────────────
if ! "$PYBIN" "$SCRIPT_DIR/citation-audit.py" "$ROOT/wiki" --raw "$ROOT/raw" --coverage >/dev/null 2>&1; then
  "$PYBIN" "$SCRIPT_DIR/citation-audit.py" "$ROOT/wiki" --raw "$ROOT/raw" --coverage 2>&1 | grep '✗' | head -5 >&2
  fail "G4 coverage: claim-bearing page(s) carry no citation — a buyer would catch this; cite them or set 'provenance: none'"
fi
ok "G4 coverage: every claim-bearing page carries a resolving citation"

# ── Stage the bundle (include list only) ────────────────────────────────────
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/package-wiki.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
DEST="$STAGE/$BUNDLE"
mkdir -p "$DEST"

copy_if() {  # copy_if <relative-path>  (file or directory; silent if absent)
  local rel="$1"
  [ -e "$ROOT/$rel" ] || return 0
  mkdir -p "$DEST/$(dirname "$rel")"
  cp -Rp "$ROOT/$rel" "$DEST/$rel"
}

copy_if raw
copy_if wiki
copy_if AGENTS.md
copy_if log.md
copy_if LICENSE
copy_if CLAUDE.md
copy_if GEMINI.md
copy_if .clinerules
copy_if .cursor
copy_if .github/copilot-instructions.md
copy_if .claude/commands
copy_if templates
for s in body-hash.sh preflight.sh verify-extract.sh vtt-to-md.sh verify-bundle.sh citation-audit.py; do
  copy_if "scripts/$s"
done
copy_if scripts/lib
copy_if scripts/synthesize

# Generated: LICENSE stub if the seller has none.
if [ ! -f "$DEST/LICENSE" ]; then
  cat > "$DEST/LICENSE" <<'EOF'
ALL RIGHTS RESERVED — SELLER: FILL THIS IN BEFORE DISTRIBUTING.

This knowledge bundle is sold, not open-sourced. State here what the buyer
may do (use, modify, extend privately) and may not do (redistribute, resell).
EOF
fi

# Generated: buyer-facing README.
cat > "$DEST/BUYER-README.md" <<EOF
# $NAME — knowledge bundle $VERSION

This is an LLM-wiki: a curated, cross-linked, provenance-tracked knowledge
base. You query it with the AI tool you already use — no service, no account.

## Use it (2 minutes)

1. Unpack this bundle anywhere and open the directory in an agentic AI tool
   (Claude Code: \`cd\` here, run \`claude\`). Run \`./scripts/preflight.sh\`
   to confirm your environment.
2. Ask your first question: \`/wiki-query "<anything about this topic>"\`
3. Every answer cites its sources — raw material ships in \`raw/\`, claims
   link to it. Verify citation integrity (intact + citations resolve +
   every claim-bearing page is sourced) at any time:

       ./scripts/verify-bundle.sh

4. The wiki is yours to extend: \`/wiki-extract <your-source>\` then
   \`/wiki-ingest\`. Your additions never overwrite the purchased provenance.

Integrity: MANIFEST lists a SHA-256 for every file in this bundle.
EOF

# Generated: MANIFEST (hash everything staged, except MANIFEST itself).
(
  cd "$DEST" || exit 2
  file_list="$(find . -type f | LC_ALL=C sort)"
  {
    echo "# MANIFEST — $NAME $VERSION — generated $(date '+%Y-%m-%d %H:%M')"
    echo "# verify with: ./scripts/verify-bundle.sh"
    printf '%s\n' "$file_list" | while IFS= read -r f; do
      printf '%s  %s\n' "$(openssl dgst -sha256 < "$f" | awk '{print $NF}')" "${f#./}"
    done
  } > MANIFEST
)
# Optional authenticity: if a signing key is named (WIKI_SIGN_KEY) and gpg is
# present, emit a detached signature of the MANIFEST + the public key, so the
# buyer can verify "genuinely from you". Otherwise the bundle is UNSIGNED and
# integrity only proves "intact since packaging", not authenticity.
if [ -n "${WIKI_SIGN_KEY:-}" ] && command -v gpg >/dev/null 2>&1; then
  if gpg --batch --yes --local-user "$WIKI_SIGN_KEY" --detach-sign --armor \
       --output "$DEST/MANIFEST.sig" "$DEST/MANIFEST" 2>/dev/null \
     && gpg --batch --yes --armor --export "$WIKI_SIGN_KEY" > "$DEST/MANIFEST.pubkey" 2>/dev/null \
     && [ -s "$DEST/MANIFEST.pubkey" ]; then
    ok "signed MANIFEST with key $WIKI_SIGN_KEY (MANIFEST.sig + MANIFEST.pubkey bundled)"
  else
    rm -f "$DEST/MANIFEST.sig" "$DEST/MANIFEST.pubkey"
    echo "⚠ signing requested (WIKI_SIGN_KEY=$WIKI_SIGN_KEY) but gpg failed — bundle is UNSIGNED" >&2
  fi
else
  echo "⚠ UNSIGNED bundle: integrity proves 'intact since packaging', not authenticity (set WIKI_SIGN_KEY + gpg to sign)"
fi

files=$(find "$DEST" -type f | wc -l | tr -d ' ')
ok "staged $files files; MANIFEST written"

# ── Tar it up ───────────────────────────────────────────────────────────────
mkdir -p "$OUT"
tar -czf "$OUT/$BUNDLE.tar.gz" -C "$STAGE" "$BUNDLE" || fail "tar failed" 2
size=$(du -h "$OUT/$BUNDLE.tar.gz" | awk '{print $1}')
echo
ok "bundle: $OUT/$BUNDLE.tar.gz ($size, $files files)"
echo
echo "Before distributing:"
echo "  1. Fill in $BUNDLE/LICENSE (a stub was generated unless you ship your own)."
echo "  2. Confirm raw/ contains ONLY content you have the right to redistribute."
echo "  3. For authenticity, package with WIKI_SIGN_KEY=<your-gpg-id> set (signs"
echo "     the MANIFEST), or sign the tarball: gpg --detach-sign \"$OUT/$BUNDLE.tar.gz\""
exit 0
