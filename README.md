# llm-wiki-bootstrap

A starter kit for personal LLM-wiki knowledge bases. Five slash commands let you (or any user) build, ingest into, query, and maintain a wiki — operated entirely from an AI agentic tool, no UI required.

The pattern is Andrej Karpathy's: an LLM incrementally builds and maintains a persistent, interlinked markdown wiki sitting between you and your raw sources. You curate sources and ask questions; the LLM does all the writing, cross-referencing, and maintenance.

The wiki that ships with this repo is *meta*: it's a wiki about the LLM-wiki pattern itself. Read it via [`wiki/index.md`](wiki/index.md). Keep it as living documentation, or wipe it and start your own.

## Quick start

**Prerequisite:** an agentic AI tool. The reference path is [Claude Code](https://docs.anthropic.com/claude/code) (`claude` on your `$PATH`); other tools work too — see [Tool support](#tool-support).

```bash
git clone https://github.com/FrancyJGLisboa/llm-wiki-bootstrap my-wiki
cd my-wiki && claude          # open Claude Code in the repo
```

The repo ships with a working demo wiki, so the very first command already returns an answer — no setup:

```
/wiki-query "what is an llm-wiki, and why not just use RAG?"   # answered from the shipped wiki
```

Then start building your own knowledge base:

```
/wiki-extract https://example.com/some-article   # pull a source into raw/
/wiki-ingest                                       # integrate it into the wiki
/wiki-query "what does that article say about X?"  # ask — answers now include your source
```

That's the whole loop. **Make it yours:** keep adding sources alongside the demo, or [start from a clean slate](#starting-your-own-wiki-clean-slate).

## Install details

### Starting your own wiki (clean slate)

The clone above keeps the demo content (a meta-wiki about the LLM-wiki pattern — a handy worked example). To generate a clean skeleton with **no demo content** instead:

```bash
git clone https://github.com/FrancyJGLisboa/llm-wiki-bootstrap tmp
tmp/scripts/create-llm-wiki.sh ~/my-wiki   # fresh skeleton, no demo content
rm -rf tmp
cd ~/my-wiki
```

The installer is manifest-driven (`scripts/installer-skeleton-manifest.txt`) and verified by `scripts/verify-create-llm-wiki.sh`.

### Optional: confirm your full setup

Just trying it out? Skip this. When you want to confirm the whole pipeline works on your machine, run:

```bash
./scripts/preflight.sh    # hard reqs (bash/awk/openssl/git) + which extract formats work first-try
./scripts/smoke-all.sh    # full pipeline (extract → ingest → query) on a fictitious fixture; 10 binary checks
```

`preflight.sh` tells you in advance which `/wiki-extract` formats your environment supports first-try (PDF needs `pdftotext`; DOCX needs `pandoc`; XLSX needs `xlsx2csv` — each has a fallback, but knowing in advance avoids surprises).

`smoke-all.sh` drives `claude -p` on a small fixture, asks the wiki a question, and confirms the answer recalls the fact and cites the source. First run takes ~30–60s (LLM); subsequent runs sub-second (idempotent via body-hash). All 10 green = your install works end-to-end. Spec at [`.scratch/plug-and-play-curator-smoke/GOAL.md`](.scratch/plug-and-play-curator-smoke/GOAL.md).

**For the per-tool first-use sequence (which commands to type, in order, in each AI tool), see [`docs/QUICKSTART.md`](docs/QUICKSTART.md).** For the *mental model* — three layers, five commands, and the build-system analogy mapped to things you already know — see [`docs/EXPLAIN.md`](docs/EXPLAIN.md).

### Tool support

The project ships shim files for every major agentic tool. Whatever you use, the AI will load the schema automatically:

| Tool | Shim file (already in repo) | Invocation | Status |
|---|---|---|---|
| Claude Code (modern) | `AGENTS.md` (canonical) | `/wiki-init`, `/wiki-extract`, etc. — real slash commands | **e2e-verified** (driven by `scripts/smoke-all.sh`) |
| Claude Code (legacy) | `CLAUDE.md` | same as modern | e2e-verified |
| Cursor | `.cursor/rules/llm-wiki.mdc` | natural language: "run wiki-ingest" | Documented, not yet e2e-verified |
| Cline (VSCode) | `.clinerules` | natural language | Documented, not yet e2e-verified |
| GitHub Copilot | `.github/copilot-instructions.md` | natural language | Documented, not yet e2e-verified |
| Gemini CLI | `GEMINI.md` | natural language | Documented, not yet e2e-verified |
| OpenAI Codex | `AGENTS.md` (canonical — auto-loads) | natural language | Documented, not yet e2e-verified |

The shim files all point at `AGENTS.md` as the canonical schema and at `.claude/commands/wiki-*.md` as the workflow definitions. Tools without first-class slash commands (Cursor, Cline, Copilot, Gemini, Codex) invoke the workflows by natural language; the LLM follows the prompt body of the corresponding command file step-by-step.

**"Documented, not yet e2e-verified"** means: the shim file ships, the natural-language workflow is specified, and the pattern is expected to work — but the smoke harness only drives Claude Code, so these paths have not been observed end-to-end by the project. If you use one of these tools and something does not work, that is a reportable bug — please open an issue.

## The five slash commands

Every command has both a prefixed form (`/wiki-extract`) and a short alias (`/extract`). The short forms are the ones you'll actually type once you're inside a fresh installed repo; the prefixed form is there for global use where namespace collisions matter. Both resolve to the exact same procedure.

| Prefixed | Short | What it does |
|---|---|---|
| `/wiki-init` | `/init` | Scaffold the wiki structure (raw/, wiki/, AGENTS.md, README.md, log.md). Idempotent. Use only if you copied just `.claude/commands/` into an existing project — cloning this repo already gives you the structure. |
| `/wiki-extract <urls-or-files>` | `/extract` | Pull **one or many** URLs / local files (PDF, DOCX, XLSX, CSV, image, or plain text) into `raw/` with frontmatter. Bulk mode: pass multiple sources space- or newline-separated and they're all extracted in one pass with a consolidated OK/Degraded/Failed summary at the end. Parses binary content to markdown when a handler exists. Also accepts **pasted inline text** via `--text [--title "..."] <content>` (single source, never whitespace-split). Does **not** touch `wiki/`. |
| `/wiki-ingest [<raw-file>]` | `/ingest` | Process `raw/` → `wiki/` using the 7-step pipeline. Detects deltas via hash; idempotent on unchanged sources. |
| `/wiki-query <question>` | `/query` | Answer from the wiki; web-search and auto-promote new knowledge if there's a gap. `--no-promote` suppresses promotion. **`--visual [html\|pdf\|png]`** also emits a diagram of the answer, archetype auto-picked from the query (same design system as `/wiki-diagram`). |
| `/wiki-lint [--apply]` | `/lint` | Health-check: broken links, orphans, contradictions, stale claims, gaps. Reports by default; `--apply` writes proposed fixes. |

Full spec at [`wiki/commands.md`](wiki/commands.md).

### Output commands

Two more commands render or export an **already-built** wiki — they sit outside the acquire→maintain loop above and are read-only on `raw/` and `wiki/` (they only write new output files).

| Prefixed | Short | What it does |
|---|---|---|
| `/wiki-visualize [graph\|mermaid\|slides\|serve] [target]` | `/visualize` | Render the wiki as an interactive D3 graph (default), MARP slides, or mermaid images, or serve it locally. Thin wrapper over `scripts/visualize/*`; checks `python3`/`npx` and prints install hints. |
| `/wiki-flashcards [dir]` | `/flashcards` | Export every `## Flashcards` section to an Anki-importable CSV. Wraps `scripts/wiki-to-anki.sh`. |
| `/wiki-diagram "<intent>"` | `/diagram` | Synthesize an audience-targeted diagram from an intent — retrieve relevant pages, score the 8 archetypes, you pick, it generates a self-contained HTML poster. Output to `diagrams/`. |

`/wiki-visualize` is **mechanical** (renders the structure that already exists); `/wiki-diagram` is **semantic** (composes a new poster by reasoning over a query). See the diagram contracts in `templates/infographic/`.

**Optional: typed relations.** Inside `## Related`, you can attach a verb to a link — `- [[embrapa]] founded-by 1973 — Brazilian R&D agency`. Pure CommonMark; backward-compat with untyped lines. Verb regex: `[a-z][a-z0-9-]*`. Validate with `./scripts/wiki-lint-typed-relations.sh wiki/`; the graph viz colours and filters edges by verb. Full spec in [`AGENTS.md`](AGENTS.md) → "Typed relations". An empirical eval (`scripts/eval-multi-hop.sh`) measures whether typed verbs improve `/wiki-query` recall over the same wiki with verbs stripped — see [`.scratch/typed-wikilinks-semantic-viz/GOAL.md`](.scratch/typed-wikilinks-semantic-viz/GOAL.md) for the methodology and current null-result on a Wikipedia-derived fixture.

## Multi-wiki factory

This repo doesn't just *become* one wiki — it can **generate many**, each shaped for its own domain and tracked in a local catalog. Two factory commands (they live here, in the factory; they are not shipped inside the wikis they create):

| Prefixed | Short | What it does |
|---|---|---|
| `/wiki-new <name> --domain "<description>"` | `/new` | Generate a new wiki pre-shaped for `<description>`. Scaffolds a fresh skeleton, then authors a domain layer: a `## Domain conventions` section in the new wiki's `AGENTS.md`, a navigation `index.md`, and 3–5 honest seed pages. Registers it in the workspace catalog. |
| `/wiki-registry [prune]` | `/wikis` | List every wiki you've generated — name, domain, seeded status, and drift (a registered dir that's gone, or a stray dir not in the catalog). `prune --apply` removes dangling entries. |

