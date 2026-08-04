#!/usr/bin/env bash
# scripts/verify-query-temporal-contract.sh — guard the /wiki-query contract for
# change-over-time questions. No LLM, no spend.
#
# Why this exists: cross-temporal questions ("how did his position change",
# "does he still think that") scored 3/6 while single-source dated recall scored
# 16/16. The mechanism was not comprehension — it was that the failing answers
# opened ZERO files and narrated a trajectory out of the auto-generated
# synthesis artifacts, which aggregate the timeline away.
#
# The fix is two halves that only work together: a router that tells the model
# to materialize the dated reading list (wiki-timeline.py), and a floor that
# makes the zero-read answer unexpressible (wiki-metrics.sh --temporal). Either
# half alone is decorative — a router with no floor is a suggestion, a floor
# with no router is a wall with no door.
#
# This is the same shape as verify-query-citation-contract.sh, and for the same
# reason: that contract silently decayed three times (R4 = 0/5, 0/5, 0/7) before
# it had a test. A spec with no test decays.
#
# The FIRST version of this feature left the classification to the model — the
# doc listed trigger phrases and asked it to notice. Measured: 3/7 with a median
# of ZERO file reads. The model that misses a cross-temporal question is the same
# one that won't run a check on itself, so the guard was skipped exactly when it
# was needed. The router is now unconditional and the classification is in code;
# T2 and T6 exist to stop that regression from coming back quietly.
#
#   T1 the doc has a temporal-traversal section
#   T2 the router is UNCONDITIONAL (--question, run always, no model judgment)
#   T3 it states the >= 2 distinct dates floor and calls it blocking
#   T4 it invokes scripts/wiki-timeline.py by exact path (catches a rename)
#   T5 the floor actually blocks — asserted BOTH directions against the real
#      wiki-metrics.sh on a fixture: two dated citations pass, one fails
#   T6 the classifier MEASURES up on the real question sets: recall on the 30
#      cross-temporal questions, restraint on the point-in-time `-asof` ones
#
# T5 and T6 are the ones that matter. T1-T4 assert the doc says the right words;
# T5 asserts the floor is a mechanism rather than a promise, and T6 asserts the
# classifier still carries signal — one that degraded to "always SINGLE-POINT"
# would leave every other check green while restoring the original failure.
#
# Usage: ./scripts/verify-query-temporal-contract.sh   Exit: 0 green, 1 failed.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DOC=".claude/commands/wiki-query.md"
if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

[ -f "$DOC" ] || { fail "T0 $DOC missing"; exit 1; }

# T1 — the router section exists at all
grep -qiE '^\*\*Temporal / change-over-time traversal' "$DOC" \
  && ok "T1 doc has a temporal / change-over-time traversal section" \
  || fail "T1 no temporal traversal section (change-over-time questions fall through to synthesis)"

# T2 — THE regression that produced 3/7 with 0 reads: the router must be
# UNCONDITIONAL. Earlier this check asserted the doc listed trigger phrases for
# the model to match on; that design is exactly what failed, so the check now
# asserts the opposite — that the doc tells the model to run the classifier
# every time and pass the question through, rather than judging it first.
t2=0
grep -qiE 'run this ALWAYS|unconditional' "$DOC" || t2=1
grep -qF -- '--question' "$DOC" || t2=1
grep -qiE 'Not "if the question looks temporal"|not to decide whether to' "$DOC" || t2=1
[ "$t2" -eq 0 ] \
  && ok "T2 doc makes the router unconditional (--question, run always, no model-side judgment)" \
  || fail "T2 the router is conditional again — a guard the model must decide to run is skipped exactly when needed"

# T3 — the floor is stated AND called blocking. "Should read two sources" is
# advice; "exit 4 is blocking" is a contract.
t3=0
grep -qiE 'two (rows|distinct dates|different dates)|>= ?2|at least two' "$DOC" || t3=1
grep -qiF -- '--temporal' "$DOC" || t3=1
grep -qiE 'blocking' "$DOC" || t3=1
[ "$t3" -eq 0 ] \
  && ok "T3 doc states the >=2-distinct-dates floor and calls it blocking" \
  || fail "T3 the floor is absent, unquantified, or phrased as advice rather than a block"

# T4 — exact script path, so a rename breaks the test instead of the feature
grep -qF 'scripts/wiki-timeline.py' "$DOC" \
  && ok "T4 doc invokes scripts/wiki-timeline.py by exact path" \
  || fail "T4 doc does not name scripts/wiki-timeline.py (router has nothing to call)"

