# Baseline arms

- `compiled`: answers from profile-compiled context.
- `long-context`: answers from all staged raw sources in one prompt.
- `bm25`: answers from the same model after deterministic BM25 top-k retrieval.

Prediction files are JSON objects with `arm`, `model`, `generated_at`, and an
`answers` array containing `{id, answer, status, assertion_keys, citations}`. Semantic
`assertion_keys` are gold labels, not claim IDs. Citations contain exact `source_id` and
`anchor` pairs, so missing or fabricated anchors reduce precision/recall/F1. The scorer never
calls a model. BM25 instrument mode reports retrieval candidates only and must
not be represented as answer quality.

`prepare` produces comparable, answer-free task contracts. Optional `execute` records
tool/default-model labels and elapsed time; it remains outside keyless verification.
The compiled arm additionally returns `claim_ids`; the runner snapshots resolvable
`CLM-*` IDs from its isolated compiled packet and reports claim-resolution accuracy.
Baseline arms are not required to reproduce compiler hashes.
