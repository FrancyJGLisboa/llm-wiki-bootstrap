---
description: Scaffold an empty llm-wiki-bootstrap structure in the current directory (idempotent — won't overwrite existing files)
allowed-tools: Bash, Read, Write, Glob
argument-hint: (no arguments)
---

You are executing `/wiki-init` from the `llm-wiki-bootstrap` system. Your job is to scaffold an empty LLM-wiki structure in the current working directory.

## What this command does

Create the directory layout and the required schema/log/readme files in `$(pwd)`, **without overwriting** anything that already exists.

## Read first

Read `AGENTS.md` if it exists in the current directory — it tells you the project conventions. If it doesn't exist, you will create one (see step 3 below).

## Steps

1. **Detect current state.** List `$(pwd)` to see what's already there. Report what you find before proceeding.

2. **Create the directory skeleton** if missing:
   - `raw/`
   - `wiki/`
   - `.claude/commands/`

3. **Create files if missing** (never overwrite existing — if a file exists, skip it and report):
   - `AGENTS.md` — the canonical schema. If you are running this in a fresh directory, write a minimal `AGENTS.md` that documents the three layers, page template, link convention, raw source convention, and the five slash commands. Reference the version in this project (the project you are running from) as the canonical template.
   - `wiki/index.md` — a navigation page with the frontmatter `type: navigation`, `source: analysis`. Body should explain how to start adding raw sources and use `/wiki-fetch` + `/wiki-ingest`.
   - `log.md` — newest-at-top, with an initial entry: `## <today> <time> — /wiki-init` listing the files created.
   - `README.md` — a quickstart explaining: how to add sources (`/wiki-fetch`), how to ingest (`/wiki-ingest`), how to ask (`/wiki-ask`), how to maintain (`/wiki-lint`). Use plain CommonMark only (no Obsidian-specific syntax).

4. **Idempotence check.** Run `/wiki-init` twice should leave the directory in the same state after the first run. Verify by re-listing.

## What you must NOT do

- Overwrite any existing file. If `AGENTS.md` already exists, leave it. If `wiki/index.md` exists, leave it. Report what you skipped.
- Add content to `raw/` (that's `/wiki-fetch`'s job).
- Add wiki pages beyond `wiki/index.md` (that's `/wiki-ingest` or `/wiki-ask`).
- Use Obsidian-specific markdown (callouts, dataview, embeds). Pure CommonMark only.

## Output

End with a status report:

```
/wiki-init complete.

Created:
- raw/
- wiki/
- .claude/commands/
- AGENTS.md
- wiki/index.md
- log.md
- README.md

Skipped (already present):
- (none)

Next: drop sources into raw/ via /wiki-fetch, then /wiki-ingest.
```
