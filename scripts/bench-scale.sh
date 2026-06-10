#!/usr/bin/env bash
# scripts/bench-scale.sh — measure the deterministic substrate at corpus scale.
#
# The architecture is incremental by design, but until now nobody had numbers
# for "what does a few-hundred-source wiki cost per operation". This harness
# generates a synthetic corpus (N raw sources, N/2 wiki pages citing them),
# then times the real deterministic stages every wiki-mutating command runs:
#
#   hash-scan   scripts/body-hash.sh over every raw file (ingest delta detection)
#   audit       scripts/citation-audit.py C1+C2 over every citation
#   synthesis   scripts/synthesize/all.sh (dashboards + knowledge-graph.json)
#
# Produces NUMBERS, not prose (philosophy of eval-multi-hop.sh: the deliverable
# is the measurement). The default run costs zero LLM tokens. The one thing this
# does NOT measure by default is LLM ingest itself — pass --llm-sample K to
# additionally time K real `claude -p /wiki-ingest` runs and project per-source
# cost to the full corpus.
#
# Usage:
#   scripts/bench-scale.sh [N] [--llm-sample K] [--keep]
#
#   N             number of synthetic raw sources (default 500)
#   --llm-sample  also run K real single-source ingests via claude -p (default 0)
#   --keep        keep the generated corpus directory for inspection
#
# Exit codes:
#   0  harness completed (timings reported)
#   2  setup error (python3 missing, generator failed)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

N=500
LLM_SAMPLE=0
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --llm-sample) LLM_SAMPLE="${2:?--llm-sample needs a count}"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    *[!0-9]*) echo "error: unknown argument: $1 (usage: bench-scale.sh [N] [--llm-sample K] [--keep])" >&2; exit 2 ;;
    *) N="$1"; shift ;;
  esac
done

