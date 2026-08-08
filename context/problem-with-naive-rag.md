---
title: The Problem With Naive RAG
type: concept
source: video
updated: 2026-05-25
tags: [foundations, rag, motivation]
---

# The Problem With Naive RAG

## Definition / TL;DR

Naive Retrieval-Augmented Generation (RAG) — the "upload files, ask questions, get chunks-stitched-into-an-answer" pattern — rediscovers knowledge from scratch on every query. Nothing accumulates between conversations. The LLM-wiki pattern is a direct response to this.

## Body

In the dominant LLM-with-documents UX (ChatGPT file uploads, NotebookLM, most chat-with-your-PDF tools), each question triggers a retrieval pass: the system finds N chunks that look relevant, hands them to the LLM, and the LLM produces an answer. `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`

This works fine for shallow questions. It fails — or at least wastes effort — when:

- A question requires synthesizing claims from 5+ documents. The LLM has to find and connect those pieces *every single time you ask anything similar.* `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`
- A contradiction across sources needs to be noticed and flagged. Naive RAG doesn't compare retrieved chunks against each other for consistency.
- Cross-references between concepts would be useful as standing knowledge. Naive RAG has nowhere to put them.

In the video's framing: *"Nothing accumulates. Every time you ask a question, the LLM is rediscovering knowledge from scratch. It's repiecing together fragments every single time."* `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`

The [[core-idea]] of the LLM-wiki pattern inverts this. Instead of retrieving at query time, the LLM **builds the synthesis up front** into a persistent wiki layer. Cross-refs are already there. Contradictions are already flagged. The wiki *is* the accumulated understanding. See [[operation-ingest]] for how this gets written, and [[operation-query]] for how reading the wiki replaces the retrieval pass.

## Related

- [[core-idea]] — what the pattern proposes instead
- [[knowledge-compounds]] — the property RAG lacks and the wiki pattern is built around
- [[operation-query]] — what "asking a question" looks like when there's a wiki to read
- [[query-as-write-loop]] — how query results in this pattern *also* compound the wiki

## Open questions on this page

- Are there question types where naive RAG actually beats the LLM-wiki? (Probable answer: one-off lookups against a corpus too volatile to be worth maintaining a wiki over.)
- How do agentic-search systems (e.g., open-deep-research) compare? They don't build a wiki but they do iterative retrieval — different point in the design space.
