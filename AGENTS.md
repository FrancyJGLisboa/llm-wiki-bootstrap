# AGENTS.md — `llm-wiki-bootstrap` schema

**Schema version:** 1 — introduced 2026-05-25. Changes to this number signal that slash commands, frontmatter conventions, or layer rules have shifted in a way older clients may need to adapt for. See "Schema versioning" near the bottom for the bump policy.

This file is the **schema** layer of the LLM-wiki pattern (see [`wiki/layer-schema.md`](wiki/layer-schema.md)). It tells any AI agent operating on this directory how the wiki is structured and how to work with it.

## What this project is

A personal LLM-wiki knowledge base, operated **exclusively via slash commands** in any agentic tool (Claude Code first; others follow). The wiki layer is **owned by the LLM** — the user curates raw sources and asks questions; the LLM does all writing, cross-referencing, and maintenance.

The wiki currently shipped is *meta*: a wiki **about** the LLM-wiki pattern itself, derived from `raw/karpathy-llm-wiki-video-transcript.md`. It serves as both the system's reference documentation and as a worked example of the pattern. Users may extend it, replace it, or wipe it (`rm -rf wiki/* && /wiki-init`) to start their own.

## Three-layer model

| Layer | Path | Owned by | Mutability |
|---|---|---|---|
| **Raw sources** | `raw/` | User (via `/wiki-extract` or manual drop) | Immutable after fetch (user may edit; ingest detects via hash) |
| **Wiki** | `wiki/` | **LLM only** | Mutable, rewritten freely by `/wiki-ingest`, `/wiki-query` (promote), `/wiki-lint` |
| **Schema** | `AGENTS.md` (this file), `log.md` | User + LLM (co-evolved) | User-readable; LLM may propose edits via `/wiki-lint` |

**Critical:** The LLM must never edit files in `raw/` (it may only read them). The user must never edit files in `wiki/` directly — instead, edit raw sources or use `/wiki-query` to file the new claim, then re-run `/wiki-ingest` or `/wiki-lint`.

## The five slash commands

| Command | Purpose |
|---|---|
| `/wiki-init` | Scaffold an empty wiki structure (raw/, wiki/, AGENTS.md, README.md, log.md) in the current directory. Idempotent. |
| `/wiki-extract <source>` | Acquire a URL / local file / image into `raw/` with frontmatter. Does **not** touch `wiki/`. |
| `/wiki-ingest [<raw-file>]` | Process raw → wiki: 7-step pipeline (read, extract, write summary, update entity/concept pages, flag contradictions, update index, append log.md). Detects deltas via body hash. |
| `/wiki-query <question>` | Answer from wiki; if gaps, web-search and auto-promote answers as new/updated pages. Flag `--no-promote` to disable promotion. |
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

File names: `raw/<slug>.<ext>` for plain text (`.md`, `.txt`, `.html`, `.json`, etc.) — or `raw/<slug>.<ext>` plus sidecar `raw/<slug>.<ext>.md` for binaries (images, PDFs, DOCX, XLSX) and tabular text (CSV). The sidecar carries both the extracted markdown content and the frontmatter.

Every raw file starts with frontmatter:

```yaml
---
source_url: <url|n/a>
source_type: video-transcript | tweet | article | image | pdf | docx | xlsx | csv | chat | book-chapter | meeting-notes | ...
source_title: "..."
source_author: "..."
fetched_at: YYYY-MM-DD
ingested_hash: <sha256 of body at last successful ingest, or "">
ingested_at: YYYY-MM-DD HH:MM | never
ingested_pages: [<list of wiki/*.md files this raw touched on last ingest>]
extraction_method: <see below>            # set by /wiki-extract
extraction_status: <ok | degraded | failed>  # optional; omit when ok
notes: |
  Optional context about how this source was acquired or interpreted. If extraction was degraded or failed, name the missing tool + install hint here.
---
```

### Supported source formats and extraction

`/wiki-extract` handles these formats. Every shell dependency is **optional with a documented fallback** — the system never silently fails.

