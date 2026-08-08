#!/usr/bin/env bash
# scripts/new-gate.sh — scaffold a gate + its fixture pair from the template.
#
# Used by /ctx-gate step 2. Deliberately dumb: it copies
# templates/gate/gate.sh.tmpl, substitutes the rule id, and creates the fixture
# directory. It does NOT write detection logic and does NOT fill in the contract
# — those are decisions, and a scaffolder that guesses at them produces a gate
# whose author never had to think about scope or blind spots.
#
# It refuses to overwrite an existing gate. Regenerating over a working gate
# would silently discard its detection logic and its declared known_gaps.
#
# Exit: 0 = scaffolded · 1 = refused (bad id, gate exists, no rule page)
#       · 2 = setup error (template missing).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || { printf 'new-gate: cannot cd to %s\n' "$REPO_ROOT" >&2; exit 2; }

die1() { printf 'new-gate: %s\n' "$1" >&2; exit 1; }
die2() { printf 'new-gate: %s\n' "$1" >&2; exit 2; }

RULE_ID="${1:-}"
[ -n "$RULE_ID" ] || die1 "usage: new-gate.sh <RULE-ID>   (e.g. new-gate.sh RULE-0007)"

case "$RULE_ID" in
  RULE-[0-9][0-9][0-9][0-9]) : ;;
  *) die1 "rule id must look like RULE-0007 (got '$RULE_ID'). Ids key the gate, the fixture directory and the baseline row — a free-form id silently decouples all three." ;;
esac

TEMPLATE="templates/gate/gate.sh.tmpl"
[ -r "$TEMPLATE" ] || die2 "missing $TEMPLATE"

GATE="gates/$RULE_ID.sh"
FIXDIR="gates/fixtures/$RULE_ID"

[ -e "$GATE" ] && die1 "$GATE already exists. Refusing to overwrite — regenerating would discard its detection logic and its declared known_gaps. Edit it, or delete it deliberately first."

# The rule page is what authorises the gate. Without it there is no statement,
# no evidence citation, and no class — so there is nothing to build against.
RULE_PAGE="$(find wiki/rules -type f -name "$RULE_ID-*.md" 2>/dev/null | head -1)"
[ -n "$RULE_PAGE" ] || die1 "no rule page found at wiki/rules/**/$RULE_ID-*.md. Run /ctx-rules first — a gate with no rule page enforces something nobody can trace to a source."

CLASS="$(awk -F': *' '/^rule_class:/{print $2; exit}' "$RULE_PAGE" | tr -d '"'"'"' ')"
[ "$CLASS" = "deterministic" ] || die1 "$RULE_PAGE has rule_class '$CLASS'. Only deterministic rules become gates; a heuristic rule in a script is confidently wrong on exactly the cases that need judgement."

STATEMENT="$(awk -F': *' '/^statement:/{sub(/^statement: */,""); print; exit}' "$RULE_PAGE" | sed 's/^"//; s/"$//')"
DETECTION="$(awk -F': *' '/^detection:/{sub(/^detection: */,""); print; exit}' "$RULE_PAGE" | sed 's/^"//; s/"$//')"

mkdir -p gates "$FIXDIR" || die2 "cannot create gates/ or $FIXDIR"

sed -e "s|__RULE_ID__|$RULE_ID|g" \
    -e "s|__RULE_PAGE__|$RULE_PAGE|g" \
    -e "s|__STATEMENT__|${STATEMENT:-<fill in from the rule page>}|g" \
    -e "s|__DETECTION__|${DETECTION:-<fill in: the mechanism, not the intention>}|g" \
    "$TEMPLATE" > "$GATE" || die2 "writing $GATE failed"
chmod +x "$GATE" || die2 "chmod failed on $GATE"

printf 'new-gate: scaffolded %s\n' "$GATE"
printf 'new-gate: fixture directory %s/ (empty — you must write both files)\n' "$FIXDIR"
printf '\nNot done yet. The gate has no detection logic and no fixtures, so it\n'
printf 'currently proves nothing. Next:\n'
printf '  1. fill in the detection in %s\n' "$GATE"
printf '  2. write %s/violating.<ext>  (must exit 1)\n' "$FIXDIR"
printf '  3. write %s/clean.<ext>      (must exit 0)\n' "$FIXDIR"
printf '  4. run the five-way mutation proof and declare three known gaps\n'
printf '  5. add a baseline row with the REAL violation count, and wire into smoke-all.sh\n'
