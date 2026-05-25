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

From the video: *"You drop a new source into a raw folder and tell the LLM to process it. It reads the source, writes a summary page, updates the index, and cross-links it across all relevant existing pages. A single source might touch 10 to 15 wiki pages."* `(source: raw/karpathy-llm-wiki-video-transcript.md#3:50-4:07)`

### Inputs and outputs

- **Input:** one or more files in `raw/` whose `ingested_hash` is empty or stale.
- **Output:** new or updated pages in `wiki/`; appended `log.md` entry; updated `ingested_*` fields in the raw frontmatter.

### Compounding effect

The crucial property: **one new source touches many wiki pages, not one.** Ingesting a single article might create one summary page, update three concept pages (because the article's claims relate to existing ones), create two new entity pages (for people the article mentions), and add cross-links between five other pages. This is what the video calls "the entire wiki gets a little bit smarter." `(source: raw/karpathy-llm-wiki-video-transcript.md#5:30-5:45)`

For the full step-by-step, see [[ingest-pipeline]].

### Delta detection `(analysis: project convention)`

`/wiki-ingest` runs over all raw files by default; it skips any whose body hash matches `ingested_hash` in their frontmatter. To re-ingest a single file, edit it or pass it explicitly: `/wiki-ingest raw/foo.md`.

### Relation to other operations

- [[operation-query]] reads wiki pages produced by ingest
- [[operation-lint]] catches mistakes ingest made or didn't catch
- [[query-as-write-loop]] does *ingest-like writes* triggered by queries instead of new raw files

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
