---
title: Ingest Pipeline (7 Steps)
type: concept
source: video
updated: 2026-05-25
tags: [operations, ingest, pipeline]
---

# Ingest Pipeline (7 Steps)

## Definition / TL;DR

The seven-step procedure that [[operation-ingest]] runs for each raw source. Reading → extraction → writing summary → updating related pages → flagging contradictions → updating the index → appending to the changelog.

## Body

Verbatim from the video: *"What happens when you ingest a source — because this is where the real power in this is."* `(source: raw/karpathy-llm-wiki-video-transcript.md#4:46-5:00)`

| # | Step | What it does |
|---|---|---|
| 1 | **Read the raw source** | LLM reads the file in `raw/`. For images / PDFs, reads the sidecar `.md` produced by `/wiki-fetch`. |
| 2 | **Extract key information** | Pulls out concepts, entities, claims, data points. `(source: raw/karpathy-llm-wiki-video-transcript.md#4:55-5:00)` |
| 3 | **Write a summary page** | New `wiki/<source-slug>-summary.md` (or similar) with the source's main takeaways, metadata, tags. `(source: raw/karpathy-llm-wiki-video-transcript.md#5:00-5:04)` |
| 4 | **Update existing entity / concept pages** | Integrate the new information into pages that already exist. A new claim about Concept X gets added to `wiki/x.md`. `(source: raw/karpathy-llm-wiki-video-transcript.md#5:04-5:11)` |
| 5 | **Flag contradictions** | If a new claim conflicts with an existing one, the LLM marks it visibly. *"When new data conflicts with existing claims."* `(source: raw/karpathy-llm-wiki-video-transcript.md#5:11-5:18)` |
| 6 | **Update the index** | `wiki/index.md` — the master catalog — gets the new pages listed. `(source: raw/karpathy-llm-wiki-video-transcript.md#5:18-5:23)` |
| 7 | **Append to the log** | A timestamped record in `CHANGELOG.md`: what raw was processed, which pages created/updated, which contradictions flagged. `(source: raw/karpathy-llm-wiki-video-transcript.md#5:23-5:30)` |

### The compounding outcome

After all seven steps: *"one source drops in and the entire wiki gets a little bit smarter."* `(source: raw/karpathy-llm-wiki-video-transcript.md#5:30-5:40)` This is why a single ingest typically touches **10 to 15 wiki pages**, not just one. `(source: raw/karpathy-llm-wiki-video-transcript.md#4:01-4:07)`

### How `/wiki-ingest` implements this `(analysis)`

The slash command's prompt walks the LLM through these 7 steps explicitly, and at the end writes `ingested_hash`, `ingested_at`, `ingested_pages` into the raw file's frontmatter so subsequent runs can skip it.

## Related

- [[operation-ingest]] — the operation this pipeline implements
- [[knowledge-compounds]] — why step 4 (update existing pages) is what makes the pattern work
- [[layer-wiki]] — where steps 3-6 write
- [[operation-lint]] — what catches mistakes the pipeline makes
- [[division-of-labor]] — why the LLM (not the user) does all 7 steps

## Open questions on this page

- Is step 5 (contradiction flagging) deep enough? Detecting "X says A; Y says ¬A" is one thing — detecting subtler conflicts (X claims A in 2024, Y claims a more nuanced A' in 2026) is harder.
- Should steps be reorderable? E.g., for a very small source, maybe just steps 1-3-7 suffice.
- How does step 4 cap blast radius? A claim could plausibly touch 50 pages — does the LLM update all 50, or only the most relevant N?
