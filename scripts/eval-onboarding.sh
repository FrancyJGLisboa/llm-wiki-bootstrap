#!/usr/bin/env bash
# scripts/eval-onboarding.sh — empirical newcomer ease-of-use eval.
#
# Turns "is this easier to use?" into a number. Drives `claude -p` as a brand-new
# user in a FRESH wiki (built by create-llm-wiki.sh) whose only entry point is the
# README, hands it a source file + a question with a known answer, and measures
# whether it reaches the answer and how much friction it hit. A separate doc-judge
# scores the two checks that are document properties, not behaviours.
#
# Loss function — 5 binary checks (approved):
#   C1  reaches a correct first answer following the README        [behavioural]
#   C2  one unambiguous "start here" across README/QUICKSTART/FRESH [doc-judge]
#   C3  zero dead-ends on the happy path (no error tool-results)    [behavioural]
#   C4  discoverable without opening AGENTS.md (295-line schema)    [behavioural]
#   C5  <= 2 new concepts required before first value               [doc-judge]
#
# ease score = passed / 5, plus a ranked friction list (action count, dead-ends,
# whether AGENTS.md had to be opened, and the judge's reasons).
#
# Philosophy (mirrors eval-multi-hop / eval-citation-faithfulness): the
# deliverable is the MEASUREMENT. Exit 0 when the harness completes; non-zero
# only on setup failure or when --min-score is given and not met.
#
# Usage:
#   scripts/eval-onboarding.sh [--keep] [--min-score <0..5>]
#     --keep        leave the temp fresh-wiki for inspection (prints the path)
#     --min-score N fail (exit 1) if the ease score is below N
#
# Exit codes: 0 completed (>= --min-score), 1 below --min-score, 2 setup error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/eval/onboarding-fixture/source.md"
QUESTION="What Halcyon Index value triggers a managed-retreat review?"
EXPECT_TOKENS=("60" "managed-retreat")   # both must appear (case-insensitive)

keep=0; min_score=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --keep) keep=1; shift ;;
    --min-score) min_score="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "error: unknown arg $1" >&2; exit 2 ;;
  esac
done

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else RED=; GREEN=; YELLOW=; DIM=; RESET=; fi
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
no()   { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; }
info() { printf "%s•%s %s\n" "$DIM"   "$RESET" "$1"; }

command -v claude  >/dev/null 2>&1 || { echo "error: claude CLI required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 required" >&2; exit 2; }
[ -f "$FIXTURE" ] || { echo "error: fixture missing: $FIXTURE" >&2; exit 2; }

WORK="$(mktemp -d -t eval-onboarding.XXXXXX)"
WIKI="$WORK/newwiki"
cleanup() { [ "$keep" -eq 1 ] && { echo "kept: $WORK" >&2; return; }; rm -rf "$WORK"; }
trap cleanup EXIT

info "building a fresh wiki (what a newcomer gets) ..."
"$SCRIPT_DIR/create-llm-wiki.sh" "$WIKI" >/dev/null 2>&1 || { echo "error: create-llm-wiki.sh failed" >&2; exit 2; }
mkdir -p "$WIKI/inbox"
cp "$FIXTURE" "$WIKI/inbox/source.md"

# ── Behavioural run: a newcomer whose only briefing is the README ──────────────
STREAM="$WORK/stream.jsonl"
NEWCOMER_PROMPT="You just installed this tool and know nothing about how it works. \
Read README.md to learn its normal workflow. A colleague left a source file at \
inbox/source.md. Using this tool's intended workflow, bring that source in and then \
answer this question from the resulting wiki: \"$QUESTION\". Actually run the steps — \
do not just describe them. End your reply with a line exactly like: FINAL ANSWER: <answer>."

info "running the newcomer (claude -p, fresh wiki, README-only briefing) ..."
# bypassPermissions: this WIKI is a disposable mktemp sandbox and the eval
# simulates a real user who approves the workflow's writes. Without it the agent
# cannot write raw//wiki/ and we'd measure the permission gate, not the docs.
( cd "$WIKI" && claude -p --output-format stream-json --verbose \
    --permission-mode bypassPermissions "$NEWCOMER_PROMPT" </dev/null \
    > "$STREAM" 2>/dev/null ) || true

