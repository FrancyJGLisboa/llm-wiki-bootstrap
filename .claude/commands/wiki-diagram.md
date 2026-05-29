---
description: Synthesize an audience-targeted diagram from a natural-language intent — retrieve from the wiki, score archetype candidates, let the user pick, generate a self-contained HTML poster. Read-only on raw/ and wiki/.
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "<what you want to show, and for whom>" [--pdf|--png]
---

You are executing `/wiki-diagram $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to turn a natural-language **intent** into a visual artifact by reasoning over the wiki: retrieve the relevant knowledge, propose the best diagram archetypes, let the user pick, and generate a self-contained HTML poster.

This is an **output command** in the semantic tier. It is distinct from `/wiki-visualize`:

- `/wiki-visualize` is **mechanical** — it renders structure that already exists (the `[[link]]` graph, mermaid blocks, slides). No reasoning about a query.
- `/wiki-diagram` is **semantic** — it composes a *new* diagram that answers an intent by synthesizing across pages.

## Read first

Read the vendored contracts under `templates/infographic/` — they are the single source of truth; do **not** invent your own archetypes, scoring, or design system:

- `templates/infographic/archetypes.md` — the 8 archetype lenses + content structures
- `templates/infographic/scoring-rubric.md` — the 4-dimension rubric and the ≥3.5 surfacing threshold
- `templates/infographic/generator-contract.md` — the design system + generation protocol
- `templates/infographic/example-poster.html` — a worked style scaffold (palette, fonts, layout)

## Invariants

- **Read-only on `raw/` and `wiki/`.** This command never edits wiki pages. It writes only the output artifact.
- **Wiki-only by default — no web search, no promotion.** A diagram is a *view* of existing knowledge. If the wiki lacks what the intent needs, say so and recommend running `/wiki-query` first to fill the gap, then re-running this.
- **Never invent connections** not supported by the retrieved pages. Every diagram cites its `source_pages`.
- Output goes to `diagrams/<slug>.html` (the `diagrams/` directory is git-ignored).

## Procedure

### 1. Parse intent
From `$ARGUMENTS`, extract: what to show, and the audience (default: "technical stakeholder" if unstated). Strip an optional `--pdf` or `--png` flag (remember it for step 5 — it also renders the poster to that format). If the intent is too vague to retrieve against, ask one clarifying question before proceeding.

### 2. Retrieve (reuse `/wiki-query` discipline)
Read `wiki/index.md` to locate candidate pages, then read the relevant pages (frontmatter + body). Gather the material that bears on the intent. Note which pages you used — these become `source_pages`. Journal entries under `wiki/journal/` may be cited as evidence but never rewritten.

If retrieval comes back thin (the wiki doesn't cover the intent), stop and tell the user, recommending `/wiki-query "<intent>"` to fill the gap first.

### 3. Scan all 8 lenses and score
Apply **every** archetype lens from `archetypes.md` independently to the retrieved material. Score each candidate on the 4 dimensions in `scoring-rubric.md`. Mark hybrids. Route material that fits no lens to `archetype_gaps`.

### 4. Present the candidate menu
Show the user:
- Candidates scoring **≥ 3.5**, as a scored table (archetype, the 4 sub-scores, overall, one-line why-it-fired), best first.
- Lower-scoring candidates listed briefly.
- `archetype_gaps` — visualizable content no archetype captured (a signal for new archetypes).

Then ask the user to **pick one or more**.

### 5. Generate one poster per pick
For each chosen candidate, fill its `handoff_to_generator` block (the variables in `generator-contract.md`) and apply the generation protocol to produce a **single self-contained HTML file (no JavaScript, only Google Fonts external)**, using `example-poster.html` as the style scaffold and the archetype's content structure from `archetypes.md`. Write each to `diagrams/<slug>.html`. The footer must cite `source_pages`.

If `--pdf` or `--png` was passed, also render each poster to that format:

```bash
scripts/visualize/render.sh diagrams/<slug>.html --pdf   # or --png
```

If `render.sh` exits non-zero (no headless browser and no Node/puppeteer), it keeps the HTML and prints an install hint — surface that hint and point the user at the `.html` (degraded, not failed).

### 6. Report
Print the full path(s) written. Note that diagrams are interpretive (`source: analysis`-equivalent) — synthesized by the librarian, grounded in the cited pages, not extracted verbatim. Optionally suggest `/wiki-visualize serve diagrams` to browse them.

## What you must NOT do

- Edit anything under `raw/` or `wiki/`. Read-only; you only write `diagrams/*.html`.
- Web-search or promote new pages — that's `/wiki-query`'s job. If the wiki is insufficient, hand the user back to `/wiki-query`.
- Invent archetypes, scoring, or a design system — use the vendored contracts.
- Emit JavaScript or non-Google-Fonts external dependencies in the HTML.
- Fabricate connections the retrieved pages don't support.