```
/wiki-new "vineyard-ops" --domain "vineyard operations management"
# → ~/llm-wikis/vineyard-ops/  (own git repo, domain-shaped, seeded)
# → registered in ~/llm-wikis/registry.jsonl

/wiki-registry            # see the whole catalog
```

**Where wikis go.** By default each new wiki lands under a **workspace** (`${LLM_WIKI_WORKSPACE:-~/llm-wikis}`) as its own git repo, with a `registry.jsonl` catalog at the workspace root. Want it elsewhere? `--target <path>` creates an independent repo anywhere and still registers it (by absolute path). The deterministic half is plain shell — `scripts/new-wiki.sh` (which reuses the proven `scripts/create-llm-wiki.sh`) and `scripts/registry.sh` — so you can script wiki creation without an AI tool; only the seed-page authoring needs the LLM.

**No pre-baked domains.** The factory ships zero hand-authored domain content. You describe the domain in one line (`--domain "..."`) and the seed pages are generated for *that* description. Seed pages are always `source: analysis` (interpretation, no raw source yet) and disclose it — enforced by `scripts/verify-multi-wiki.sh`.

> Not yet built (phase 2): freezing a built wiki into a reusable static template (`snapshot`), and a *remote/published* registry others can browse. Today's registry is local.

## Visualize your wiki

