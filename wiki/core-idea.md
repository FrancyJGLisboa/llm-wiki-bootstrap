---
title: Core Idea
type: concept
source: video
updated: 2026-07-07
tags: [foundations, karpathy]
---

# Core Idea

## Definition / TL;DR

An LLM-wiki is a **persistent, interlinked markdown wiki** that an LLM incrementally builds and maintains, sitting between the user and the user's raw sources. The user curates sources and questions; the LLM does all the writing, summarizing, and cross-referencing.

## Body

The video's central quote, attributed to Karpathy (paraphrased by the YouTuber): *"The LLM incrementally builds and maintains a persistent wiki — structured, interlinked markdown files sitting between you and your raw sources."* `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`

Three things make this an idea worth a name, rather than just "use markdown for notes":

1. **The LLM is the sole writer of the wiki layer.** The user never edits wiki pages directly. The user's contribution is upstream (dropping in raw sources, asking questions) and the LLM's job is everything downstream of that (see [[division-of-labor]]). `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`

2. **Knowledge accumulates rather than being rediscovered per query.** Cross-references, contradictions, and synthesis are written *into* the markdown — not recomputed each time you ask. This is the inversion of [[problem-with-naive-rag]].

3. **The wiki is persistent.** Files on disk, not embeddings in a vector store, not memory in a chat session. Anyone (or any tool) can read it; you keep it (see [[four-principles]]).

The user's role is to be in charge of "the important stuff — finding the good sources, exploring, asking the right questions." The LLM handles "all the grunt work — the summarizing, the cross-referencing, the filing, the bookkeeping — all the stuff that makes knowledge bases useful, but that no one actually wants to do." `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`

The idea has since been formalized beyond Karpathy's sketch: in June 2026 Google Cloud published the [[open-knowledge-format]], describing it as "an open specification that formalizes the LLM-wiki pattern into a portable, interoperable format" (source: raw/google-cloud-okf-blog.md#overview) — standardizing the container, though not the maintenance loop (see [[okf-vs-llm-wiki-bootstrap]]).

## Related

- [[problem-with-naive-rag]] — what this is a reaction against
- [[knowledge-compounds]] — the engine that makes the idea pay off
- [[three-layer-architecture]] — how the idea is structured into raw / wiki / schema
- [[division-of-labor]] — who does what
- [[four-principles]] — properties that make the idea durable
- [[open-knowledge-format]] causes — the pattern's traction led Google to formalize it as OKF

## Open questions on this page

- What's the minimum number of raw sources where the compounding effect starts to show value? (Two? Ten?)
- Does the pattern work for users who can't articulate good questions yet (i.e., the wiki as a *learning* tool, not just a *research* tool)?
