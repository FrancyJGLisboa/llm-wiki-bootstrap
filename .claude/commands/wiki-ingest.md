---
description: Process raw/ into wiki/ via the 7-step pipeline, then regenerate synthesis artifacts. Detects deltas via body hash; idempotent on unchanged sources.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [<raw-file>]
---

You are executing `/wiki-ingest $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to integrate raw sources into the wiki using the 7-step pipeline.

## Read first

**Run from the wiki root** — the directory holding `raw/`, `wiki/`, `AGENTS.md`, and `log.md`. If `raw/` and `wiki/` are absent you are not in a wiki: tell the user to run `/wiki-init` first (or `cd` into their wiki), then stop.

Read `wiki/index.md` (what already exists) and `log.md` (recent activity). You don't need to re-read all of `AGENTS.md` — the page template you'll write is inlined below; consult `AGENTS.md` → "Wiki page convention" only for edge cases.

## Determine scope

- If `$ARGUMENTS` is empty: walk all files in `raw/`. For each, compute the current body hash by running **`scripts/body-hash.sh <file>`** (this is the canonical algorithm — do NOT recompute the hash inline with `sha256sum`, `shasum`, or a different awk pattern, or idempotence will break). Skip files whose `ingested_hash` in frontmatter matches the current hash.
- If `$ARGUMENTS` names a specific file: process only that file, regardless of hash.

If nothing to process: print "No changes to ingest.", **still run Step 8 (synthesis) below**, then exit — other commands (`/wiki-query` promote, `/wiki-lint --apply`) may have changed `wiki/` since the last synthesis, so the dashboards must be refreshed even on a no-op ingest. If `raw/` is **empty** (no sources at all), add: "Next: run `/wiki-extract <source>` to acquire a source, then `/wiki-ingest` again."

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

## The 7-step pipeline (run per raw file)

For each raw file that needs processing:

### Step 1 — Read the raw source

Read the file. For binaries (image, PDF), read the sidecar `.md` instead.

**If the sidecar is segmented** (frontmatter `segmented: true`): it is a section tree — a sequence of `#{level} <Title> (lines A-B | pages N-M)` anchors built by `segment-doc.py`. Skim the headings first to grasp the shape, then read **only the sections you need**, section by section. Do not load the whole blob into context — avoiding that is the entire point of segmentation (no context rot on a long doc).

### Step 2 — Extract key information

Identify: concepts (ideas, terms, patterns), entities (people, tools, places, datasets), claims (statements that could be true or false), data points (numbers, dates, quotes).

### Step 3 — Write a summary page

Create or update `wiki/<source-slug>-summary.md` with `type: summary`, `source: <type>` (matching the raw's `source_type` family — `video` for video-transcript, `external` for fetched web pages, etc.), and the source's main takeaways. Cite the raw inline with `(source: raw/<filename>#<anchor>)`.

**For a segmented source** (`segmented: true`): write the summary `## Body` as a **section tree** — a nested bullet outline mirroring the sidecar's heading hierarchy, **one line per node** summarizing that section, each ending with its anchor `(source: raw/<slug>.<ext>.md#<section-slug>)`. The `<section-slug>` is the kebab-case of the heading title **with the `(lines …)`/`(pages …)` range dropped** (e.g. `## Power Envelope (lines 13-19)` → `#power-envelope`). This compact tree — not a wall of prose — is what `/wiki-query` later walks to fetch only the relevant section. Every leaf's anchor MUST correspond to a real heading in the sidecar (no invented anchors).

### Step 4 — Update existing entity / concept pages

For each concept and entity from step 2:
- Glob `wiki/` to see if a matching page exists.
- If yes: read it, decide what to add, append the new claim with citation. **Do not duplicate existing content.**
- If no AND the concept/entity is referenced by 2+ raws OR is structurally important: create a new `wiki/<slug>.md` with `type: concept` or `type: entity`.
- Cross-link: every page that mentions another covered page should `[[wiki-link]]` to it.
- **Encode causation, don't bury it.** When the source states that one thing *causes / leads to / enables / prevents / contributes to* another, write that `## Related` link with a **canonical causal verb** — `causes`, `caused-by`, `enables`, `prevents`, or `contributes-to` (form: `- [[effect]] causes — <prose>`; put the inverse on the effect's page as `- [[cause]] caused-by — <prose>`). Do NOT flatten cause→effect into a plain `related-to`, and do NOT invent synonyms (`results-in`, `due-to`, `enabled-by`) — `scripts/wiki-lint-causal.sh` rejects those. These canonical edges are what let `/wiki-query` answer "what caused X / what does X enable / how does A connect to B" by graph traversal (see `AGENTS.md` → "Causal relations"). A multi-step causal story should become a *chain* of canonical edges across pages, not one lump.

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

