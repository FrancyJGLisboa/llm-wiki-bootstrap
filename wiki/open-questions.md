---
title: Open Questions
type: analysis
source: analysis
updated: 2026-05-25
tags: [system, analysis, gaps]
---

# Open Questions

> **This page is `source: analysis`.** These are gaps the video doesn't address — questions that a working implementation has to answer, but for which we don't have guidance from the video. Each will be resolved by use, not by re-watching.

## Definition / TL;DR

The video shows the LLM-wiki pattern at a high level. There are several questions that any working system must answer in practice, but that the video doesn't address. They're listed here so they're tracked rather than forgotten.

## Operational questions

### Are the new extraction handlers actually correct?

Added 2026-05-25 (see [[commands]] and `AGENTS.md` "Supported source formats and extraction"): the DOCX (`pandoc` / `python-docx`), XLSX (`xlsx2csv` / `openpyxl`), CSV (passthrough + markdown-table preview), and PDF-LLM-vision-fallback handlers are **specified, not demonstrated**. None have been invoked end-to-end.

Concrete unknowns:

- Does `pandoc -f docx -t markdown` reliably preserve tables and lists across the kinds of DOCX our users actually have? Or do we hit edge cases (track-changes, embedded images, footnotes)?
- Does the `xlsx2csv` → markdown-table pipeline produce something the LLM can actually reason over, or does the loss of cell formatting break things?
- For CSVs with >100 rows, is "first 20 + truncated" the right cutoff? Or should we sample (header + 20 random) for better representativeness?
- For PDF-LLM-vision fallback: does the agent actually engage vision on a PDF when `pdftotext` returns near-empty? How does it know "near-empty" — character count threshold?
- Does the `extraction_status: failed` sidecar pattern actually surface usefully to `/wiki-ingest` later, or does ingest treat it the same as a successful extraction and pollute the wiki?

First real `/wiki-extract` on each format is the smoke test. Until then, the matrix in `AGENTS.md` describes what the system *intends to do*, not what it has been observed doing.

**Partial status (2026-05-25):** the markdown and CSV paths are now covered by canary fixtures (`tests/canary/canary-smoke-test.md`, `tests/canary/canary-csv.csv`) and shape-checked by `scripts/verify-extract.sh`. DOCX, XLSX, and the PDF-LLM-vision fallback remain undemonstrated.

### The most important open question: do the 7 steps actually happen?

**Resolved 2026-05-26.** The end-to-end smoke at `scripts/smoke-all.sh` (driven by `.scratch/plug-and-play-curator-smoke/GOAL.md`) drove `/wiki-ingest` on a fictitious fixture (`tests/smoke/smoke-source.md` — "phase coherence engineering" / Quortex protocol / Dr. Alma Voss) on first try, and produced: 4 new wiki pages (`smoke-source-summary`, `quortex-protocol`, `dr-alma-voss`, `phase-coherence-engineering`), an update to `wiki/index.md` cross-referencing the new pages, a fully-populated `ingested_*` frontmatter block on `raw/smoke-source.md`, and a structured `log.md` entry covering all 4 sub-actions (Processed / Created / Updated / Contradictions flagged). A subsequent `/wiki-query` answered with the literal "47 phase rotations" anchor AND a citation back to `raw/smoke-source.md`. All 9 smoke checks passed (5 behavioral + 4 regression guards). The original concrete unknowns are now answered observationally:

- *Will the LLM perform all 7 steps?* Yes on this fixture. Steps 3 (summary page) and 5 (contradictions flagged) both happened; the log entry includes the "Contradictions flagged: none" line correctly.
- *Step 4 blast radius?* On this small (51-line) fixture: 4 created + 1 updated. Below the video's 10-15 target, consistent with the fixture being shorter than the video transcripts.
- *Step 5 sensitivity?* Untested here — the smoke fixture's domain is disjoint from the existing meta-wiki, so there was nothing to contradict.
- *Token / time budget?* First run ~45s wall-clock for the full ingest + query; idempotent reruns sub-second.

Below is the original framing, kept for context.

Specified in three places — the source slide, [[ingest-pipeline]], and the prompt body of `.claude/commands/wiki-ingest.md`. Demonstrated nowhere. `/wiki-ingest` has never been invoked in this project; the initial wiki was hand-written during the design conversation, simulating the pipeline.

Concrete unknowns:

- Will an LLM following the prompt perform **all 7 steps**, or quietly skip some? (Step 5 contradiction-flagging and step 3 summary-page creation are the most likely to be skipped — the latter was in fact skipped in the manual bootstrap and backfilled later.)
- For step 4 ("update existing pages"), what's the right blast radius? The video says "10-15 pages per source." If the LLM only touches 2-3 the compounding effect dies; if it touches 50 the wiki churns.
- For step 5, what counts as a contradiction subtle enough to flag? Naive string-mismatch is too narrow; deep semantic comparison may exceed the LLM's reliability.
- Token / time budget per ingest call?

The smoke test is the first invocation of `/wiki-ingest <new-source>`. Until then, the operation pages describe an intention, not a measurement. See [[operation-ingest]]'s "Verification status" section.

### Concurrency

The video mentions the YouTuber's Claude Code running *two parallel ingest agents* during the initial ingestion of 8 transcripts. `(source: raw/karpathy-llm-wiki-video-transcript.md#10:08)` But it doesn't say:

