---
description: Answer a question from the wiki (web-search + auto-promote on gaps). Optionally also emit a diagram of the answer with --visual html|pdf|png.
allowed-tools: Bash, Read, Write, Edit, WebSearch, WebFetch, Glob, Grep
argument-hint: <question> [--no-promote] [--visual [html|pdf|png]] [--archetype <name>]
---

You are executing `/wiki-query $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to answer the user's question from the wiki and, when the wiki falls short, to fetch new knowledge and **file it back into the wiki**.

## Read first

**Run from the wiki root** (the directory with `raw/`, `wiki/`, `AGENTS.md`, `log.md`). If `AGENTS.md` is absent, you're not in a wiki: tell the user to run `/wiki-init` first (or `cd` into their wiki), then stop.

Read `AGENTS.md` (conventions). Read `wiki/index.md` to locate relevant pages.

## Parse the question

- Strip a `--no-promote` flag if present; remember it for step 5.
- Strip a `--visual [<format>]` flag if present; remember it for step 5.5. `<format>` ∈ {`html`,`pdf`,`png`}; a bare `--visual` means `html`. Absent ⇒ no visual.
- Strip a `--archetype <name>` flag if present; remember it for step 5.5 (forces a specific archetype instead of auto-selecting).
- Treat the rest as the question.
- If no question, ask the user what to ask.

## Steps

### Step 1 — Locate relevant pages

From `wiki/index.md` and via `Grep` over `wiki/`, identify the 3-10 pages most likely to contain relevant material. Read them (frontmatter + body).

### Step 1.5 — Causal traversal (when the question is causal)

If the question is **causal** — "what caused X?", "what are the downstream effects of Y?", "trace the chain from A to B", "why did Z happen?" — reason over the causal graph, not just nearest-page prose:

1. **Materialize the causal graph.** Check for `wiki/_kg.jsonl`; if absent, build it on demand with `scripts/wiki-to-kg.py --causal-only wiki/` (read-only — do **not** write the sidecar into `wiki/`). Each line is a directed triple `{"source","verb","target"}`, `verb` ∈ {`causes`,`caused-by`,`enables`,`prevents`,`contributes-to`}. **Causal direction lives only in these triples** — page bodies may be silent on, or even misleading about, which node causes which.
2. **Traverse by shelling out to `scripts/wiki-graph-walk.py` — do not walk the graph in your head.** A deterministic walk is correct and traceable every time; eyeballing a small graph is guess-prone, and a cyclic graph would loop. Pipe the causal KG into the walker:

   ```bash
   scripts/wiki-to-kg.py --causal-only wiki/ | scripts/wiki-graph-walk.py --start <slug> --direction down --max-hops 2
   ```

   - "downstream effects of Y" → `--start <y> --direction down`; "what caused X / why did X / root cause" → `--direction up`.
   - Add `--max-hops N` when the question bounds the distance ("two hops downstream", "the Nth node"); **omit** it for "the full chain / the root cause" — the walk is cycle-safe (a visited-set terminates even on a ring), so it returns the full reachable closure.
   - The walker prints the reached nodes in hop order (`{"hop","node","via"}`), start excluded. **Treat this output as authoritative.** (If `wiki-graph-walk.py` is absent — an older generated wiki — fall back to reasoning over the triples directly, walking backward for causes / forward for effects.)
3. Read the pages on the resulting node(s) for the requested detail (e.g. an attribute or `Code` in the body), then answer — citing each node as `[[page-name]]`. Follow any output-format instruction in the question literally (e.g. "reply with the integer only").

If the question is not causal, skip this step. The KG is a retrieval aid layered on the typed `## Related` edges — see `AGENTS.md` → "Causal relations".

### Step 2 — Try to answer from the wiki alone

Synthesize an answer using only what you've read. If the answer is complete and confident, present it to the user with citations: each non-trivial claim should reference the wiki page that supports it as `[[page-name]]`.

If the wiki suffices: skip to step 6 (no promote needed; nothing was newly learned).

### Step 3 — If the wiki is insufficient, search

Identify what's missing. Run `WebSearch` (and `WebFetch` for promising results) to fill the gap. Stay narrow — answer the user's question; don't drift.

### Step 4 — Synthesize the full answer

Combine wiki content + web-search results into a coherent answer. Make sure to cite:
- Wiki sources as `[[page-name]]`
- Web sources as `[<title>](<url>)`

### Step 5 — Promote (default behavior, unless `--no-promote`)

