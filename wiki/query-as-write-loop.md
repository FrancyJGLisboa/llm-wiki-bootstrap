---
title: Query-as-Write Loop
type: concept
source: video
updated: 2026-05-25
tags: [operations, query, compounding]
---

# Query-as-Write Loop

## Definition / TL;DR

When the user asks a question the wiki can't answer, the LLM web-searches for the missing knowledge and **files the new content as wiki pages**. The next time anyone asks anything in that area, the wiki already has it. Queries grow the wiki the same way ingest does — they're a second engine of compounding.

## Body

From the video: *"If I ask any question based on this wiki information that it doesn't have on hand, it can then do a web search and then it will go and automatically backfill the wiki with the new information that it found."* `(source: raw/karpathy-llm-wiki-video-transcript.md#13:08)`

### The example

In the video, the user asks: "Is there any other way to identify [draws on liquidity]? Check outside the wiki." The LLM doesn't know — the wiki doesn't have the answer. It does a web search, finds five other identification methods, gives the user an answer, and **writes new wiki pages**: `order-blocks`, `breaker-blocks`, `equal-high-lows`. `(source: raw/karpathy-llm-wiki-video-transcript.md#13:08)`

From this point on, future queries about any of those three concepts read from the wiki, not from web search. The cost-per-query drops; coverage grows.

### Why this is the second engine

[[operation-ingest]] grows the wiki when the user **adds raw sources**. The query-as-write loop grows it when the user **asks questions whose answers don't exist yet in raw**. Both ratchet the wiki forward; both compound. Together they cover:

- Sources you find and decide are worth keeping (ingest)
- Knowledge you didn't know you'd need until you asked (query-as-write)

### How `/wiki-query` implements this `(analysis)`

When the wiki is insufficient for a question, the LLM:
1. Notes the gap
2. Does a `WebSearch` + `WebFetch`
3. Synthesizes an answer for the user
4. Decides whether the new knowledge is **notable** (introduces a new term, makes a new connection, cites a new external source)
5. If notable: writes / updates wiki pages and logs the promotion in `log.md`

The user can pass `--no-promote` to disable step 5 (one-off questions where the user doesn't want the wiki to drift toward the topic).

### The video's own framing

The LLM's reply (quoted in the video) sums it up: *"This is exactly how the wiki is meant to grow. You ask a question, I researched beyond the wiki and the new knowledge got filed back as permanent pages. So every future query can now reference order blocks, breaker blocks, equal highs and lows along with the original stuff."* `(source: raw/karpathy-llm-wiki-video-transcript.md#15:10)`

## Related

- [[operation-query]] — the broader operation
- [[operation-ingest]] — the *other* engine of compounding
- [[knowledge-compounds]] — the property that both engines feed
- [[four-principles]] — *Explicit* underwrites this: the promoted pages are auditable
- [[problem-with-naive-rag]] — query-as-write is what RAG never gets you

## Open questions on this page

- How does the system avoid runaway growth? (A noisy curious user could explode the wiki with low-quality promoted pages.) Likely answer: notability threshold + periodic [[operation-lint]] to prune orphans.
- Should promoted pages be marked `source: external` so they're visibly different from `source: video` and `source: analysis`? (Current project convention: yes — see `AGENTS.md`.)
- When the same question is asked twice, should the second ask refresh the web-searched content, or trust the previously promoted page?
