# llm-wiki-bootstrap

A starter kit for personal LLM-wiki knowledge bases. Five slash commands let you (or any user) build, ingest into, query, and maintain a wiki — operated entirely from an AI agentic tool, no UI required.

The pattern is Andrej Karpathy's: an LLM incrementally builds and maintains a persistent, interlinked markdown wiki sitting between you and your raw sources. You curate sources and ask questions; the LLM does all the writing, cross-referencing, and maintenance.

The wiki that ships with this repo is *meta*: it's a wiki about the LLM-wiki pattern itself. Read it via [`wiki/index.md`](wiki/index.md). Keep it as living documentation, or wipe it and start your own.

## Install

**Prerequisite — install an agentic AI tool first.** The slash commands here run inside the tool, not from the shell. The reference path is [Claude Code](https://docs.anthropic.com/claude/code) (`claude` on your `$PATH`). Other supported tools — Copilot CLI, Cursor, Cline, Gemini CLI, Codex, VSCode Copilot Chat — are documented in [`docs/QUICKSTART.md`](docs/QUICKSTART.md) with per-tool invocation patterns.

```bash
git clone <this-repo> my-wiki
cd my-wiki
```

This clone ships with demonstration content (a meta-wiki about the LLM-wiki pattern itself + a smoke fixture). To start your **own** wiki without that demo content, use the installer:

```bash
git clone <this-repo> tmp
tmp/scripts/create-llm-wiki.sh ~/my-wiki   # fresh skeleton, no demo content
rm -rf tmp
cd ~/my-wiki
```

The installer is manifest-driven (`scripts/installer-skeleton-manifest.txt`) and verified by `scripts/verify-create-llm-wiki.sh`.

Optional but recommended: run `./scripts/preflight.sh` to confirm hard requirements (`bash`/`awk`/`openssl`/`git`) are met and to see which `/wiki-extract` formats your environment supports first-try (PDF needs `pdftotext`; DOCX needs `pandoc`; XLSX needs `xlsx2csv` — each has a fallback, but the preflight tells you in advance).

That's it. The structure is already there. Open the directory in Claude Code (or any agentic tool that supports `.claude/commands/`) and the five slash commands are available immediately.

**For the per-tool first-use sequence (which commands to type, in order, in each AI tool), see [`docs/QUICKSTART.md`](docs/QUICKSTART.md).** For the *mental model* — three layers, five commands, and the build-system analogy mapped to things you already know — see [`docs/EXPLAIN.md`](docs/EXPLAIN.md).

### Tool support

The project ships shim files for every major agentic tool. Whatever you use, the AI will load the schema automatically:

| Tool | Shim file (already in repo) | Invocation |
|---|---|---|
| Claude Code (modern) | `AGENTS.md` (canonical) | `/wiki-init`, `/wiki-extract`, etc. — real slash commands |
| Claude Code (legacy) | `CLAUDE.md` | same as modern |
| Cursor | `.cursor/rules/llm-wiki.mdc` | natural language: "run wiki-ingest" |
| Cline (VSCode) | `.clinerules` | natural language |
| GitHub Copilot | `.github/copilot-instructions.md` | natural language |
| Gemini CLI | `GEMINI.md` | natural language |
| OpenAI Codex | `AGENTS.md` (canonical — auto-loads) | natural language |

The shim files all point at `AGENTS.md` as the canonical schema and at `.claude/commands/wiki-*.md` as the workflow definitions. Tools without first-class slash commands (Cursor, Cline, Copilot, Gemini) invoke the workflows by natural language; the LLM follows the prompt body of the corresponding command file step-by-step.

## The five slash commands

Every command has both a prefixed form (`/wiki-extract`) and a short alias (`/extract`). The short forms are the ones you'll actually type once you're inside a fresh installed repo; the prefixed form is there for global use where namespace collisions matter. Both resolve to the exact same procedure.

| Prefixed | Short | What it does |
|---|---|---|
| `/wiki-init` | `/init` | Scaffold the wiki structure (raw/, wiki/, AGENTS.md, README.md, log.md). Idempotent. Use only if you copied just `.claude/commands/` into an existing project — cloning this repo already gives you the structure. |
| `/wiki-extract <urls-or-files>` | `/extract` | Pull **one or many** URLs / local files (PDF, DOCX, XLSX, CSV, image, or plain text) into `raw/` with frontmatter. Bulk mode: pass multiple sources space- or newline-separated and they're all extracted in one pass with a consolidated OK/Degraded/Failed summary at the end. Parses binary content to markdown when a handler exists. Does **not** touch `wiki/`. |
| `/wiki-ingest [<raw-file>]` | `/ingest` | Process `raw/` → `wiki/` using the 7-step pipeline. Detects deltas via hash; idempotent on unchanged sources. |
| `/wiki-query <question>` | `/query` | Answer from the wiki; web-search and auto-promote new knowledge if there's a gap. Use `--no-promote` to suppress promotion. |
| `/wiki-lint [--apply]` | `/lint` | Health-check: broken links, orphans, contradictions, stale claims, gaps. Reports by default; `--apply` writes proposed fixes. |

Full spec at [`wiki/commands.md`](wiki/commands.md).

**Optional: typed relations.** Inside `## Related`, you can attach a verb to a link — `- [[embrapa]] founded-by 1973 — Brazilian R&D agency`. Pure CommonMark; backward-compat with untyped lines. Verb regex: `[a-z][a-z0-9-]*`. Validate with `./scripts/wiki-lint-typed-relations.sh wiki/`; the graph viz colours and filters edges by verb. Full spec in [`AGENTS.md`](AGENTS.md) → "Typed relations". An empirical eval (`scripts/eval-multi-hop.sh`) measures whether typed verbs improve `/wiki-query` recall over the same wiki with verbs stripped — see [`.scratch/typed-wikilinks-semantic-viz/GOAL.md`](.scratch/typed-wikilinks-semantic-viz/GOAL.md) for the methodology and current null-result on a Wikipedia-derived fixture.

## Verify your install

Once you've cloned and have Claude Code installed, run:

```bash
./scripts/smoke-all.sh
```

It drives `claude -p` to ingest a small fictitious fixture, asks the wiki a question, and confirms the answer recalls the fact and cites the source. First run takes ~30–60s (LLM); subsequent runs are sub-second (idempotent via body-hash). All 9 checks green = your install works end-to-end. Spec at [`.scratch/plug-and-play-curator-smoke/GOAL.md`](.scratch/plug-and-play-curator-smoke/GOAL.md).

## Visualize your wiki

```bash
./scripts/visualize/graph.sh wiki/ > graph.html   # interactive D3 force graph (no install)
./scripts/visualize/serve.sh                     # browse the wiki + graph locally
```

Four opt-in wrappers under `scripts/visualize/`: a Python+D3 graph generator (zero dependencies), plus `slides.sh`, `mermaid.sh`, and `serve.sh` for MARP / mermaid-CLI / local HTTP. All open source; no Obsidian required. Heavier alternatives (Quartz, mdBook, SilverBullet) covered in [`docs/VISUALIZATION.md`](docs/VISUALIZATION.md).

## MCP access (optional)

Expose this wiki over the Model Context Protocol so any MCP-aware AI client — Claude Desktop, Claude Code, Cursor, ChatGPT Desktop, etc. — can read it (and optionally write to it) without slash-command indirection. Uses [`@bitbonsai/mcpvault`](https://github.com/bitbonsai/mcpvault), which works on any markdown directory with no Obsidian dependency. BM25 search built in.

```bash
./scripts/mcp-server.sh        # foreground stdio server pointed at wiki/
```

For client config snippets (Claude Desktop, Claude Code, Cursor) and the recommended read-only posture, see [`docs/MCP.md`](docs/MCP.md).

## Flashcards (optional)

Any wiki page may declare a `## Flashcards` section with `Q: …` / `A: …` bullet pairs. Export to an Anki-importable CSV with:

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

# ask the wiki something
/wiki-query "what does this article say about X?"

# periodically tidy up
/wiki-lint
```

## Make it yours

The shipped wiki content is illustrative — it's a wiki *about* the LLM-wiki pattern, derived from the YouTube transcript in `raw/karpathy-llm-wiki-video-transcript.md`. To start your own:

1. **Keep it as reference and add alongside:** drop your own sources into `raw/`, run `/wiki-ingest`. Your pages live next to the meta-wiki content.
2. **Replace it:** `./scripts/wipe-meta-wiki.sh` (prompts for confirmation; `--yes` to skip). Wipes `wiki/*.md` and `raw/*`, resets `wiki/index.md` and `log.md` to minimal stubs.

The `AGENTS.md` schema is project-agnostic — it works the same whether the wiki is about LLM-wikis, trading, M&A, your team's roadmap, or anything else.

## Project layout

```
.
├── AGENTS.md                       # canonical schema (read by AI tools) — schema v2
├── CLAUDE.md                       # shim → points to AGENTS.md
├── GEMINI.md                       # shim → points to AGENTS.md
├── README.md                       # this file (dev-side)
├── README-FRESH.md                 # template used by the installer for fresh skeletons
├── log.md                          # append-only log of ingests, schema bumps, infra changes
├── .claude/
│   └── commands/                   # five Claude Code slash commands
│       ├── wiki-init.md
│       ├── wiki-extract.md
│       ├── wiki-ingest.md
│       ├── wiki-query.md
│       └── wiki-lint.md
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
│   └── visualize/                  # opt-in OSS visualization wrappers
│       ├── graph.sh                # bash wrapper around graph-html.py
│       ├── graph-html.py           # stdlib-only D3 force-graph generator
│       ├── slides.sh               # MARP-CLI wrapper (npx)
│       ├── mermaid.sh              # mermaid-CLI wrapper (npx)
│       ├── serve.sh                # python3 -m http.server wrapper
│       └── verify-visualizers.sh   # smoke harness (V1–V5)
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

## Principles this project honors

1. **Explicit.** Everything in markdown. No hidden embeddings, no opaque memory.
2. **Yours.** Local files. Portable. You decide what stays and what goes.
3. **File-over-app.** Pure CommonMark. Works with `cat`, `grep`, `git`, any viewer. **No Obsidian dependency** (or any other viewer).
4. **BYO AI.** Any LLM that supports file read/write and (optionally) web search.

See `wiki/four-principles.md` for the full account.

## Status

V2. Multi-tool shims for Claude Code, Cursor, Cline, Copilot CLI, Gemini CLI, and Codex are all in place. Real slash commands exist only for Claude Code; other tools invoke the five workflows by natural language using the same prompt bodies. Registry publishing, richer outputs (slideshows / plots), and parallel-ingest concurrency are still future work.

**Runtime behaviour is untested.** The wiki was bootstrapped by direct file writes during the design conversation, not by `/wiki-ingest`. Your first real invocation of any slash command is the smoke test — expect minor wording adjustments to the command prompts after the first use.

## License

MIT — see [LICENSE](LICENSE).
