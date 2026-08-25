# Northstar benchmark — first measured run

**Date: 2026-08-25.** Model: `claude` CLI, installed default, one run per arm.
Scored by `scripts/northstar-benchmark.py score` against `gold/cases.json`. The
scorer never calls a model.

Until this date the benchmark had **never been executed**. `runs/` was empty and
every claim about compiled context was `UNMEASURED` by the project's own
definition. These are the first numbers. They are transcribed here because
`runs/` is git-ignored.

## What was measured

Twelve graded cases, three arms, identical task contracts — same questions, same
required JSON shape, same instruction to answer `UNKNOWN` rather than guess. Only
the *material* differs:

| arm | material |
|---|---|
| `compiled` | the compiled package (`context/claims`, `context/decisions`) |
| `long-context` | every file under `raw/` |
| `bm25` | deterministic BM25 top-5 from `raw/` |

## Result at the shipped corpus size (24 sources, 28 files, ~3,537 tokens)

| arm | content_recall | refusal_correct | claim_resolution | total | per question | files/question |
|---|---|---|---|---|---|---|
| compiled | 1.00 | 0.92 | **0.75** | 628s | 52.3s | 26 |
| long-context | 1.00 | 0.92 | — | 469s | 39.0s | 28 |
| bm25 | 0.73 | 0.83 | — | 300s | 25.0s | 5 |

**The compiled arm is slower than long-context, no more accurate, and required
~25 minutes of compilation first.**

The 0.75 claim-resolution figure was initially described here as a quarter of
cited IDs failing to resolve. That was wrong, and the corrected reading is worse
for a different reason. Every `CLM-*` ID the arm cited resolved: 65 catalog IDs,
all well-formed, zero fabrications. The 0.75 is 9 of 12 cases scoring 1.0, because
**three answerable cases supplied no claim IDs at all** — `current-01`, `pit-01`
and `super-01`. Those are the current-state, point-in-time and supersession cases:
the compiled arm answered them correctly and attached no auditable identifier to
the answer, which is the one thing the compiled arm exists to provide.

`bm25` is the only arm that clearly loses. It failed `super-01` outright
(`UNKNOWN`): retrieval never surfaced both documents. Naive retrieval is a real
but weak competitor; it is not the one that matters.

## Result at 48× corpus (828 files, ~172,000 tokens)

800 deterministic distractor sources added by
`tests/eval/northstar-scale/gen-northstar-filler.sh`, disjoint from every graded
needle (blocklist-enforced, negative-control tested).

| | 28 files | 828 files |
|---|---|---|
| content_recall | 1.00 | **0.97** |
| refusal_correct | 0.92 | 0.92 |
| point-in-time / supersession / contradiction | 1.00 | **1.00** |
| per question | 39.1s | 55.1s |

Only `speaker-01` degraded (1.00 → 0.67). **48× the corpus cost 3% accuracy and
1.4× the time.** The baseline scales sublinearly because the agent greps and opens
a handful of files rather than reading everything — which is already what "do the
work once, then queries are cheap reading" was meant to buy, delivered with no
build step.

The compiled arm was **not** run at 828 files. The decision rule was fixed before
the scale run: if long-context held, compiling at scale would pay hours up front
to tie. It held.

## Update, same day: the metrics were repaired and the arms re-run

Four defects were fixed and the comparison repeated twice under the corrected
contract. `runs/*-v2-*` and `*-v3-*` hold the artifacts.

**What was fixed**

- `status` — the prompt now states the allowed values (`answered` / `refused`) and
  the scorer compares case-insensitively. Re-scoring the *existing* predictions,
  with no new model calls, moved it 0.0 → 0.83 / 0.75 / 0.67.
- `citations` — anchors are compared as bare slugs. More importantly the metric
  itself was replaced: see below.
- `assertion_keys` — every task now carries the same 20-key label space, allowed
  and forbidden mixed, so selecting between `assumes-brl-usd-5.50-as-of-june` and
  `...-5.70-as-of-june` remains a real discrimination while the metric becomes
  answerable at all.
- **claim resolution 0.75 → 1.00.** The defect was in the contract, not the
  compiler: the prompt never asked for `claim_ids`, so three answerable cases
  omitted them. Stated explicitly, all twelve now supply resolvable ids. Stable
  across both runs.

**Two metrics replace anchor-exact matching**

`citation_doc_f1` scores whether the right *source document* was cited,
independent of addressing scheme. `citation_resolvable` scores whether a reader
can follow each pointer to real text — a heading slug, a frontmatter anchor, or an
in-range line — and is negative-controlled against fabricated sources, invented
slugs and out-of-range lines.

This mattered: the compiled arm's anchor-exact precision and recall are exactly
**0.00**, because it addresses evidence only by line range (`L23-L24`), which can
never string-match gold's section slugs. The old metric rewarded vocabulary
agreement. Anchor-exact numbers are retained in the output for continuity and
should not be read as provenance quality.

**Result, two runs at 24 sources**

| metric | compiled (v2/v3) | long-context (v2/v3) | gap | within-arm swing |
|---|---|---|---|---|
| `citation_doc_f1` | 0.552 / 0.541 | 0.492 / 0.490 | **+0.060 / +0.051** | 0.011 |
| `assertion_score` | 0.599 / 0.548 | 0.529 / 0.510 | +0.071 / +0.038 | 0.051 |
| `content_recall` | 1.000 / 1.000 | 0.972 / 1.000 | +0.028 / 0.000 | 0.028 |
| claim resolution | 1.000 / 1.000 | — | — | 0.000 |

`citation_doc_f1` is the only gap that exceeds its own noise — roughly 5× — and it
held in both runs. **The compiled package cites the right source documents better
than an agent reading the folder.** That is the first measured advantage for the
compiled arm recorded here.

