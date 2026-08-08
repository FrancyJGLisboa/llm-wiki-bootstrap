#!/usr/bin/env bash
# scripts/verify-package-quality.sh — oracle for the Context Package Quality
# scorecard (scripts/package-quality.sh). No LLM, no spend. Q1–Q7 must pass.
#
#   Q1 detects-unsound : a package with a BROKEN citation must show that row
#                        FAIL. A scorecard that only ever prints green is a
#                        decoration, and a decoration nobody can fail is worse
#                        than no scorecard — it launders debt as quality.
#   Q2 label-collision : corpus-health prints "thin (<2 related): 0", whose
#                        LABEL contains a 2. The first draft grabbed the first
#                        number on the line and reported the THRESHOLD as the
#                        count — a clean package scored "2 thin". This pins the
#                        fix (read --json fields, never the prose).
#   Q3 exit-contract   : default exits 0 even with failing rows (instrument,
#                        not gate); --strict exits 1. A repo with known debt
#                        must still be able to read its own numbers.
#   Q4 json-agrees     : --json is parseable AND its `failed` count equals the
#                        number of FAIL verdicts it lists. Two renderings of
#                        one run that can disagree will eventually disagree.
#   Q5 read-only       : the scorecard never writes raw/ or wiki/ (hard rule 1).
#                        A measurement that mutates what it measures is not one.
#   Q6 no-false-green  : an EMPTY package must not report a perfect score.
#                        Absence of findings is not evidence of quality.
#   Q7 not-a-package   : a directory with no wiki/ or raw/ exits 2, not 0.
#
# WIRED AT: scripts/smoke-all.sh (R35) → CI.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORE="$SCRIPT_DIR/package-quality.sh"

[ -x "$SCORE" ] || { echo "verify-package-quality: $SCORE missing or not executable" >&2; exit 2; }

fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }
tmp="$(mktemp -d -t verify-package-quality.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------- fixtures
#
# Built with printf, never copied from the repo: a fixture that tracks the real
# wiki stops testing the checker and starts testing today's content.

# A SOUND package: two pages, cross-linked (>=2 related each), every claim cited
# to a raw anchor that exists, and the source carrying a real ingest commitment.
mk_sound() {
  local W="$1"; mkdir -p "$W/wiki" "$W/raw"
  printf -- '---\nsource_url: n/a\nfetched_at: 2026-01-01\nasserted_at: 2026-01-01\nasserted_at_source: "raw/src.md#the-claim"\ningested_hash: ""\ningested_at: 2026-01-01\ningested_pages: []\n---\n\n## The Claim\n\nThe rotor spins at 47 hertz.\n\n## Other Section\n\nSecondary detail lives here.\n' > "$W/raw/src.md"
  # Commitment must be DERIVED, never hand-written — a hash nobody computed is
  # a fabricated receipt (AGENTS.md canonical-hashing rule).
  local h; h="$(bash "$SCRIPT_DIR/body-hash.sh" "$W/raw/src.md")"
  perl -pi -e "s/^ingested_hash: \"\"/ingested_hash: \"$h\"/" "$W/raw/src.md"
  printf -- '---\ntitle: Alpha\ntype: concept\nsource: analysis\nupdated: 2026-01-01\ntags: [t]\n---\n\n# Alpha\n\n## Definition / TL;DR\nAlpha.\n\n## Body\nThe rotor spins at 47 hertz (source: raw/src.md#the-claim).\n\n## Related\n- [[beta]] — pairs with it\n- [[index]] — home\n' > "$W/wiki/alpha.md"
  printf -- '---\ntitle: Beta\ntype: concept\nsource: analysis\nupdated: 2026-01-01\ntags: [t]\n---\n\n# Beta\n\n## Definition / TL;DR\nBeta.\n\n## Body\nSecondary detail lives here (source: raw/src.md#other-section).\n\n## Related\n- [[alpha]] — pairs with it\n- [[index]] — home\n' > "$W/wiki/beta.md"
  printf -- '---\ntitle: Index\ntype: navigation\nsource: analysis\nupdated: 2026-01-01\ntags: [t]\n---\n\n# Index\n\n## Definition / TL;DR\nHome.\n\n## Body\n- [[alpha]]\n- [[beta]]\n' > "$W/wiki/index.md"
}

SOUND="$tmp/sound"; mk_sound "$SOUND"

# ------------------------------------------------------------------- Q1

# Same package, one citation pointed at an anchor that does not exist.
BROKEN="$tmp/broken"; mk_sound "$BROKEN"
perl -pi -e 's/#the-claim/#no-such-anchor/' "$BROKEN/wiki/alpha.md"

