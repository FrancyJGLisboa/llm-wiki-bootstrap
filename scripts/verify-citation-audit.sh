#!/usr/bin/env bash
# scripts/verify-citation-audit.sh — assert the C1+C2 deterministic floor of the
# citation-faithfulness eval actually catches broken citations.
#
# Runs scripts/citation-audit.py against tests/eval/faithfulness-fixture/, which
# plants four cases:
#   page-good.md          — resolves + (live judge) faithful
#   page-unfaithful.md    — resolves but contradicts evidence (caught only by C3)
#   page-broken-file.md   — cites a nonexistent raw file        (C1 must flag)
#   page-broken-anchor.md — cites a nonexistent heading anchor  (C2 must flag)
#
# This pins the deterministic half (no LLM): the floor must flag exactly the two
# broken citations and must NOT flag the two that resolve. The C3 entailment
# teeth are proven by a live `scripts/eval-citation-faithfulness.sh` run (needs
# the claude CLI, like the smoke harness) — not here.
#
# Exit 0 iff the floor behaves correctly.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

AUDIT="$SCRIPT_DIR/citation-audit.py"
WIKI="tests/eval/faithfulness-fixture/wiki"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

command -v python3 >/dev/null 2>&1 || { fail "python3 required"; exit 1; }

report="$(python3 "$AUDIT" "$WIKI" 2>&1)"; rc=$?

# 1. Non-zero exit because broken citations exist.
[ "$rc" -ne 0 ] && ok "audit exits non-zero (broken citations present)" \
                || fail "audit exited 0 — broken citations not detected"

# 2. The broken-file case is flagged (C1).
printf '%s' "$report" | grep -q 'page-broken-file.md.*file missing' \
  && ok "C1 flags the nonexistent raw file" \
  || fail "C1 did not flag page-broken-file.md"

# 2b. A SEGMENTED heading resolves by the anchor AGENTS.md tells the compiler to
# write — the title with its positional range dropped.
#
# This is a regression test for a bug that produced 15,440 unresolvable citations
# in a real 2,414-source corpus without a single check going red. AGENTS.md says
# to cite `## Power Envelope (lines 13-19)` as `#power-envelope`; the resolver
# slugified the whole heading, giving `power-envelope-lines-13-19`, so the two
# could never agree and every citation into a segmented source failed. The
# compiler was following the schema exactly.
#
# Both forms must resolve — the range-dropped one because it is what the schema
# asks for, the full one so packages already citing it keep working. A
# nonexistent heading must still fail, or this "fix" is just a resolver that
# says yes.
seg_probe="$(python3 - "$AUDIT" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("ca", sys.argv[1])
ca = importlib.util.module_from_spec(spec); spec.loader.exec_module(ca)
lines = ["---", "a: b", "---", "", "## Power Envelope (lines 13-19)", "", "body text."]
dropped = ca.resolve_anchor("power-envelope", lines)[0]
full    = ca.resolve_anchor("power-envelope-lines-13-19", lines)[0]
absent  = ca.resolve_anchor("no-such-heading", lines)[0]
print("PASS" if (dropped and full and not absent) else f"FAIL dropped={dropped} full={full} absent={absent}")
PYEOF
)"
[ "$seg_probe" = "PASS" ] \
  && ok "C2 resolves a segmented heading by its range-dropped anchor (AGENTS.md form)" \
  || fail "C2 segmented-anchor resolution: $seg_probe"

# 3. The broken-anchor case is flagged (C2).
printf '%s' "$report" | grep -q 'page-broken-anchor.md.*anchor unresolved' \
  && ok "C2 flags the nonexistent heading anchor" \
  || fail "C2 did not flag page-broken-anchor.md"

# 4. The two resolving pages are NOT flagged (no false positives on the floor).
if printf '%s' "$report" | grep -qE 'page-good\.md|page-unfaithful\.md'; then
  fail "floor false-positive: a resolving citation was flagged as broken"
else
  ok "resolving citations (good + unfaithful) pass the floor — C3's job to judge"
fi

# 5. Path-traversal confinement: a `(source: raw/../secret.txt#L1)` joins to a
# file OUTSIDE raw/. Even if that file exists, C1 must NOT resolve it (it can't
# earn coverage or feed the entailment judge an out-of-tree file), while a
# genuine raw cite and a normalizing raw//x.md cite are handled correctly.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/raw" "$tmp/wiki"
printf 'leaked secret\n' > "$tmp/secret.txt"
printf '# Heading\nreal body line\n' > "$tmp/raw/x.md"
cat > "$tmp/wiki/p.md" <<'EOF'
---
type: concept
---
A traversal claim (source: raw/../secret.txt#L1).
A genuine claim (source: raw/x.md#heading).
EOF
tsv="$(python3 "$AUDIT" "$tmp/wiki" --raw "$tmp/raw" --tsv 2>&1)"
# traversal cite: file part '../secret.txt', C1 column (field 6) must be 0.
if printf '%s' "$tsv" | grep -qE '^BAD	p\.md	4	\.\./secret\.txt	L1	0	0'; then
  ok "C1 confinement: raw/../secret.txt escapes raw/ and does NOT resolve (c1=0)"
else
  fail "C1 did not confine raw/../secret.txt — traversal target resolved (security hole)"
fi
# genuine in-tree cite still resolves (c1=1, c2=1).
if printf '%s' "$tsv" | grep -qE '^OK	p\.md	5	x\.md	heading	1	1'; then
  ok "genuine in-tree cite (raw/x.md#heading) still resolves under confinement"
else
  fail "confinement broke a genuine in-tree citation"
fi
# the default audit on this wiki exits non-zero (the traversal cite is broken).
python3 "$AUDIT" "$tmp/wiki" --raw "$tmp/raw" >/dev/null 2>&1
[ "$?" -ne 0 ] && ok "default audit exits non-zero when a traversal cite is present" \
              || fail "default audit exited 0 with an unresolvable traversal cite"

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s).\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s Citation-audit floor catches broken citations and passes resolving ones.\n" "$GREEN" "$RESET"
exit 0