If web search produced **notable** new knowledge, file it back into the wiki. Notability = at least one of:
- Introduces a new term (worth a glossary entry + likely a concept page)
- Makes a new connection between existing pages
- Cites a new external source worth keeping

For each notable piece:
- If a relevant page exists: append the new claim with a `(source: <url>)` citation. Update `updated:` in frontmatter.
- If no page exists and the concept is non-trivial: create a new `wiki/<slug>.md` with `type: concept` or `type: entity`, `source: external`, and cite the URL.
- Update `wiki/index.md` to list the new page(s).
- Append a `log.md` entry:

  ```markdown
  ## YYYY-MM-DD HH:MM — /wiki-query "<short question>"

  - Web-searched: <urls>
  - Promoted: wiki/<file> (new) | wiki/<file> (updated)
  ```

If `--no-promote` was passed: skip this entire step. Mention to the user that promotion was disabled.

### Step 5.5 — Visual output (only if `--visual` was passed)

Produce a diagram **of the answer you just synthesized**, using the same archetype system and design as `/wiki-diagram` (the vendored Infographic-extractor contracts). The text answer is always produced; this is **additive**. Skip this step entirely if `--visual` was not passed.

1. **Read the contracts** (single source of truth — do not invent archetypes/scoring/design):
   - `templates/infographic/archetypes.md`, `templates/infographic/scoring-rubric.md`, `templates/infographic/generator-contract.md`, `templates/infographic/example-poster.html`.
   - If `templates/infographic/` is absent (an older generated wiki), tell the user the visual feature needs those contracts and skip — still deliver the text answer.

2. **Choose the archetype from the query.** Treat the synthesized answer (its claims, structure, and relationships) as the material. Score **all 8** archetypes on the 4 dimensions in `scoring-rubric.md`.
   - If `--archetype <name>` was given, use that one (validate it's one of the 8; if not, say so and fall back to auto).
   - Otherwise **auto-select the highest-scoring** archetype. If none clears the ≥3.5 threshold, pick the best available and note it's a weak fit. Always **report which archetype you chose and its score, plus one plain-English clause on why it fits** (e.g. "A5-causal-chain (4.2) — the answer is a cause→effect chain of drivers"). Then add: "Run `/wiki-diagram \"<intent>\"` to see all scored options and pick a different lens. The 8 archetypes are listed in `AGENTS.md` → Diagram archetypes."

3. **Generate the poster.** First ensure the output directory exists (it is git-ignored and absent in a fresh wiki — the Write tool fails on a missing parent):

   ```bash
   mkdir -p diagrams
   ```

   Then fill the chosen candidate's `handoff_to_generator` block and apply the generation protocol in `generator-contract.md` to produce a **single self-contained HTML file** (no JavaScript; only Google Fonts external), styled per `example-poster.html`. Write it to `diagrams/query-<slug>.html`, where `<slug>` is a kebab-case slug of the question. The footer must cite the **wiki pages** used (`source_pages`) and any **web URLs** that contributed to the answer. Never invent connections the answer doesn't support.

4. **Render to the requested format.** If `<format>` is `pdf` or `png`, run:

   ```bash
   scripts/visualize/render.sh diagrams/query-<slug>.html --pdf   # or --png
   ```

   - On success it writes `diagrams/query-<slug>.<pdf|png>` next to the HTML.
   - If `render.sh` exits non-zero (no headless browser and no Node/puppeteer), it **keeps the HTML** and prints an install hint — surface that hint to the user and point them at the `.html` (degraded, not failed). `html` format never needs `render.sh`.

### Step 6 — Present the answer

Give the user:
1. The answer itself (well-formed, scannable).
2. A "Sources" footer listing wiki pages read and any external URLs used.
3. If promoted: a one-line summary of what was filed into the wiki.

## What you must NOT do

- Make up facts when the wiki and the web don't support them. Say "I don't know" instead.
- Promote sensitive content (personal/medical/financial details the user mentioned in passing) without explicit consent.
- Drift from the question. The web search is a tool, not a research expedition.
- Modify `raw/`.
- Use Obsidian-specific markdown in promoted pages.

## Output format

```
<the answer>

---

Sources:
- Wiki: [[page-a]], [[page-b]]
- Web: <urls if used>

Promoted to wiki: wiki/<file> (new) | (nothing — `--no-promote` was set | wiki was sufficient)
Visual: diagrams/query-<slug>.<html|pdf|png> (archetype: <name>, score <n>) | (none — no --visual) | (HTML only — renderer missing, see hint above)
```
