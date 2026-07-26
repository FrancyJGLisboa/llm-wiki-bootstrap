#!/usr/bin/env bash
# scripts/verify-asserted-at.sh — oracle for the valid-time contract lint.
# No LLM, no spend, runnable in CI.
#
#   A1 dated + anchor      : a real date with an anchor into the passage that
#                            states it passes
#   A2 missing field       : silence is a violation (the whole point — an as-of
#                            query has nothing to resolve against)
#   A3 unknown + note      : an explicit unknown passes; undated sources are
#                            legitimate and must not push authors to fabricate
#   A4 unknown, no note    : bare `unknown` is a violation
#   A5 fetch-date stamping : asserted_at == fetched_at with an anchor that does
#                            NOT contain the date is rejected, and the message
#                            names the pattern. THIS IS THE GOODHART CHECK:
#                            stamping fetched_at is the cheapest way to make
#                            every source look dated while encoding nothing.
#   A6 anchor must resolve : a date whose anchor points nowhere is rejected
#   A7 anchor must contain : a date whose anchor resolves to a passage that does
#                            not state that date is rejected (cite anything,
#                            prove nothing — same hole R4 closes for citations)
#   A8 prose date forms    : "March 31, 2026" in the passage satisfies
#                            asserted_at: 2026-03-31 (real documents write dates
#                            in prose; a lint that only accepted ISO would push
#                            authors to edit raw/, which rule 1 forbids)
#   A9 never-ingested      : ingested_hash "" is skipped, same as drift lint
#  A10 sidecar pairs       : the binary half of <slug>.csv + <slug>.csv.md is
#                            not audited (it has no frontmatter by design)
#  A11 real raw/           : the repo's own raw/ is reported, advisory only —
#                            these sources predate the field
#
# Usage: ./scripts/verify-asserted-at.sh   Exit: 0 all green, 1 a check failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

