#!/usr/bin/env bash
# scripts/ctx-lint-rules.sh — rule-integrity checks R-01, R-02, R-05, R-06.
#
# RULE (R-01, the one that matters): a rule classified `deterministic` must not
# stay prose-only. If a script can settle it, a script must settle it.
#
# WHY THIS EXISTS: this is `docs/deterministic-gates.md` §1 turned on the
# compiler's own output. The whole point of classifying a rule as deterministic
# is that an exit code can decide it — a deterministic rule sitting in
# `wiki/rules/deterministic/` with `gate: none` has been *identified* as
# enforceable and then *not enforced*, which is strictly worse than never
# classifying it: the page reads like a control while nothing checks it.
#
# CHECKS:
#   R-01  rule_class: deterministic with gate: none
#   R-02  gate: names a file that does not exist or is not executable
#   R-05  a gate with no reachable exit-2 path (a gate that cannot report its
#         own failure will report a broken dependency as compliance)
#   R-06  fewer than 3 known_gaps on a gated rule
#
# R-03 (missing fixture pair) and R-04 (gate does not discriminate) are NOT here
# — scripts/gate-fixtures.sh already owns both, and two gates reporting the same
# violation means fixing it once still leaves a red check.
#
# ALL CHECKS ARE REPORT-ONLY. There is no --apply. Auto-fixing R-01 would mean
# generating a gate without the mutation proof, which is the precise failure the
# discipline exists to prevent; the fix path prints the /ctx-gate command and
# stops.
#
# FAILURE MODES — the honest ones:
#   - Frontmatter is read with awk, not a YAML parser. A rule page using block
#     scalars or flow mappings for these keys reads as absent. The template and
#     AGENTS.md both specify simple `key: value`, and R-07 (schema drift) in
#     /ctx-lint is what catches malformed frontmatter generally.
#   - R-05 greps for `exit 2` / `gate_die`. A gate that reaches exit 2 through
#     an indirection this cannot see reads as missing it — a false positive,
#     which is the safe direction.
#   - R-06 counts list items, not distinct ideas. Three restatements of one gap
#     pass. Nothing deterministic can judge that; it is what a reviewer is for.
#   - It says nothing about whether a gate's detection actually implements the
#     rule its page states. That gap is unclosable by script and is exactly why
#     `rule_class: heuristic` exists.
#
# SCOPE: wiki/rules/**/*.md. Pages under `discarded/` are skipped for R-01 —
# an unverifiable rule having no gate is the correct outcome, not a violation.
#
# EXIT: 0 = clean · 1 = at least one violation · 2 = the gate itself failed.
#
# MODES:
#   (default)      check this repository
#   --repo <dir>   check the tree at <dir> — fixture mode
#   --count        print "<violations>TAB<suppressions>" and exit 0
#
# RUNTIME: bash 3.2+ + awk + grep. No LLM, no network, no key.
# WIRED AT: scripts/smoke-all.sh (R39) → CI, and /ctx-lint's Rule integrity block.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate-lib.sh
. "$SCRIPT_DIR/lib/gate-lib.sh" || { printf 'ctx-lint-rules: cannot source lib/gate-lib.sh\n' >&2; exit 2; }
gate_init "ctx-lint-rules" "RULE-INTEGRITY"

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

RULES_DIR="wiki/rules"
# An absent rules directory is not a violation: a context package may legitimately
# contain no rules at all. It is only an error if something claims otherwise.
if [ ! -d "$RULES_DIR" ]; then
  gate_verdict "clean — no $RULES_DIR/ directory; this package declares no rules."
fi

# fm <file> <key> — read a simple `key: value` from the frontmatter block only.
fm() {
  awk -v k="$2" '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---"  { exit }
    infm {
      if ($0 ~ "^"k":") { sub("^"k":[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }
    }
  ' "$1"
}

# count_list <file> <key> — number of `  - ` items under a frontmatter key.
count_list() {
  awk -v k="$2" '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---"  { exit }
    infm && $0 ~ "^"k":" { inlist=1; n=0; next }
    inlist && /^[[:space:]]+- / { n++; next }
    inlist && /^[^[:space:]]/ { inlist=0 }
    END { print n+0 }
  ' "$1"
}

pages=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  pages=$((pages + 1))

  rule_id="$(fm "$f" rule_id)"
  class="$(fm "$f" rule_class)"
  gate="$(fm "$f" gate)"

  [ -n "$rule_id" ] || {
    gate_violation "$f:1" "rule page has no \`rule_id\`. The id keys the gate, the fixture directory and the baseline row — without it none of the three can be linked."
    continue
  }
  [ -n "$class" ] || {
    gate_violation "$f:1" "rule page has no \`rule_class\`. Classify it deterministic, heuristic, or unverifiable — an unclassified rule is one nobody decided how to enforce."
    continue
  }

  case "$f" in
    */discarded/*)
      # An unverifiable rule with no gate is the correct outcome. What it must
      # have is the reason, or "we discarded it" is indistinguishable from
      # "we forgot about it".
      [ -n "$(fm "$f" discard_reason)" ] || gate_violation "$f:1" \
"R-01 discarded rule has no \`discard_reason\`. Recording that nothing can check
       this rule is a finding; dropping it without the reason looks identical to
       never having noticed it."
      continue ;;
  esac

  # ── R-01 — the standing rule ──
  if [ "$class" = "deterministic" ] && { [ -z "$gate" ] || [ "$gate" = "none" ]; }; then
    gate_violation "$f:1" \
"R-01 $rule_id is classified deterministic but has \`gate: none\` — it is enforced
       by prose alone. A script can settle it, so a script must:
         /ctx-gate $rule_id
       (Not auto-fixable: a gate generated without the five-way mutation proof
       is the never-fires gate this whole discipline exists to prevent.)"
    continue
  fi

  [ -n "$gate" ] && [ "$gate" != "none" ] || continue

  # ── R-02 — the named gate must exist and be runnable ──
  if [ ! -f "$gate" ]; then
    gate_violation "$f:1" "R-02 $rule_id names \`gate: $gate\`, which does not exist. The page claims enforcement that is not there."
    continue
  fi
  if [ ! -x "$gate" ]; then
    gate_violation "$gate:1" "R-02 $rule_id's gate is not executable. Run: chmod +x $gate"
  fi

  # ── R-05 — the gate must be able to report its own failure ──
  if ! grep -qE 'gate_die|exit[[:space:]]+2' "$gate" 2>/dev/null; then
    gate_violation "$gate:1" \
"R-05 $rule_id's gate has no reachable exit-2 path. A gate that cannot report
       its own failure reports a missing dependency as compliance — worse than
       no gate at all. Source scripts/lib/gate-lib.sh and use gate_die."
  fi

  # ── R-06 — declared blind spots ──
  gaps="$(count_list "$f" known_gaps)"
  if [ "${gaps:-0}" -lt 3 ]; then
    gate_violation "$f:1" \
"R-06 $rule_id declares $gaps known_gaps; three are required. An author who
       cannot name three ways around their own gate has not understood the
       problem space — they have only observed that the gate passes.
       (deterministic-gates §5.3)"
  fi
done <<EOF
$(find "$RULES_DIR" -type f -name '*.md' 2>/dev/null | sort)
EOF

if [ "$pages" -eq 0 ]; then
  gate_verdict "clean — $RULES_DIR/ exists but holds no rule pages yet."
fi

gate_verdict "clean — $pages rule page(s); every deterministic rule is gated, every gate exists and can fail."
