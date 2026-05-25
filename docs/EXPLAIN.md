# EXPLAIN — `llm-wiki-bootstrap` for a dev who just cloned it

For developers. If you've used `git`, `make` / `npm run build`, and `eslint`, every novel concept here maps onto something you already do. This file is the missing 5-minute "what *is* this and why is it shaped this way" — `README.md` tells you what it does, [`QUICKSTART.md`](QUICKSTART.md) tells you which commands to type in which tool, and [`../AGENTS.md`](../AGENTS.md) is the spec. None of those tell you the mental model. This does.

---

## The 30-second version

It's a build system. Source files are PDFs, transcripts, articles, screenshots — anything you'd otherwise lose track of. The build output is an interlinked Markdown wiki the LLM writes and maintains. You curate sources and ask questions. The LLM does the bookkeeping (summaries, cross-links, contradiction-flagging, indexing). Five commands, three folders, no app to install, no embeddings, no vector DB. The pattern is Andrej Karpathy's; this repo is the smallest tool-agnostic implementation of it.

---

## Why you'd want this (dev pains it answers)

- You re-ask ChatGPT the same questions because the chat has no memory of the last time you researched it.
- Your notes are spread across Notion, Obsidian, ten browser tabs, and `~/Downloads/`. None of them talk to each other.
- You tried RAG. It demoed great. On your own corpus it returned irrelevant chunks and you stopped trusting it. (See [`wiki/problem-with-naive-rag.md`](../wiki/problem-with-naive-rag.md).)
- You want the synthesis ("how do all these articles disagree about X?") that no search box or vector store does for you.

The pattern's bet: stop trying to *retrieve* knowledge at query time. **Write the synthesis to disk, once, when each source comes in.** Then queries are just `cat` + LLM-over-context, not a similarity hunt.

---

## The central analogy: this is `make` for your understanding

Read the table left-to-right. If you've ever maintained a `Makefile` or a `package.json`, the shape is familiar.

| In this repo | Dev analog | What it is |
|---|---|---|
| `raw/` | `src/` | The inputs. Immutable after fetch. You curate. |
| `wiki/` | `dist/` | The build output. LLM-only. You never hand-edit. |
| `AGENTS.md` | `Makefile` / `package.json scripts` | The declarative recipe — tells the agent how to build. |
| `/wiki-ingest` | `npm run build` | Runs the 7-step pipeline raw → wiki. Hash-gated. |
| `scripts/body-hash.sh` | webpack content hash | The build-cache key. "If I've built this exact bytes before, skip." |
| `/wiki-lint` | `eslint --fix` | Catches broken links, orphans, contradictions, stale claims. |
| `/wiki-ask "..."` | `grep` + Stack Overflow + auto-PR | Reads the wiki. On a gap, web-searches and *promotes* the answer as a new page. |
| `log.md` | `CHANGELOG` | Append-only record of every ingest / promote / lint. |

The build-cache key is the single most important mechanical idea. Here's the entirety of how it's computed — note that it's deliberately one short shell script, not inline logic spread across the slash commands:

```bash
# $ sed -n '31,33p' scripts/body-hash.sh
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$file" \
  | openssl dgst -sha256 \
  | awk '{print $NF}'
```

"Body" = everything after the closing `---` of the YAML frontmatter. Frontmatter itself is excluded because the LLM writes back `ingested_hash`, `ingested_at`, `ingested_pages` into the frontmatter after a successful ingest — and you obviously don't want the hash to depend on fields the hash itself sets. Same trick a content-addressable build cache uses to avoid the chicken-and-egg.

---

## The three layers, mapped

| Layer | Path | Analog | Mutability |
|---|---|---|---|
| **Raw sources** | `raw/` | `src/` — your inputs | Immutable after fetch; user-curated |
| **Wiki** | `wiki/` | `dist/` — derived | LLM-only; rewritten freely |
| **Schema** | `AGENTS.md`, `log.md` | `Makefile` + `CHANGELOG` | Co-evolved, human-readable |

The hard boundary: **the LLM is forbidden from editing anything in `raw/` except three frontmatter fields (`ingested_hash`, `ingested_at`, `ingested_pages`) as the last step of `/wiki-ingest`.** That's not stylistic — it's structural. If the LLM could rewrite raw content, the hash key would shift under its own feet and idempotence would break. Same reason `make` doesn't let recipes rewrite `src/` mid-build.

Conversely, the user is forbidden from hand-editing `wiki/`. If you want to change a claim, edit the raw source (or file the new claim via `/wiki-ask`) and re-run `/wiki-ingest`. Hand-editing `wiki/` is like hand-editing `dist/` after a webpack build — the next rebuild will eat your changes, and you'll never know exactly which file the build *would* have produced.

