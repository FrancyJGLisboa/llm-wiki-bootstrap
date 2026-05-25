---
title: Layer — Raw Sources
type: concept
source: mixed
updated: 2026-05-25
tags: [architecture, raw, conventions]
---

# Layer — Raw Sources

## Definition / TL;DR

`raw/` holds the user-curated source material the LLM learns from. Articles, papers, video transcripts, images, datasets — whatever the user finds worth keeping. **Immutable to the LLM** (read-only); the user may edit if needed, and [[operation-ingest]] detects the change.

## Body

From the video: *"Articles, papers, images, data sets, whatever you're collecting... these are your raw sources and these are immutable. The LLM reads them but never touches them. They're your source of truth."* `(source: raw/karpathy-llm-wiki-video-transcript.md#2:42-2:59)`

### What lives here

- Article / blog post text (preferably as markdown)
- Video transcripts (this project's first raw source is one)
- Tweets, threads, chat exports
- Images, PDFs, datasets — as binaries with a sidecar `.md` containing the LLM-extracted text/description
- Meeting notes, customer-call transcripts, book chapters

### Naming convention `(analysis: from AGENTS.md)`

- Text: `raw/<slug>.md` (or `.txt`)
- Binary: `raw/<slug>.<ext>` plus `raw/<slug>.<ext>.md` sidecar with extracted text

Slugs are kebab-case, descriptive, dated when useful (`whatsapp-francy-juliano-2026-05-21.md`).

### Frontmatter `(analysis: from AGENTS.md)`

Every raw file starts with frontmatter capturing where it came from and when, plus three fields owned by [[operation-ingest]]: `ingested_hash`, `ingested_at`, `ingested_pages`. See [`AGENTS.md`](../AGENTS.md) for the schema.

### Acquisition

Two paths to get a source into `raw/`:

1. **`/wiki-extract <source>`** — preferred. URL → markdown via WebFetch; local file → copy; image → vision + sidecar. Frontmatter populated automatically.
2. **Manual drop** — `cp` or paste the file in. The user must add frontmatter by hand, or rely on `/wiki-ingest` to prompt for missing fields.

### What the LLM may NOT do here

- Edit any existing file in `raw/`. Read-only.
- Delete files from `raw/`. The user owns deletion.
- Reorganize the directory. Flat structure, user controls.

## Related

- [[three-layer-architecture]] — where this fits
- [[layer-wiki]] — where the LLM writes the derived knowledge
- [[operation-ingest]] — what processes raw into wiki

## Open questions on this page

- What happens when a raw source is a *live URL* whose content changes over time? Manual re-fetch + `/wiki-ingest` handles it, but there's no automation.
- How big is too big? A 50-page PDF probably fits one raw file; a 50-hour podcast series probably doesn't.
- Are sub-folders in `raw/` ever useful (e.g., `raw/podcasts/`, `raw/papers/`)? Current default: flat. May revisit.
