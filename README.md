# llm-wiki-bootstrap

A starter kit for personal LLM-wiki knowledge bases. Five slash commands let you (or any user) build, ingest into, query, and maintain a wiki — operated entirely from an AI agentic tool, no UI required.

The pattern is Andrej Karpathy's: an LLM incrementally builds and maintains a persistent, interlinked markdown wiki sitting between you and your raw sources. You curate sources and ask questions; the LLM does all the writing, cross-referencing, and maintenance.

The wiki that ships with this repo is *meta*: it's a wiki about the LLM-wiki pattern itself. Read it via [`wiki/index.md`](wiki/index.md). Keep it as living documentation, or wipe it and start your own.

## Install

```bash
git clone <this-repo> my-wiki
cd my-wiki
```

That's it. The structure is already there. Open the directory in Claude Code (or any agentic tool that supports `.claude/commands/`) and the five slash commands are available immediately.

### Tool support

The project ships shim files for every major agentic tool. Whatever you use, the AI will load the schema automatically:

| Tool | Shim file (already in repo) | Invocation |
|---|---|---|
| Claude Code (modern) | `AGENTS.md` (canonical) | `/wiki-init`, `/wiki-fetch`, etc. — real slash commands |
| Claude Code (legacy) | `CLAUDE.md` | same as modern |
| Cursor | `.cursor/rules/llm-wiki.mdc` | natural language: "run wiki-ingest" |
| Cline (VSCode) | `.clinerules` | natural language |
| GitHub Copilot | `.github/copilot-instructions.md` | natural language |
| Gemini CLI | `GEMINI.md` | natural language |
| OpenAI Codex | `AGENTS.md` (canonical — auto-loads) | natural language |

The shim files all point at `AGENTS.md` as the canonical schema and at `.claude/commands/wiki-*.md` as the workflow definitions. Tools without first-class slash commands (Cursor, Cline, Copilot, Gemini) invoke the workflows by natural language; the LLM follows the prompt body of the corresponding command file step-by-step.

## The five slash commands

| Command | What it does |
|---|---|
| `/wiki-init` | Scaffold the wiki structure (raw/, wiki/, AGENTS.md, README.md, CHANGELOG.md). Idempotent. Use only if you copied just `.claude/commands/` into an existing project — cloning this repo already gives you the structure. |
| `/wiki-fetch <url-or-file>` | Pull a URL, file, or image into `raw/` with frontmatter. Does **not** touch `wiki/`. |
| `/wiki-ingest [<raw-file>]` | Process `raw/` → `wiki/` using the 7-step pipeline. Detects deltas via hash; idempotent on unchanged sources. |
| `/wiki-ask <question>` | Answer from the wiki; web-search and auto-promote new knowledge if there's a gap. Use `--no-promote` to suppress promotion. |
| `/wiki-lint [--apply]` | Health-check: broken links, orphans, contradictions, stale claims, gaps. Reports by default; `--apply` writes proposed fixes. |

Full spec at [`wiki/commands.md`](wiki/commands.md).

## A typical session

```
# add a source
/wiki-fetch https://example.com/some-article

# integrate it
/wiki-ingest

# ask the wiki something
/wiki-ask "what does this article say about X?"

# periodically tidy up
/wiki-lint
```

## Make it yours

The shipped wiki content is illustrative — it's a wiki *about* the LLM-wiki pattern, derived from the YouTube transcript in `raw/karpathy-llm-wiki-video-transcript.md`. To start your own:

1. **Keep it as reference and add alongside:** drop your own sources into `raw/`, run `/wiki-ingest`. Your pages live next to the meta-wiki content.
2. **Replace it:** `rm -rf wiki/*.md raw/*` then `/wiki-init` and start fresh.

The `AGENTS.md` schema is project-agnostic — it works the same whether the wiki is about LLM-wikis, trading, M&A, your team's roadmap, or anything else.

## Project layout

```
.
├── AGENTS.md                       # canonical schema (read by AI tools)
├── CLAUDE.md                       # shim → points to AGENTS.md
├── GEMINI.md                       # shim → points to AGENTS.md
├── README.md                       # this file
├── CHANGELOG.md                    # append-only log of ingests, lints, promotes
├── .claude/
│   └── commands/                   # five Claude Code slash commands
│       ├── wiki-init.md
│       ├── wiki-fetch.md
│       ├── wiki-ingest.md
│       ├── wiki-ask.md
│       └── wiki-lint.md
├── .cursor/
│   └── rules/
│       └── llm-wiki.mdc            # Cursor shim
├── .clinerules                     # Cline shim
├── .github/
│   └── copilot-instructions.md     # GitHub Copilot shim
├── scripts/
│   └── body-hash.sh                # canonical SHA-256 over a raw file's body
├── raw/                            # immutable source material (you curate)
│   └── karpathy-llm-wiki-video-transcript.md
└── wiki/                           # the wiki itself (LLM-owned)
    ├── index.md                    # start here
    ├── core-idea.md
    ├── ... (18 more pages)
    └── glossary.md
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
