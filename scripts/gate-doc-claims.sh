#!/usr/bin/env bash
# scripts/gate-doc-claims.sh — gate DOC-CLAIM-RECOMPUTE.
#
# RULE: a structural number stated in prose must be recomputed from the
# repository, never typed. Bound claims are written as
# `<!-- claim:<id> -->VALUE<!-- /claim -->`; the gate recomputes each id via
# scripts/doc-claims.tsv and fails if VALUE disagrees.
#
# WHY THIS GATE EXISTS: `README.md` described smoke-all.sh as running "R1–R4
# regression guards" for the twenty-four commits it took to reach R28 — the
# number went stale the first time a guard was added and nothing noticed,
# because a doc that lies produces no red. `scripts/verify-site-claims.sh`
# already pins a handful of specific claims (the smoke-check count on
# site/index.html and in README, the command count, the retrieval-check count);
# this generalises the mechanism so any number in any doc can be bound without
# writing a bespoke check for each one. verify-site-claims.sh is left alone —
# it also enforces claim policy this gate does not touch (score claims must
# carry a date; superseded figures must not reappear).
#
# DETECTION: marker extraction + command recomputation. Not pattern-hunting for
# numbers — a regex over `\d+ checks` misfires on prose about history ("it
# advertised 31 but ran 26" is a real sentence in verify-site-claims.sh's own
# header), on the README's directory tree, and on en-dash vs hyphen ranges. A
# number is checked when an author chose to bind it.
#
# NO SILENT NO-OPS, BOTH DIRECTIONS:
#   - a marker naming an id absent from doc-claims.tsv is a violation, not a
#     skip (otherwise a typo'd id silently unbinds the claim);
#   - an id in doc-claims.tsv that no document uses is a violation too (a claim
#     nobody states is a recompute command rotting quietly);
#   - a recompute command that fails or prints nothing is exit 2, not a pass.
#
# SCOPE: *.md and *.html outside raw/, wiki/, .git, and tests/gates/ — raw/ is
# immutable evidence and wiki/ is generated from it, so neither carries
# repo-structural claims. tests/gates/ is excluded because it holds this gate's
# own VIOLATING fixture: without the exclusion the repo-wide run would report
# the planted failure as a real one and could only be made green by deleting
# the fixture that proves the gate works. This is the one scope exclusion in
# the gate and it is named here rather than buried, per deterministic-gates
# §caveat — fixture data is an input to a gate, not documentation.
#
# EXIT: 0 = every bound claim holds · 1 = a claim is stale / unbound / unused
#       · 2 = the gate itself failed (missing table, recompute command broke).
#
# MODES:
#   (default)      check this repository
#   --repo <dir>   check the tree at <dir> — fixture mode
#
# RUNTIME: bash + grep + sed. No LLM, no network, no key.
# WIRED AT: scripts/smoke-all.sh (R34) → CI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULE_ID="DOC-CLAIM-RECOMPUTE"

die2() { printf 'gate-doc-claims: %s\n' "$1" >&2; exit 2; }

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COUNT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) ROOT="${2:-}"; [ -n "$ROOT" ] || die2 "--repo needs a directory"; shift 2 ;;
    --count) COUNT=1; shift ;;
    *) die2 "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || die2 "not a directory: $ROOT"
cd "$ROOT" || die2 "cannot cd to $ROOT"

TABLE="scripts/doc-claims.tsv"
[ -r "$TABLE" ] || die2 "cannot read $TABLE (the claims table is the gate's input)"

tmp="$(mktemp -d)" || die2 "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# ── documents in scope ──
find . \( -path ./.git -o -path ./raw -o -path ./wiki -o -path ./node_modules -o -path ./tests/gates \) -prune -o \
     -type f \( -name '*.md' -o -name '*.html' \) -print 2>/dev/null | sed 's|^\./||' | sort > "$tmp/docs"
[ -s "$tmp/docs" ] || die2 "no *.md or *.html documents found in scope"

# ── extract every marker occurrence: file<TAB>line<TAB>id<TAB>stated ──
: > "$tmp/markers"
while IFS= read -r doc; do
  grep -noE '<!--[[:space:]]*claim:[a-z0-9-]+[[:space:]]*-->[^<]*<!--[[:space:]]*/claim[[:space:]]*-->' "$doc" 2>/dev/null \
  | while IFS=: read -r lineno rest; do
      id="$(printf '%s' "$rest" | sed -n 's/.*claim:\([a-z0-9-]*\).*/\1/p')"
      stated="$(printf '%s' "$rest" | sed 's/^[^>]*-->//; s/<!--.*$//')"
      printf '%s\t%s\t%s\t%s\n' "$doc" "$lineno" "$id" "$stated" >> "$tmp/markers"
    done
