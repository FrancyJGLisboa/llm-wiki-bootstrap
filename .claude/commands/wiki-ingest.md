---
description: Process raw/ into wiki/ via the 7-step pipeline. Detects deltas via body hash; idempotent on unchanged sources.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [<raw-file>]
---

You are executing `/wiki-ingest $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to integrate raw sources into the wiki using the 7-step pipeline.

## Read first

Read `AGENTS.md` (conventions), `wiki/index.md` (what already exists), and `CHANGELOG.md` (recent activity).

## Determine scope

- If `$ARGUMENTS` is empty: walk all files in `raw/`. For each, compute the current body hash by running **`scripts/body-hash.sh <file>`** (this is the canonical algorithm — do NOT recompute the hash inline with `sha256sum`, `shasum`, or a different awk pattern, or idempotence will break). Skip files whose `ingested_hash` in frontmatter matches the current hash.
- If `$ARGUMENTS` names a specific file: process only that file, regardless of hash.

If nothing to process: print "No changes to ingest." and exit.

## The 7-step pipeline (run per raw file)

For each raw file that needs processing:

### Step 1 — Read the raw source

Read the file. For binaries (image, PDF), read the sidecar `.md` instead.

### Step 2 — Extract key information

Identify: concepts (ideas, terms, patterns), entities (people, tools, places, datasets), claims (statements that could be true or false), data points (numbers, dates, quotes).

### Step 3 — Write a summary page

Create or update `wiki/<source-slug>-summary.md` with `type: summary`, `source: <type>` (matching the raw's `source_type` family — `video` for video-transcript, `external` for fetched web pages, etc.), and the source's main takeaways. Cite the raw inline with `(source: raw/<filename>#<anchor>)`.

### Step 4 — Update existing entity / concept pages

For each concept and entity from step 2:
- Glob `wiki/` to see if a matching page exists.
- If yes: read it, decide what to add, append the new claim with citation. **Do not duplicate existing content.**
- If no AND the concept/entity is referenced by 2+ raws OR is structurally important: create a new `wiki/<slug>.md` with `type: concept` or `type: entity`.
- Cross-link: every page that mentions another covered page should `[[wiki-link]]` to it.

### Step 5 — Flag contradictions

If a new claim from this source disagrees with an existing claim in the wiki, **flag it visibly** in both pages: add a sentence like `> CONTRADICTION FLAGGED 2026-05-25: this claim is contradicted by [[other-page]] which says: ...`. Do not silently overwrite either.

### Step 6 — Update the index

Read `wiki/index.md`. Add new pages to the appropriate section. Remove links to pages that were deleted (rare). Keep the existing organization.

### Step 7 — Append to the changelog

Append (newest at top) to `CHANGELOG.md`:

```markdown
## YYYY-MM-DD HH:MM — /wiki-ingest

- Processed: raw/<file> (hash <8-char-prefix>)
- Created: wiki/<file>, wiki/<file>
- Updated: wiki/<file>, wiki/<file>
- Contradictions flagged: none | <description>
```

## After all steps for a file

Update the raw file's frontmatter:
- `ingested_hash:` set to the body hash you computed via `scripts/body-hash.sh`
- `ingested_at:` set to current timestamp (format: `YYYY-MM-DD HH:MM`)
- `ingested_pages:` set to the array of wiki files this raw touched (created or updated)

## What you must NOT do

- Edit anything in `raw/` other than the frontmatter fields `ingested_hash`, `ingested_at`, `ingested_pages`.
- Skip the changelog entry.
- Use Obsidian-specific syntax in any wiki page.
- Promote orphan information (claims that don't relate to anything else) into their own page just to have something. Better: skip them and let lint surface gaps.

## Output

End with a status report listing files processed, files skipped (and why), and pages created/updated. Suggest `/wiki-lint` if you flagged contradictions or noticed gaps.
