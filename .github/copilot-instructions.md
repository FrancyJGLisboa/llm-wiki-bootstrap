# context-compiler-bootstrap (GitHub Copilot instructions)

This repository is an `context-compiler-bootstrap` instance — a **context compiler**: it turns unstructured sources into a structured, provenance-aware, machine-navigable context package LLMs can navigate, retrieve from, and reason over.

## Read first

**`AGENTS.md`** at the project root is the canonical schema. Read it before any work in this repo. It defines the three-layer model (raw / wiki / schema), page conventions, link convention (`[[kebab-case]]`), raw source frontmatter, and the five named workflows.

## Three-layer model (one-line summary)

- `raw/` — immutable source material the user curates. Read-only for you.
- `wiki/` — LLM-owned markdown. **You are the sole writer.**
- `AGENTS.md` + `log.md` — the schema and audit log, co-owned.

## Daily user flow

When the user adds evidence, follow `.claude/commands/ctx-add.md`. Preserve every regular
file first, compile supported content, report degraded or failed extraction explicitly,
and finish successful validation with `scripts/checkpoint-context.sh`. Do not ask the user
to run Git commands and never use `git add -A` for a compiler checkpoint.

## Advanced compiler workflows

Defined as Claude Code slash commands at `.claude/commands/ctx-*.md`. From Copilot, the user invokes them by natural language ("ingest the latest raw," "ask the wiki about X"); follow the corresponding command file's prompt body step-by-step.

- `ctx-init` — scaffold structure (idempotent)
- `ctx-extract <source>` — acquire URL / file / image into `raw/`
- `ctx-compile [<raw-file>]` — process raw → wiki via 7-step pipeline; hash via `scripts/body-hash.sh`
- `ctx-query <question>` — answer from wiki; web-search + promote on gaps; `--visual [html|pdf|png]` also emits a diagram of the answer
- `ctx-lint [--apply]` — find issues; report or apply fixes

Plus two **output workflows** that render/export an already-built wiki (read-only on `raw/` and `wiki/`):

- `ctx-visualize [graph|mermaid|slides|serve] [target]` — graph / slides / mermaid / local server; wraps `scripts/visualize/*` (mechanical: renders existing structure)
- `ctx-flashcards [dir]` — export `## Flashcards` sections to an Anki CSV; wraps `scripts/wiki-to-anki.sh`
- `ctx-diagram "<intent>"` — semantic: retrieve from wiki, score the 8 archetypes, user picks, generate a self-contained HTML poster to `diagrams/`; contracts in `templates/infographic/`

A blank wiki can be scaffolded with `scripts/create-context-compiler.sh <target-dir>` (the installer; verified by `scripts/verify-create-context-compiler.sh`). To start fresh **without** the bash installer, scaffold in place by following `.claude/commands/ctx-init.md` — pure file creation, no shell needed.

## First run (help the user reach their first result)

Shortest path to value: create/open the workspace → add any evidence through `ctx-add` →
prepare the requested brief or answer. Translate this into internal workflows yourself;
do not make a daily user choose between extract, compile, and checkpoint steps.

## Shell requirement (matters on Windows)

`ctx-compile` and the visualize/flashcards workflows call bash + Python helpers (`scripts/body-hash.sh`, `scripts/synthesize/all.sh`, `scripts/visualize/*`). They need a real POSIX shell on PATH. On Windows the default terminal is PowerShell, which **cannot** run `.sh` files — if a `./scripts/*.sh` call fails, tell the user to install **Git for Windows** (bundles Git Bash + `awk`/`openssl`), set Git Bash as the VS Code default terminal, then re-run `bash scripts/preflight.sh` to confirm. See `docs/QUICKSTART.md` → "Windows setup". Never work around `body-hash.sh` by hashing inline — that breaks ingest idempotence (hard rule 2).

## Hard rules

1. **Do not write to `raw/`** except the three `ingested_*` fields, and only as the last step of `ctx-compile`.
2. **Use `scripts/body-hash.sh`** for the canonical body hash. Do not reinvent.
3. **Pure CommonMark only.** No Obsidian callouts, dataview, or any rendering-dependent markdown.
4. **Cite raw sources** inline: `(source: raw/<file>#<anchor>)`.
5. **Append a log.md entry** for every ingest, promote, or lint-apply.

## When in doubt

Read `AGENTS.md`, then `wiki/index.md`.
