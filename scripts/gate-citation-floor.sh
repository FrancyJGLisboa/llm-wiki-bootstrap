#!/usr/bin/env bash
# scripts/gate-citation-floor.sh — gate CITATION-FLOOR.
#
# RULE: every `(source: raw/...#anchor)` in the compiled context resolves to a
# real passage in the file it names.
#
# WHY THIS GATE EXISTS — and it is the most expensive omission in this repo's
# history. Eleven gates ran green for a full day over a corpus carrying 18,900
# broken citations. Every one of them checked something real; none checked THIS.
# CLOSED-CORPUS verifies that citations POINT at corpus sources. ADAPTER-CONTRACT
# verifies staged sources are compilable. Neither asks whether an anchor
# actually lands on anything.
#
# The failure is silent by construction. A page with a broken anchor still
# renders, still names a real file, still reads as sourced. /ctx-query still
# answers from it. Nothing goes red, because nothing was looking — and the
# citation is the entire basis on which this package claims to be trustworthy.
#
# It surfaced only because an answer-verifier written for a different purpose
# happened to run the audit over an answer, against a corpus everyone believed
# was sound. That is not a process anyone should rely on twice.
#
# DETECTION: delegated wholesale to scripts/citation-audit.py, the same engine
# the compiler, the packager's G3 gate and the answer verifier all use. A second
# implementation of "does this anchor resolve" would eventually disagree with the
# first, and then the corpus would be sound according to one and broken according
# to the other.
#
# RATCHETED, NOT DEMANDED AT ZERO. 48 citations are recorded as broken today:
# two sources cited at line numbers past their own length, which needs those
# pages recompiled rather than a resolver change. Requiring zero on arrival is
# how a gate gets disabled instead of obeyed; requiring the number never to rise
# is how it gets fixed.
#
# FAILURE MODES — the honest ones:
#   1. It proves an anchor LANDS somewhere, not that the passage SUPPORTS the
#      claim attached to it. That is entailment, it needs a model, and it is a
#      write-time gate (`wiki-faithfulness-gate.sh`), not this one.
#   2. A citation with no anchor at all — `(source: raw/x.md)` — resolves to the
#      whole file and passes. Whole-file citations are legal and deliberately so;
#      citation density is what corpus-health.py reports on.
#   3. It says nothing about claims carrying NO citation. That floor is
#      `citation-audit.py --coverage`, a different check with its own exemptions.
#
# SCOPE: the compiled context root, resolved via ctx_root().
#
# EXIT: 0 = at or below baseline · 1 = an anchor stopped resolving
#       · 2 = the gate itself failed (no audit engine, no context root).
#
# MODES:
#   (default)      check this repository
#   --repo <dir>   check the tree at <dir> — fixture mode
#   --count        print "<violations>TAB<suppressions>" and exit 0
#
# RUNTIME: bash 3.2+ + python3. No LLM, no network, no key.
# WIRED AT: gates/baseline.tsv.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate-lib.sh
. "$SCRIPT_DIR/lib/gate-lib.sh" || { printf 'gate-citation-floor: cannot source lib/gate-lib.sh\n' >&2; exit 2; }
gate_init "gate-citation-floor" "CITATION-FLOOR"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  ROOT="${2:-}"; [ -n "$ROOT" ] || gate_die "--repo needs a directory"; shift 2 ;;
    --count) GATE_COUNT_MODE=1; shift ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || gate_die "not a directory: $ROOT"
cd "$ROOT" || gate_die "cannot cd to $ROOT"

gate_need python3

# Resolved from the deployment, not the tree under test: a fixture is a scrap of
# compiled output with no scripts/ of its own.
AUDIT="$SCRIPT_DIR/citation-audit.py"
[ -r "$AUDIT" ] || gate_die "$AUDIT missing — the single definition of anchor resolution is unavailable, and a second one written here would eventually disagree with it"

# shellcheck source=lib/ctx-root.sh
. "$SCRIPT_DIR/lib/ctx-root.sh" || gate_die "cannot source lib/ctx-root.sh"
# The message deliberately does not spell the legacy root as a path token:
# CTX-ROOT-ADOPTION counts any non-comment line containing one, so wording that
# named it literally would inflate the very number it reports. Declared failure
# mode 2 of that gate, met for the second time.
CTXDIR="$(ctx_root .)" || gate_die "no compiled-context root under $ROOT (neither of the two supported directory names exists)"
[ -d raw ] || gate_die "no raw/ under $ROOT — citations cannot be resolved without the sources they point at"

pages="$(find "$CTXDIR" -name '*.md' -not -path '*/journal/*' 2>/dev/null | wc -l | tr -d ' ')"
[ "$pages" -gt 0 ] || gate_die "$CTXDIR holds no pages — a clean verdict would be vacuous"

OUT="$(mktemp)" || gate_die "mktemp failed"
trap 'rm -f "$OUT"' EXIT
python3 "$AUDIT" "$CTXDIR" --raw raw >"$OUT" 2>&1

# One violation per unresolved citation. Counted rather than reported one by one:
# a corpus with thousands of them would bury its own summary, and the audit
# output is the place to read the detail.
broken="$(grep -cE '✗' "$OUT" 2>/dev/null || true)"
[ -n "$broken" ] || broken=0

if [ "$broken" != "0" ]; then
  grep -E '✗' "$OUT" | head -8 | sed 's/^/  /' >&2
  [ "$broken" -gt 8 ] && printf '  … and %d more (run: python3 scripts/citation-audit.py %s --raw raw)\n' \
    "$((broken - 8))" "$CTXDIR" >&2
  i=0
  while [ "$i" -lt "$broken" ]; do
    gate_violation "$CTXDIR:1" \
"a citation anchor does not resolve in the file it names. The citation is the
       whole basis on which this package claims to be checkable, and a broken one
       fails silently: the page still renders, still names a real source, and
       still reads as sourced. Recompile the page, or fix the anchor."
    i=$((i + 1))
  done
fi

gate_verdict "clean — every citation across $pages page(s) resolves to a real passage."