| Format | Primary handler | Fallback | `extraction_method` value |
|---|---|---|---|
| URL | `WebFetch` → markdown | — | `webfetch` |
| Plain text (`.md`, `.txt`, `.html`, `.json`, etc.) | Passthrough copy | — | `passthrough` |
| `.csv` | Copy + render markdown table preview in sidecar | — | `csv-passthrough` |
| Image (`.png`/`.jpg`/`.jpeg`/`.gif`/`.webp`) | LLM-vision (text + description) | — | `llm-vision` |
| `.pdf` | `pdftotext` | LLM-vision (read PDF) | `pdftotext` \| `llm-vision` |
| `.docx` | `pandoc -f docx -t markdown` | `python-docx` | `pandoc` \| `python-docx` |
| `.xlsx` | `xlsx2csv` → markdown table per sheet | `openpyxl` | `xlsx2csv` \| `openpyxl` |

If every handler for a binary format fails, the binary is still saved to `raw/` and the sidecar `<file>.<ext>.md` carries `extraction_status: failed` plus a one-line install hint. This preserves the BYO-AI guarantee — a user with zero shell tools installed still gets a functional repo, just with degraded extraction quality on formats whose only handler is a shell tool.

**Verification status:** the DOCX, XLSX, CSV, and PDF-LLM-vision handlers are **specified, not yet demonstrated**. First real `/wiki-extract` on each format is the smoke test. Same posture as the 7-step ingest pipeline (see [[operation-ingest]]).

`/wiki-ingest` computes the current body hash; if it differs from `ingested_hash`, the source is processed (or re-processed). Otherwise it's skipped.

**Canonical hashing.** The ONE allowed way to compute `ingested_hash` is `scripts/body-hash.sh <file>`. Do not reinvent the hashing logic inline (different awk patterns, different newline handling, different SHA tools → different hashes → broken idempotence). The script defines "body" as everything after the closing `---` of frontmatter, hashed with SHA-256.

**Environment check.** `scripts/preflight.sh` reports which extraction tools (`pdftotext`, `pandoc`, `xlsx2csv`, `python-docx`, `openpyxl`) are present and which `/wiki-extract` formats will run first-try vs fall back vs fail. Suggest running it if a user reports unexpected `extraction_status: failed` sidecars or asks why DOCX/XLSX produced empty content.

## log.md format

`log.md` is append-only, newest at top:

```markdown
## YYYY-MM-DD HH:MM — /wiki-ingest

- Processed: raw/<file> (hash <8-char-prefix>)
- Created: wiki/<file>, wiki/<file>
- Updated: wiki/<file>
- Contradictions flagged: none | <description>

## YYYY-MM-DD HH:MM — /wiki-query "..."

- Web-searched: <urls>
- Promoted: wiki/<file> (new)
- Updated: wiki/<file>
```

## What the LLM must NOT do

1. Edit anything in `raw/`. Read-only.
2. Use Obsidian-specific extensions (callouts `> [!note]`, dataview blocks, embedded queries, etc.). Pure CommonMark only.
3. Add backlinks blocks manually — let `/wiki-lint` compute them if requested.
4. Modify `AGENTS.md` without surfacing the change to the user (this is shared schema).
5. Delete wiki pages without leaving a log.md entry.
6. Add a wiki page without filling required frontmatter fields.

## Schema versioning

The number at the top of this file (`Schema version: 1`) increments when conventions in this document change in a way that could surprise an older client. The policy:

- **Bump for breaking or behavior-changing edits.** Examples: renaming a frontmatter field, changing what `/wiki-extract` writes, redefining a layer's ownership rules, restructuring `log.md`'s format.
- **Don't bump for typo fixes, clarifications, or additions that are strictly opt-in.** Adding an optional frontmatter field with a documented default is additive, not breaking.
- **Record the bump in `log.md`** with a rationale + a one-sentence migration note (what an older slash command might do wrong if it doesn't know about the change).
- **No runtime enforcement (V1).** Slash commands today don't check `schema_version` and don't refuse to run against an older schema. The version is a marker for humans reviewing diffs and for future tooling — not a guard.

If you fork the project, keep your own `schema_version` independent. Upstream changes that bump our version should be reviewed and merged on your own cadence.

## When in doubt

Pages that explain how this system works are in `wiki/`. Start at [`wiki/index.md`](wiki/index.md).
