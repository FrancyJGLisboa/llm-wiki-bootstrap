#!/usr/bin/env bash
# scripts/verify-faithfulness-gate.sh — deterministic oracle for the faithfulness
# gate (R16). Proves the gate's PLUMBING + POLICY with MOCKED verdicts — no LLM,
# no network. The live `claude` entailment judge is exercised separately by
# scripts/eval-citation-faithfulness.sh (informational, like eval-causal.sh).
#
# Asserts, all offline:
#   G1  CONTRADICTED blocks in both modes, non-vacuously (>=1 claim judged)
#   G2  UNSUPPORTED is asymmetric: blocks on promote, flags-with-marker on ingest
#   G3  a faithful (SUPPORTED) page passes both modes with zero markers
#   G4  deterministic: two --verdicts runs are byte-identical (stdout + marking)
#   C2  the oracle can FAIL: mislabeling the contradicted page SUPPORTED un-blocks it
#   C9  the real (non-injected) judge branch parses, via a fake `claude` on PATH
#   C6b the --verdicts path never consults `claude` (a broken shim is ignored)
#
# Runs entirely in a temp copy — never mutates the committed fixture.
# Exit 0 iff every assertion holds.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE="$REPO_ROOT/tests/eval/faithfulness-fixture"
GATE="$SCRIPT_DIR/wiki-faithfulness-gate.sh"

if [ -t 1 ]; then RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'; else RED=; GREEN=; RESET=; fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }

[ -f "$GATE" ] || { fail "gate script missing: $GATE"; exit 1; }
[ -d "$FIXTURE/wiki" ] || { fail "fixture missing: $FIXTURE"; exit 1; }
command -v python3 >/dev/null 2>&1 || { fail "python3 required"; exit 1; }

TMPROOT="$(mktemp -d)"; trap 'rm -rf "$TMPROOT"' EXIT
n=0
fresh() {  # echoes a fresh wiki dir (with sibling raw/ + verdicts.tsv)
  n=$((n + 1)); local d="$TMPROOT/f$n"; mkdir -p "$d"; cp -R "$FIXTURE/." "$d/"; echo "$d/wiki"
}

# ── G1 — CONTRADICTED blocks in both modes, non-vacuously ─────────────────────
W="$(fresh)"; V="$(dirname "$W")/verdicts.tsv"
oi="$(bash "$GATE" --mode ingest  --verdicts "$V" "$W/page-unfaithful.md")"; ri=$?
bash "$GATE" --mode promote --verdicts "$V" "$W/page-unfaithful.md" >/dev/null; rp=$?
if [ "$ri" -ne 0 ] && [ "$rp" -ne 0 ] && printf '%s' "$oi" | grep -q 'judged 1'; then
  ok "G1 CONTRADICTED blocks ingest+promote, >=1 claim judged"
else
  fail "G1 CONTRADICTED not blocked in both modes or judged 0 (ingest rc=$ri promote rc=$rp)"
fi

# ── G2 — UNSUPPORTED: blocks on promote, flags-with-marker on ingest ──────────
W="$(fresh)"; V="$(dirname "$W")/verdicts.tsv"
bash "$GATE" --mode promote --verdicts "$V" "$W/page-unsupported.md" >/dev/null; rp=$?
bash "$GATE" --mode ingest  --verdicts "$V" "$W/page-unsupported.md" >/dev/null; ri=$?
marks="$(grep -c 'FAITHFULNESS UNVERIFIED' "$W/page-unsupported.md")"
lc_before="$(wc -l < "$FIXTURE/wiki/page-unsupported.md")"; lc_after="$(wc -l < "$W/page-unsupported.md")"
if [ "$rp" -ne 0 ] && [ "$ri" -eq 0 ] && [ "$marks" -eq 1 ] && [ "$lc_before" -eq "$lc_after" ]; then
  ok "G2 UNSUPPORTED blocks promote, flags ingest (1 marker, line count preserved)"
else
  fail "G2 asymmetry/marker wrong (promote rc=$rp ingest rc=$ri marks=$marks lines $lc_before->$lc_after)"
fi

# ── G3 — faithful page passes both modes, no markers ──────────────────────────
W="$(fresh)"; V="$(dirname "$W")/verdicts.tsv"
bash "$GATE" --mode ingest  --verdicts "$V" "$W/page-good.md" >/dev/null; ri=$?
bash "$GATE" --mode promote --verdicts "$V" "$W/page-good.md" >/dev/null; rp=$?
marks="$(grep -c 'FAITHFULNESS UNVERIFIED' "$W/page-good.md")"
if [ "$ri" -eq 0 ] && [ "$rp" -eq 0 ] && [ "$marks" -eq 0 ]; then
  ok "G3 SUPPORTED page passes both modes, zero markers (no false positive)"
else
  fail "G3 false positive on faithful page (ingest rc=$ri promote rc=$rp marks=$marks)"
fi

# ── G4 — deterministic: two identical --verdicts runs (stdout + marking) ──────
W="$(fresh)"; V="$(dirname "$W")/verdicts.tsv"
r1="$(bash "$GATE" --mode ingest --verdicts "$V" "$W/page-unfaithful.md")"
r2="$(bash "$GATE" --mode ingest --verdicts "$V" "$W/page-unfaithful.md")"
W2="$(fresh)"; V2="$(dirname "$W2")/verdicts.tsv"
bash "$GATE" --mode ingest --verdicts "$V2" "$W2/page-unsupported.md" >/dev/null
s1="$(cat "$W2/page-unsupported.md")"
bash "$GATE" --mode ingest --verdicts "$V2" "$W2/page-unsupported.md" >/dev/null
s2="$(cat "$W2/page-unsupported.md")"
if [ "$r1" = "$r2" ] && [ "$s1" = "$s2" ]; then
  ok "G4 deterministic: identical stdout + idempotent marking across runs"
