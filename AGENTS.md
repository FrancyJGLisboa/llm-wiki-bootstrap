# AGENTS.md — `llm-wiki-bootstrap` schema

This file is the **schema** layer of the LLM-wiki pattern (see [`wiki/layer-schema.md`](wiki/layer-schema.md)). It tells any AI agent operating on this directory how the wiki is structured and how to work with it.

## What this project is

A personal LLM-wiki knowledge base, operated **exclusively via slash commands** in any agentic tool (Claude Code first; others follow). The wiki layer is **owned by the LLM** — the user curates raw sources and asks questions; the LLM does all writing, cross-referencing, and maintenance.

The wiki currently shipped is *meta*: a wiki **about** the LLM-wiki pattern itself, derived from `raw/karpathy-llm-wiki-video-transcript.md`. It serves as both the system's reference documentation and as a worked example of the pattern. Users may extend it, replace it, or wipe it (`rm -rf wiki/* && /wiki-init`) to start their own.

## Three-layer model

| Layer | Path | Owned by | Mutability |
|---|---|---|---|
| **Raw sources** | `raw/` | User (via `/wiki-fetch` or manual drop) | Immutable after fetch (user may edit; ingest detects via hash) |
| **Wiki** | `wiki/` | **LLM only** | Mutable, rewritten freely by `/wiki-ingest`, `/wiki-ask` (promote), `/wiki-lint` |
| **Schema** | `AGENTS.md` (this file), `CHANGELOG.md` | User + LLM (co-evolved) | User-readable; LLM may propose edits via `/wiki-lint` |

**Critical:** The LLM must never edit files in `raw/` (it may only read them). The user must never edit files in `wiki/` directly — instead, edit raw sources or use `/wiki-ask` to file the new claim, then re-run `/wiki-ingest` or `/wiki-lint`.

## The five slash commands

| Command | Purpose |
|---|---|
| `/wiki-init` | Scaffold an empty wiki structure (raw/, wiki/, AGENTS.md, README.md, CHANGELOG.md) in the current directory. Idempotent. |
| `/wiki-fetch <source>` | Acquire a URL / local file / image into `raw/` with frontmatter. Does **not** touch `wiki/`. |
| `/wiki-ingest [<raw-file>]` | Process raw → wiki: 7-step pipeline (read, extract, write summary, update entity/concept pages, flag contradictions, update index, append CHANGELOG). Detects deltas via body hash. |
| `/wiki-ask <question>` | Answer from wiki; if gaps, web-search and auto-promote answers as new/updated pages. Flag `--no-promote` to disable promotion. |
| `/wiki-lint` | Maintenance pass: broken links, orphans, contradictions, stale claims, unresolved open-questions, gaps. Reports + proposes edits; `--apply` to write them. |

Full spec lives at [`wiki/commands.md`](wiki/commands.md). Implementations at `.claude/commands/wiki-*.md`.

## Wiki page convention

Every file in `wiki/` follows this template:

```markdown
---
title: <Title Case>
type: concept | entity | summary | analysis | navigation
source: video | analysis | external | mixed
updated: YYYY-MM-DD
tags: [...]
---

# <Title>

## Definition / TL;DR
1-3 sentences. What this page is about.

## Body
Free-form prose. Inline `[[wiki-links]]` to related pages, and `(source: <raw-file>#<anchor>)` refs back to raw sources for any non-trivial claim.

## Related
- [[other-page]] — why it relates

## Open questions on this page
- ... (consumed by /wiki-lint)
```

### Frontmatter fields

- `title` — Title Case display name (the file name is the slug).
- `type` — `concept` (idea/term), `entity` (named thing/person/tool), `summary` (per-source recap), `analysis` (interpretation, not in raw), `navigation` (index/TOC pages).
- `source` — `video` (literal from a raw video transcript), `analysis` (LLM/user interpretation; must be honest about being interpretive), `external` (added from web search), `mixed` (both video and analysis).
- `updated` — ISO date of last edit.
- `tags` — array of kebab-case tags.

### Link convention

`[[kebab-case-page-name]]` resolves to `wiki/kebab-case-page-name.md`. Textual only — **no rendering dependency** (no Obsidian, no Dataview). The LLM resolves links by string match.

`/wiki-lint` flags any `[[link]]` with no matching file.

### Source attribution

Any claim that came from a raw source must include `(source: <raw-file>#<anchor>)` inline. Example: `(source: raw/karpathy-llm-wiki-video-transcript.md#3:50)`. The anchor can be a timestamp, heading, or line range.

Pages with `source: analysis` must say so visibly in the body (e.g., "This page is interpretation, not extracted from the video.").

## Raw source convention

File names: `raw/<slug>.<ext>` for text (`.md`, `.txt`) — or `raw/<slug>.<ext>` plus sidecar `raw/<slug>.<ext>.md` for binaries (images, PDFs).

Every raw file starts with frontmatter:

```yaml
---
source_url: <url|n/a>
source_type: video-transcript | tweet | article | image | pdf | chat | book-chapter | meeting-notes | ...
source_title: "..."
source_author: "..."
fetched_at: YYYY-MM-DD
ingested_hash: <sha256 of body at last successful ingest, or "">
ingested_at: YYYY-MM-DD HH:MM | never
ingested_pages: [<list of wiki/*.md files this raw touched on last ingest>]
notes: |
  Optional context about how this source was acquired or interpreted.
---
```

`/wiki-ingest` computes the current body hash; if it differs from `ingested_hash`, the source is processed (or re-processed). Otherwise it's skipped.

**Canonical hashing.** The ONE allowed way to compute `ingested_hash` is `scripts/body-hash.sh <file>`. Do not reinvent the hashing logic inline (different awk patterns, different newline handling, different SHA tools → different hashes → broken idempotence). The script defines "body" as everything after the closing `---` of frontmatter, hashed with SHA-256.

## CHANGELOG format

`CHANGELOG.md` is append-only, newest at top:

```markdown
## YYYY-MM-DD HH:MM — /wiki-ingest

- Processed: raw/<file> (hash <8-char-prefix>)
- Created: wiki/<file>, wiki/<file>
- Updated: wiki/<file>
- Contradictions flagged: none | <description>

## YYYY-MM-DD HH:MM — /wiki-ask "..."

- Web-searched: <urls>
- Promoted: wiki/<file> (new)
- Updated: wiki/<file>
```

## What the LLM must NOT do

1. Edit anything in `raw/`. Read-only.
2. Use Obsidian-specific extensions (callouts `> [!note]`, dataview blocks, embedded queries, etc.). Pure CommonMark only.
3. Add backlinks blocks manually — let `/wiki-lint` compute them if requested.
4. Modify `AGENTS.md` without surfacing the change to the user (this is shared schema).
5. Delete wiki pages without leaving a CHANGELOG entry.
6. Add a wiki page without filling required frontmatter fields.

## When in doubt

Pages that explain how this system works are in `wiki/`. Start at [`wiki/index.md`](wiki/index.md).
