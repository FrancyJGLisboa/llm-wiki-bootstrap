# llm-wiki-bootstrap (Gemini CLI)

This project's canonical schema is **`AGENTS.md`** in the same directory. Some Gemini CLI versions load `GEMINI.md` only; this file exists as a shim for those.

**Read `AGENTS.md`** for all conventions: three-layer model (raw / wiki / schema), page template, link convention `[[kebab-case]]`, raw source frontmatter spec, and the five named workflows.

The five workflows are defined at `.claude/commands/wiki-*.md` (named for Claude Code's slash command location, but the prompt bodies are tool-agnostic — read them as workflow definitions). The user invokes them in Gemini by natural language ("ingest raw," "ask the wiki about X").

- `wiki-init` — scaffold structure (idempotent)
- `wiki-fetch <source>` — acquire URL / file / image into `raw/`
- `wiki-ingest [<raw-file>]` — process raw → wiki via the 7-step pipeline (hash via `scripts/body-hash.sh`)
- `wiki-ask <question>` — answer from wiki; web-search + promote on gaps
- `wiki-lint [--apply]` — find issues; report or apply fixes

Hard rules (full text in `AGENTS.md`):

1. Never write to `raw/` except the three `ingested_*` frontmatter fields.
2. Use `scripts/body-hash.sh` for the canonical hash — do not reinvent.
3. Pure CommonMark. No rendering-dependent markdown.
4. Cite raw sources inline: `(source: raw/<file>#<anchor>)`.
5. Append a CHANGELOG entry for every ingest, promote, or lint-apply.
