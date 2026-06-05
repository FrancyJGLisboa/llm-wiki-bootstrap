---
description: Process raw/ into wiki/ via the 7-step pipeline. Detects deltas via body hash; idempotent on unchanged sources.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [<raw-file>]
---

You are executing `/wiki-ingest $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to integrate raw sources into the wiki using the 7-step pipeline.

## Read first

**Run from the wiki root** — the directory holding `raw/`, `wiki/`, `AGENTS.md`, and `log.md`. If `AGENTS.md` is absent you are not in a wiki: tell the user to run `/wiki-init` first (or `cd` into their wiki), then stop.

Read `wiki/index.md` (what already exists) and `log.md` (recent activity). You don't need to re-read all of `AGENTS.md` — the page template you'll write is inlined below; consult `AGENTS.md` → "Wiki page convention" only for edge cases.

## Determine scope

- If `$ARGUMENTS` is empty: walk all files in `raw/`. For each, compute the current body hash by running **`scripts/body-hash.sh <file>`** (this is the canonical algorithm — do NOT recompute the hash inline with `sha256sum`, `shasum`, or a different awk pattern, or idempotence will break). Skip files whose `ingested_hash` in frontmatter matches the current hash.
- If `$ARGUMENTS` names a specific file: process only that file, regardless of hash.

If nothing to process: print "No changes to ingest." and exit. If `raw/` is **empty** (no sources at all), add: "Next: run `/wiki-extract <source>` to acquire a source, then `/wiki-ingest` again."

## Page template (every page you create or update in steps 3–4)

Inlined so you don't have to cross-reference `AGENTS.md`. Pure CommonMark — no Obsidian callouts/dataview.

```markdown
---
title: <Title Case>
type: concept | entity | summary | analysis | navigation
source: video | analysis | external | mixed
updated: YYYY-MM-DD
tags: [...]
---

# <Title>

## Definition / TL;DR
1-3 sentences. What this page is about.

## Body
Free-form prose. Inline `[[wiki-links]]` to related pages, and `(source: <raw-file>#<anchor>)` for any non-trivial claim.

## Related
- [[other-page]] — why it relates
- [[another-page]] — why it relates

## Open questions on this page
- ... (consumed by /wiki-lint)
```

The `## Related` section needs **≥ 2** `[[links]]` so the page joins the web (navigation/journal pages are exempt — see `AGENTS.md`). Cite anchors by source type: `#heading-name` (markdown/article), `#L5-L10` (line range), `#2:01` (video timestamp).

**Type causal links.** When the source states a **cause→effect** relationship between two covered concepts, encode it as a typed causal edge on the single-target `## Related` line using a **canonical causal verb** (`causes`, `caused-by`, `enables`, `prevents`, `contributes-to` — see `AGENTS.md` → "Causal relations" and `templates/causal-vocab.txt`), not the implicit `related-to` form. Direction is source-page → target: on page `drought`, write `- [[yield-drop]] causes — sustained moisture deficit cuts realized yield`. Use the canonical verb, not a synonym (`leads-to`/`due-to`/etc.) — `scripts/wiki-lint-causal.sh` flags those. Do **not** build or write any knowledge-graph sidecar during ingest — the causal graph is materialized on demand by `scripts/wiki-to-kg.py` at query time, never here, so it stays out of the body-hash.

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

If a new claim from this source disagrees with an existing claim in the wiki, **flag it visibly** in both pages. Do not silently overwrite either. Use this **exact** line format (a CommonMark blockquote — `/wiki-lint` matches the literal token `CONTRADICTION FLAGGED`):

```markdown
> CONTRADICTION FLAGGED YYYY-MM-DD: <one-line description>. Contradicts [[other-page]], which says <their claim>.
```

Worked example — `wiki/fluid-bed-roaster.md` gains, and `wiki/drum-roaster.md` gains the mirror:

```markdown
> CONTRADICTION FLAGGED 2026-05-30: this source says fluid-bed roasting is faster for light roasts. Contradicts [[drum-roaster]], which says drum roasting reaches first crack sooner.
```

Add the mirror flag to the page it points at so the contradiction is visible from both sides.

### Step 6 — Update the index

Read `wiki/index.md`. Add new pages to the appropriate section. Remove links to pages that were deleted (rare). Keep the existing organization.

### Step 7 — Append to the changelog

Append (newest at top) to `log.md`:

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

End with a status report listing files processed, files skipped (and why), and pages created/updated. Then point the user at the verification loop: "Next: run `/wiki-query \"what does <source> say about <topic>?\"` to verify the ingest." Suggest `/wiki-lint` if you flagged contradictions or noticed gaps.
