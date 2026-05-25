---
title: The Five Slash Commands
type: analysis
source: analysis
updated: 2026-05-25
tags: [system, commands, spec]
---

# The Five Slash Commands

> **This page is `source: analysis`.** The video describes three core operations (ingest / query / lint). The five-command split below is this project's design decision, not a direct quote from the video. The mapping back to the video's operations is annotated.

## Definition / TL;DR

`llm-wiki-bootstrap` exposes five slash commands that together let any user operate an LLM-wiki from any agentic tool. Three implement the video's named operations ([[operation-ingest]], [[operation-query]], [[operation-lint]]); two ([[#wiki-init]], [[#wiki-extract]]) handle bootstrap and source acquisition.

## The five

| Command | Purpose | Maps to |
|---|---|---|
| `/wiki-init` | Scaffold an empty wiki structure in the current directory. | (bootstrap) |
| `/wiki-extract <source>` | Acquire a URL / file / image into `raw/` with frontmatter. | (acquisition; precedes [[operation-ingest]]) |
| `/wiki-ingest [<raw-file>]` | Process `raw/` → `wiki/` via the 7-step [[ingest-pipeline]]. | [[operation-ingest]] |
| `/wiki-query <question>` | Answer from wiki; web-search and auto-promote when gaps appear. | [[operation-query]] + [[query-as-write-loop]] |
| `/wiki-lint` | Maintenance pass: broken links, orphans, contradictions, gaps. | [[operation-lint]] |

Implementations live at `.claude/commands/wiki-*.md`.

## Why five (not three)

The video names three operations. We chose to add two more commands because:

- **Bootstrap is its own act.** Creating the directory layout and seeding `AGENTS.md` is a one-time setup that needs a single user-facing affordance. Folding it into `/wiki-ingest` would conflate two unrelated things.
- **Acquisition is its own act.** "Fetch a URL and deposit it in `raw/`" is a distinct user intent from "process raw into wiki." Separating them lets the user (a) review the raw before ingesting, (b) re-ingest after manually editing raw, (c) batch ingestion across many fetches.

We considered a sixth — `/wiki-promote` (manually promote a query answer to a page). Cut. Promotion is a default behavior of `/wiki-query`; a separate command would be used too rarely to justify a slot in the budget of five.

## Design constraints we honored

- **Prefix `wiki-`** to avoid colliding with other slash command namespaces in the user's tool.
- **Idempotent where possible:** `/wiki-init` won't overwrite; `/wiki-ingest` skips unchanged raws via hash.
- **Reports before applies:** `/wiki-lint` proposes by default, applies with `--apply`. `/wiki-query` auto-promotes by default, suppresses with `--no-promote`.
- **No viewer dependency:** none of the commands assume Obsidian or any specific renderer. See [[implicit-constraints]].

## Command-by-command spec

### /wiki-init

**Purpose.** Create the project skeleton in the current working directory.

**Behavior.**
1. Create `raw/`, `wiki/`, `.claude/commands/` if missing.
2. Create `AGENTS.md`, `wiki/index.md`, `log.md`, `README.md` if missing — use the project's canonical templates.
3. **Never overwrite** existing files. If a file already exists, leave it; report which were skipped.

**When used.** When the user copied just `.claude/commands/` into an existing project and wants the wiki structure scaffolded. **Not used** when the user cloned this whole repo — the structure is already there.

### /wiki-extract <source>

**Purpose.** Acquire content into `raw/` without touching `wiki/`. Parses binary formats to markdown when a handler exists.

**Behavior** (per format, using a graceful tool chain — best handler first, fallback when missing, `extraction_status: failed` sidecar only as last resort):