broken_out="$("$SCORE" --repo "$BROKEN" 2>&1)"
case "$broken_out" in
  *"citation resolution"*) : ;;
  *) fail "Q1 scorecard printed no citation-resolution row at all"; ;;
esac
# The row must be marked failing (✗), not merely present.
if printf '%s' "$broken_out" | grep -E '✗.*citation resolution' >/dev/null; then
  ok "Q1 a broken citation is reported FAIL, not swallowed"
else
  fail "Q1 broken citation did NOT fail the citation-resolution row — scorecard cannot detect an unsound package"
fi

# ------------------------------------------------------------------- Q2

# The regression that shipped in the first draft. `thin` is 0 in a package
# where every page has >=2 related links; the label "(<2 related)" must not be
# read as the value.
sound_out="$("$SCORE" --repo "$SOUND" 2>&1)"
thin_val="$(printf '%s' "$sound_out" | sed -nE 's/.*link connectivity[[:space:]]+([0-9]+) thin.*/\1/p' | head -1)"
if [ "$thin_val" = "0" ]; then
  ok "Q2 link connectivity reads the VALUE (0 thin), not the threshold in its label"
else
  fail "Q2 link connectivity reported '${thin_val:-<none>}' thin on a fully-linked package — label collision is back"
fi

# ------------------------------------------------------------------- Q3

"$SCORE" --repo "$BROKEN" >/dev/null 2>&1
rc_default=$?
"$SCORE" --repo "$BROKEN" --strict >/dev/null 2>&1
rc_strict=$?
if [ "$rc_default" -eq 0 ] && [ "$rc_strict" -eq 1 ]; then
  ok "Q3 exit contract: default 0 on a failing package, --strict 1"
else
  fail "Q3 exit contract wrong — default=$rc_default (want 0), strict=$rc_strict (want 1)"
fi

# ------------------------------------------------------------------- Q4

json_out="$("$SCORE" --repo "$BROKEN" --json 2>&1)"
agree="$(printf '%s' "$json_out" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("UNPARSEABLE:%s" % e); sys.exit(0)
listed = sum(1 for m in d.get("measures", []) if m.get("verdict") == "FAIL")
print("OK" if listed == d.get("failed") else "MISMATCH:listed=%d field=%s" % (listed, d.get("failed")))
' 2>&1)"
case "$agree" in
  OK) ok "Q4 --json parses and its failed count matches the rows it lists" ;;
  *)  fail "Q4 --json disagrees with itself or does not parse: $agree" ;;
esac

# ------------------------------------------------------------------- Q5

raw_before="$(find "$SOUND/raw" -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}')"
wiki_before="$(find "$SOUND/wiki" -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}')"
"$SCORE" --repo "$SOUND" >/dev/null 2>&1
raw_after="$(find "$SOUND/raw" -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}')"
wiki_after="$(find "$SOUND/wiki" -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}')"
if [ "$raw_before" = "$raw_after" ] && [ "$wiki_before" = "$wiki_after" ]; then
  ok "Q5 scoring is read-only on raw/ and wiki/"
else
  fail "Q5 the scorecard MUTATED the package it measured (raw changed: $([ "$raw_before" != "$raw_after" ] && echo yes || echo no), wiki changed: $([ "$wiki_before" != "$wiki_after" ] && echo yes || echo no))"
fi

# ------------------------------------------------------------------- Q6

EMPTY="$tmp/empty"; mkdir -p "$EMPTY/wiki" "$EMPTY/raw"
empty_out="$("$SCORE" --repo "$EMPTY" 2>&1)"
# An empty package has nothing to find, so it must not render as a clean sweep.
if printf '%s' "$empty_out" | grep -qE 'structural measures pass\.'; then
  fail "Q6 an EMPTY package reported a perfect score — absence of findings read as quality"
else
  ok "Q6 an empty package does not report a perfect score"
fi

# ------------------------------------------------------------------- Q7

NOTPKG="$tmp/notpkg"; mkdir -p "$NOTPKG"
"$SCORE" --repo "$NOTPKG" >/dev/null 2>&1
rc_notpkg=$?
if [ "$rc_notpkg" -eq 2 ]; then
  ok "Q7 a directory that is not a package exits 2 (setup error), not 0"
else
  fail "Q7 non-package exited $rc_notpkg — want 2, so a mis-pointed --repo cannot read as a pass"
fi

# ------------------------------------------------------------------- exit

echo ""
if [ "$fails" -eq 0 ]; then
  echo "verify-package-quality: Q1–Q7 all green — the scorecard detects unsoundness, reads values not labels, and never edits what it measures."
  exit 0
fi
echo "verify-package-quality: $fails failure(s)" >&2
exit 1