PYBIN="$(command -v python3 || command -v python || true)"
[ -n "$PYBIN" ] || { echo "error: python3 required for corpus generation, audit, and synthesis" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/bench-scale.XXXXXX")"
[ "$KEEP" -eq 1 ] || trap 'rm -rf "$WORK"' EXIT

now() { "$PYBIN" -c 'import time; print(f"{time.time():.3f}")'; }
elapsed() { "$PYBIN" -c "print(f'{$2 - $1:.1f}')"; }

echo "bench-scale: N=$N raw sources, $((N / 2)) wiki pages, work dir: $WORK"
echo

# ── Stage 0: generate synthetic corpus ──────────────────────────────────────
t0=$(now)
if ! BENCH_N="$N" BENCH_WORK="$WORK" "$PYBIN" - <<'EOF'
import os, pathlib

n = int(os.environ["BENCH_N"])
work = pathlib.Path(os.environ["BENCH_WORK"])
raw = work / "raw"; wiki = work / "wiki"
raw.mkdir(); wiki.mkdir(); (wiki / "journal").mkdir()

TOPICS = ["irrigation", "soil-carbon", "futures-basis", "crop-rotation",
          "grain-storage", "freight-index", "weather-model", "yield-trial"]

for i in range(n):
    topic = TOPICS[i % len(TOPICS)]
    body = []
    for s in range(3):
        body.append(f"## Finding {s + 1} on {topic} study {i}\n")
        body.append(
            f"Synthetic source {i} section {s + 1}: the {topic} measurement "
            f"series reported value {(i * 7 + s * 13) % 997} in trial block "
            f"{(i + s) % 24}. This sentence exists to give the body realistic "
            f"length and a citable heading.\n")
    (raw / f"source-{i:04d}.md").write_text(
        "---\n"
        f"source_url: n/a\n"
        f"source_type: note\n"
        f'source_title: "Synthetic {topic} source {i}"\n'
        f'source_author: "bench-scale generator"\n'
        f"fetched_at: 2026-01-01\n"
        f'ingested_hash: ""\n'
        f"ingested_at: never\n"
        f"ingested_pages: []\n"
        f"extraction_method: passthrough\n"
        "---\n\n" + "\n".join(body))

pages = n // 2
names = [f"page-{i:04d}" for i in range(pages)]
for i in range(pages):
    a, b = (2 * i) % n, (2 * i + 1) % n
    nxt = names[(i + 1) % pages]
    (wiki / f"{names[i]}.md").write_text(
        "---\n"
        f"title: Bench Page {i}\n"
        "type: concept\n"
        "source: analysis\n"
        "updated: 2026-01-02\n"
        f"tags: [bench, {TOPICS[i % len(TOPICS)]}]\n"
        "---\n\n"
        f"# Bench Page {i}\n\n"
        f"Claim one cites a real anchor (source: raw/source-{a:04d}.md#finding-1-on-{TOPICS[a % len(TOPICS)]}-study-{a}).\n\n"
        f"Claim two cites a second source (source: raw/source-{b:04d}.md#finding-2-on-{TOPICS[b % len(TOPICS)]}-study-{b}).\n\n"
        "## Related\n\n"
        f"- [[{nxt}]]\n")

(wiki / "index.md").write_text(
    "---\ntitle: Index\ntype: navigation\nsource: analysis\nupdated: 2026-01-02\ntags: [index]\n---\n\n# Index\n\n"
    + "\n".join(f"- [[{p}]]" for p in names) + "\n")
(work / "log.md").write_text("# log.md\n\nAppend-only log.\n")
EOF
then
  echo "error: corpus generation failed" >&2; exit 2
fi
t1=$(now)
echo "generate    $(elapsed "$t0" "$t1")s   ($N raw + $((N / 2 + 1)) wiki files written)"

# ── Stage 1: hash-scan (what /wiki-ingest does to detect deltas) ────────────
t2=$(now)
hashed=0
for f in "$WORK"/raw/*.md; do
  "$SCRIPT_DIR/body-hash.sh" "$f" >/dev/null || { echo "error: body-hash failed on $f" >&2; exit 2; }
  hashed=$((hashed + 1))
done
t3=$(now)
echo "hash-scan   $(elapsed "$t2" "$t3")s   ($hashed files, $("$PYBIN" -c "print(f'{$hashed / ($t3 - $t2):.0f}')") files/s)"

# ── Stage 2: citation audit C1+C2 (deterministic faithfulness floor) ────────
t4=$(now)
audit_out="$("$PYBIN" "$SCRIPT_DIR/citation-audit.py" "$WORK/wiki" --raw "$WORK/raw" 2>&1 | tail -1)"
t5=$(now)
echo "audit       $(elapsed "$t4" "$t5")s   ($audit_out)"

# ── Stage 3: synthesis dashboards + knowledge graph ─────────────────────────
t6=$(now)
if ! "$SCRIPT_DIR/synthesize/all.sh" "$WORK" >/dev/null 2>&1; then
  echo "error: synthesize/all.sh failed" >&2; exit 2
fi
t7=$(now)
nodes="$("$PYBIN" -c "import json; print(len(json.load(open('$WORK/wiki/knowledge-graph.json'))['nodes']))" 2>/dev/null || echo "?")"
echo "synthesis   $(elapsed "$t6" "$t7")s   (dashboards + knowledge-graph.json, $nodes nodes)"

total=$("$PYBIN" -c "print(f'{($t3 - $t2) + ($t5 - $t4) + ($t7 - $t6):.1f}')")
echo
echo "deterministic loop total: ${total}s for a $N-source wiki (excl. generation)"

# ── Optional: real LLM ingest sample ────────────────────────────────────────
if [ "$LLM_SAMPLE" -gt 0 ]; then
  if ! command -v claude >/dev/null 2>&1; then
    echo "llm-sample: skipped — claude CLI not on PATH" >&2
  else
    cp -r "$REPO_ROOT/.claude" "$WORK/"
    cp "$REPO_ROOT/AGENTS.md" "$WORK/"
    mkdir -p "$WORK/scripts" && cp "$SCRIPT_DIR/body-hash.sh" "$WORK/scripts/"
    cp -r "$SCRIPT_DIR/synthesize" "$WORK/scripts/" && cp -r "$SCRIPT_DIR/visualize" "$WORK/scripts/" 2>/dev/null
    echo
    echo "llm-sample: ingesting $LLM_SAMPLE source(s) via claude -p …"
    t8=$(now)
    ok_runs=0
    for i in $(seq 0 $((LLM_SAMPLE - 1))); do
      src=$("$PYBIN" -c "print(f'raw/source-{$i:04d}.md')")
      if (cd "$WORK" && claude -p "/wiki-ingest $src" >/dev/null 2>&1); then ok_runs=$((ok_runs + 1)); fi
    done
    t9=$(now)
    if [ "$ok_runs" -gt 0 ]; then
      per=$("$PYBIN" -c "print(f'{($t9 - $t8) / $ok_runs:.0f}')")
      proj=$("$PYBIN" -c "print(f'{(($t9 - $t8) / $ok_runs) * $N / 3600:.1f}')")
      echo "llm-ingest  $(elapsed "$t8" "$t9")s   ($ok_runs/$LLM_SAMPLE succeeded, ~${per}s/source → projected ~${proj}h serial for all $N)"
    else
      echo "llm-ingest: all $LLM_SAMPLE sample runs failed" >&2
    fi
  fi
fi

[ "$KEEP" -eq 1 ] && echo "corpus kept at: $WORK"
exit 0