# T5 — the mechanism, exercised both ways on a real fixture.
FIX=$(mktemp -d -t temporal-contract.XXXXXX)
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/raw" "$FIX/wiki"
printf -- '---\nasserted_at: 2021-02-25\n---\n\nChina cancelled cargoes this week.\n' > "$FIX/raw/early.md"
printf -- '---\nasserted_at: 2022-04-01\n---\n\nThe cancellations largely reversed.\n' > "$FIX/raw/late.md"
printf -- 'Then (source: raw/early.md), later (source: raw/late.md).\n\n- Wiki: [[x]]\n' > "$FIX/two.md"
printf -- 'Only one point in time (source: raw/early.md).\n\n- Wiki: [[x]]\n' > "$FIX/one.md"

bash "$SCRIPT_DIR/wiki-metrics.sh" query "$FIX/two.md" "$FIX" --temporal >/dev/null 2>&1
pass_rc=$?
bash "$SCRIPT_DIR/wiki-metrics.sh" query "$FIX/one.md" "$FIX" --temporal >/dev/null 2>&1
block_rc=$?

if [ "$pass_rc" -eq 0 ] && [ "$block_rc" -eq 4 ]; then
  ok "T5 the floor admits two dated citations (rc=0) and blocks one (rc=4)"
elif [ "$pass_rc" -ne 0 ]; then
  fail "T5 the floor BLOCKED a legitimate two-date answer (rc=$pass_rc) — it would suppress correct answers"
else
  fail "T5 the floor PASSED a single-date answer (rc=$block_rc, want 4) — the 3/6 failure is unguarded"
fi

# T6 — the classifier's MEASURED behaviour, against the real question sets.
# T1-T5 assert the wiring; this asserts the wiring carries signal. A classifier
# that silently degrades to "never fires" would leave every other check green
# while restoring the original failure, because the router would still be
# invoked — it would just always say SINGLE-POINT.
TQ="tests/eval/grain-corpus/temporal-questions.md"
GQ="tests/eval/grain-corpus/gold-questions.md"
if [ -f "$TQ" ] && [ -f "$GQ" ] && command -v python3 >/dev/null 2>&1; then
  t6=$(python3 - "$TQ" "$GQ" <<'PY'
import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("wt", "scripts/wiki-timeline.py")
wt = importlib.util.module_from_spec(spec); spec.loader.exec_module(wt)

def questions(path):
    out = []
    for blk in re.split(r"^### ", open(path, encoding="utf-8").read(), flags=re.M)[1:]:
        lines = blk.split("\n"); qid = lines[0].strip(); body = []
        for ln in lines[1:]:
            if re.match(r"^[a-z-]+:", ln):
                break
            # chr(96) is a backtick. Written this way because bash 3.2 scans
            # backticks inside $( ... <<'HEREDOC' ) even when the delimiter is
            # quoted, and a literal fence here is a syntax error in the caller.
            if ln.startswith(chr(96) * 3) or ln.startswith("#"):
                continue
            body.append(ln)
        q = " ".join(body).strip()
        if q:
            out.append((qid, q))
    return out

pos = questions(sys.argv[1])
# `-asof` questions ask what was true at ONE moment — point-in-time retrieval,
# not reconciliation. They are the discipline half: a classifier that fires on
# everything would score perfect recall and be worthless.
asof = [(i, q) for i, q in questions(sys.argv[2]) if i.startswith("A2") and i.endswith("-asof")]
hit_pos = sum(1 for _i, q in pos if wt.classify(q)[0])
hit_asof = sum(1 for _i, q in asof if wt.classify(q)[0])
print(f"{hit_pos} {len(pos)} {hit_asof} {len(asof)}")
PY
)
  set -- $t6
  if [ "${1:-0}" -ge 28 ] && [ "${3:-99}" -le 2 ]; then
    ok "T6 classifier recall ${1}/${2} cross-temporal, fires on only ${3}/${4} point-in-time"
  else
    fail "T6 classifier measured ${1:-?}/${2:-?} recall and ${3:-?}/${4:-?} point-in-time fires (want >=28 recall, <=2 fires)"
  fi
else
  ok "T6 skipped (question sets or python3 absent — nothing to measure against)"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d /wiki-query temporal-contract check(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s T1-T6 green — router unconditional, floor blocks, classifier measured.\n" "$GREEN" "$RESET"
exit 0
