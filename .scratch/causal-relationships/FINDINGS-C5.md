# C5 (discrimination eval) — findings

**Status: OPEN.** The causal capability is built and its deterministic checks
(C1–C3, verify-causal.sh, smoke R11) pass, but the C5 numeric gate
(`typed − baseline ≥ 2` in `scripts/eval-causal.sh`) is **not robustly met**.
This note records why, so the gate isn't mistaken for "passed."

## What is proven
- **The typed path works.** Across 7 eval rounds the typed variant (causal
  verbs intact + `wiki/_kg.jsonl`, traversed by `/wiki-query` Step 1.5) scored
  **perfectly every time** (5/5, 6/6, 8/8). The KG materialization + traversal
  is correct and reliable.
- **In true isolation the capability discriminates.** Run faithfully — verbs
  stripped, no `_kg.jsonl`, no `scripts/` — the baseline `/wiki-query`
  *correctly refuses*: "the causal type layer the question depends on is
  missing… I won't fabricate an answer." It cannot answer without the KG.

## Why the automated delta stays low
The eval-harness baseline keeps scoring high anyway, for two reasons that
**fixture sealing cannot fix**:
1. **Forced-answer inference.** Under "reply with the integer only," a reasoning
   LLM commits to the most plausible causal ordering of the link graph instead
   of refusing; on a small graph it is often right.
2. **No filesystem isolation.** `claude -p` runs with `cwd=WORK/baseline` but can
   read the *real* repo's **unstripped** fixture on disk (`tests/eval/causal-fixture/*.md`
   still carries the `causes` verbs). A baseline that greps the filesystem reaches
   the answer. No synthetic fixture can blind a baseline that can read the source.

## Eval iterations (each fixed a real leak the metric exposed)
1. prose stated the chain → pseudonyms + neutral bodies
2. verb-stripping doesn't seal *direction* (link placement already encodes it)
   → the discriminator is edge **type**, not direction
3. clean backbone vs hub decoys leaked topology → fully symmetric ring
4. "see graph" vs "see also" prose leaked the causal line → uniform prose
5. node-name answers let a hedging baseline pass the numeric grader → switched
   to **sum-of-Codes** answers (a value absent from the fixture: no hedging, no guessing)

Even after all five, baseline inference (#1) and FS non-isolation (#2) keep the
delta at ~0–1 noisy.

## To actually close C5 (harness work, not fixture work)
- Isolate the baseline from the source: run `eval-causal.sh` in a copied tree
  with the source fixture removed, or in a sandbox with no read access to the repo.
- Consider a non-LLM-judge floor for the typed path (e.g. assert the typed
  variant's `_kg.jsonl` yields the correct traversal deterministically), so the
  capability has a green automated check that does not depend on out-reasoning a
  filesystem-capable baseline.

## Honest takeaway
The causal layer (vocab, lint, KG, query traversal) is real and works. The
*marginal value over the plain typed-link graph, for a capable reasoner*, is
narrow — and demonstrating it automatically is blocked by baseline reasoning +
harness non-isolation, not by the capability being absent.