From inside your AI tool, just run `/wiki-visualize` (alias `/visualize`) — it dispatches to the right backend and checks the required tool is installed. Or call the scripts directly:

```bash
./scripts/visualize/graph.sh wiki/ > graph.html   # interactive D3 force graph (no install)
./scripts/visualize/serve.sh                     # browse the wiki + graph locally
```

Five opt-in wrappers under `scripts/visualize/`: a Python+D3 graph generator (zero dependencies), plus `slides.sh`, `mermaid.sh`, `serve.sh` (MARP / mermaid-CLI / local HTTP), and `render.sh` (HTML poster → PDF/PNG, used by `/wiki-query --visual` and `/wiki-diagram --pdf/--png`; graceful fallback to HTML when no browser/Node). All open source; no Obsidian required. Heavier alternatives (Quartz, mdBook, SilverBullet) covered in [`docs/VISUALIZATION.md`](docs/VISUALIZATION.md).

## MCP access (optional)

Expose this wiki over the Model Context Protocol so any MCP-aware AI client — Claude Desktop, Claude Code, Cursor, ChatGPT Desktop, etc. — can read it (and optionally write to it) without slash-command indirection. Uses [`@bitbonsai/mcpvault`](https://github.com/bitbonsai/mcpvault), which works on any markdown directory with no Obsidian dependency. BM25 search built in.

```bash
./scripts/mcp-server.sh        # foreground stdio server pointed at wiki/
```

For client config snippets (Claude Desktop, Claude Code, Cursor) and the recommended read-only posture, see [`docs/MCP.md`](docs/MCP.md).

## Flashcards (optional)

Any wiki page may declare a `## Flashcards` section with `Q: …` / `A: …` bullet pairs. Export to an Anki-importable CSV with `/wiki-flashcards` (alias `/flashcards`) from inside your AI tool, or run the script directly:

```bash
./scripts/wiki-to-anki.sh > anki.csv
```

The page slug becomes the Anki tag for that card. See the convention notes in [`AGENTS.md`](AGENTS.md).

## A typical session

```
# add a source
/wiki-extract https://example.com/some-article

# integrate it
/wiki-ingest

# commit before the next ingest — git is your rollback (no atomic writes inside the pipeline)
git add wiki/ log.md raw/
git commit -m "ingest: <source title>"

# ask the wiki something
/wiki-query "what does this article say about X?"

# periodically tidy up
/wiki-lint
```

Commit-per-ingest is the recommended discipline: `/wiki-ingest` touches many files (a summary page, several concept pages, the index, `log.md`, raw-file frontmatter) and is not atomic. If a future ingest goes sideways, `git checkout -- wiki/ log.md raw/<file>` is your only clean recovery path. Skip the commit and the rollback also rolls back the good ingest before it.

## Make it yours

The shipped wiki content is illustrative — it's a wiki *about* the LLM-wiki pattern, derived from the YouTube transcript in `raw/karpathy-llm-wiki-video-transcript.md`. To start your own:

1. **Keep it as reference and add alongside:** drop your own sources into `raw/`, run `/wiki-ingest`. Your pages live next to the meta-wiki content.
2. **Replace it:** `./scripts/wipe-meta-wiki.sh` (prompts for confirmation; `--yes` to skip). Wipes `wiki/*.md` and `raw/*`, resets `wiki/index.md` and `log.md` to minimal stubs.

The `AGENTS.md` schema is project-agnostic — it works the same whether the wiki is about LLM-wikis, trading, M&A, your team's roadmap, or anything else.

## Project layout

<details>
<summary>Full repository tree (click to expand)</summary>

```
.
├── AGENTS.md                       # canonical schema (read by AI tools) — schema v2
├── CLAUDE.md                       # shim → points to AGENTS.md
├── GEMINI.md                       # shim → points to AGENTS.md
├── README.md                       # this file (dev-side)
├── README-FRESH.md                 # template used by the installer for fresh skeletons
├── log.md                          # append-only log of ingests, schema bumps, infra changes
├── .claude/
│   └── commands/                   # Claude Code slash commands (canonical + aliases)
│       ├── wiki-init.md
│       ├── wiki-extract.md
│       ├── wiki-ingest.md
│       ├── wiki-query.md
│       ├── wiki-lint.md
│       ├── wiki-new.md             # factory: generate a new domain-shaped wiki (+ alias new.md)
│       └── wiki-registry.md        # factory: list/prune the workspace catalog (+ alias wikis.md)
├── .cursor/
│   └── rules/
│       └── llm-wiki.mdc            # Cursor shim
├── .clinerules                     # Cline shim
├── .github/
│   └── copilot-instructions.md     # GitHub Copilot shim
├── docs/
│   ├── QUICKSTART.md               # per-tool first-use guide (start here after cloning)
│   ├── EXPLAIN.md                  # mental model for devs: build-system analogy, dev-mapped verbs
│   ├── MCP.md                      # optional MCP read surface (Claude Desktop / Cursor / etc.)
│   ├── VISUALIZATION.md            # graph view, slides, mermaid render, local server — no Obsidian
│   └── pitch-vscode.html           # self-contained pitch page (PT, internal reference)
├── scripts/
│   ├── body-hash.sh                # canonical SHA-256 over a raw file's body
│   ├── preflight.sh                # environment & dependency check (run before first /wiki-extract)
│   ├── wipe-meta-wiki.sh           # remove shipped meta-wiki content for a clean start
│   ├── verify-extract.sh           # shape-check /wiki-extract output
│   ├── wiki-to-anki.sh             # export ## Flashcards sections to Anki CSV
│   ├── verify-wiki-to-anki.sh      # shape-check the Anki exporter
│   ├── mcp-server.sh               # launch @bitbonsai/mcpvault pointed at wiki/
│   ├── smoke-build.sh              # LLM-driven build phase (drives claude -p)
│   ├── smoke-check.sh              # pure-shell asserts C1–C5 on the smoke artifacts
│   ├── smoke-all.sh                # umbrella: build + check + R1–R4 regression guards
│   ├── r3-obsidian-patterns.txt    # patterns file for the no-Obsidian-syntax check
│   ├── create-llm-wiki.sh          # manifest-driven installer for a fresh skeleton
│   ├── verify-create-llm-wiki.sh   # oracle for the installer (I1–I5)
│   ├── installer-skeleton-manifest.txt # single source of truth for what ships fresh
│   ├── new-wiki.sh                 # factory: scaffold + register a new wiki (reuses create-llm-wiki.sh)
│   ├── registry.sh                 # factory: owner of the workspace registry.jsonl catalog
│   ├── verify-multi-wiki.sh        # factory oracle (M1–M5: scaffold/register/drift/seeded-validity)
│   └── visualize/                  # opt-in OSS visualization wrappers
│       ├── graph.sh                # bash wrapper around graph-html.py
│       ├── graph-html.py           # stdlib-only D3 force-graph generator
│       ├── slides.sh               # MARP-CLI wrapper (npx)
│       ├── mermaid.sh              # mermaid-CLI wrapper (npx)
│       ├── serve.sh                # python3 -m http.server wrapper
│       ├── render.sh               # HTML poster → PDF/PNG (chrome/puppeteer; graceful fallback)
│       └── verify-visualizers.sh   # smoke harness (V1–V5 + render checks)
├── templates/
│   └── journal-entry.md            # template for wiki/journal/YYYY-MM-DD-*.md entries
├── tests/
│   ├── canary/                     # tiny known-good fixtures (shape-level smokes)
│   │   ├── canary-smoke-test.md
│   │   ├── canary-csv.csv
│   │   ├── canary-flashcards.md
│   │   ├── graph-fixture/          # 4 nodes / 4 edges flat fixture (V2 graph smoke)
│   │   └── graph-fixture-nested/   # 2 nodes / 1 edge nested fixture (V2b recursion smoke)
│   ├── smoke/                      # end-to-end smoke (Phase Coherence fixture + outputs)
│   │   ├── smoke-source.md
│   │   ├── expected-query.md
│   │   └── output/baseline-wiki.txt
│   └── installer-output/           # temp dirs the installer verifier writes to (gitignored)
├── raw/                            # immutable source material (you curate)
│   ├── karpathy-llm-wiki-video-transcript.md
│   ├── karpathy-video-slide-ingest-pipeline.png
│   ├── karpathy-video-slide-ingest-pipeline.png.md
│   └── smoke-source.md             # ingest-demonstrated smoke source
└── wiki/                           # the wiki itself (LLM-owned)
    ├── index.md                    # start here (dev meta-wiki)
    ├── index-FRESH.md              # stub used by the installer for fresh skeletons
    ├── core-idea.md
    ├── ... (25 more pages, including the 4 smoke-derived pages: quortex-protocol, dr-alma-voss, phase-coherence-engineering, smoke-source-summary)
    ├── glossary.md
    └── journal/                    # user-owned, time-stamped observations (schema-v2 exception)
```

</details>

## Principles this project honors

1. **Explicit.** Everything in markdown. No hidden embeddings, no opaque memory.
2. **Yours.** Local files. Portable. You decide what stays and what goes.
3. **File-over-app.** Pure CommonMark. Works with `cat`, `grep`, `git`, any viewer. **No Obsidian dependency** (or any other viewer).
4. **BYO AI.** Any LLM that supports file read/write and (optionally) web search.

See `wiki/four-principles.md` for the full account.

## Status

V2. Multi-tool shims for Claude Code, Cursor, Cline, Copilot CLI, Gemini CLI, and Codex are all in place. Real slash commands exist only for Claude Code; other tools invoke the workflows by natural language using the same prompt bodies.

The **multi-wiki factory** (`/wiki-new`, `/wiki-registry`) now exists: it generates domain-shaped wikis into a workspace and tracks them in a local `registry.jsonl`. Its deterministic half (`scripts/new-wiki.sh`, `scripts/registry.sh`) is shell-verified by `scripts/verify-multi-wiki.sh` (checks M1–M5, all green), and the existing single-wiki installer oracle (`scripts/verify-create-llm-wiki.sh`) still passes unchanged — the factory was built additively on top of it. *Remote/published* registry publishing, template snapshotting, richer outputs, and parallel-ingest concurrency are still future work.

**Runtime behaviour is untested.** The wiki was bootstrapped by direct file writes during the design conversation, not by `/wiki-ingest`. Your first real invocation of any slash command is the smoke test — expect minor wording adjustments to the command prompts after the first use.

## License

MIT — see [LICENSE](LICENSE).
