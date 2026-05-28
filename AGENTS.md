# AGENTS.md — `llm-wiki-bootstrap` schema

**Schema version:** 2 — bumped 2026-05-26 (was: 1 introduced 2026-05-25). v2 adds the `wiki/journal/` user-owned exception (and the `type: journal` enum value), the `## Flashcards` content convention, and the optional MCP read surface. Changes to this number signal that slash commands, frontmatter conventions, or layer rules have shifted in a way older clients may need to adapt for. See "Schema versioning" near the bottom for the bump policy.

This file is the **schema** layer of the LLM-wiki pattern (see [`wiki/layer-schema.md`](wiki/layer-schema.md)). It tells any AI agent operating on this directory how the wiki is structured and how to work with it.

## What this project is

A personal LLM-wiki knowledge base, operated **exclusively via slash commands** in any agentic tool (Claude Code first; others follow). The wiki layer is **owned by the LLM** — the user curates raw sources and asks questions; the LLM does all writing, cross-referencing, and maintenance.

The wiki currently shipped is *meta*: a wiki **about** the LLM-wiki pattern itself, derived from `raw/karpathy-llm-wiki-video-transcript.md`. It serves as both the system's reference documentation and as a worked example of the pattern. Users may extend it, replace it, or wipe it (`./scripts/wipe-meta-wiki.sh`) to start their own.

## Three-layer model

| Layer | Path | Owned by | Mutability |
|---|---|---|---|
| **Raw sources** | `raw/` | User (via `/wiki-extract` or manual drop) | Immutable after fetch (user may edit; ingest detects via hash) |
| **Wiki** | `wiki/` | **LLM only** | Mutable, rewritten freely by `/wiki-ingest`, `/wiki-query` (promote), `/wiki-lint` |
| **Schema** | `AGENTS.md` (this file), `log.md` | User + LLM (co-evolved) | User-readable; LLM may propose edits via `/wiki-lint` |

**Critical:** The LLM must never edit files in `raw/` (it may only read them). The user must never edit files in `wiki/` directly — instead, edit raw sources or use `/wiki-query` to file the new claim, then re-run `/wiki-ingest` or `/wiki-lint`.

### Exception: `wiki/journal/`

Files under `wiki/journal/` are **user-owned**, not LLM-owned. They hold time-stamped observations (a trade log, a research log, daily lessons, incident notes — any domain where practice should feed back into theory). Convention:

- Path: `wiki/journal/<YYYY-MM-DD>-<slug>.md` — one entry per file.
- Template: [`templates/journal-entry.md`](templates/journal-entry.md). `type: journal`, free-form body.
- Cross-references: entries use `[[wiki-link]]` to anchor observations to concept pages. `/wiki-lint` will flag broken links here just like anywhere else in `wiki/`.
- `/wiki-ingest` **must not rewrite** files under `wiki/journal/`. They are inputs to thinking, not outputs of it. If the LLM wants to cite a journal entry, it may read it and reference it from a concept page — but the entry stays as the user wrote it.
- `/wiki-query` may surface journal entries as evidence when answering a question, with the same `[[link]]` citation convention.

This is the only exception to "LLM owns wiki/". The optional `wiki/journal/` directory is reserved by a `.gitkeep` on fresh clones.

## The five slash commands

Each command has a prefixed name (`/wiki-extract`) and a short alias (`/extract`). Both resolve to the same procedure — the short forms are aliases that delegate to the canonical `.claude/commands/wiki-*.md` files. Use whichever you prefer.

| Prefixed | Short | Purpose |
|---|---|---|
| `/wiki-init` | `/init` | Scaffold an empty wiki structure (raw/, wiki/, AGENTS.md, README.md, log.md) in the current directory. Idempotent. |
| `/wiki-extract <sources>` | `/extract` | Acquire **one or many** URLs / local files / images into `raw/` with frontmatter. Bulk mode: multiple space- or newline-separated sources are extracted in a single pass with a consolidated summary. Does **not** touch `wiki/`. |
| `/wiki-ingest [<raw-file>]` | `/ingest` | Process raw → wiki: 7-step pipeline (read, extract, write summary, update entity/concept pages, flag contradictions, update index, append log.md). Detects deltas via body hash. |
| `/wiki-query <question>` | `/query` | Answer from wiki; if gaps, web-search and auto-promote answers as new/updated pages. Flag `--no-promote` to disable promotion. |
| `/wiki-lint` | `/lint` | Maintenance pass: broken links, orphans, contradictions, stale claims, unresolved open-questions, gaps. Reports + proposes edits; `--apply` to write them. |

Full spec lives at [`wiki/commands.md`](wiki/commands.md). Canonical implementations at `.claude/commands/wiki-*.md`; the short-form aliases at `.claude/commands/{init,extract,ingest,query,lint}.md` are thin delegators.

Two further **output commands** (`/wiki-visualize`, `/wiki-flashcards`) sit alongside the five — they render or export an already-built wiki rather than participating in the acquire→maintain loop. See below.

### Output commands

These operate on an **already-built** wiki: they are not lifecycle steps. Both are **read-only on `raw/` and `wiki/`** — they only write new output artifacts (`*.html`, `*.png`, `anki.csv`), never edit wiki pages, so the three-layer ownership model is untouched. Same prefixed/short-alias convention as the five.

