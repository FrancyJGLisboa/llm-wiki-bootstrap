#!/usr/bin/env bash
# scripts/verify-scale-eval.sh — deterministic oracle for the scale eval.
# No LLM, no spend. An eval whose filler generator or trace parser is
# unverified measures nothing. F1–F6, all must pass.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GEN="$REPO_ROOT/tests/eval/retrieval-corpus/gen-scale-filler.sh"
TRACE="$SCRIPT_DIR/lib/query-trace.py"
DRIFT="$SCRIPT_DIR/wiki-lint-hash-drift.sh"
EVAL="$SCRIPT_DIR/eval-retrieval.sh"

fails=0
ok()   { echo "  ok: $1"; }
fail() { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }

tmp="$(mktemp -d -t verify-scale.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

mkskel() {  # minimal installed-wiki skeleton
  mkdir -p "$1/wiki" "$1/raw"
  printf -- '---\ntitle: Index\n---\n\n# Index\n\n## Sources\n\n- [[retry-budget-memo-apr-summary]] — needle\n' \
    > "$1/wiki/index.md"
}

echo "F1: filler generation is deterministic (same N → identical manifest)"
mkskel "$tmp/a"; mkskel "$tmp/b"
"$GEN" "$tmp/a" 60 >/dev/null 2>&1 || fail "generator failed on skeleton a"
"$GEN" "$tmp/b" 60 >/dev/null 2>&1 || fail "generator failed on skeleton b"
ha=$(sed -n 's/^sha256=//p' "$tmp/a/.scale-manifest"); hb=$(sed -n 's/^sha256=//p' "$tmp/b/.scale-manifest")
if [ -n "$ha" ] && [ "$ha" = "$hb" ]; then ok "manifests identical ($ha)"; else fail "manifests differ or empty ($ha vs $hb)"; fi

echo "F2: filler shape — every page cited + Related; raw hashes are REAL (drift lint clean)"
n_pages=$(find "$tmp/a/wiki" -name 'scale-*.md' | wc -l | tr -d ' ')
[ "$n_pages" = "60" ] && ok "60 filler pages" || fail "expected 60 pages, got $n_pages"
bad=0
for f in "$tmp/a/wiki"/scale-*.md; do
  grep -q '(source: raw/scale-' "$f" && grep -q '^## Related' "$f" || bad=$((bad + 1))
done
[ "$bad" -eq 0 ] && ok "every page carries a raw citation and a Related section" || fail "$bad pages malformed"
if "$DRIFT" "$tmp/a/raw" >/dev/null 2>&1; then ok "drift lint clean over filler raws (hashes canonical)"; else fail "drift lint fired on freshly generated filler"; fi

echo "F3: filler is DISJOINT from every needle (blocklist) yet DISTRACTOR-DENSE (near-domain terms)"
block=0
for pat in 'NEEDLE' 'sustained[ -]throughput' 'retry[ -]budget' 'application logs' 'backup' 'sandbox' \
           'dead[ -]letter' 'cutover' 'supersed' '(^|[^0-9])(412|389|999)([^0-9]|$)' \
           '(^|[^0-9])(30|35|90|180) days' '(^|[^0-9])(3|7) attempts'; do
  if grep -rqiE "$pat" "$tmp/a/wiki"/scale-*.md "$tmp/a/raw"/scale-*; then
    fail "blocklist hit: $pat"; block=1
  fi
done
[ "$block" -eq 0 ] && ok "no needle phrase, figure, or identifier leaks into filler"
for term in 'retention window' 'retry ceiling' 'peak throughput'; do
  grep -rqi "$term" "$tmp/a/wiki"/scale-*.md && ok "distractor term present: $term" || fail "distractor term missing: $term"
done

echo "F4: index integration — entries match page count, needles survive, idempotent"
have=$(grep -c '^- \[\[scale-' "$tmp/a/wiki/index.md" || true)
[ "$have" = "60" ] && ok "60 index entries" || fail "index entries: $have"
grep -q 'retry-budget-memo-apr-summary' "$tmp/a/wiki/index.md" && ok "pre-existing needle entry untouched" || fail "needle entry lost from index"
"$GEN" "$tmp/a" 60 >/dev/null 2>&1
have2=$(grep -c '^- \[\[scale-' "$tmp/a/wiki/index.md" || true)
[ "$have2" = "60" ] && ok "re-generation is idempotent (still 60 entries)" || fail "re-generation duplicated entries: $have2"

echo "F5: query-trace.py — answer extraction + read counting from a stream transcript"
cat > "$tmp/stream.json" <<'EOF'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/w/wiki/index.md"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/w/wiki/retry-budget.md"}},{"type":"tool_use","name":"Read","input":{"file_path":"/w/raw/memo.md"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Grep","input":{"pattern":"x"}},{"type":"tool_use","name":"Bash","input":{"command":"grep -r foo wiki/"}}]}}
{"type":"result","result":"The answer is 7 attempts."}
EOF
out=$(python3 "$TRACE" "$tmp/stream.json" --counts "$tmp/counts")
[ "$out" = "The answer is 7 attempts." ] && ok "answer text extracted from result event" || fail "answer extraction wrong: '$out'"
counts=$(cat "$tmp/counts")
[ "$counts" = "reads_wiki=2 reads_raw=1 reads_other=0 greps=2" ] \
  && ok "counts correct ($counts)" || fail "counts wrong: '$counts'"
printf 'API Error: 529 Overloaded\n' > "$tmp/garbage"
out=$(python3 "$TRACE" "$tmp/garbage" --counts "$tmp/counts2")
case "$out" in *"API Error"*) ok "unparseable stream falls back to raw bytes (error markers survive)" ;; *) fail "fallback lost error markers" ;; esac

echo "F6: harness flags — --scale validated, advertised in usage"
if "$EVAL" --scale=abc >/dev/null 2>&1; then fail "--scale=abc accepted"; else ok "--scale=abc rejected"; fi
("$EVAL" --bogus 2>&1 || true) | grep -q -- '--scale=N' && ok "usage names --scale" || fail "usage does not name --scale"

echo ""
if [ "$fails" -eq 0 ]; then
  echo "verify-scale-eval: F1–F6 all green — the scale eval's oracle holds."
  exit 0
fi
echo "verify-scale-eval: $fails failure(s)" >&2
exit 1