For the full layer treatment see [`wiki/three-layer-architecture.md`](../wiki/three-layer-architecture.md). For who-edits-what see [`wiki/division-of-labor.md`](../wiki/division-of-labor.md).

---

## The five commands, mapped to git verbs

| Command | Closest analog | What it does |
|---|---|---|
| `/wiki-init` | `git init` | Scaffold `raw/`, `wiki/`, `AGENTS.md`, `log.md`. Idempotent. |
| `/wiki-fetch <src>` | `git add` (sort of) | Pull a URL / local file / image into `raw/` with frontmatter. Does **not** touch `wiki/`. |
| `/wiki-ingest [<raw-file>]` | `npm run build` | The 7-step pipeline raw → wiki. Hash-gated; idempotent on unchanged sources. |
| `/wiki-ask "..."` | `grep` + Stack Overflow + auto-PR | Answer from the wiki. On gap → web-search → promote a new page. `--no-promote` to suppress. |
| `/wiki-lint [--apply]` | `eslint --fix` | Find broken links, orphans, contradictions, stale claims. Reports by default; `--apply` writes fixes. |

Two of these surprise devs every time:

**`/wiki-ask` is not search.** It's "read the wiki, synthesize an answer, and if there's a knowledge gap, go fetch + write a new wiki page so the gap is gone next time." The auto-promote step is what makes the wiki *compound* (see [`wiki/knowledge-compounds.md`](../wiki/knowledge-compounds.md)). It's the opposite of how a chat session works: every question leaves the knowledge base stronger instead of throwing the work away when the tab closes.

**A "command" is a Markdown prompt, not executable code.** Open one and you'll see this:

```markdown
# $ sed -n '7,15p' .claude/commands/wiki-ingest.md
You are executing `/wiki-ingest $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to integrate raw sources into the wiki using the 7-step pipeline.

## Read first

Read `AGENTS.md` (conventions), `wiki/index.md` (what already exists), and `log.md` (recent activity).

## Determine scope

- If `$ARGUMENTS` is empty: walk all files in `raw/`. For each, compute the current body hash by running **`scripts/body-hash.sh <file>`** (this is the canonical algorithm — do NOT recompute the hash inline with `sha256sum`, `shasum`, or a different awk pattern, or idempotence will break). Skip files whose `ingested_hash` in frontmatter matches the current hash.
```

The "executable" is the agent. The "program" is the prompt body. The slash-command files in `.claude/commands/` are workflow definitions, the shim files in the repo root (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.clinerules`, `.cursor/rules/`, `.github/copilot-instructions.md`) point any agentic tool at those definitions. In tools that don't support real slash commands (Copilot CLI, Cursor, Cline), you invoke a workflow by saying *"run the wiki-ingest workflow per `.claude/commands/wiki-ingest.md`"* and the agent follows the file. Same workflow, different invocation surface.

---

## The plot twist: there's almost no code

```text
# $ find . -type f ! -path '*/.git/*' | wc -l
      45
# $ find . -type f ! -path '*/.git/*' | awk -F. '{print $NF}' | sort | uniq -c | sort -rn
  38 md
   1 sh
   1 png
   1 mdc
   1 html
   1 gitignore
   1 clinerules
   1 /LICENSE
```

That's the whole repo. 38 Markdown files (this `EXPLAIN.md` included). One shell script (the hash). One PNG (a screenshot of one slide). One HTML page (the pitch). One `LICENSE` (extensionless — that's the `/LICENSE` row, an awk quirk). The rest is config + shims. The `dist/`-equivalent (the example `wiki/`) is 25 of those Markdown files; everything else is schema, commands, and shims.

Reframe your model:

- **The prompts are the program.** `.claude/commands/wiki-*.md` are the verbs.
- **The AI tool is the runtime.** Claude Code, Cursor agent mode, Cline, Copilot CLI — interchangeable runtimes for the same program.
- **The Markdown files are the database.** No Postgres, no SQLite, no vector store. `grep` is your query planner. `git` is your write-ahead log.

That's why the [four principles](../wiki/four-principles.md) — explicit, yours, file-over-app, BYO AI — aren't aspirational marketing copy. They're forced by the implementation choices above.

---

## What happens when you run `/wiki-ingest`

You drop a transcript into `raw/`. You run one command. 30–90 seconds later you have 5–10 new wiki pages plus updates to existing pages. The 7 steps that happen, lifted verbatim from [`wiki/ingest-pipeline.md`](../wiki/ingest-pipeline.md):

