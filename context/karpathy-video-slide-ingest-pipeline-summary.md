---
title: "Source Summary — Slide: What happens when you ingest a source"
type: summary
source: video
updated: 2026-05-25
tags: [source-summary, ingest, pipeline]
---

# Source Summary — Slide: "What happens when you ingest a source"

## Definition / TL;DR

This is the per-source summary for the **second raw source** in this project: a single slide from the same video that gave us the main transcript (see [[karpathy-llm-wiki-video-transcript-summary]]). It restates the [[ingest-pipeline]] in 7 numbered bullets and crucially **mandates two file names** (`index.md`, `log.md`) and **one extra detail** (the index entry contains a one-line summary).

## What the slide says (verbatim, from `raw/karpathy-video-slide-ingest-pipeline.png.md`)

> **DEEP DIVE — What happens when you ingest a source**
>
> 01 LLM reads the raw source — article, paper, transcript, dataset
> 02 Extracts key information — concepts, entities, claims, data points
> 03 Writes a summary page in the wiki with metadata and tags
> 04 Updates entity & concept pages — new info integrated into existing knowledge
> 05 Flags contradictions where new data conflicts with existing claims
> 06 Updates `index.md` — catalog entry with link and one-line summary
> 07 Appends to `log.md` — timestamped record of what changed

`(source: raw/karpathy-video-slide-ingest-pipeline.png.md#body-verbatim-numbered-0107)`

## What this source adds beyond the transcript

This source overlaps with `raw/karpathy-llm-wiki-video-transcript.md` at timestamps 4:46-5:30 (the same content, in spoken form). The slide is more **prescriptive** in two places:

1. **File names.** The transcript says "updates the index" and "appends to the log" generically. The slide names them: `index.md` and `log.md`. This project adopted `log.md` (over the conventional `CHANGELOG.md`) to honor this — see [[source-attribution]] for the trail.
2. **Index entry format.** The transcript says "updates the index, the master catalog of everything in the wiki." The slide adds that each entry is "a catalog entry with **link and one-line summary**." [[ingest-pipeline]] step 6 now reflects this; [[index]] follows the convention (every entry there has a one-line description).

## Why a separate summary page for this

Per the [[ingest-pipeline]] convention, each raw source gets a summary page. Even when a source's content overlaps with an earlier source, the summary page records (a) **what's new vs the existing wiki**, (b) **which pages this source touched** during ingest. That makes future drift auditable: if a claim in this wiki contradicts a future source, we can trace which raw sources support which side.

## Pages touched when ingesting this source

This source updated, but did not create, the following pages:

- [[ingest-pipeline]] — steps 6 and 7 refined to incorporate slide-specific wording.
- [[source-attribution]] — added the slide as a second source confirming the pipeline; documented the `log.md` naming decision.
- [[index]] — added this summary to the navigation.

It also drove a project-wide rename: `CHANGELOG.md` → `log.md`. That rename touches AGENTS.md, README.md, all 5 slash commands, all cross-tool shims, and several wiki pages.

## Related

- [[ingest-pipeline]] — the seven steps the slide depicts
- [[operation-ingest]] — the operation that runs the pipeline
- [[source-attribution]] — provenance bookkeeping
- The full transcript: `raw/karpathy-llm-wiki-video-transcript.md`

## Open questions on this page

- Should every "second source confirming an existing claim" get its own summary page like this one, or only when the source disagrees / adds something? Current default: yes, always.
- The slide is silent on parallelism, conflict resolution, lint cadence — see [[open-questions]] for the broader gap list.
