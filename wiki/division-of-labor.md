---
title: Division of Labor
type: concept
source: video
updated: 2026-07-07
tags: [foundations, philosophy]
---

# Division of Labor

## Definition / TL;DR

The human **curates** (chooses sources, asks questions, decides what matters). The LLM **maintains** (summarizes, cross-references, files, lints). The whole pattern hinges on the LLM being good enough — and cheap enough — at maintenance that wiki rot stops being the limiting factor.

## Body

From the video: *"The human curates questions and thinks. You pick the sources, you direct the analysis, you ask the good questions, you decide what actually matters. The LLM agent just summarizes, cross-references, and maintains. It writes all of the wiki pages."* `(source: raw/karpathy-llm-wiki-video-transcript.md#5:40)`

### Why this works

The central observation, attributed to Karpathy: *"Humans abandon wikis because the maintenance burden grows faster than the value."* `(source: raw/karpathy-llm-wiki-video-transcript.md#5:40)`

It's not that people don't want knowledge bases. It's that wikis past a certain size require more bookkeeping than any single person is willing to do — updating cross-references when a concept is renamed, summarizing a new source into multiple existing pages, noticing when an old claim has gone stale. That work isn't *hard*; it's *tedious*. So it doesn't happen, and the wiki ages out.

LLMs are different on exactly this axis: *"LLMs don't get bored. They don't forget to update a cross reference. They can touch 15 files in a single pass. The cost of maintenance drops to near zero."* `(source: raw/karpathy-llm-wiki-video-transcript.md#5:40)`

### The split, made concrete

| Activity | Owned by |
|---|---|
| Picking raw sources | **User** |
| Adding a source via `/wiki-extract` | User triggers; LLM executes |
| Writing wiki pages | **LLM** (always) |
| Updating cross-references | **LLM** |
| Asking questions | **User** |
| Answering questions | **LLM** |
| Deciding what's worth promoting from a query into a wiki page | **LLM** (auto-promote heuristic; user vetoes with `--no-promote`) |
| Catching contradictions, orphans, stale claims | **LLM** via [[operation-lint]] |
| Resolving a flagged contradiction | **User** decides; LLM applies |
| Editing the schema | User and LLM, co-evolved |

### What this implies for the user

The user's job is **upstream**: be a good curator (high-quality raw sources beat lots of low-quality ones) and a good interrogator (questions reveal gaps the wiki should fill). Everything downstream of those two activities is the LLM's problem.

### What happens when the maintenance half is dropped

The [[open-knowledge-format]] is a natural experiment: when Google standardized the LLM-wiki pattern, it "kept the folder and left out the part that keeps it alive" — Karpathy's instructions for how the AI maintains the wiki (source: raw/devsplainers-okf-llm-wiki-video-transcript.md#3:29). The predicted failure mode is exactly the one this split exists to prevent: a shared folder "goes still in a month. Nobody volunteers to tend it and the agent starts answering from knowledge that expired back in spring" (source: raw/devsplainers-okf-llm-wiki-video-transcript.md#4:54). The maintenance half of the division of labor is not an accessory to the format — it is the part that makes the format worth having.

## Related

- [[core-idea]] — the whole pattern restates this split
- [[knowledge-compounds]] — what makes this split worth doing
- [[operation-ingest]] — the LLM's bulk work
- [[operation-lint]] — the LLM's antidote to rot
- [[four-principles]] — *Yours* (you own the wiki; you also own the curation) builds on this
- [[open-knowledge-format]] — what a format looks like when the maintenance half is dropped

## Open questions on this page

- How does the user know whether the LLM is doing a good job? (Lint reports, periodic spot-checks, occasional manual reads of wiki pages.)
- Is there a use case for the user editing a wiki page directly? Current default: no — edit the raw source or use `/wiki-query` to file a new claim. But there might be edge cases (typo fix, sensitive redaction) where direct edit is fine.
- Does this split scale to multi-user wikis? (Two humans curating; one LLM maintaining? Conflict resolution gets harder.)
