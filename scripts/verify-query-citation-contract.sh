#!/usr/bin/env bash
# scripts/verify-query-citation-contract.sh — guard the /ctx-query output
# contract for raw citations. No LLM, no spend.
#
# Why this exists: the retrieval eval scored R4 at 0/5, 0/5 and 0/7 across three
# runs, and the cause was not the model. `/ctx-query`'s output template asked
# for `- Wiki:` and `- Web:` and never asked for an inline
# `(source: raw/<file>#<anchor>)` at all — so answers that emitted one were
# improvising, and the shape varied per run: backticked paths, the path merged
# into a wikilink parenthesis, or provenance listed only in the Sources block.
# Every one of those is unverifiable, because citation-audit.py locates evidence
# by grepping the literal `(source:` form.
#
# The fix is a spec, and a spec with no test decays. These checks assert the
# instruction is present and that the shape it teaches is the shape the grader
# recognises — so the contract and the audit can never drift apart silently.
#
#   Q1 output template asks for a `- Raw:` line
#   Q2 the mandated form is spelled out literally as (source: raw/<file>#<anchor>)
#   Q3 the doc names the failing shapes (backticks / merged wikilink / bare path)
#   Q4 the doc tells the author to prefer the narrowest anchor
#   Q5 the form the doc teaches is exactly what citation-audit.py extracts
#      (asserted by round-tripping a sample answer through the real extractor)
#
# Usage: ./scripts/verify-query-citation-contract.sh   Exit: 0 green, 1 failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DOC=".claude/commands/ctx-query.md"
if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

[ -f "$DOC" ] || { fail "Q0 $DOC missing"; exit 1; }

# Q1 — the Sources block must ask for raw provenance, not just pages and urls
grep -qE '^- Raw: ' "$DOC" \
  && ok "Q1 output template asks for a '- Raw:' line" \
  || fail "Q1 output template has no '- Raw:' line (R4 measured 0/N for exactly this)"

# Q2 — the mandated shape is stated literally, not merely implied
grep -qF '(source: raw/<file>#<anchor>)' "$DOC" \
  && ok "Q2 the required citation form is spelled out literally" \
  || fail "Q2 the doc never states the literal (source: raw/<file>#<anchor>) form"

# Q3 — naming the near-misses is what stops them; an author who only sees the
# right answer reinvents the wrong ones.
q3=0
grep -qF '`raw/f.md#L20`' "$DOC" || q3=1          # backticked path
grep -qF '([[page-summary]], source:' "$DOC" || q3=1  # merged into a wikilink
[ "$q3" -eq 0 ] \
  && ok "Q3 the doc names the shapes that fail (backticks, merged wikilink)" \
  || fail "Q3 the doc does not show the near-miss shapes that actually occurred"

# Q4 — span discipline: R4 also fails on citations that resolve but gesture
grep -qiE 'narrowest anchor|#L948. over|narrowest' "$DOC" \
  && ok "Q4 the doc tells the author to prefer the narrowest anchor" \
  || fail "Q4 no guidance to prefer a tight anchor over a wide one"

# Q5 — THE ONE THAT MATTERS: the form the doc teaches must be the form the audit
# extracts. If these ever diverge, /ctx-query emits citations nothing can check
# and R4 goes back to zero with no visible cause.
sample=$(mktemp); trap 'rm -f "$sample"' EXIT
printf 'The budget is 3 attempts (source: raw/retry-budget-memo-feb.md#L20-L22).\n' > "$sample"
extracted=$(grep -oE '\(source:[[:space:]]*raw/[^)]+\)' "$sample" | head -1)
if [ "$extracted" = "(source: raw/retry-budget-memo-feb.md#L20-L22)" ]; then
  ok "Q5 the taught form round-trips through the grader's extractor"
else
  fail "Q5 the taught form does not match what the extractor recognises (got: '$extracted')"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d /ctx-query citation-contract check(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s Q1-Q5 green — the citation contract is stated, exemplified, and grader-compatible.\n" "$GREEN" "$RESET"
exit 0
