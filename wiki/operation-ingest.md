---
title: Operation — Ingest
type: concept
source: video
updated: 2026-05-25
tags: [operations, ingest]
---

# Operation — Ingest

## Definition / TL;DR

**Ingest** is the operation that processes a raw source into wiki pages. The user drops a source into `raw/` and runs `/wiki-ingest`; the LLM reads, extracts, summarizes, cross-links, flags contradictions, updates the index, and logs the change.

## Body

From the video: *"You drop a new source into a raw folder and tell the LLM to process it. It reads the source, writes a summary page, updates the index, and cross-links it across all relevant existing pages. A single source might touch 10 to 15 wiki pages."* `(source: raw/karpathy-llm-wiki-video-transcript.md#3:50)`

### Inputs and outputs

- **Input:** one or more files in `raw/` whose `ingested_hash` is empty or stale.
- **Output:** new or updated pages in `wiki/`; appended `log.md` entry; updated `ingested_*` fields in the raw frontmatter.

### Compounding effect

The crucial property: **one new source touches many wiki pages, not one.** Ingesting a single article might create one summary page, update three concept pages (because the article's claims relate to existing ones), create two new entity pages (for people the article mentions), and add cross-links between five other pages. This is what the video calls "the entire wiki gets a little bit smarter." `(source: raw/karpathy-llm-wiki-video-transcript.md#4:46)`

For the full step-by-step, see [[ingest-pipeline]].

### Delta detection `(analysis: project convention)`

`/wiki-ingest` runs over all raw files by default; it skips any whose body hash matches `ingested_hash` in their frontmatter. To re-ingest a single file, edit it or pass it explicitly: `/wiki-ingest raw/foo.md`.

### Relation to other operations

- [[operation-query]] reads wiki pages produced by ingest
- [[operation-lint]] catches mistakes ingest made or didn't catch
- [[query-as-write-loop]] does *ingest-like writes* triggered by queries instead of new raw files

## Verification status (as of 2026-06-08)

**Status note** `(source: analysis)`: the 7-step pipeline is **demonstrated end-to-end and CI-gated**. `scripts/smoke-build.sh` drives a real LLM session — `claude -p "/wiki-ingest raw/smoke-source.md"` — and `scripts/smoke-all.sh` runs it on every push; the C1 check confirms a follow-up `/wiki-query` against the result reaches the right answer. `scripts/eval-onboarding.sh` independently drives a fresh newcomer through extract→ingest→query. So `/wiki-ingest` is now **observed working**, not just specified.

Honest nuance: the original meta-wiki pages (the karpathy-derived set) were hand-bootstrapped by direct file writes during the design conversation, with the LLM playing /wiki-ingest by hand — those specific pages were not machine-ingested. The smoke-fixture pages (`smoke-source-summary.md` and friends) **were** produced by the real command, which is what makes them the proof.

What the smoke test does **not** granularly assert (residual unknowns):

- Whether an LLM following the prompt fires **all 7 steps every time**, or quietly skips one (e.g., step 5's contradiction-flagging) — the smoke checks the end result, not each step's firing.
- Whether step 4 ("update existing pages") touches the right pages — not too few (loses compounding) and not too many (collateral churn).
- Whether step 5 catches subtle contradictions or only obvious ones.
- How long the pipeline takes for a large source of ~5,000 words (token budget, wall-clock).

Treat the pipeline as **observed to run and reach correct answers**, with per-step conformance verified only at the coarse end-to-end level.

## Related

- [[ingest-pipeline]] — the 7-step procedure in detail
- [[knowledge-compounds]] — why ingest's 10-15-pages-per-source property matters
- [[layer-raw-sources]] — where ingest reads from
- [[layer-wiki]] — where ingest writes to
- [[operation-query]], [[operation-lint]] — the other two core operations
- [[division-of-labor]] — why the LLM does this work, not the user

## Open questions on this page

- How does ingest decide when to create a *new* page vs update an *existing* one? (LLM judgment based on whether a closely-matching page already exists. Worth formalizing in the schema.)
- Should ingest run in parallel (multiple raw files at once) or serial? The video shows two parallel ingest agents. Risk: parallel writes to the same wiki page need conflict resolution.
- What's the budget for one ingest call? Time, tokens, web-search calls?