# ── Parse the event stream deterministically ──────────────────────────────────
EXPECT_JOINED="$(IFS='|'; echo "${EXPECT_TOKENS[*]}")"
read -r REACHED ACTIONS DEAD_ENDS READ_AGENTS FINAL < <(python3 - "$STREAM" "$EXPECT_JOINED" <<'PY'
import json, sys
stream, expect = sys.argv[1], sys.argv[2].lower().split("|")
actions = dead_ends = read_agents = 0
final = ""
for line in open(stream, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        e = json.loads(line)
    except Exception:
        continue
    t = e.get("type")
    if t == "assistant":
        for b in e.get("message", {}).get("content", []):
            if b.get("type") == "tool_use":
                actions += 1
                blob = json.dumps(b.get("input", {})).lower()
                if "agents.md" in blob:
                    read_agents += 1
    elif t == "user":
        for b in e.get("message", {}).get("content", []):
            if b.get("type") == "tool_result" and b.get("is_error"):
                dead_ends += 1
    elif t == "result":
        final = e.get("result", "") or ""
low = final.lower()
reached = 1 if all(tok in low for tok in expect) else 0
# single space-free line for `read`
print(reached, actions, dead_ends, 1 if read_agents else 0,
      final.replace("\n", " ")[:400] or "(no final text)")
PY
)

# ── C1 hardening: the answer must come from a wiki the newcomer actually BUILT,
# not from reciting the raw source while blocked. The source's distinctive term
# ("Halcyon") landing in a wiki/ page proves extract+ingest really happened.
WIKI_BUILT=0
grep -rqi "halcyon" "$WIKI/wiki/" 2>/dev/null && WIKI_BUILT=1

# ── Doc-judge: the two checks that are document properties (C2, C5) ────────────
judge() {  # $1 = check description; echoes PASS|FAIL + reason
  local q="$1" out
  local docs="===README.md===
$(cat README.md 2>/dev/null)
===QUICKSTART.md===
$(sed -n '1,80p' docs/QUICKSTART.md 2>/dev/null)
===templates/README-fresh.md (NOT a repo entry point — the installer ships this as the README INSIDE a freshly-created clean wiki, which has no demo to query; it is never read from the bootstrap repo root)===
$(cat templates/README-fresh.md 2>/dev/null)"
  local prompt="You are auditing a tool's onboarding docs for EASE OF USE for a brand-new user. \
Answer this yes/no question, then on the FINAL line output exactly VERDICT=PASS or VERDICT=FAIL.
Be strict: if a newcomer would be confused, that is a FAIL.

QUESTION: $q

DOCS:
$docs"
  out="$(claude -p "$prompt" </dev/null 2>/dev/null)" || out=""
  local v; v="$(printf '%s\n' "$out" | grep -oiE 'VERDICT=(PASS|FAIL)' | tail -1 | tr '[:lower:]' '[:upper:]')"
  local reason; reason="$(printf '%s' "$out" | grep -ivE 'VERDICT=' | grep -E '[A-Za-z]' | tail -1 | cut -c1-120)"
  case "$v" in
    *PASS*) echo "PASS|$reason" ;;
    *) echo "FAIL|${reason:-judge unparseable -> fail-closed}" ;;
  esac
}

info "doc-judge scoring C2 (one start-here) and C5 (<=2 concepts) ..."
C2="$(judge "Is there ONE unambiguous 'start here' first command + example query that README, QUICKSTART, and README-FRESH agree on — with no contradictory demo queries and no decision a newcomer must resolve before their first answer?")"
C5="$(judge "Can a newcomer reach their FIRST useful answer while holding at most TWO new concepts — i.e. the happy path does NOT require understanding the frontmatter spec, slug rules, typed relations, or citation anchors up front?")"
C2_V="${C2%%|*}"; C2_R="${C2#*|}"
C5_V="${C5%%|*}"; C5_R="${C5#*|}"

# ── Score the 5 checks ────────────────────────────────────────────────────────
score=0
echo
printf "%s== onboarding ease-of-use ==%s\n" "$DIM" "$RESET"
if [ "$REACHED" = 1 ] && [ "$WIKI_BUILT" = 1 ]; then
  ok "C1 newcomer built the wiki AND reached a correct first answer"; score=$((score+1))
elif [ "$REACHED" = 1 ]; then
  no "C1 answer tokens present but wiki was NOT built (recited the raw source — not a real first answer)"
else
  no "C1 newcomer did NOT reach a correct answer (wiki_built=$WIKI_BUILT)"
fi
[ "$C2_V" = PASS ]      && { ok "C2 one unambiguous start-here";              score=$((score+1)); } \
                        || no "C2 start-here is ambiguous — $C2_R"
[ "${DEAD_ENDS:-0}" -eq 0 ] && { ok "C3 zero dead-ends on the happy path";    score=$((score+1)); } \
                        || no "C3 hit ${DEAD_ENDS} dead-end(s) / error tool-result(s)"
[ "${READ_AGENTS:-1}" -eq 0 ] && { ok "C4 done without opening AGENTS.md";    score=$((score+1)); } \
                        || no "C4 had to open AGENTS.md (295-line schema) to proceed"
[ "$C5_V" = PASS ]      && { ok "C5 <=2 concepts to first value";             score=$((score+1)); } \
                        || no "C5 too many concepts up front — $C5_R"

echo
printf "%sease score: %s/5%s\n" "$GREEN" "$score" "$RESET"
printf "%sfriction:%s wiki built: %s; %s tool-action(s); %s dead-end(s); AGENTS.md opened: %s\n" \
  "$DIM" "$RESET" "$([ "${WIKI_BUILT:-0}" -eq 1 ] && echo yes || echo NO)" \
  "${ACTIONS:-?}" "${DEAD_ENDS:-?}" "$([ "${READ_AGENTS:-1}" -eq 0 ] && echo no || echo yes)"
printf "%sfinal answer:%s %s\n" "$DIM" "$RESET" "$FINAL"

if [ -n "$min_score" ] && [ "$score" -lt "$min_score" ]; then
  echo; no "ease score $score < --min-score $min_score"; exit 1
fi
exit 0
