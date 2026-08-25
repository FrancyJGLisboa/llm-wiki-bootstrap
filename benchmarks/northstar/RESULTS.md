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
~25 minutes of compilation first.** A quarter of the `CLM-*` claim IDs it cited
did not resolve — and resolvable provenance is its differentiator.

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
