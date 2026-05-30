---
title: Use Cases
type: concept
source: video
updated: 2026-05-25
tags: [foundations, applications]
---

# Use Cases

## Definition / TL;DR

The LLM-wiki pattern applies wherever knowledge accumulates from many sources over time and benefits from being interlinked. Research, personal tracking, internal business knowledge, deep reading, and due-diligence work all qualify.

## Body

From the video: *"What can you build with this? This pattern applies to a lot of different domains."* `(source: raw/karpathy-llm-wiki-video-transcript.md#7:35)`

The five examples named in the video:

### Research

*"Going deep on a topic over weeks and months, reading papers, building up a comprehensive wiki with an evolving thesis."* `(source: raw/karpathy-llm-wiki-video-transcript.md#7:35)`

Long-horizon investigation where you read 30+ papers and need the synthesis to compound rather than re-do itself each session. Classic academic / industrial-research use.

### Personal

*"You can track your goals, health, self-improvement. You can build a structured picture of yourself over time."* `(source: raw/karpathy-llm-wiki-video-transcript.md#7:35)`

Raw sources: journal entries, lab results, training logs, mood notes. Wiki pages: per-goal status, evolving self-models, retrospectives. The wiki *becomes a mirror.*

### Business

*"An internal wiki fed by Slack, meetings, customer calls, always current because the LLM handles maintenance."* `(source: raw/karpathy-llm-wiki-video-transcript.md#7:35)`

The killer feature here is *always current.* Most internal wikis decay because no one wants to maintain them. With LLM maintenance, that flips. Raw sources: call transcripts, meeting notes, Slack exports, customer interviews.

### Reading

*"Filling each chapter of a book, building out character and theme pages."* `(source: raw/karpathy-llm-wiki-video-transcript.md#7:35)`

One raw source per chapter; entity pages for characters, locations, themes; cross-references showing how they evolve. Functions as a per-book companion knowledge base.

### Due diligence

*"And due diligence — obviously."* `(source: raw/karpathy-llm-wiki-video-transcript.md#7:35)`

Investment, M&A, vendor evaluation — anywhere a decision rests on synthesizing many sources about a single target. Raw sources: filings, news articles, interviews, financial data, technical docs.

### What these have in common

- **Many sources** over time, not a single document
- **Synthesis matters** — the relationships between sources are valuable, not just the sources individually
- **Maintenance burden is the actual bottleneck** today (per [[division-of-labor]])
- **Knowledge persists** beyond any single chat session

## Related

- [[core-idea]] — what these use cases are use cases *of*
- [[division-of-labor]] — why maintenance is the real unlock
- [[four-principles]] — *Yours* makes each of these portable
- [[problem-with-naive-rag]] — why these use cases aren't well served by upload-and-ask tools

## Open questions on this page

- Which use cases are a *bad* fit? (One-off lookups; structured data better held in a DB; volatile sources where the wiki would be permanently stale; anything covered by a single document.)
- Are there use cases the video didn't name? (Plausibly: codebase mental model; therapy / coaching journals; legal-case timeline tracking.)
- How does multi-user collaboration interact with these? (Especially Business.)
