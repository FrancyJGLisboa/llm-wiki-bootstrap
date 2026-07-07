#!/usr/bin/env bash
# scripts/verify-wiki-to-okf.sh — verify scripts/wiki-to-okf.py holds its four
# export guarantees, against the real wiki and a minimal fixture.
#
# The four guarantees (the agreed loss function for OKF export):
#   (a) every exported non-reserved .md has parseable frontmatter, non-empty type
#   (b) zero unconverted canonical wikilinks remain in the output
#   (c) deterministic — a rerun on unchanged input is byte-identical
#   (d) read-only on the source — wiki/ and raw/ are untouched by an export
#
# (a) and (b) are enforced in-process by `wiki-to-okf.py --check`; this script
# adds (c) determinism and (d) read-only, plus a fixture proving the field
# mapping ([[link]]→md, updated→timestamp, TL;DR→description) actually happens.
#
# Usage:   ./scripts/verify-wiki-to-okf.sh
# Exit:    0 all checks passed · 1 a check failed · 2 setup error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYBIN="$(command -v python3 || command -v python || true)"
[ -n "$PYBIN" ] || { echo "python3 required" >&2; exit 2; }

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
fails=0
pass() { echo "${GREEN}✓${RESET} $1"; }
fail() { echo "${RED}✗${RESET} $1" >&2; fails=$((fails + 1)); }
# assert <label> <cmd...> — pass if cmd succeeds, fail otherwise. The wrapped
# command's own output is swallowed; we print our own labelled line.
assert()  { local l="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$l"; else fail "$l"; fi; }
# refute <label> <cmd...> — pass if cmd FAILS (the condition must not hold).
refute()  { local l="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$l"; else pass "$l"; fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/verify-okf.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# ── (a)+(b) on the real wiki, via --check ────────────────────────────────────
if "$PYBIN" "$SCRIPT_DIR/wiki-to-okf.py" --out "$TMP/real" --check >/dev/null 2>&1; then
  pass "(a) non-empty type + (b) zero unconverted wikilinks — real wiki"
else
  "$PYBIN" "$SCRIPT_DIR/wiki-to-okf.py" --out "$TMP/real" --check 2>&1 | grep '✗' >&2 || true
  fail "(a)/(b) failed on the real wiki"
fi

# ── (c) determinism: two exports byte-identical ──────────────────────────────
"$PYBIN" "$SCRIPT_DIR/wiki-to-okf.py" --out "$TMP/det1" >/dev/null 2>&1
"$PYBIN" "$SCRIPT_DIR/wiki-to-okf.py" --out "$TMP/det2" >/dev/null 2>&1
if diff -rq "$TMP/det1" "$TMP/det2" >/dev/null 2>&1; then
  pass "(c) deterministic — reruns are byte-identical"
else
  fail "(c) non-deterministic — reruns differ"
fi

# ── (d) read-only: wiki/ and raw/ unchanged across an export ─────────────────
sig() { find "$REPO_ROOT/wiki" "$REPO_ROOT/raw" -type f -exec shasum {} \; | LC_ALL=C sort | shasum | awk '{print $1}'; }
before="$(sig)"
"$PYBIN" "$SCRIPT_DIR/wiki-to-okf.py" --out "$TMP/ro" >/dev/null 2>&1
assert "(d) read-only — wiki/ and raw/ untouched" test "$before" = "$(sig)"

# ── (d, negative) refuse an --out that overlaps the source ───────────────────
refute "(d) refuses an --out that overlaps the read-only source" \
  "$PYBIN" "$SCRIPT_DIR/wiki-to-okf.py" --out "$REPO_ROOT/wiki/leak"

# ── field mapping on a minimal fixture ───────────────────────────────────────
FIX="$TMP/fixture"
mkdir -p "$FIX/wiki"
: > "$FIX/AGENTS.md"
cat > "$FIX/wiki/alpha.md" <<'EOF'
---
title: Alpha
type: concept
source: analysis
updated: 2026-01-02
tags: [x]
---

# Alpha

## Definition / TL;DR
Alpha explains [[beta]] using one crisp sentence.

## Body
See [[beta]] for the rest.
EOF
out="$FIX/out"
"$PYBIN" "$SCRIPT_DIR/wiki-to-okf.py" "$FIX" --out "$out" >/dev/null 2>&1
a="$out/alpha.md"
assert "updated → timestamp"          grep -q '^timestamp: 2026-01-02$'          "$a"
assert "[[beta]] → [beta](./beta.md)" grep -q '\[beta\](\./beta\.md)'            "$a"
assert "TL;DR → description"          grep -q '^description: Alpha explains beta' "$a"
refute "no stale 'updated' key"       grep -q '^updated:'                        "$a"

if [ "$fails" -eq 0 ]; then
  echo "${GREEN}All wiki-to-okf checks passed.${RESET}"
  exit 0
fi
echo "${RED}$fails check(s) failed.${RESET}" >&2
exit 1