| Prefixed | Short | Purpose |
|---|---|---|
| `/wiki-visualize [graph\|mermaid\|slides\|serve] [target] [--out <path>]` | `/visualize` | Render the wiki as an interactive D3 graph (default), MARP slides, or mermaid images, or serve it locally. Thin dispatcher over `scripts/visualize/*` — checks `python3`/`npx` presence and surfaces install hints. |
| `/wiki-flashcards [dir] [--out <path>]` | `/flashcards` | Export every `## Flashcards` section to an Anki-importable CSV (`Front,Back,Tags`; tag = page slug). Wraps `scripts/wiki-to-anki.sh`. |
| `/wiki-diagram "<intent>"` | `/diagram` | Synthesize an audience-targeted diagram from a natural-language intent: retrieve relevant pages, score the 8 archetypes, present a candidate menu, generate a self-contained HTML poster per pick. Wiki-read-only; output to `diagrams/`. Contracts vendored in `templates/infographic/`. |

**`/wiki-visualize` vs `/wiki-diagram`:** visualize is **mechanical** — it renders structure that already exists (the `[[link]]` graph, mermaid, slides). diagram is **semantic** — it composes a *new* audience-targeted poster by reasoning over a query. Use visualize to *see the wiki*; use diagram to *make a point from it*.

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
- `type` — `concept` (idea/term), `entity` (named thing/person/tool), `summary` (per-source recap), `analysis` (interpretation, not in raw), `navigation` (index/TOC pages), `journal` (user-owned time-stamped entry, lives only under `wiki/journal/`).
- `source` — `video` (literal from a raw video transcript), `analysis` (LLM/user interpretation; must be honest about being interpretive), `external` (added from web search), `mixed` (both video and analysis).
- `updated` — ISO date of last edit.
- `tags` — array of kebab-case tags.

### Link convention

`[[kebab-case-page-name]]` resolves to `wiki/kebab-case-page-name.md`. Textual only — **no rendering dependency** (no Obsidian, no Dataview). The LLM resolves links by string match.

`/wiki-lint` flags any `[[link]]` with no matching file.

### Typed relations

Inside a `## Related` section, a link can carry an optional **verb** (and one optional **attribute** token) immediately after the closing `]]`:

```
## Related
- [[embrapa]] founded-by-government-in 1973 — Brazilian R&D agency
- [[cerrado]] located-in — central biome where soy frontier moved
- [[plano-real]] enabled-by 1994 — stabilization plan that withdrew subsidies
```

Parse rule (single regex, no AST):

```
- [[<target>]] <verb> [<attr>] — <prose>
```

- `<verb>` matches `[a-z][a-z0-9-]*` (lowercase kebab-case, like page slugs).
- `<attr>` is optional: one whitespace-delimited token, free-form (year, percentage, etc.).
- `<prose>` is everything after the em-dash (`—`) or double-hyphen (`--`).

**Backward-compat (no migration required):**

- A line without a verb token (the existing form `- [[other-page]] — why it relates`) is treated as implicit `related-to`. Lint passes.
- A line containing more than one `[[…]]` token (e.g. `- [[a]], [[b]], [[c]] — …`) is always treated as implicit `related-to` for every link, regardless of what follows. Verbs only apply to single-target lines.

**Vocabulary**: open. There is no controlled list. `/wiki-lint` only validates the regex shape — semantics (does the verb make sense?) is the wiki author's call. Visualization (`scripts/visualize/graph.sh`) groups edges by verb for filtering.

**Where typed lines live**: only inside `## Related`. Verbs in body prose, `## Open questions`, `## Flashcards`, or `index.md` are ignored by the lint and the graph.

### Source attribution

Any claim that came from a raw source must include `(source: <raw-file>#<anchor>)` inline. Example: `(source: raw/karpathy-llm-wiki-video-transcript.md#3:50)`. The anchor can be a timestamp, heading, or line range.

Pages with `source: analysis` must say so visibly in the body (e.g., "This page is interpretation, not extracted from the video.").

### Optional `## Flashcards` section

Any wiki page may include a `## Flashcards` section to declare spaced-repetition cards drawn from that page's content. Format:

```markdown
## Flashcards

- Q: <question>
  A: <answer>
- Q: <question>
  A: <answer text that wraps
     across indented continuation lines>
```

Rules:

- `Q:` starts a new card on a bullet line.
- `A:` lives on the next line, indented under the bullet.
- An answer may span multiple indented continuation lines (each starting with whitespace, not a `-`).
- A blank line is fine inside an answer's continuation chain *only as long as the next line is again indented* — the parser stops the continuation at the first non-indented or sub-bulleted line.
- Another `## ` heading ends the Flashcards section.

Export: `./scripts/wiki-to-anki.sh > anki.csv` scans every `.md` file under `wiki/` (or any directory you pass) and writes a CSV with columns `Front,Back,Tags`. The page slug becomes the single Anki tag, which lets you build subdecks per topic. Importing the CSV into Anki uses the default delimiter (comma).

This convention is **viewer-agnostic** — `## Flashcards` reads as a plain markdown list in any renderer; only the exporter script treats it specially.

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

**Optional MCP read surface.** A user may launch `./scripts/mcp-server.sh` to expose `wiki/` to any MCP-aware client (Claude Desktop, Cursor, ChatGPT Desktop, etc.) with BM25 search over the wiki. This is **read-by-convention**, additive, and does not change the three-layer model or the slash commands. Writes should still flow through `/wiki-ingest` / `/wiki-query` so `log.md` stays accurate. Setup: [`docs/MCP.md`](docs/MCP.md).

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
