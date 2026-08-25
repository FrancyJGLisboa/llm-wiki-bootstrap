# Northstar Feeds Decision-Context Benchmark

Northstar Feeds is fictional. Every person, organization, message, number, and
event in this corpus is synthetic and exists only to test decision-context
behavior.

**First measured run: [`RESULTS.md`](RESULTS.md) (2026-08-25).** Read it before
citing this benchmark: three of its seven metrics are currently broken, and the
compiled arm did not beat an agent with the raw folder at either size tested.

`sources/` contains the 24 inputs visible to a compiler. `gold/` contains the
independent scoring key and must never enter a compilation workspace.
`holdout/` contains reserved metadata used only by the leakage verifier.
`baselines/` documents the comparison arms. `runs/` accepts ignored run output.

The benchmark does not ship model scores. A result is `measured` only when a
prediction file is supplied to the runner and scored against `gold/cases.json`.
Deterministic BM25 retrieval is an instrument check, not a model-answer score.

## Clean-user sequence

1. `./scripts/create-context-compiler.sh /tmp/northstar-compiler`
2. `./scripts/stage-northstar.sh /tmp/northstar-compiler`
3. In that directory run `/ctx-compile`, `/client-brief northstar-feeds`,
   `/client-delta northstar-feeds --since 2026-06-01`, and `/client-why "BRL 5.70"`.
4. Prepare tasks: `./scripts/run-northstar-benchmark.sh prepare compiled --workspace
   /tmp/northstar-compiler --out benchmarks/northstar/runs/compiled-tasks.json`.
5. Optionally use `execute ... --tool claude|codex`, then `score PREDICTIONS --out RESULT`.

Preparation is **UNMEASURED**. Retrieval is not answer quality. Only persisted model
predictions scored against the independent key are **MEASURED**. Live execution is never
part of keyless CI.

Answer correctness uses semantic `assertion_keys`; these are intentionally not presented
as compiler claim IDs. Provenance is scored on exact source-and-anchor pairs. Only the
compiled arm reports resolvable `CLM-*` support, as a separate measured metric; raw
baselines are not penalized for lacking compiler-generated hashes.
