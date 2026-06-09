---
title: Index
type: navigation
source: analysis
updated: 2026-05-26
tags: [navigation, index]
---

# Index

> **This page is `source: analysis`.** Navigation pages are not extracted from raw sources — they're written by the LLM (and editable by `/wiki-lint`) to organize what already exists in the wiki.

Navigation page for the wiki. Pages are grouped by what they're about, not alphabetically. Start with [[core-idea]] if you've never seen this pattern before.

## Foundations

- [[core-idea]] — what an LLM-wiki is, and Karpathy's central claim
- [[problem-with-naive-rag]] — what the pattern is a reaction against
- [[knowledge-compounds]] — the single property that makes the pattern work
- [[four-principles]] — Explicit / Yours / File-over-app / BYO AI
- [[use-cases]] — research, personal, business, reading, due diligence
- [[division-of-labor]] — human curates; LLM maintains

## Architecture

- [[three-layer-architecture]] — Raw / Wiki / Schema, at a glance
- [[layer-raw-sources]] — what goes in `raw/`
- [[layer-wiki]] — what goes in `wiki/`
- [[layer-schema]] — what `AGENTS.md` is for

## Operations

- [[operation-ingest]] — raw → wiki
- [[operation-query]] — asking the wiki questions
- [[operation-lint]] — keeping the wiki healthy
- [[ingest-pipeline]] — the 7 steps of ingest, in detail
- [[synthesis-artifacts]] — Step 8: the derived views regenerated on every mutation
- [[query-as-write-loop]] — how queries also grow the wiki

## This system specifically

- [[commands]] — the five slash commands (`/wiki-init`, `/wiki-extract`, `/wiki-ingest`, `/wiki-query`, `/wiki-lint`)
- [`AGENTS.md`](../AGENTS.md) — the schema (root of the project)
- [`README.md`](../README.md) — install + quickstart

## Source summaries (per-source recaps — `type: summary`)

- [[karpathy-llm-wiki-video-transcript-summary]] — main YouTube transcript (primary source)
- [[karpathy-video-slide-ingest-pipeline-summary]] — single slide on the ingest pipeline (second source, same video)
- [[smoke-source-summary]] — end-to-end smoke fixture (fictional "phase coherence engineering" primer)

## Analysis (interpretive — `source: analysis`)

- [[implicit-constraints]] — rules any faithful implementation must honor
- [[open-questions]] — gaps the video doesn't address
- [[source-attribution]] — what's Karpathy, what's the YouTuber, what's us
- [[glossary]] — terms used throughout the wiki

## Smoke fixture (derived from `raw/smoke-source.md` — fictional, do not treat as real-world knowledge)

- [[phase-coherence-engineering]] — the (invented) field the fixture introduces
- [[quortex-protocol]] — the central artifact; carries the literal "47 phase rotations" anchor for smoke C2
- [[dr-alma-voss]] — the (invented) founder, smoke anchor

## Reading orders

**If you want the literal video content first:**
[[core-idea]] → [[problem-with-naive-rag]] → [[knowledge-compounds]] → [[three-layer-architecture]] → [[layer-raw-sources]] → [[layer-wiki]] → [[layer-schema]] → [[operation-ingest]] → [[operation-query]] → [[operation-lint]] → [[ingest-pipeline]] → [[division-of-labor]] → [[four-principles]] → [[query-as-write-loop]] → [[use-cases]]

**If you want to install and use the system:**
[`README.md`](../README.md) → [[commands]] → [[layer-schema]] → [[implicit-constraints]]

**If you want to extend or fork:**
[[implicit-constraints]] → [[open-questions]] → [[source-attribution]] → [[commands]]

## How this page is maintained

`/wiki-ingest` updates this index automatically when it creates new wiki pages. `/wiki-lint` flags entries here that point to missing pages, and flags wiki pages not listed here.

## Related

- All other wiki pages (this is the index)

## Open questions on this page

- Should the index auto-categorize by `tags:` in frontmatter, or stay hand-grouped?
- At what page count does a flat index stop scaling? (~50? ~100?)
- Should each entry show the page's TL;DR as a tooltip / one-liner? (Currently no — keeps the index scannable.)
