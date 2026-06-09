# llm-wiki-bootstrap (GitHub Copilot instructions)

This repository is an `llm-wiki-bootstrap` instance — a personal LLM-wiki knowledge base.

## Read first

**`AGENTS.md`** at the project root is the canonical schema. Read it before any work in this repo. It defines the three-layer model (raw / wiki / schema), page conventions, link convention (`[[kebab-case]]`), raw source frontmatter, and the five named workflows.

## Three-layer model (one-line summary)

- `raw/` — immutable source material the user curates. Read-only for you.
- `wiki/` — LLM-owned markdown. **You are the sole writer.**
- `AGENTS.md` + `log.md` — the schema and audit log, co-owned.

## The five workflows

Defined as Claude Code slash commands at `.claude/commands/wiki-*.md`. From Copilot, the user invokes them by natural language ("ingest the latest raw," "ask the wiki about X"); follow the corresponding command file's prompt body step-by-step.

- `wiki-init` — scaffold structure (idempotent)
- `wiki-extract <source>` — acquire URL / file / image into `raw/`
- `wiki-ingest [<raw-file>]` — process raw → wiki via 7-step pipeline; hash via `scripts/body-hash.sh`
- `wiki-query <question>` — answer from wiki; web-search + promote on gaps; `--visual [html|pdf|png]` also emits a diagram of the answer
- `wiki-lint [--apply]` — find issues; report or apply fixes

Plus two **output workflows** that render/export an already-built wiki (read-only on `raw/` and `wiki/`):

- `wiki-visualize [graph|mermaid|slides|serve] [target]` — graph / slides / mermaid / local server; wraps `scripts/visualize/*` (mechanical: renders existing structure)
- `wiki-flashcards [dir]` — export `## Flashcards` sections to an Anki CSV; wraps `scripts/wiki-to-anki.sh`
- `wiki-diagram "<intent>"` — semantic: retrieve from wiki, score the 8 archetypes, user picks, generate a self-contained HTML poster to `diagrams/`; contracts in `templates/infographic/`

A blank wiki can be scaffolded with `scripts/create-llm-wiki.sh <target-dir>` (the installer; verified by `scripts/verify-create-llm-wiki.sh`). To start fresh **without** the bash installer, scaffold in place by following `.claude/commands/wiki-init.md` — pure file creation, no shell needed.

## First run (help the user reach their first source)

Shortest path to value: scaffold (`wiki-init`) → acquire one source (`wiki-extract <url>`) → integrate (`wiki-ingest`) → ask (`wiki-query`). `wiki-init` and a URL `wiki-extract` need **no shell scripts** — do them directly. When a new user arrives with a URL or file, offer to run `wiki-init` + `wiki-extract` in one go.

## Shell requirement (matters on Windows)

`wiki-ingest` and the visualize/flashcards workflows call bash + Python helpers (`scripts/body-hash.sh`, `scripts/synthesize/all.sh`, `scripts/visualize/*`). They need a real POSIX shell on PATH. On Windows the default terminal is PowerShell, which **cannot** run `.sh` files — if a `./scripts/*.sh` call fails, tell the user to install **Git for Windows** (bundles Git Bash + `awk`/`openssl`), set Git Bash as the VS Code default terminal, then re-run `bash scripts/preflight.sh` to confirm. See `docs/QUICKSTART.md` → "Windows setup". Never work around `body-hash.sh` by hashing inline — that breaks ingest idempotence (hard rule 2).

## Hard rules

1. **Do not write to `raw/`** except the three `ingested_*` fields, and only as the last step of `wiki-ingest`.
2. **Use `scripts/body-hash.sh`** for the canonical body hash. Do not reinvent.
3. **Pure CommonMark only.** No Obsidian callouts, dataview, or any rendering-dependent markdown.
4. **Cite raw sources** inline: `(source: raw/<file>#<anchor>)`.
5. **Append a log.md entry** for every ingest, promote, or lint-apply.

## When in doubt

Read `AGENTS.md`, then `wiki/index.md`.