LINT="$SCRIPT_DIR/wiki-lint-asserted-at.sh"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; RESET=$'\033[0m'
else RED=; GREEN=; YEL=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }
note() { printf "%s•%s %s\n" "$YEL"   "$RESET" "$1"; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# mk <dir> <file> <asserted_at block...> — a raw source whose body states a date
mk() {
  local dir="$1" file="$2"; shift 2
  mkdir -p "$dir"
  { echo "---"
    echo "source_url: n/a"
    echo "source_type: note"
    echo "source_title: \"Capacity\""
    echo "fetched_at: 2026-07-24"
    for line in "$@"; do echo "$line"; done
    echo "ingested_hash: abc123def456"
    echo "ingested_at: 2026-07-24 10:00"
    echo "ingested_pages: [wiki/capacity.md]"
    echo "---"
    echo ""
    echo "## Reporting period"
    echo ""
    echo "This report covers the quarter ending 2026-03-31."
    echo ""
    echo "## Method"
    echo ""
    echo "Sampled hourly. No date here."
  } > "$dir/$file"
}

# A1 — dated with a resolving, containing anchor
d="$TMP/a1"; mk "$d" doc.md "asserted_at: 2026-03-31" "asserted_at_source: #reporting-period"
if "$LINT" "$d" >/dev/null 2>&1; then ok "A1 dated source with a containing anchor passes"
else fail "A1 valid dated source rejected"; fi

# A2 — silence
d="$TMP/a2"; mk "$d" doc.md
if "$LINT" "$d" >/dev/null 2>"$TMP/a2.err"; then
  fail "A2 missing asserted_at accepted (as-of has nothing to resolve against)"
elif grep -q 'no asserted_at' "$TMP/a2.err"; then ok "A2 missing asserted_at rejected and named"
else fail "A2 rejected but the message does not name the missing field"; fi

# A3 — explicit unknown with a reason
d="$TMP/a3"; mk "$d" doc.md "asserted_at: unknown" "asserted_at_note: \"undated internal memo, no byline\""
if "$LINT" "$d" >/dev/null 2>&1; then ok "A3 explicit unknown with a note passes"
else fail "A3 explicit unknown rejected — undated sources must stay ingestable"; fi

# A4 — bare unknown
d="$TMP/a4"; mk "$d" doc.md "asserted_at: unknown"
if "$LINT" "$d" >/dev/null 2>&1; then fail "A4 bare \`unknown\` accepted with no reason"
else ok "A4 \`unknown\` without asserted_at_note rejected"; fi

# A5 — THE GOODHART CHECK: stamp fetched_at as the document date
d="$TMP/a5"; mk "$d" doc.md "asserted_at: 2026-07-24" "asserted_at_source: #method"
if "$LINT" "$d" >/dev/null 2>"$TMP/a5.err"; then
  fail "A5 fetch-date stamping accepted (every source looks dated, nothing is)"
elif grep -q 'fetched_at' "$TMP/a5.err"; then
  ok "A5 fetch-date stamping rejected and the pattern is named in the message"
else fail "A5 rejected but the message does not call out the fetched_at pattern"; fi

# A6 — anchor resolves nowhere
d="$TMP/a6"; mk "$d" doc.md "asserted_at: 2026-03-31" "asserted_at_source: #nope"
if "$LINT" "$d" >/dev/null 2>&1; then fail "A6 unresolvable asserted_at_source accepted"
else ok "A6 anchor that does not resolve rejected"; fi

# A7 — anchor resolves but the passage does not state the date
d="$TMP/a7"; mk "$d" doc.md "asserted_at: 2026-03-31" "asserted_at_source: #method"
if "$LINT" "$d" >/dev/null 2>&1; then
  fail "A7 anchor to a passage without the date accepted (cite anything, prove nothing)"
else ok "A7 anchor whose passage lacks the date rejected"; fi

# A8 — prose date form
d="$TMP/a8"; mkdir -p "$d"
{ echo "---"; echo "source_type: note"; echo "fetched_at: 2026-07-24"
  echo "asserted_at: 2026-03-31"; echo "asserted_at_source: #period"
  echo "ingested_hash: abc123"; echo "ingested_at: 2026-07-24 10:00"; echo "---"
  echo ""; echo "## Period"; echo ""; echo "Published March 31, 2026 by the platform team."
} > "$d/doc.md"
if "$LINT" "$d" >/dev/null 2>&1; then ok "A8 prose date form (\"March 31, 2026\") satisfies the ISO field"
else fail "A8 prose date rejected — would force authors to edit raw/, which rule 1 forbids"; fi

# A9 — never ingested
d="$TMP/a9"; mkdir -p "$d"
{ echo "---"; echo "source_type: note"; echo "fetched_at: 2026-07-24"
  echo "ingested_hash: \"\""; echo "ingested_at: never"; echo "---"; echo ""; echo "Body."
} > "$d/doc.md"
if "$LINT" "$d" >/dev/null 2>&1; then ok "A9 never-ingested source skipped (extract's job, not the lint's)"
else fail "A9 never-ingested source flagged — noise trains users to ignore the lint"; fi

# A10 — sidecar pair: the binary half carries no frontmatter
d="$TMP/a10"; mkdir -p "$d"
printf 'id,region\n1,west\n' > "$d/data.csv"
{ echo "---"; echo "source_type: csv"; echo "fetched_at: 2026-07-24"
  echo "asserted_at: 2026-03-31"; echo "asserted_at_source: #period"
  echo "ingested_hash: abc123"; echo "ingested_at: 2026-07-24 10:00"; echo "---"
  echo ""; echo "## Period"; echo ""; echo "Extract covers through 2026-03-31."
} > "$d/data.csv.md"
if "$LINT" "$d" >/dev/null 2>&1; then ok "A10 sidecar pair audited once, on the .md that carries frontmatter"
else fail "A10 sidecar pair flagged (the binary half has no frontmatter by design)"; fi

# A11 — the repo's own raw/, advisory: these sources predate the field
if [ -d raw ]; then
  if "$LINT" raw >/dev/null 2>"$TMP/real.err"; then
    ok "A11 real raw/ already satisfies the valid-time contract"
  else
    note "A11 real raw/ has $(grep -c 'asserted_at' "$TMP/real.err" || echo '?') source(s) without valid time — expected until backfilled (advisory)"
  fi
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d valid-time check(s) did not pass.\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s A1-A10 green — dates traceable, unknowns explicit, fetch-date stamping blocked.\n" "$GREEN" "$RESET"
exit 0