- **URL:** `WebFetch` → markdown → `raw/<slug>.md`. → `extraction_method: webfetch`.
- **Plain text** (`.md`/`.txt`/`.html`/`.json`/`.yaml`/source code): passthrough copy. → `passthrough`.
- **CSV:** copy + render markdown table preview (≤100 rows full, larger truncated) in sidecar. → `csv-passthrough`.
- **Image** (`.png`/`.jpg`/`.jpeg`/`.gif`/`.webp`): copy + LLM-vision extraction of text and description into sidecar. → `llm-vision`.
- **PDF:** `pdftotext` → text in sidecar; LLM-vision fallback when `pdftotext` is missing or returns near-empty. → `pdftotext` \| `llm-vision`.
- **DOCX:** `pandoc -f docx -t markdown` → text in sidecar; `python-docx` fallback if Python is available. → `pandoc` \| `python-docx`.
- **XLSX:** `xlsx2csv` → markdown table per sheet in sidecar; `openpyxl` fallback. → `xlsx2csv` \| `openpyxl`.

Slug is derived from the source: domain + title for URLs, filename for files.

Two optional frontmatter fields document the run: `extraction_method` (which handler succeeded) and `extraction_status` (`ok` is omitted; `degraded` or `failed` is set with a one-line note in `notes:`).

**Tool policy.** Every shell binary (`pdftotext`, `pandoc`, `xlsx2csv`, `python3`) is **optional with a documented fallback**. A user with none of them installed still gets a functional repo — only the formats whose only handler is the shell tool degrade. See `AGENTS.md` "Supported source formats and extraction" for the matrix.

**Never modifies** `wiki/`. Run `/wiki-ingest` next to integrate.

### /wiki-ingest [<raw-file>]

**Purpose.** Process raw → wiki per [[ingest-pipeline]].

**Behavior.**
- No argument: walk all files in `raw/`. For each, compute body hash; skip if it matches `ingested_hash` in frontmatter.
- With argument: process just that file.
- For each file processed, run the 7 steps from [[ingest-pipeline]].
- After success: update the raw's frontmatter (`ingested_hash`, `ingested_at`, `ingested_pages`).
- Append a `log.md` entry summarizing what changed.

### /wiki-query <question>

**Purpose.** Answer the user's question. Compound the wiki when the answer required new knowledge.

**Behavior.**
1. Read `wiki/index.md` to locate relevant pages.
2. Read those pages (frontmatter + body).
3. Synthesize an answer.
4. If the wiki is insufficient: WebSearch + WebFetch; weave in.
5. Decide notability of the new knowledge: introduces a new term? makes a new connection? cites a new external source? If yes, **promote**: create/update wiki pages with `source: external` (web-search-derived) or `source: mixed`.
6. Append to `log.md` if anything was promoted.

Flag `--no-promote` skips step 5.

### /wiki-lint

**Purpose.** Health-check the wiki.

**Behavior.** Scan `wiki/` and report:
- Broken `[[wiki-links]]` (link targets that don't exist)
- Orphans (pages with no inbound links)
- Contradictions (claims in different pages that disagree — flagged for the user, not auto-resolved)
- Stale claims (frontmatter `updated` older than threshold AND claims that look time-sensitive)
- Unresolved "Open questions on this page" blocks
- Gaps where a web search would obviously help
- Schema drift (pages missing required frontmatter fields, links not in `[[kebab-case]]` form, etc.)

Without `--apply`: print the report only.
With `--apply`: write proposed fixes (create stub pages for broken links, delete orphans the user confirms, etc.).

## Related

- [[operation-ingest]], [[operation-query]], [[operation-lint]] — the video-named operations these commands implement
- [[ingest-pipeline]] — what `/wiki-ingest` runs internally
- [[query-as-write-loop]] — the mechanism inside `/wiki-query`
- [[layer-schema]] — `AGENTS.md` references this command set
- [[implicit-constraints]] — the design constraints these commands honor

## Open questions on this page

- Should there be a `/wiki-export` (e.g., bundle the wiki into a static site, a single PDF, a presentation)? Defer to V2.
- Should commands accept stdin / chained input (e.g., `/wiki-extract <url> | /wiki-ingest`)? Probably not — slash commands are not Unix pipes.
- Versioning the schema: if `AGENTS.md` changes, do existing commands still work? Need a compatibility note.
