---
title: Layer — Wiki
type: concept
source: mixed
updated: 2026-05-25
tags: [architecture, wiki, conventions]
---

# Layer — Wiki

## Definition / TL;DR

`wiki/` is the LLM-owned knowledge layer: a directory of interlinked markdown pages (summaries, concept pages, entity pages, analysis pages). The LLM is the sole writer. The user never edits these files directly.

## Body

From the video: *"In the middle is the wiki itself, a directory of markdown files that the LLM owns entirely — summaries, entity pages, concept pages, comparisons. The LLM creates these, updates them when new sources come in, and maintains all the cross references, keeps everything consistent."* `(source: raw/karpathy-llm-wiki-video-transcript.md#2:32)`

And critically: *"The critical thing is you never write the wiki yourself. The LLM writes and maintains all of it."* `(source: raw/karpathy-llm-wiki-video-transcript.md#0:51)`

### Page types `(analysis: from AGENTS.md convention)`

Every page has `type` in its frontmatter, with one of:

- **`concept`** — an idea, term, or pattern (e.g., this page; [[ingest-pipeline]])
- **`entity`** — a named thing: a person, tool, paper, dataset (e.g., a page about Karpathy himself, or about NotebookLM)
- **`summary`** — a per-source recap (e.g., one page summarizing one paper)
- **`analysis`** — interpretation that goes beyond what raw sources literally say; must be visibly marked as such
- **`navigation`** — index / TOC pages (e.g., [[index]])

### Link convention `(analysis)`

`[[kebab-case-page-name]]` resolves to `wiki/kebab-case-page-name.md`. Text-only — no rendering dependency (see [[implicit-constraints]]). The LLM resolves links by string match; [[operation-lint]] flags `[[links]]` with no matching file.

### What goes in a page

See the page template in `AGENTS.md`. Each page has: frontmatter, TL;DR, body with inline citations to raw sources, a `Related` section listing 2+ wiki-links with one-line justifications, and an `Open questions on this page` block consumed by [[operation-lint]].

### What the LLM may NOT do here

- Add Obsidian-specific syntax (callouts, dataview, embeds) — pure CommonMark only
- Manually maintain backlinks blocks — [[operation-lint]] computes these on demand
- Skip the source citation when claims came from a specific raw source

## Related

- [[three-layer-architecture]] — where this fits
- [[layer-raw-sources]] — what feeds in
- [[layer-schema]] — what configures this layer's conventions
- [[operation-ingest]] — how new pages are created
- [[division-of-labor]] — why only the LLM writes here

## Open questions on this page

- When does a concept page "split" into multiple pages (the concept got too big)? When does it merge with another?
- Should entity pages for transient people (e.g., a YouTuber whose name appears once in a transcript) exist at all?
- Does the LLM ever delete a wiki page proactively, or only when the user asks?
