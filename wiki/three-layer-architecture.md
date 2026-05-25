---
title: Three-Layer Architecture
type: concept
source: video
updated: 2026-05-25
tags: [architecture, foundations]
---

# Three-Layer Architecture

## Definition / TL;DR

The LLM-wiki pattern is structured as three layers: **raw sources** (immutable, user-curated), the **wiki** (LLM-owned markdown), and the **schema** (a config file the user and LLM co-evolve).

## Body

From the video: *"The basic architecture has three different layers based on what Karpathy was describing, and it's fairly clean."* `(source: raw/karpathy-llm-wiki-video-transcript.md#2:32-2:42)`

| Layer | Path in this project | Owned by | Mutates? |
|---|---|---|---|
| [[layer-raw-sources]] | `raw/` | User (drops via `/wiki-extract` or manually) | Immutable after fetch; user may edit, [[operation-ingest]] detects via hash |
| [[layer-wiki]] | `wiki/` | LLM only | Mutated by `/wiki-ingest`, `/wiki-query` (promote), `/wiki-lint` |
| [[layer-schema]] | `AGENTS.md` (this project) | User + LLM (co-evolved) | User edits when conventions change; LLM proposes via `/wiki-lint` |

### The video's analogy

The YouTuber summarizes the architecture as: *"The wiki is a codebase, Obsidian is the IDE, the LLM is the programmer, and the schema is the style guide."* `(source: raw/karpathy-llm-wiki-video-transcript.md#3:35-3:50)`

In this project we deliberately drop the "Obsidian is the IDE" part — see [[implicit-constraints]]. The wiki is still the codebase and the LLM still the programmer, but there is **no required viewer**. Read the markdown with `cat`, a code editor's preview, GitHub web, or Obsidian if you happen to like it. The system depends on none.

### Why three (not two)

Two-layer alternatives would be raw + wiki, with conventions implicit in prompts. The schema layer exists because conventions need to be (a) explicit, (b) editable by the user when they want to steer the LLM, (c) automatically read by the agent each session. Putting conventions in a separate file (rather than as a section of the wiki itself) is what makes the user a peer in evolving the system.

## Related

- [[layer-raw-sources]] — the immutable layer
- [[layer-wiki]] — the LLM-owned layer
- [[layer-schema]] — the user-LLM contract layer
- [[core-idea]] — what these three layers together enable
- [[operation-ingest]] — what crosses from raw to wiki

## Open questions on this page

- Should derived artifacts (slideshows, plots, exported summaries) be a fourth layer, or live inside the wiki?
- How does the schema layer evolve gracefully if the user changes conventions mid-project? (E.g., renames a tag — does ingest re-write old pages?)
