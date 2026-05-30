---
title: Knowledge Compounds
type: concept
source: mixed
updated: 2026-05-25
tags: [foundations, compounding, motivation]
---

# Knowledge Compounds

## Definition / TL;DR

The defining property of the LLM-wiki pattern: **what the LLM learns from one source stays available for every future question.** The wiki is the persistent record of accumulated understanding. The LLM never starts from scratch on a question it has already engaged with — the cross-references, contradictions, and synthesis are already written into the markdown.

## Body

This is the single property that separates the LLM-wiki pattern from naive RAG. It's worth stating it cleanly because the video returns to it from three different angles.

### Angle 1 — the negative case (RAG)

*"Nothing accumulates. Every time you ask a question, the LLM is rediscovering knowledge from scratch. It's repiecing together fragments every single time. So if you ask something subtle that requires synthesizing five different documents, it has to find and connect all those pieces on every query. There's no memory, no cross references, no accumulated understanding."* `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`

In naive RAG, the synthesis lives in the LLM's working memory during a single query and dies there. Two minutes later, the same question costs the same work.

### Angle 2 — the positive case (LLM-wiki)

*"Instead of retrieving at query time, the LLM builds a persistent interlinked wiki up front. The cross references are already there. Contradictions are already flagged. The synthesis already reflects everything you've already fed it. Knowledge compounds instead of being thrown away after each conversation."* `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`

The work is done once, written down, and reused. The wiki is the **memoization of synthesis.**

### Angle 3 — the compounding effect

*"One source drops in and the entire wiki gets a little bit smarter. So that's the compounding effect."* `(source: raw/karpathy-llm-wiki-video-transcript.md#4:46)`

A new raw source doesn't just add itself. It touches 10-15 existing wiki pages (per [[ingest-pipeline]]), strengthens cross-references, may resolve previously-flagged contradictions, may reveal new ones. The wiki's value grows super-linearly with the number of sources, because each source connects to all the others through the wiki layer.

## Two engines of compounding

Within this system, knowledge accumulates through **two distinct paths**, both of which write to `wiki/`:

| Engine | Trigger | What grows the wiki |
|---|---|---|
| [[operation-ingest]] | User adds a raw source | The 7-step [[ingest-pipeline]] writes summaries and updates entity / concept pages |
| [[query-as-write-loop]] | User asks a question the wiki can't fully answer | Web-search backfill + auto-promotion writes new pages |

Both ratchet the wiki forward. Together they cover:

- Sources you **find** and curate as worth keeping (ingest path)
- Knowledge you **discover you need** the moment you try to ask about it (query path)

A wiki maintained only via ingest grows where you point it. A wiki maintained with both grows where you point it **and** where you turn out to be curious.

## Why this changes the economics

Naive RAG has roughly constant cost per query — every question pays the same retrieval-and-synthesis tax. The LLM-wiki pattern shifts the cost forward: high-ish cost per ingest (the LLM does serious work), then approximately free reads (you just read existing markdown).

In a domain where you ask many overlapping questions over weeks or months ([[use-cases]] — research, business, due diligence), this trade favors the wiki by orders of magnitude. In a domain of one-off lookups, it doesn't.

## Implications

Several other ideas in this wiki are downstream of compounding:

- [[four-principles]] — *Explicit* is only meaningful because there is something accumulated to be explicit about.
- [[division-of-labor]] — the LLM does maintenance precisely because the value of the wiki grows with maintenance. The whole division only pays off if knowledge actually compounds.
- [[operation-lint]] — lint exists to prevent the compounding from rotting (contradictions go un-flagged, orphans accumulate, cross-refs decay). Without lint, the compounding works against you.

## Related

- [[core-idea]] — the high-level statement of the pattern; this page is the engine room
- [[problem-with-naive-rag]] — what compounding fixes
- [[operation-ingest]] — engine 1
- [[query-as-write-loop]] — engine 2
- [[ingest-pipeline]] — the mechanism by which one source touches many pages
- [[four-principles]] — what compounding makes possible
- [[division-of-labor]] — what compounding is worth doing the work for

## Open questions on this page

- At what wiki size does compounding's value become obvious? (~50 pages? ~200?) Below that threshold the pattern looks like more work for similar results.
- Does compounding ever become **negative**? A wiki that's too dense in cross-references could be harder to navigate than a smaller, cleaner one. Where's the break-even?
- Is there a "cooling-off" mechanism — pages that haven't been read in a year get demoted or archived? Currently no; [[open-questions]] tracks this.