### Step 5.5 — Faithfulness gate (verify claims against evidence before committing)

After writing/updating the pages for this source, verify every cited claim actually holds
against its `raw/` evidence — don't trust your own paraphrase. Run the gate over the pages
you created or updated in this ingest:

```bash
scripts/wiki-faithfulness-gate.sh --mode ingest wiki/<changed-page>.md [wiki/<more>.md ...]
```

It reuses `scripts/citation-audit.py` to extract each `(source: raw/<file>#<anchor>)` claim,
judges it against the cited passage (SUPPORTED / UNSUPPORTED / CONTRADICTED), and applies:

- **CONTRADICTED, or a broken citation → the gate exits non-zero (blocks).** Fix the
  offending claim — rewrite it to match the evidence, or drop the citation if the source
  doesn't support it — then re-run the gate **once**. If it still blocks, leave that page
  out of this ingest and tell the user, rather than committing an unfaithful claim.
- **UNSUPPORTED → the gate appends a `FAITHFULNESS UNVERIFIED` marker** to the claim's line
  (line count preserved) and passes. Leave the marker in place — `/wiki-lint` surfaces it
  later. Don't hand-delete it; cite better evidence or rephrase if you want it gone.

The entailment judgment uses the `claude` CLI. C3 entailment inherently needs an LLM, so
this is a **write-time gate** (ingest + promote), not a keyless-CI check: the deterministic
floor that CI/offline enforces is the citation audit (C1/C2, plus `--coverage`), **not**
entailment. With no judge available the gate **fails closed (exit 3)** rather than passing
unchecked — install the `claude` CLI, or pass `--allow-unjudged` to proceed on the citation
floor only (it prints a loud `FAITHFULNESS UNVERIFIED` warning so the gap is visible). This
is the BYO-agent analogue of the existing `eval-citation-faithfulness.sh` measurement, run
as a gate on the specific pages this ingest touched.

Follow-ups (deferred, not built here): a per-page `entailment: judged|skipped` frontmatter
marker, and a git pre-commit hook template that runs this gate.

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

## Step 8 — Regenerate synthesis artifacts (once, after all files)

After the per-file loop — and **also on the "No changes to ingest" path** — run the
synthesis regenerator exactly once:

```bash
./scripts/synthesize/all.sh
```

This is a **mechanical, deterministic** pass (no LLM work): it aggregates markers
you already wrote into four standing artifacts and rewrites them only if their
content changed.

- `wiki/open-questions-dashboard.md` — every `## Open questions on this page` section, grouped by page
- `wiki/tensions.md` — every `> CONTRADICTION FLAGGED` flag (step 5), newest first
- `wiki/decision-timeline.md` — reverse-chronological `log.md` activity timeline
- `wiki/knowledge-graph.json` — the `[[link]]` graph as deterministic JSON (reuses the `/wiki-visualize` parser)

These four are **generated, not authored**: never hand-edit them, never cite them as
sources, and don't count them when deciding what to create in step 4 — they are
overwritten on every run. If `scripts/synthesize/all.sh` is absent (older wiki), skip
this step and tell the user to re-scaffold with `scripts/create-llm-wiki.sh` to pick it up.

## What you must NOT do

- Edit anything in `raw/` other than the frontmatter fields `ingested_hash`, `ingested_at`, `ingested_pages`.
- Skip the changelog entry.
- Hand-edit the four Step-8 synthesis artifacts — they are regenerated mechanically.
- Use Obsidian-specific syntax in any wiki page.
- Promote orphan information (claims that don't relate to anything else) into their own page just to have something. Better: skip them and let lint surface gaps.

## Output

End with a status report listing files processed, files skipped (and why), and pages created/updated. Then point the user at the verification loop: "Next: run `/wiki-query \"what does <source> say about <topic>?\"` to verify the ingest." Suggest `/wiki-lint` if you flagged contradictions or noticed gaps.
