# context-compiler-bootstrap (Claude Code)

This project is a **context compiler**: it turns unstructured sources into a structured, provenance-aware, machine-navigable context package LLMs can navigate, retrieve from, and reason over (see `docs/CONTEXT-COMPILER.md`).

This project's canonical schema is **`AGENTS.md`** in the same directory. Modern Claude Code loads `AGENTS.md` automatically; this file exists for older Claude Code versions that only load `CLAUDE.md`.

**Read `AGENTS.md`** for all conventions: three-layer model (raw / wiki / schema), page template, link convention `[[kebab-case]]`, raw source frontmatter spec, and the five slash commands.

The five slash commands live at `.claude/commands/ctx-*.md`:

- `/ctx-init` — scaffold structure (idempotent)
- `/ctx-extract <source>` — acquire URL / file / image into `raw/`
- `/ctx-compile [<raw-file>]` — process raw → wiki via the 7-step pipeline (hash via `scripts/body-hash.sh`)
- `/ctx-query <question>` — answer from wiki; web-search + promote on gaps; `--visual [html|pdf|png]` also emits a diagram of the answer
- `/ctx-lint [--apply]` — find issues; report or apply fixes

Plus two **output commands** that render/export an already-built wiki (read-only on `raw/` and `wiki/`):

- `/ctx-visualize [graph|mermaid|slides|serve] [target]` — graph / slides / mermaid / local server; wraps `scripts/visualize/*` (mechanical: renders existing structure)
- `/ctx-flashcards [dir]` — export `## Flashcards` sections to an Anki CSV; wraps `scripts/wiki-to-anki.sh`
- `/ctx-diagram "<intent>"` — semantic: retrieve from wiki, score the 8 archetypes, user picks, generate a self-contained HTML poster to `diagrams/`; contracts in `templates/infographic/`

A blank wiki can be scaffolded for use with `scripts/create-context-compiler.sh <target-dir>` (the installer; verified by `scripts/verify-create-context-compiler.sh`).

Hard rules (full text in `AGENTS.md`):

1. Never write to `raw/` except the three `ingested_*` frontmatter fields, as the last step of `/ctx-compile`.
2. Use `scripts/body-hash.sh` for the canonical hash — do not reinvent inline.
3. Pure CommonMark. No Obsidian callouts, dataview blocks, or any rendering-dependent markdown.
4. Cite raw sources inline: `(source: raw/<file>#<anchor>)`.
5. Append a log.md entry for every ingest, promote, or lint-apply.