- What happens if both agents try to update the same wiki page simultaneously?
- Should `/wiki-ingest` run sources serially or in parallel by default?
- Is there a locking mechanism, or are conflicts resolved post-hoc by [[operation-lint]]?

Likely tentative answer: serial by default; future versions can opt into parallelism with a coarse lock per page or a merge step.

### Conflict resolution

The video says step 5 of [[ingest-pipeline]] flags contradictions. But it doesn't say:

- What does the wiki *look like* when a contradiction is flagged? An inline note in both pages? A separate "contradictions" page? A frontmatter field?
- Who resolves it — the user manually, the LLM with web-search arbitration, the user with LLM advice?
- What if both claims are sourced — do we prefer the more recent, the more specific, the more authoritative?

### Lint cadence

[[operation-lint]] is described but not scheduled. Questions:

- Should `/wiki-lint` run automatically after every `/wiki-ingest`?
- Periodically (cron-style)?
- Only on user demand?
- On wiki size thresholds (e.g., every 50 new pages)?

### Versioning

The video doesn't discuss version control. Questions:

- Is the wiki under git by default? (Probably yes — it's just markdown.)
- Does `/wiki-ingest` commit after each ingest? Or batch?
- How are bad ingests rolled back? `git reset` or `/wiki-lint --rollback`?

### Multi-user

All use cases in [[use-cases]] are implicitly single-user. Real teams need:

- Multiple curators (different people drop sources into `raw/`)
- Concurrent edits to the schema
- Per-page provenance (who added what)
- A merge story for two wikis being combined

Out of scope for V1.

## Design questions

### Privacy and secrets

Raw sources may contain PII, credentials, or confidential information. The wiki, being a synthesis, can leak that information in unexpected ways (e.g., "Customer X mentioned their internal system Y" propagated across 5 pages). Questions:

- Should there be a `secret: true` frontmatter field that redacts certain sources from ingest?
- How to handle raw sources that should never be promoted (only used as context for queries)?
- Audit log for what was read when answering a query?

### When to NOT promote

[[query-as-write-loop]] auto-promotes notable answers. But:

- One-off lookups don't deserve a permanent page.
- Sensitive questions ("what's a good gift for my partner") may not belong in the wiki.
- How does the LLM decide?

Current heuristic: notable = introduces a new term, makes a new connection, cites a new external source. May need refinement.

### Wiki page lifecycle

When does a page:

- Get created? (Concept gets mentioned ≥ N times? Or any mention?)
- Get split? (Page exceeds size threshold?)
- Get merged? (Two pages overlap heavily?)
- Get deleted? (Orphaned + stale + no value?)

No video guidance. Likely answered through use + lint feedback.

### Index page structure

The video shows an `index` page that's the "master catalog." But:

- Is the index a flat alphabetical list? Categorized? Graph-style?
- Does the LLM regenerate it on every ingest, or append?
- How does the LLM avoid the index becoming the bottleneck (a huge file that grows linearly with wiki size)?

## Architectural questions

### Where do derived artifacts live?

The video mentions the LLM can output slideshows, markdown files, matplotlib images as query results. `(source: raw/karpathy-llm-wiki-video-transcript.md#14:40)` Where do these go?

- In `wiki/` (mixed with knowledge pages)? Probably bad — they're outputs, not knowledge.
- In a separate `outputs/` directory? Possibly.
- Streamed to the user without persistence? Default, probably.

### Fine-tuning loop

[[four-principles]] #4 (BYO AI) mentions you can *"fine-tune a model on your wiki so it knows your data in its weights."* `(source: raw/karpathy-llm-wiki-video-transcript.md#6:25)` This implies a workflow:

- Export the wiki as training data
- Fine-tune (LoRA?) on it
- Swap the model into the agentic tool

None of this is described in the video. It's a promising path but entirely outside V1.

### MCP / API surface

**Resolved 2026-05-26.** `scripts/mcp-server.sh` launches [`@bitbonsai/mcpvault`](https://github.com/bitbonsai/mcpvault) pointed at `wiki/`, exposing read, BM25 search, and (optionally) write tools to any MCP-aware client (Claude Desktop, Claude Code, Cursor, ChatGPT Desktop, etc.). The integration is opt-in and additive — no change to the three-layer model or the five slash commands. Recommended posture is read-only via MCP; writes still flow through `/wiki-ingest` and `/wiki-query` so `log.md` stays accurate. Setup details in [`docs/MCP.md`](../docs/MCP.md). The remaining sub-question is whether out-of-band MCP writes that touch `ingested_*` fields will break ingest idempotence in practice — to be observed once real users start writing through MCP.

## Use-of-this-page

This page is consumed by [[operation-lint]] — the LLM may suggest resolving specific questions when it has accumulated relevant evidence (e.g., after enough ingests, propose an answer for "should ingest run serial or parallel?"). When a question is resolved, move it to the relevant concept page and delete it here.

## Related

- [[implicit-constraints]] — constraints the video also doesn't state, but that we infer
- [[commands]] — the spec answers some of these tentatively
- [[operation-lint]] — the mechanism that should periodically surface these
- All operation pages — most questions touch one of [[operation-ingest]], [[operation-query]], [[operation-lint]]