done < "$tmp/docs"

# ── an opening marker with no closing one is a silent unbinding ──
: > "$tmp/dangling"
while IFS= read -r doc; do
  opens=$(grep -oE '<!--[[:space:]]*claim:[a-z0-9-]+[[:space:]]*-->' "$doc" 2>/dev/null | wc -l | tr -d ' ')
  closes=$(grep -oE '<!--[[:space:]]*/claim[[:space:]]*-->' "$doc" 2>/dev/null | wc -l | tr -d ' ')
  [ "$opens" = "$closes" ] || printf '%s\t%s\t%s\n' "$doc" "$opens" "$closes" >> "$tmp/dangling"
done < "$tmp/docs"

fails=0
checked=0
: > "$tmp/used-ids"

while IFS=$'\t' read -r doc lineno id stated; do
  [ -n "${id:-}" ] || continue
  checked=$((checked + 1))
  echo "$id" >> "$tmp/used-ids"

  cmd="$(awk -F'\t' -v want="$id" '!/^#/ && $1 == want { print $2; exit }' "$TABLE")"
  if [ -z "$cmd" ]; then
    printf '%s:%s: %s\n' "$doc" "$lineno" "$RULE_ID" >&2
    printf '  marker names claim id `%s`, which is not in %s.\n' "$id" "$TABLE" >&2
    printf '  An unknown id is not a skip — it would silently unbind the claim.\n' >&2
    printf '  FIX: add a row `%s<TAB><recompute command>` to %s, or fix the typo.\n' "$id" "$TABLE" >&2
    fails=$((fails + 1))
    continue
  fi

  actual="$(eval "$cmd" 2>"$tmp/cmderr")"
  rc=$?
  [ "$rc" -eq 0 ] || die2 "recompute for '$id' exited $rc: $(head -1 "$tmp/cmderr")"
  [ -n "$actual" ] || die2 "recompute for '$id' printed nothing — the command cannot distinguish a true zero from a broken pipeline"

  if [ "$stated" != "$actual" ]; then
    printf '%s:%s: %s\n' "$doc" "$lineno" "$RULE_ID" >&2
    printf '  claim `%s` states "%s"; the repository says "%s".\n' "$id" "$stated" "$actual" >&2
    printf '  FIX: set the value between the markers to "%s".\n' "$actual" >&2
    fails=$((fails + 1))
  fi
done < "$tmp/markers"

# ── dangling markers ──
while IFS=$'\t' read -r doc opens closes; do
  [ -n "${doc:-}" ] || continue
  printf '%s: %s\n' "$doc" "$RULE_ID" >&2
  printf '  %s opening claim marker(s) but %s closing one(s). An unclosed marker\n' "$opens" "$closes" >&2
  printf '  is never extracted, so the claim silently stops being checked.\n' >&2
  printf '  FIX: close every `<!-- claim:<id> -->` with `<!-- /claim -->`.\n' >&2
  fails=$((fails + 1))
done < "$tmp/dangling"

# ── table rows nothing uses ──
while IFS=$'\t' read -r id _cmd; do
  case "$id" in ''|\#*) continue ;; esac
  grep -qxF "$id" "$tmp/used-ids" 2>/dev/null && continue
  printf '%s: %s\n' "$TABLE" "$RULE_ID" >&2
  printf '  claim id `%s` is defined but no document states it. A recompute\n' "$id" >&2
  printf '  command nothing checks is dead weight that reads as coverage.\n' >&2
  printf '  FIX: bind it in a doc with `<!-- claim:%s -->…<!-- /claim -->`, or drop the row.\n' "$id" >&2
  fails=$((fails + 1))
done < "$TABLE"

# --count: tally for scripts/gate-ratchet.sh. No suppression mechanism exists
# for this gate — a claim is bound or it is not — so the second column is 0.
if [ "$COUNT" = 1 ]; then
  printf '%d\t0\n' "$fails"
  exit 0
fi

if [ "$fails" -gt 0 ]; then
  printf 'gate-doc-claims: %d claim problem(s) — %s\n' "$fails" "$RULE_ID" >&2
  exit 1
fi

printf 'gate-doc-claims: clean — %d bound claim(s) recomputed and matching.\n' "$checked"
exit 0
