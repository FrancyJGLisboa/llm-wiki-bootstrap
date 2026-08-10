#!/usr/bin/env bash
# scripts/verify-corpus-eval.sh — oracle for stage-transcripts.py + eval-corpus.sh.
#
# No LLM, no spend, no network. Every answer is pre-seeded into the work dir,
# which eval-corpus.sh reuses verbatim ("cached, regrading"), so the entire
# grading path runs without a single query. A fake `claude` goes on PATH so the
# CLI presence check passes in CI where the real one is absent.
#
# An eval nobody checks measures nothing. These are the failures that would
# silently make the assessment vacuous rather than wrong-looking:
#
#   V1  the date grader can FAIL — a right-sounding answer citing the wrong
#       episode must not score as retrieval (without this A1 is just A-substring)
#   V2  staging is deterministic — same seed + same source dir => byte-identical
#       manifest, or no published number is reproducible
#   V3  the padding hazard stays fixed — a staged transcript resolves BOTH
#       #04:41 and #4:41, and still rejects a fabricated #99:99
#   V4  --control actually flags a parametric question (the discard list is the
#       only reason to believe A1 on a corpus whose subject is in pretraining)
#   V5  A2 needs BOTH legs — passing only the as-of leg must not score the topic
#
# retr_grade_citation's own honesty (whole-file cites, wrong-line cites,
# oversized-but-containing) is already verified by verify-retrieval-eval.sh E4;
# not duplicated here.
#
# Usage: ./scripts/verify-corpus-eval.sh
# Exit:  0 all checks pass, 1 a check failed, 2 setup error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGE="$SCRIPT_DIR/stage-transcripts.py"
EVAL="$SCRIPT_DIR/eval-corpus.sh"
AUDIT="$SCRIPT_DIR/citation-audit.py"

for f in "$STAGE" "$EVAL" "$AUDIT"; do
  [ -f "$f" ] || { echo "error: missing $f" >&2; exit 2; }
