# llm-wiki-bootstrap (Gemini CLI)

This project's canonical schema is **`AGENTS.md`** in the same directory. Some Gemini CLI versions load `GEMINI.md` only; this file exists as a shim for those.

**Read `AGENTS.md`** for all conventions: three-layer model (raw / wiki / schema), page template, link convention `[[kebab-case]]`, raw source frontmatter spec, and the five named workflows.

The five workflows are defined at `.claude/commands/wiki-*.md` (named for Claude Code's slash command location, but the prompt bodies are tool-agnostic — read them as workflow definitions). The user invokes them in Gemini by natural language ("ingest raw," "ask the wiki about X").

- `wiki-init` — scaffold structure (idempotent)
- `wiki-extract <source>` — acquire URL / file / image into `raw/`
- `wiki-ingest [<raw-file>]` — process raw → wiki via the 7-step pipeline (hash via `scripts/body-hash.sh`)
- `wiki-query <question>` — answer from wiki; web-search + promote on gaps; `--visual [html|pdf|png]` also emits a diagram of the answer
- `wiki-lint [--apply]` — find issues; report or apply fixes

Plus two **output workflows** that render/export an already-built wiki (read-only on `raw/` and `wiki/`):

- `wiki-visualize [graph|mermaid|slides|serve] [target]` — graph / slides / mermaid / local server; wraps `scripts/visualize/*` (mechanical: renders existing structure)
- `wiki-flashcards [dir]` — export `## Flashcards` sections to an Anki CSV; wraps `scripts/wiki-to-anki.sh`
- `wiki-diagram "<intent>"` — semantic: retrieve from wiki, score the 8 archetypes, user picks, generate a self-contained HTML poster to `diagrams/`; contracts in `templates/infographic/`

Two **factory workflows** generate and catalog *other* wikis (they belong to this repo only — they are not shipped into the wikis they create; real slash commands in Claude Code, natural-language in Gemini):

- `wiki-new <name> --domain "<description>"` — scaffold a new domain-shaped wiki and register it; wraps `scripts/new-wiki.sh` (which reuses `scripts/create-llm-wiki.sh`)
- `wiki-registry [prune]` — list / prune the workspace catalog (`registry.jsonl`); wraps `scripts/registry.sh`

See `AGENTS.md` → "Generating new wikis (the factory)".

Hard rules (full text in `AGENTS.md`):

1. Never write to `raw/` except the three `ingested_*` frontmatter fields.
2. Use `scripts/body-hash.sh` for the canonical hash — do not reinvent.
3. Pure CommonMark. No rendering-dependent markdown.
4. Cite raw sources inline: `(source: raw/<file>#<anchor>)`.
5. Append a log.md entry for every ingest, promote, or lint-apply.