`assertion_score` moves the same way but its gap is the size of its swing; it is
not established. `content_recall` shows no difference.

**What this still does not establish.** The advantage is one axis, ~0.05, at a
corpus size where the compiled arm remains slower per question and costs ~25
minutes of compilation up front. `citation_resolvable` was 1.00 for every arm in
every run: at this scale nothing fabricated a citation, so the premise that an
agent invents provenance did not hold. Two runs of twelve cases on one corpus with
one model cannot size a 0.05 effect; it can only show the ordering did not
collapse. bm25's third run aborted on a transient CLI failure and is reported as
two arms rather than three.

## The document-citation advantage widens with corpus size

`citation_doc_f1`, the one metric whose gap exceeded its noise, was re-measured
with the corpus grown 48× (828 files, ~172,000 tokens; 800 deterministic
distractors, blocklist verified).

| | doc_f1 | resolvable | content_recall |
|---|---|---|---|
| compiled, 24 sources (mean of 2 runs) | **0.547** | 1.00 | 1.00 |
| long-context, 24 sources (mean of 2 runs) | 0.491 | 1.00 | 0.99 |
| long-context, **828 sources** | **0.455** | 1.00 | 1.00 |

Gap against compiled: **−0.056 at 24 sources, −0.091 at 828.** Long-context's
document-citation quality fell 0.036 — three times its own run-to-run swing of
0.011 — while its answers stayed perfect at 1.00 content recall.

**The mechanism.** Gold lists 1.5 evidence documents per case.

| | citations per question | distinct documents cited |
|---|---|---|
| compiled, 24 sources | 6.3 | **4.2** |
| long-context, 24 sources | 5.0 | 4.8 |
| long-context, 828 sources | 5.1 | **5.1** |

The compiled arm concentrates: more citations across fewer documents, several
precise anchors inside a tight set. The agent offers roughly one citation per
document and widens as the corpus grows, from 4.8 to 5.1 distinct documents. The
advantage is not "finds the right document" — both do — it is "does not drag in
extra ones, and tightens rather than loosens as the corpus grows."

**Read this as an upper bound, not a result.** The compiled package contains only
the 24 needle sources; the 800 distractors were never compiled. This compares a
perfectly curated index against an agent facing noise, not two systems on the same
corpus. It is decisive in one direction only: had the compiled arm failed to win
under conditions this favourable, it would not win at all. To make it a result,
compile all 828 sources and repeat — which the widening gap now justifies, where
before there was no signal worth the compute.

Also unchanged at scale: `citation_resolvable` stayed 1.00. Nothing fabricated a
citation at 828 sources either. Single run at scale, n=12, one model.

## Three metrics do not work

`assertion_score`, `citation_precision/recall/f1` and `status_correct` returned
**0.0 for every arm at every size.** These are harness defects, not results:

- **status** — the model returns `ANSWERED`; the scorer expects `answered`. The
  prompt never states the allowed values.
- **citations** — the model returns anchor `#procurement-variables`; gold stores
  `decision-status`. The `#` prefix breaks exact matching.
- **assertion_keys** — the model is asked for "semantic assertion_keys" and never
  told the vocabulary. Gold uses labels like `decision-q1-soymeal-evaluating`,
  which are unguessable. This one **cannot** be fixed by putting the vocabulary in
  the prompt: the vocabulary contains `forbidden_assertion_keys`, the anti-gaming
  controls.

Consequence: the axis where compiled context should win — provenance that resolves
under challenge — produced **no signal in either direction**. The tie on
`content_recall` is a ceiling effect, not evidence of equivalence.

## A structural observation

Compiling 24 sources (~3,537 tokens) produced 83 files (~39,058 tokens) — the
compiled package is **11× larger than the material it was built from**, and the
benchmark then feeds 26 of those files back per question against long-context's
28. There is no context reduction at this size. Per-source overhead (frontmatter,
provenance, claim records, cross-links) dominates.

## What these numbers do and do not license

**Supported:** at 24 and at 828 sources, compiled context did not produce better
answers than an agent with access to the raw folder. The claim "compiled context
gives better answers" is not supported at either size tested.

**Not supported, in either direction:** anything about provenance quality,
auditability, or citation precision — those metrics are broken. Anything about
corpora beyond 828 files. Anything about compiled packages consumed without the
tooling that built them.

**Limitations:** n=12, one run per arm, one model, one corpus, one domain. No
confidence intervals. `bm25` cannot be scaled by this harness at all — its
`prepare` draws candidates from `manifest["sources"]`, not from the workspace, so
it retrieves from 24 documents regardless of corpus size; it was dropped from the
scale run rather than reported as a scaled number.

## Reproducing

```bash
./scripts/create-context-compiler.sh /tmp/ns && ./scripts/stage-northstar.sh /tmp/ns
cd /tmp/ns && claude -p "/ctx-compile"          # ~25 min at 24 sources
cd -  # back to the bootstrap repo
./scripts/run-northstar-benchmark.sh prepare compiled --workspace /tmp/ns --out benchmarks/northstar/runs/compiled-tasks.json
./scripts/run-northstar-benchmark.sh execute benchmarks/northstar/runs/compiled-tasks.json --workspace /tmp/ns --tool claude --out benchmarks/northstar/runs/compiled-predictions.json
./scripts/run-northstar-benchmark.sh score benchmarks/northstar/runs/compiled-predictions.json --out benchmarks/northstar/runs/compiled-result.json
```

For the scale arm, add `./tests/eval/northstar-scale/gen-northstar-filler.sh /tmp/ns 800`
before `prepare`, and verify disjointness with `--verify /tmp/ns`.
