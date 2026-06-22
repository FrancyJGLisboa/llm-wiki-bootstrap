#!/usr/bin/env bash
# scripts/verify-bundle-roundtrip.sh — end-to-end proof that the package +
# verify gates actually bite. Builds a tiny throwaway wiki, packages it, then
# tampers with it five ways and asserts verify-bundle.sh rejects each:
#
#   0. pristine bundle               → verify exits 0
#   a. modify a manifested file      → non-zero (B1 hash mismatch)
#   b. add an unmanifested file      → non-zero (B2 completeness)
#   c. break a citation              → non-zero (B4 citations)
#   d. add an uncited claim page     → non-zero (B5 coverage — proves G4/B5)
#
# Self-contained: mktemp + trap cleanup, no git, no network. Run it from
# anywhere. Exit 0 means every gate behaved as designed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE="$SCRIPT_DIR/package-wiki.sh"
[ -x "$PACKAGE" ] || { echo "error: $PACKAGE not executable" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/vbr.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() {  # check <label> <expected: 0|nonzero> <actual-exit>
  local label="$1" want="$2" got="$3"
  if { [ "$want" = "0" ] && [ "$got" -eq 0 ]; } || { [ "$want" = "nonzero" ] && [ "$got" -ne 0 ]; }; then
    echo "  ✓ $label (exit $got, expected $want)"; pass=$((pass + 1))
  else
    echo "  ✗ $label (exit $got, expected $want)" >&2; fail=$((fail + 1))
  fi
}

# ── Build a tiny fixture wiki ────────────────────────────────────────────────
WIKI="$WORK/fixture-wiki"
mkdir -p "$WIKI/raw" "$WIKI/wiki" "$WIKI/scripts"

cat > "$WIKI/raw/note.md" <<'EOF'
---
title: Source Note
type: source
source: analysis
updated: 2026-06-22
---

## Key Finding

The sky is blue under clear daytime conditions.
EOF

cat > "$WIKI/wiki/finding.md" <<'EOF'
---
title: Finding
type: concept
source: analysis
updated: 2026-06-22
---

The sky is blue under clear daytime conditions
(source: raw/note.md#key-finding).
EOF

cat > "$WIKI/AGENTS.md" <<'EOF'
# Fixture wiki schema
A throwaway wiki for verify-bundle-roundtrip.sh.
EOF

cat > "$WIKI/log.md" <<'EOF'
# Log
- 2026-06-22 fixture created.
EOF

# package-wiki ships verify-bundle.sh + citation-audit.py from THIS scripts/.
# Copy them in so the fixture is a real wiki root the packager will accept.
cp "$SCRIPT_DIR/body-hash.sh" "$WIKI/scripts/"
cp "$SCRIPT_DIR/citation-audit.py" "$WIKI/scripts/"
cp "$SCRIPT_DIR/verify-bundle.sh" "$WIKI/scripts/"

DIST="$WORK/dist"
echo "[build] packaging fixture wiki"
if ! "$PACKAGE" "$WIKI" --version vtest --out "$DIST" >/dev/null 2>&1; then
  echo "✗ packaging the pristine fixture failed — cannot run roundtrip" >&2
  "$PACKAGE" "$WIKI" --version vtest --out "$DIST" 2>&1 | sed 's/^/    /' >&2
  exit 1
fi
TARBALL="$(find "$DIST" -name '*.tar.gz' | head -1)"
[ -n "$TARBALL" ] || { echo "✗ no tarball produced" >&2; exit 1; }

# Helper: unpack a fresh copy of the bundle into a new dir, echo its root.
unpack() {
  local dst; dst="$(mktemp -d "$WORK/unpack.XXXXXX")"
  tar -xzf "$TARBALL" -C "$dst"
  find "$dst" -maxdepth 1 -type d -name 'fixture-wiki-*' | head -1
}

run_verify() {  # run_verify <bundle-root>; returns its exit code
  ( cd "$1" && ./scripts/verify-bundle.sh ) >/dev/null 2>&1
}

# ── 0. pristine ──────────────────────────────────────────────────────────────
echo "[0] pristine bundle"
B="$(unpack)"; run_verify "$B"; check "pristine verifies" 0 $?

# ── a. modify a manifested file ──────────────────────────────────────────────
echo "[a] modify a manifested file"
B="$(unpack)"; printf '\ntampered\n' >> "$B/wiki/finding.md"; run_verify "$B"
check "modified file rejected" nonzero $?

# ── b. add an unmanifested file ──────────────────────────────────────────────
echo "[b] add an unmanifested file"
B="$(unpack)"; echo "injected" > "$B/wiki/stowaway.md"; run_verify "$B"
check "unmanifested file rejected" nonzero $?

# ── c. break a citation ──────────────────────────────────────────────────────
# Repoint the citation at a raw anchor that does not exist. We must re-hash the
# edited file in the MANIFEST so B1 still passes and the failure is isolated to
# B4 (a broken citation, not a tamper).
echo "[c] break a citation"
B="$(unpack)"
python3 - "$B" <<'PY'
import hashlib, os, sys, re
root = sys.argv[1]
page = os.path.join(root, "wiki", "finding.md")
data = open(page, "rb").read().replace(b"#key-finding", b"#no-such-anchor")
open(page, "wb").write(data)
# recompute the manifest hash for this file so only B4 trips
newhash = hashlib.sha256(data).hexdigest()
man = os.path.join(root, "MANIFEST")
lines = []
for line in open(man, encoding="utf-8"):
    if line.rstrip("\n").endswith("wiki/finding.md"):
        lines.append(re.sub(r"^[0-9a-f]+", newhash, line))
    else:
        lines.append(line)
open(man, "w", encoding="utf-8").write("".join(lines))
PY
run_verify "$B"; check "broken citation rejected" nonzero $?

# ── d. add an uncited claim page (proves G4/B5) ──────────────────────────────
# A new claim-bearing page with no citation. We add it to the MANIFEST AND run
# with --post-use so B1/B2 pass cleanly — the ONLY thing that can reject it is
# the coverage gate (B5). This proves coverage is enforced over the full tree.
echo "[d] add an uncited claim page (B5 coverage)"
B="$(unpack)"
cat > "$B/wiki/uncited.md" <<'EOF'
---
title: Uncited Claim
type: concept
source: analysis
updated: 2026-06-22
---

Grass is green and water is wet, asserted with no source whatsoever.
EOF
# Manifest the new file so B1/B2 cannot be what trips (with --post-use, B2 is
# relaxed anyway; B1 only checks manifested files exist + match).
( cd "$B" && printf '%s  wiki/uncited.md\n' \
    "$(openssl dgst -sha256 < wiki/uncited.md | awk '{print $NF}')" >> MANIFEST )
( cd "$B" && ./scripts/verify-bundle.sh --post-use ) >/dev/null 2>&1
check "uncited claim page rejected by coverage" nonzero $?

# ── Verdict ──────────────────────────────────────────────────────────────────
echo
echo "roundtrip: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
echo "All package/verify gates bite as designed."
exit 0
