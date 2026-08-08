# Assessment — vectorless RAG on a real corpus (Grain Markets, 2020–2026)

**Status:** in progress. Defects and measurements below are complete and
reproducible; the A1–A5 scores are pending the build.

**Reproduce:** every number here comes from a committed artifact —
`eval/grain_checks.yaml` (the loss function), `tests/eval/grain-corpus/manifest.tsv`
(the seeded sample), `tests/eval/grain-corpus/gold-questions.md` and
`holdout-questions.md` (the question sets). Re-run with the same seed and the
same source directory and you get the same corpus, byte for byte
(`verify-corpus-eval.sh` V2).

---

## Why this corpus

Every eval shipped in this repo runs on a corpus built to be retrievable:
synthetic needles (`NEEDLE-<MODALITY>-<hex>`) chosen to be absent from
pretraining, planted past each extractor's truncation boundary, cleanly
separated from distractors. That is the right design for finding extractor
bugs. It cannot tell you whether the system works on content that already
exists.

The published scale result — *"quality held from 19 to 495 pages (20/21 →
21/21) while median file reads per answer fell from 3 to 0"* (README.md:298) —
was measured against `gen-scale-filler.sh` output: deterministically generated
**wiki pages**, not ingested sources. Only ~13 sources have ever been through
real LLM ingest. The claim it supports is *retrieval survives a large wiki*. It
is not *ingest survives a large corpus*, and it has never been tested against
content with real semantic overlap.

This corpus is the adversarial case:

| | |
|---|---|
| Sources | 1,138 files, 2.8M words |
| Span | 2020-09-14 → 2026-06-15 |
| Field completeness | 100% on Uploaded / Video / Channel / Duration / Captions |
| Redundancy | 351 titles mention corn, 266 soybean — no clean needles |
| Contradiction | one host, weekly, reversing position as the market turned |
| Pretraining | the subject matter is public and IS in the model's weights |

That last row is why the eval carries an empty-wiki control arm: on this
subject, a naive gold set scores well with no wiki at all and measures nothing.

Sample: **N=50**, seeded and stratified by upload year-quarter, covering all 24
quarters. 40 sources for the gold set, 10 sealed for the holdout.

---

## Findings

### F1 — Headless sharded ingest silently fails to commit

`claude -p "/ctx-compile raw/<file>"` ends its turn while the faithfulness gate
is still running. Observed verbatim in the run log:

> Waiting on the gate — I'll pick up Steps 6–8 automatically when it completes.

In `-p` mode there is no later turn. The result on the first real source:

- 17 wiki pages written, `wiki/index.md` updated (Steps 1–6 ran)
- `log.md` empty, `ingested_hash: ""` (Step 7 never ran)
- **shell exit status 0**

Nothing but a `committed=N/M` check notices. Consequences are exactly those the
repo already documents for this failure class: idempotence is broken (a re-run
reprocesses everything), and every citation into an uncommitted body is
unverifiable under the drift contract.

The command file does **not** instruct backgrounding — `.claude/commands/ctx-compile.md`
Step 5.5 says to run the gate and act on its verdicts. The agent chose to
background a multi-minute serial job and end its turn. This is a headless-mode
interaction bug, not a prompt bug.

`eval-retrieval.sh:420-423` records the same silent-hash symptom at 100 filler
pages. Here it appears at **N=1**, with a proximate cause.

**Mitigation used for this assessment:** `scripts/ingest-corpus.sh` finishes the
pipeline itself — it diffs `wiki/` around the turn, runs the gate to completion
in the shell, and writes the three commitment fields via `commit-source.py`
using the canonical `scripts/body-hash.sh`. This separates the agent's authoring
quality (what A1–A4 measure) from the harness's turn-completion bug, so the
latter is reported rather than silently corrupting every other number.

### F2 — Timestamp-anchor resolution is padding-sensitive, and the house style is the broken one

`citation-audit.py` matches a `#M:SS` anchor as a whole token, bounded by
`(?<![\d:])...(?![\d:])`. Against a transcript body that writes `[04:41]`:

| anchor | resolves |
|---|---|
| `#04:41` | yes |
| `#4:41` | **no** |
| `#00:00` | yes |
| `#0:00` | **no** |

The meta-wiki's own convention is the unpadded form (`wiki/core-idea.md` cites
`#0:51`). An author following the shipped example against a zero-padded
transcript would silently break **every** citation into a sub-10-minute
timestamp — and citation failures read as retrieval failures, not as formatting
accidents.

This is not hypothetical for this corpus: the live run produced citations
`#1:03`, `#0:31`, `#4:08` — all unpadded.

**Mitigation used:** `stage-corpus.py` emits an unpadded `## (M:SS)` heading
beside each padded inline `**[MM:SS]**` marker, so both conventions resolve. It
also gives `citation-audit.py`'s `HEADING_RE` branch a tight,
semantically-bounded passage (heading → next heading) instead of a fixed 8-line
window. Regression-guarded by `verify-corpus-eval.sh` V3/V3b.

### F3 — `--allow-unjudged` does not skip judging

The flag permits proceeding when **no judge is available**; with `claude` on
PATH the gate judges regardless. Anyone reaching for it to bound ingest cost
gets no saving and no warning. Floor mode has to run the gate on a PATH without
`claude` — the gate's own documented offline path.