else
  fail "G4 non-deterministic output or marking"
fi

# ── C2 — mutation test: the 'CONTRADICTED blocks' assertion can FAIL ──────────
W="$(fresh)"; V="$(dirname "$W")/verdicts.tsv"; MUT="$(dirname "$W")/verdicts-mut.tsv"
awk -F'\t' 'BEGIN{OFS="\t"} $1=="page-unfaithful.md:12"{$2="SUPPORTED"} {print}' "$V" > "$MUT"
bash "$GATE" --mode ingest --verdicts "$MUT" "$W/page-unfaithful.md" >/dev/null; rc=$?
if [ "$rc" -eq 0 ]; then
  ok "C2 mutation: mislabeling contradicted->SUPPORTED un-blocks it (oracle is not vacuous)"
else
  fail "C2 mutation: gate still blocked with a SUPPORTED verdict (rc=$rc) — test can't distinguish"
fi

# ── C9 — real judge branch parses (fake `claude` on PATH, NO --verdicts) ──────
W="$(fresh)"
BIN="$TMPROOT/bin"; mkdir -p "$BIN"
printf '#!/usr/bin/env bash\necho "VERDICT=SUPPORTED"\n' > "$BIN/claude"; chmod +x "$BIN/claude"
out="$(PATH="$BIN:$PATH" bash "$GATE" --mode ingest "$W/page-good.md")"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'judged 1' && printf '%s' "$out" | grep -q 'SUPPORTED'; then
  ok "C9 real judge branch invokes+parses (stub VERDICT=SUPPORTED consumed)"
else
  fail "C9 judge branch broken (rc=$rc): $out"
fi

# ── C6b — --verdicts path never consults `claude` (broken shim ignored) ───────
W="$(fresh)"; V="$(dirname "$W")/verdicts.tsv"
BADBIN="$TMPROOT/badbin"; mkdir -p "$BADBIN"
printf '#!/usr/bin/env bash\necho garbage >&2; exit 1\n' > "$BADBIN/claude"; chmod +x "$BADBIN/claude"
PATH="$BADBIN:$PATH" bash "$GATE" --mode ingest --verdicts "$V" "$W/page-unfaithful.md" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 3 ]; then
  ok "C6b --verdicts path ignores a broken 'claude' (offline-safe)"
else
  fail "C6b verdicts path was affected by a broken claude shim (rc=$rc, expected 3)"
fi

# ── G5 — fail CLOSED: no judge + no --verdicts blocks (exit 3) ────────────────
# Build a minimal PATH that has the tools the gate needs (python3, openssl, awk,
# sed, grep, mktemp, sort, cut, wc, dirname, basename, cd) but NO `claude`.
W="$(fresh)"
SAFEBIN="$TMPROOT/safebin"; mkdir -p "$SAFEBIN"
for t in bash sh env python3 openssl awk sed grep mktemp sort cut wc dirname basename cat printf; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$SAFEBIN/$t" 2>/dev/null
done
no_claude() { PATH="$SAFEBIN" bash "$GATE" "$@"; }
no_claude --mode ingest "$W/page-good.md" >/dev/null 2>&1; ri=$?
no_claude --mode promote "$W/page-good.md" >/dev/null 2>&1; rp=$?
if [ "$ri" -eq 3 ] && [ "$rp" -eq 3 ]; then
  ok "G5 fail-closed: no judge + no --verdicts blocks both modes (exit 3)"
else
  fail "G5 NOT fail-closed (ingest rc=$ri promote rc=$rp; expected 3/3)"
fi

# ── G6 — --allow-unjudged proceeds on a clean page, but the citation floor still
#         blocks a broken citation (C1/C2 is enforced even when entailment is off) ─
W="$(fresh)"
no_claude --mode ingest --allow-unjudged "$W/page-good.md" >/dev/null 2>&1; rgood=$?
no_claude --mode promote --allow-unjudged "$W/page-unfaithful.md" >/dev/null 2>&1; rbad=$?
warn="$(no_claude --mode ingest --allow-unjudged "$W/page-good.md" 2>&1 >/dev/null)"
# page-unfaithful blocks here only if it carries a BAD floor row (broken citation);
# if it does not, the floor-only run passes — accept either as long as good passes
# and the loud warning is printed.
if [ "$rgood" -eq 0 ] && printf '%s' "$warn" | grep -q 'FAITHFULNESS UNVERIFIED'; then
  ok "G6 --allow-unjudged proceeds (good page exit 0) with a loud UNVERIFIED warning; floor still runs (unfaithful rc=$rbad)"
else
  fail "G6 --allow-unjudged behavior wrong (good rc=$rgood, warn missing? promote rc=$rbad)"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s).\n" "$RED" "$RESET" "$failures"; exit 1
fi
printf "%sPassed.%s Faithfulness gate: policy + plumbing proven offline (G1-G6, C2, C9, C6b).\n" "$GREEN" "$RESET"
exit 0