```text
# $ sed -n '19,27p' wiki/ingest-pipeline.md
| # | Step | What it does |
|---|---|---|
| 1 | **Read the raw source** | LLM reads the file in `raw/`. For images / PDFs, reads the sidecar `.md` produced by `/wiki-fetch`. |
| 2 | **Extract key information** | Pulls out concepts, entities, claims, data points. `(source: raw/karpathy-llm-wiki-video-transcript.md#4:55-5:00)` |
| 3 | **Write a summary page** | New `wiki/<source-slug>-summary.md` (or similar) with the source's main takeaways, metadata, tags. `(source: raw/karpathy-llm-wiki-video-transcript.md#5:00-5:04)` |
| 4 | **Update existing entity / concept pages** | Integrate the new information into pages that already exist. A new claim about Concept X gets added to `wiki/x.md`. `(source: raw/karpathy-llm-wiki-video-transcript.md#5:04-5:11)` |
| 5 | **Flag contradictions** | If a new claim conflicts with an existing one, the LLM marks it visibly. *"When new data conflicts with existing claims."* `(source: raw/karpathy-llm-wiki-video-transcript.md#5:11-5:18)` |
| 6 | **Update the index** | `wiki/index.md` — the master catalog — gets a new entry for each created page. Per the source slide, each entry is "a catalog entry with link and **one-line summary**." `(source: raw/karpathy-llm-wiki-video-transcript.md#5:18-5:23)` `(source: raw/karpathy-video-slide-ingest-pipeline.png.md#step-06)` |
| 7 | **Append to the log** | A timestamped record in `log.md`: what raw was processed, which pages created/updated, which contradictions flagged. The file name `log.md` is mandated by the source slide (the transcript only says "the log" generically). `(source: raw/karpathy-llm-wiki-video-transcript.md#5:23-5:30)` `(source: raw/karpathy-video-slide-ingest-pipeline.png.md#step-07)` |
```

The payoff property is step 4: **one source touches 10–15 wiki pages, not one.** A new article about Concept X gets cross-linked into every existing page that talks about X-adjacent things. After enough sources, the wiki has more edges than nodes — that's the [compounding](../wiki/knowledge-compounds.md) the pattern is named after.

### Honest caveat about this pipeline

The 7 steps are **specified, not yet demonstrated**. `/wiki-ingest` has never been invoked end-to-end in this repo; the shipped example wiki was hand-built during the design conversation. The full verification gap is documented at [`wiki/operation-ingest.md#verification-status`](../wiki/operation-ingest.md). Your first real `/wiki-ingest` on a fresh source is the smoke test. If the LLM skips steps (most common failure mode: skipping step 5's contradiction-flagging, or step 3's summary page), [`QUICKSTART.md`](QUICKSTART.md) lists exact re-prompts to recover.

---

## The four principles, with a "you'd lose this if…" for each

From [`wiki/four-principles.md`](../wiki/four-principles.md):

1. **Explicit.** Every claim sits in a Markdown file you can `cat`. You'd lose this the moment you put any of it in a vector store you can't read.
2. **Yours.** Files on your disk. Portable across tools and providers. You'd lose this if the wiki lived in a SaaS service or behind a hosted API.
3. **File-over-app.** Pure CommonMark, no Obsidian / Notion / Roam-specific syntax. You'd lose this the moment you used a `> [!note]` callout, a Dataview block, or any other viewer-dependent feature. This repo enforces it — see [`wiki/implicit-constraints.md`](../wiki/implicit-constraints.md).
4. **BYO AI.** Any LLM that can read/write files works. You'd lose this if the workflows depended on a vendor-specific tool feature (e.g., a Claude-only thinking block in a wiki page).

These four aren't a marketing list. They're survivability properties. The wiki is meant to outlast the LLM provider, the agentic tool, the markdown viewer, and the user's current workflow.

---

## Where to start reading the actual repo

Three files, in order. ~10 minutes total.

1. [`README.md`](../README.md) — what it is + how to install (2 min)
2. [`docs/QUICKSTART.md`](QUICKSTART.md) — your first useful run in your AI tool (5 min)
3. [`wiki/index.md`](../wiki/index.md) — the worked example. Read it like docs. Notice that the docs *are* the demo: a wiki about the LLM-wiki pattern, built by the pattern.

[`AGENTS.md`](../AGENTS.md) is the spec the *agent* reads on session start. You don't need to read it cover-to-cover until you want to change behavior — the `README` + `QUICKSTART` + `wiki/index.md` path covers usage.

The `[[kebab-case]]` link syntax you'll see throughout `wiki/` is resolved by string-match, not by any viewer. `[[foo-bar]]` means "the file `wiki/foo-bar.md`." `/wiki-lint` flags any `[[link]]` with no matching file.

---

## Honest caveat (repeat, on purpose)

**None of the slash commands have been runtime-tested in this repo.** The example wiki was built by direct file writes, not by `/wiki-ingest`. The first time *you* run a slash command on a real source is the system's first integration test. Expect to refine the prompt files in `.claude/commands/wiki-*.md` after that first invocation. File issues / PRs accordingly. The verification gap is the top entry in [`wiki/open-questions.md`](../wiki/open-questions.md).
