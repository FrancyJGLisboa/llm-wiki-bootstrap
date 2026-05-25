---
title: Operation — Query
type: concept
source: video
updated: 2026-05-25
tags: [operations, query]
---

# Operation — Query

## Definition / TL;DR

**Query** is asking questions against the wiki. The LLM reads the relevant pages and synthesizes an answer from what's already there. If the wiki doesn't have enough, the LLM does a web search and **files the new knowledge back** as wiki pages (see [[query-as-write-loop]]).

## Body

From the video: *"You ask questions against the wiki. The LLM searches the index, reads the relevant pages, and synthesizes an answer."* `(source: raw/karpathy-llm-wiki-video-transcript.md#4:07-4:18)`

The clever part: *"Good answers can be filed back into the wiki as new pages. So your explorations compound in the knowledge base just like ingested sources do."* `(source: raw/karpathy-llm-wiki-video-transcript.md#4:18-4:25)` See [[query-as-write-loop]] for the full mechanism.

### What query looks like

The video shows asking "Can you explain draw on liquidity to me?" against an already-ingested wiki. The LLM reads the relevant pages and gives a structured answer with: definition, types, qualifying/disqualifying cases, concrete examples, connections to other concepts. **No web search needed because the wiki already contains the synthesis.** `(source: raw/karpathy-llm-wiki-video-transcript.md#13:08-13:30)`

This is the inversion of [[problem-with-naive-rag]]: the synthesis was done at ingest time, not query time. The LLM is reading a pre-built knowledge layer, not re-piecing chunks.

### When the wiki doesn't have the answer

The follow-up in the video: *"If I ask any question based on this wiki information that it doesn't have on hand, it can then do a web search and then it will go and automatically backfill the wiki with the new information that it found."* `(source: raw/karpathy-llm-wiki-video-transcript.md#13:56-14:14)`

So a query that exceeds the wiki's coverage triggers web search → answer → **promote the new knowledge** as wiki pages. The next query about the same area is fast. See [[query-as-write-loop]].

### Output formats

Queries don't have to return prose. The video mentions the LLM can produce markdown files, slideshows, matplotlib images, etc. as query outputs. `(source: raw/karpathy-llm-wiki-video-transcript.md#14:40-14:56)` In this project, the `/wiki-ask` slash command returns text by default; richer outputs are open for future versions.

## Related

- [[query-as-write-loop]] — how query results compound the wiki
- [[problem-with-naive-rag]] — what query replaces
- [[operation-ingest]] — the other write path into the wiki
- [[four-principles]] — *Explicit* (the LLM only "knows" what's in the wiki) underwrites why query is auditable

## Open questions on this page

- When should a query *not* auto-promote (one-off lookups, sensitive questions about the user themselves)?
- How much wiki context fits in one query? If the wiki has 500 pages, the LLM can't read them all — what's the discovery / pagination strategy?
- How to expose the LLM's "search path" through the wiki to the user, so they can audit which pages were read?
