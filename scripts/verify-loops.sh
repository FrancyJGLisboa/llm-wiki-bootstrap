#!/usr/bin/env bash
# scripts/verify-loops.sh — deterministic oracle for wiki-loops.py and
# wiki-flows.sh. No LLM, no spend. L1–L6, all must pass.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOPS="$SCRIPT_DIR/wiki-loops.py"
FLOWS="$SCRIPT_DIR/wiki-flows.sh"

fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }
tmp="$(mktemp -d -t verify-loops.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

edge() { printf '{"source": "%s", "verb": "%s", "target": "%s", "sourced": %s}\n' "$1" "$2" "$3" "${4:-true}"; }

# Fixture: one reinforcing 3-loop (a→b→c→a, all positive), one balancing
# 2-loop (d→e via causes, e→d via prevents), acyclic noise, a non-causal verb
# (must be ignored), and an uncited edge inside the reinforcing loop.
fixture() {  # $1..$5 = node names for a b c d e ; $6 = 1 to shuffle line order
  local a="$1" b="$2" c="$3" d="$4" e="$5" out="$tmp/fx"
  : > "$out"
  edge "$a" causes "$b" false           >> "$out"
  edge "$b" enables "$c"                >> "$out"
  edge "$c" contributes-to "$a"         >> "$out"
  edge "$d" causes "$e"                 >> "$out"
  edge "$e" prevents "$d"               >> "$out"
  edge "$a" causes "noise1"             >> "$out"
  edge "noise1" founded-by "noise2"     >> "$out"
  if [ "${6:-0}" -eq 1 ]; then sort -r "$out" > "$out.s" && mv "$out.s" "$out"; fi
  cat "$out"
}

echo "L1: detection + polarity — exactly one reinforcing and one balancing loop"
out=$(fixture aa bb cc dd ee 0 | python3 "$LOOPS")
n_loops=$(printf '%s\n' "$out" | grep -c '^\(reinforcing\|balancing\|mixed\)' || true)
[ "$n_loops" = "2" ] && ok "exactly 2 loops found" || fail "expected 2 loops, got $n_loops: $out"
printf '%s\n' "$out" | grep -q '^reinforcing: aa -> bb -> cc -> aa' && ok "3-loop classified reinforcing" || fail "reinforcing 3-loop wrong: $out"
printf '%s\n' "$out" | grep -q '^balancing: dd -> ee -> dd' && ok "odd-prevents loop classified balancing" || fail "balancing loop wrong: $out"
printf '%s\n' "$out" | grep -q 'noise' && fail "acyclic/non-causal noise leaked into a loop" || ok "acyclic noise and non-causal verbs excluded"

echo "L2: provenance — uncited edges are named, never laundered"
printf '%s\n' "$out" | grep '^reinforcing' | grep -q 'contains uncited edge' \
  && ok "loop with sourced:false edge labelled uncited" || fail "uncited edge not surfaced"
printf '%s\n' "$out" | grep '^balancing' | grep -q 'all edges cited' \
  && ok "fully-cited loop labelled cited" || fail "cited loop mislabelled"

echo "L3: renaming + reordering invariance (anti-hardcoding)"
out2=$(fixture zulu yankee xray whisky victor 1 | python3 "$LOOPS")
n2=$(printf '%s\n' "$out2" | grep -c '^\(reinforcing\|balancing\)' || true)
[ "$n2" = "2" ] && ok "2 loops under renamed, reverse-sorted input" || fail "renamed fixture: got $n2 loops"
printf '%s\n' "$out2" | grep -q '^balancing: victor -> whisky -> victor\|^balancing: whisky -> victor -> whisky' \
  && ok "balancing classification stable under renaming" || fail "polarity changed under renaming: $out2"

echo "L4: caused-by normalization (reversed edge closes a loop)"
{ edge p causes q; edge p caused-by q; } | python3 "$LOOPS" > "$tmp/l4"
grep -q '^reinforcing: p -> q -> p' "$tmp/l4" && ok "caused-by reversed into a closing edge" || fail "caused-by loop missed: $(cat "$tmp/l4")"

echo "L5: honesty on absence — acyclic and empty graphs"
{ edge a causes b; edge b causes c; } | python3 "$LOOPS" | grep -q '^No feedback loops' \
  && ok "acyclic graph reports no loops" || fail "acyclic graph fabricated a loop"
printf '' | python3 "$LOOPS" | grep -q 'No causal edges' \
  && ok "empty graph says so" || fail "empty graph mishandled"
{ edge a causes b; edge b prevents c; edge c prevents a; } | python3 "$LOOPS" \
  | grep -q '^reinforcing: a -> b -> c -> a' \
  && ok "even number of prevents = reinforcing (two negatives multiply out)" \
  || fail "even-prevents polarity wrong"

echo "L6: wiki-flows.sh — stocks and flows from a fixture wiki"
mkdir -p "$tmp/w/wiki" "$tmp/w/raw"
printf 'x\n' > "$tmp/w/wiki/a.md"; printf 'x\n' > "$tmp/w/wiki/b.md"; printf 'x\n' > "$tmp/w/raw/s.md"
printf '# log.md\n\n## 2026-06-01 — first ingest\n\ntext\n\n## 2026-06-15 — lint apply\n\ntext\n\n## 2026-07-02 — promote\n\ntext\n' > "$tmp/w/log.md"
fout=$("$FLOWS" "$tmp/w")
printf '%s\n' "$fout" | grep -q 'wiki pages: 2   raw sources: 1' && ok "stocks counted" || fail "stocks wrong: $fout"
printf '%s\n' "$fout" | grep -q '2026-06: 2 entries' && ok "monthly flow counted (2026-06: 2)" || fail "flows wrong: $fout"
printf '%s\n' "$fout" | grep -q 'total logged operations: 3' && ok "total flow counted" || fail "total wrong: $fout"

echo ""
if [ "$fails" -eq 0 ]; then
  echo "verify-loops: L1–L6 all green — loop detection, polarity, provenance, and flows hold."
  exit 0
fi
echo "verify-loops: $fails failure(s)" >&2
exit 1