Measured on the same three pages: **1s floor vs 10+ min judged.**

### F4 — The size-ratio compression metric is a bad proxy (self-correction)

The plan proposed "wiki words ≤30% of raw words" as the synthesis check. Run
against the shipped meta-wiki that reads **371.9%** — it legitimately *expands*
six tiny sources with synthesis. A flat size threshold scores good work as
failure and copying-but-shorter as success.

A4 now measures the actual failure mode: the share of the wiki's 12-word
shingles appearing verbatim in the raw bodies. It calibrates on known content —
the hand-curated meta-wiki reads **4.7%** overall, while its two
closest-paraphrase smoke-derived pages read **30.3%** and **28.9%**. It
discriminates rather than merely ranking, which is what a threshold needs.

---

## A5 — cost and scale (partial)

### Deterministic stages are not the bottleneck

`scripts/bench-scale.sh 1138`, this machine:

| stage | time |
|---|---|
| generate (1138 raw + 570 wiki) | 0.8s |
| hash-scan (1138 files) | 47.3s (24 files/s) |
| audit (1138 citations) | 0.7s |
| synthesis (573 nodes) | 0.6s |
| **deterministic loop total** | **48.6s** |

At true N=1,138 the entire keyless pipeline runs in under a minute. Any claim
that the system "scales" resting on these numbers is measuring the cheap half.

### LLM ingest is the bottleneck

Cost is dominated by `wiki-faithfulness-gate.sh`, which spawns one nested
`claude -p` citation-auditor **per cited claim, serially**, with no batching,
concurrency, or cache (`wiki-faithfulness-gate.sh:195`). Per-source figures and
the first-vs-last-quartile trend are pending the build; the trend is the number
that matters, because ingest Step 4 rewrites existing pages and Step 6 rewrites
`wiki/index.md`, both growing with the corpus — so cost measured into a
near-empty wiki understates cost at N.

_Pending: per-source seconds, quartile trend, projected serial hours for 1,138,
commitment rate, reads-per-answer._


### F5 — Ingest has no timeout, retry, or cap detection

An unattended overnight run degraded without bound. Sources 1-8 ran 310-1552s
and committed; sources 9-12 then failed at 1111s, 3794s, 3908s and **28960s**.
The 8-hour turn was a 1,077-word source; the 65-minute one was **415 words**, so
this is not corpus growth. An API probe immediately after returned in 8s, so the
stalls were transient, not a hard cap.

`ingest-corpus.sh` and the `/ctx-compile` path alike have nothing bounding a
turn, so one stalled call silently consumed a third of the night. Bounding it
took three attempts and is worth recording as a harness lesson: an in-loop
counter that assumed `sleep 5` costs 5s fired at 4.4x its budget under load, and
even a wall-clock deadline inside the same loop failed to fire on the real
workload while killing a synthetic sleeper correctly. The bound that held is an
external watchdog (`scripts/ingest-watchdog.sh`) that tracks ages itself.

### F6 — The cost is a design choice, not a property of vectorless RAG

The sibling project `~/wiki-factory` compiles the same YouTube-transcript corpus
at **59-299 s/source** against this pipeline's **1554 s/source**. It is not
faster through concurrency: it is serialized too (`max_concurrent=1`), and its
Phase-0 spike explicitly falsified a per-source process fan-out, recording auth
races and 529 Overloaded on 4 of 5 sources at $2.03/src and 774 s/src. That is
the same failure class as F5, against the same backend — bootstrap's
per-source-process shape is the architecture that experiment ruled out.

Four differences account for the gap, in order of contribution:

| | wiki-factory | context-compiler-bootstrap |
|---|---|---|
| unit of work | one `claude -p` for the whole corpus | one per source |
| OS processes, 5 sources | 1 | ~5 ingest + ~75 auditors |
| citation check at build | deterministic only — anchor resolves, quoted spans verbatim | one nested `claude -p` per cited claim |
| index | server-side Python at commit, once per corpus | model rewrites `wiki/index.md` per source |
| entity dedup | 150-stem list injected once, selective reads | per-source sweep against the whole wiki |

**What that speed costs, stated exactly.** context-compiler-bootstrap enforces, blocking
and per source, that every cited claim is ENTAILED BY its cited span.
wiki-factory enforces only that the citation POINTS AT SOMETHING REAL — the file
exists, the anchor resolves, quoted text appears verbatim. Paraphrase drift,
over-claiming, and wrong-attribution of a real timestamp pass its commit gate.
Entailment survives there as a non-blocking k=5 sample whose committed baseline
is 4/5 = 0.80.

So this is not a verdict that one repo is better engineered. It is a different
point on the speed/verification curve, and the guarantee traded away is the one
README.md:268 calls the moat. The actionable finding is that bootstrap's cost is
**not** intrinsic: batching the corpus into one session, materializing the index
and dashboards in Python at commit, and demoting the per-claim gate to the
sampled check `eval-citation-faithfulness.sh --sample` already implements would
close most of a 13-26x gap without touching the entailment guarantee's
definition — only how often it is spent.

---

## A1-A4 results

_Pending the build._

---

## Reconciliation with the published claims

_Pending. Will state plainly where real-corpus results diverge from
README.md:298._