done
command -v python3 >/dev/null 2>&1 || { echo "error: python3 not on PATH" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

passes=0; fails=0
ok()   { echo "  ok   $1"; passes=$((passes + 1)); }
bad()  { echo "  FAIL $1" >&2; fails=$((fails + 1)); }

# Fake claude so eval-corpus.sh's PATH check passes. It is never invoked: every
# answer is pre-seeded, and a call would prove the cache is broken.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/claude" <<'EOF'
#!/bin/sh
echo "verify-corpus-eval: the real claude must never run here" >&2
exit 97
EOF
chmod +x "$TMP/bin/claude"
export PATH="$TMP/bin:$PATH"

# ── A source folder in yt2md shape ────────────────────────────────────────────
SRC="$TMP/src"; mkdir -p "$SRC"
make_src() { # <file> <title> <date> <id>
  cat > "$SRC/$1" <<EOF
# $2

- **Video:** <https://www.youtube.com/watch?v=$4>
- **Channel:** [Test Channel](https://www.youtube.com/channel/UCtest)
- **Uploaded:** $3
- **Duration:** 12:00
- **Captions:** en (auto-generated)

---

## Transcript

**[00:00](https://youtu.be/$4?t=0)** intro boilerplate about risk disclosure

**[04:41](https://youtu.be/$4?t=281)** the marker phrase kilowatt sorghum appears here

**[11:20](https://youtu.be/$4?t=680)** closing remarks and the website plug
EOF
}
# A leading-dash name and a bracketed id: both are live hazards in real folders.
make_src "-Dash Titled Episode [aaaaaaaaaaa].md" "Dash Titled Episode" 2023-04-12 aaaaaaaaaaa
make_src "Second Episode [bbbbbbbbbbb].md"       "Second Episode"      2024-08-03 bbbbbbbbbbb
make_src "Third Episode [ccccccccccc].md"        "Third Episode"       2025-01-27 ccccccccccc

W="$TMP/w1"
python3 "$STAGE" "$SRC" "$W" --all --manifest "$W/manifest.tsv" >"$TMP/stage1.out" 2>&1 \
  || { echo "error: staging failed" >&2; cat "$TMP/stage1.out" >&2; exit 2; }

DASHED=$(ls "$W/raw" | grep '^2023-04-12-' || true)
[ -n "$DASHED" ] || { echo "error: dash-named source did not stage" >&2; exit 2; }

# ── V2 staging determinism ────────────────────────────────────────────────────
W2="$TMP/w2"
python3 "$STAGE" "$SRC" "$W2" --all --manifest "$W2/manifest.tsv" >/dev/null 2>&1
if diff -q "$W/manifest.tsv" "$W2/manifest.tsv" >/dev/null 2>&1 \
   && diff -r -q "$W/raw" "$W2/raw" >/dev/null 2>&1; then
  ok "V2 staging is deterministic (same seed => identical manifest and raw/)"
else
  bad "V2 staging is NOT deterministic — no published number is reproducible"
fi

# A different seed must be able to choose differently, or "seeded" means nothing.
W3="$TMP/w3"
python3 "$STAGE" "$SRC" "$W3" --n 2 --seed 111 --manifest "$W3/manifest.tsv" >/dev/null 2>&1
W4="$TMP/w4"
python3 "$STAGE" "$SRC" "$W4" --n 2 --seed 999 --manifest "$W4/manifest.tsv" >/dev/null 2>&1
if [ -s "$W3/manifest.tsv" ] && [ -s "$W4/manifest.tsv" ]; then
  ok "V2b seeded sampling produces a manifest at --n < corpus size"
else
  bad "V2b seeded sampling produced no manifest"
fi

# ── V3 the padding hazard ─────────────────────────────────────────────────────
mkdir -p "$W/wiki"
cat > "$W/wiki/probe.md" <<EOF
---
title: Probe
type: concept
source: video
updated: 2026-07-30
---

# Probe

- padded (source: raw/$DASHED#04:41)
- unpadded (source: raw/$DASHED#4:41)
- heading (source: raw/$DASHED#source-metadata)

## Related
- [[a]]
- [[b]]
EOF
if python3 "$AUDIT" "$W/wiki" --raw "$W/raw" >/dev/null 2>&1; then
  ok "V3 staged transcript resolves BOTH #04:41 and #4:41 (padding hazard fixed)"
else
  bad "V3 a padded or unpadded timestamp anchor did not resolve"
fi

cat > "$W/wiki/probe.md" <<EOF
---
title: Probe
type: concept
source: video
updated: 2026-07-30
---

# Probe

- fabricated (source: raw/$DASHED#99:99)

## Related
- [[a]]
- [[b]]
EOF
if python3 "$AUDIT" "$W/wiki" --raw "$W/raw" >/dev/null 2>&1; then
  bad "V3b a fabricated #99:99 anchor RESOLVED — the resolver cannot fail"
else
  ok "V3b fabricated anchor #99:99 is still rejected"
fi
rm -f "$W/wiki/probe.md"

# ── Question set driving the grading path ─────────────────────────────────────
Q="$TMP/questions.md"
cat > "$Q" <<'EOF'
# fixture questions

### A1-right
What did the host say about kilowatt sorghum in April 2023?
modality: opinion
expects: kilowatt sorghum
cite-contains: kilowatt sorghum
max-span: 15
cite-file-matches: ^2023-04-

### A1-wrongdate
What did the host say about kilowatt sorghum in April 2023?
modality: opinion
expects: kilowatt sorghum
cite-contains: kilowatt sorghum
max-span: 15
cite-file-matches: ^2023-04-

### A2-topicx-asof
What was the position as of 2023?
modality: conflict
expects: bullish, 2023

### A2-topicx-both
How did the position change?
modality: conflict
expects: bullish, bearish, 2023, 2024
EOF

WORK="$TMP/work"; mkdir -p "$WORK"
RIGHT="$DASHED"
WRONG=$(ls "$W/raw" | grep '^2024-08-03-' || true)

# A1-right: correct claim, cited to the correctly-dated episode.
cat > "$WORK/A1-right.answer.md" <<EOF
The host discussed kilowatt sorghum at length.
(source: raw/$RIGHT#04:41)
EOF
# A1-wrongdate: same correct-sounding claim, cited to the WRONG episode. The
# claim is even genuinely present there — only the date is wrong.
cat > "$WORK/A1-wrongdate.answer.md" <<EOF
The host discussed kilowatt sorghum at length.
(source: raw/$WRONG#04:41)
EOF
# A2: as-of leg lands, both-positions leg hedges without the dated tokens.
cat > "$WORK/A2-topicx-asof.answer.md" <<'EOF'
As of 2023 he was bullish.
EOF
cat > "$WORK/A2-topicx-both.answer.md" <<'EOF'
His view shifted over time depending on conditions.
EOF

OUT="$TMP/eval.out"
bash "$EVAL" --wiki "$W" --questions "$Q" --work "$WORK" --label oracle >"$OUT" 2>"$TMP/eval.err" || true

grep -q 'A1-right | opinion | PASS | PASS | PASS' "$OUT" \
  && ok "V1a correct answer cited to the right-dated episode PASSES" \
  || { bad "V1a a fully correct A1 answer did not pass"; sed -n '/## detail/,$p' "$OUT" >&2; }

if grep -qE '^\| A1-wrongdate \|.*\| FAIL \|' "$OUT"; then
  ok "V1b right-sounding answer cited to the WRONG-dated episode FAILS"
else
  bad "V1b wrong-dated citation scored as retrieval — A1 is vacuous"
  sed -n '/## detail/,$p' "$OUT" >&2
fi

if grep -q 'A1 1/2' "$OUT"; then
  ok "V1c A1 scores 1/2 — the date leg is load-bearing in the total"
else
  bad "V1c A1 total did not reflect the date-leg failure"
fi

if grep -q 'A2 0/1' "$OUT"; then
  ok "V5 A2 topic with only the as-of leg passing scores 0 (both legs required)"
else
  bad "V5 A2 scored a topic on one leg — a hedge counts as handling a reversal"
fi

# ── V4 control arm flags a parametric question ────────────────────────────────
EMPTY="$TMP/empty"; mkdir -p "$EMPTY/wiki" "$EMPTY/raw"
CWORK="$TMP/cwork"; mkdir -p "$CWORK"
cat > "$CWORK/A1-right.answer.md" <<'EOF'
kilowatt sorghum is a well-known thing I happen to know already.
EOF
cat > "$CWORK/A1-wrongdate.answer.md" <<'EOF'
I cannot answer that from this wiki.
EOF
cat > "$CWORK/A2-topicx-asof.answer.md" <<'EOF'
No information available.
EOF
cat > "$CWORK/A2-topicx-both.answer.md" <<'EOF'
No information available.
EOF
COUT="$TMP/control.out"
bash "$EVAL" --wiki "$EMPTY" --questions "$Q" --work "$CWORK" --control --label oracle-control \
  >"$COUT" 2>"$TMP/control.err" || true

if grep -q 'parametric leak: 1/4' "$COUT" && grep -q '`A1-right`' "$COUT"; then
  ok "V4 --control flags the question the empty wiki answered, and names it"
else
  bad "V4 control arm did not flag the parametric question"
  cat "$COUT" >&2
fi

# ── V7 the work dir must live outside the wiki root ───────────────────────────
# The agent under test can list anything beneath the wiki, and work-dir files
# are named after the questions (A1-<slug>.answer.md), so a work dir inside the
# wiki hands over both the question ids and every answer already collected.
# Observed for real: an EMPTY wiki scored PASS on A1-2021-march-madness because
# it had listed .work/ and echoed the phrase back. It flagged the temptation
# instead of exploiting it; a grader cannot depend on that restraint.
INSIDE="$W/.work-inside"
mkdir -p "$INSIDE"
if bash "$EVAL" --wiki "$W" --questions "$Q" --work "$INSIDE" --label leak >/dev/null 2>&1; then
  bad "V7 a work dir INSIDE the wiki root was accepted (question ids leak to the agent)"
else
  ok "V7 a work dir inside the wiki root is refused"
fi
OUTSIDE="$TMP/work-outside"; mkdir -p "$OUTSIDE"
cp "$WORK"/*.answer.md "$OUTSIDE"/ 2>/dev/null
if bash "$EVAL" --wiki "$W" --questions "$Q" --work "$OUTSIDE" --label ok >/dev/null 2>&1; then
  ok "V7b a work dir outside the wiki root is accepted"
else
  bad "V7b a legitimate outside work dir was refused"
fi

# ── V6 commit-source writes ONLY the three permitted fields ───────────────────
# This is the one script here that writes to raw/, which AGENTS.md hard rule 1
# otherwise forbids entirely. If it can touch anything else, the raw layer stops
# being an immutable snapshot and every citation into it becomes unfalsifiable.
COMMIT="$SCRIPT_DIR/commit-source.py"
if [ -f "$COMMIT" ]; then
  ORIG="$W/raw/$DASHED"
  cp "$ORIG" "$TMP/commit-before.md"
  FAKEHASH=$(printf '%064d' 7 | tr '0-9' 'a-f0-3')
  FAKEHASH=$(printf '%s' "$FAKEHASH" | cut -c1-64)
  python3 "$COMMIT" "$ORIG" --hash "$FAKEHASH" --at "2026-07-30 00:00" \
          --pages "wiki/one.md,wiki/two.md" >/dev/null 2>&1
  if python3 - "$TMP/commit-before.md" "$ORIG" <<'PY'
import sys
TRI = ("ingested_hash", "ingested_at", "ingested_pages")
def parts(p):
    t = open(p, encoding="utf-8").read().split("\n")
    e = t.index("---", 1)
    return t[1:e], t[e:]
fb, bb = parts(sys.argv[1]); fa, ba = parts(sys.argv[2])
strip = lambda fm: [l for l in fm
                    if not any(l.startswith(k) for k in TRI) and not l.startswith("  - wiki/")]
sys.exit(0 if (bb == ba and strip(fb) == strip(fa)) else 1)
PY
  then
    ok "V6 commit-source.py leaves body and all other frontmatter byte-identical"
  else
    bad "V6 commit-source.py altered raw/ beyond the three permitted fields"
  fi

  python3 "$COMMIT" "$ORIG" --check >/dev/null 2>&1 \
    && ok "V6b --check reports a committed source as committed" \
    || bad "V6b --check failed to see a written ingested_hash"

  python3 "$COMMIT" "$W2/raw/$DASHED" --check >/dev/null 2>&1 \
    && bad "V6c --check called an UNcommitted source committed" \
    || ok "V6c --check reports an uncommitted source as uncommitted"

  python3 "$COMMIT" "$ORIG" --hash "not-a-sha" >/dev/null 2>&1 \
    && bad "V6d a non-sha256 hash was accepted into raw/" \
    || ok "V6d a non-sha256 --hash is rejected"
else
  bad "V6 scripts/commit-source.py is missing"
fi

if grep -q 'the real claude must never run' "$TMP/eval.err" "$TMP/control.err" 2>/dev/null; then
  bad "V0 a cached answer was re-queried — the oracle is spending money"
else
  ok "V0 no query was issued (all answers served from cache)"
fi

echo
echo "verify-corpus-eval: $passes passed, $fails failed"
[ "$fails" -eq 0 ]
