# llm-wiki-bootstrap (Claude Code)

This project's canonical schema is **`AGENTS.md`** in the same directory. Modern Claude Code loads `AGENTS.md` automatically; this file exists for older Claude Code versions that only load `CLAUDE.md`.

**Read `AGENTS.md`** for all conventions: three-layer model (raw / wiki / schema), page template, link convention `[[kebab-case]]`, raw source frontmatter spec, and the five slash commands.

The five slash commands live at `.claude/commands/wiki-*.md`:

- `/wiki-init` — scaffold structure (idempotent)
- `/wiki-extract <source>` — acquire URL / file / image into `raw/`
- `/wiki-ingest [<raw-file>]` — process raw → wiki via the 7-step pipeline (hash via `scripts/body-hash.sh`)
- `/wiki-query <question>` — answer from wiki; web-search + promote on gaps
- `/wiki-lint [--apply]` — find issues; report or apply fixes

Plus two **output commands** that render/export an already-built wiki (read-only on `raw/` and `wiki/`):

- `/wiki-visualize [graph|mermaid|slides|serve] [target]` — graph / slides / mermaid / local server; wraps `scripts/visualize/*` (mechanical: renders existing structure)
- `/wiki-flashcards [dir]` — export `## Flashcards` sections to an Anki CSV; wraps `scripts/wiki-to-anki.sh`
- `/wiki-diagram "<intent>"` — semantic: retrieve from wiki, score the 8 archetypes, user picks, generate a self-contained HTML poster to `diagrams/`; contracts in `templates/infographic/`

Hard rules (full text in `AGENTS.md`):

1. Never write to `raw/` except the three `ingested_*` frontmatter fields, as the last step of `/wiki-ingest`.
2. Use `scripts/body-hash.sh` for the canonical hash — do not reinvent inline.
3. Pure CommonMark. No Obsidian callouts, dataview blocks, or any rendering-dependent markdown.
4. Cite raw sources inline: `(source: raw/<file>#<anchor>)`.
5. Append a log.md entry for every ingest, promote, or lint-apply.
