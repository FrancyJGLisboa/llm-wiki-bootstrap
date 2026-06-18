---
name: long-source-tree-retrieval
status: ready-for-agent
created: 2026-06-18
---

# Long-source hierarchical tree retrieval (PageIndex port)

> Port OpenKB's PageIndex idea into the BYO-agent model: a deterministic script segments any **long source** into a hierarchy of sections with positional ranges; the agent authors a compact summary tree at ingest and, at query time, walks the tree to read only the relevant sections — instead of swallowing a flat blob.

## §1 Context

Today `/wiki-extract` turns a long PDF (or long transcript / big DOCX) into **one flat text blob** in the sidecar `raw/<slug>.<ext>.md`. Two costs follow: (1) at `/wiki-ingest` the agent must read the entire blob to write summary/concept pages → context rot on a 300-page doc; (2) at `/wiki-query` there is no way to pull *one section* of the source back — the synthesized wiki pages are all that's consulted, and `/wiki-query` Step 1 only greps `wiki/`, never the raw source.

OpenKB solves this with the `pageindex` library (a stochastic, LLM-driven Python engine). We cannot adopt that — it breaks the no-engine, no-API-key contract. But PageIndex's algorithm splits cleanly along this repo's existing seam:

- **Deterministic mechanics → a script.** Segmenting a document into a section hierarchy with positional ranges (PDF outline/headings → page ranges; transcript → timestamp ranges; markdown/DOCX → heading ranges) is pure parsing. No LLM. This is *more* auditable than PageIndex's black-box TOC guess.
- **LLM judgment → the agent.** Writing a one-line summary per node (ingest) and choosing which nodes to read (query) stays with the agent.

The retrieval primitive already exists: `scripts/vtt-to-md.sh` structures transcripts with `## (m:ss)` anchors and citations use `(source: raw/<file>#<anchor>)`. A long source becomes a sidecar of `## <Section> (<range>)` anchors — so the existing grep + anchor + citation machinery performs the tree-walk with **no new query tool, no JSON index, no vector store**.

Decisions (confirmed): **scope = any long source** (PDF page-ranges, transcript timestamp-ranges, doc heading-ranges); **segmenter = smart with graceful fallback** (PDF outline/bookmarks → font-size heading detection → fixed page-window; text/markdown → heading levels → fixed paragraph-window).

Out of scope: semantic/BM25 ranking, a runtime vector store, changing short-source handling, reworking synthesis artifacts.

## §2 Definition of done (one sentence)

A new deterministic segmenter converts any over-threshold source into an anchored, sectioned sidecar (idempotent and lossless); `/wiki-extract` routes long sources through it; `/wiki-ingest` authors the summary page as a tree of one-line section summaries each citing a resolvable anchor; `/wiki-query` reads the tree and fetches only the cited sections; and a fixture-driven verifier proves all of this with exit codes while no existing verifier regresses.

## §3 Success checks (the oracle)

Deterministic core (no agent needed — run by `scripts/verify-segment-doc.sh`):

| # | Check | Shell predicate (intent) |
|---|---|---|
| C1 | Fixture exists: a long multi-section source with known section anchors | `test -f tests/segment/long-source.md && [ "$(grep -c '^## ' tests/segment/long-source.md)" -ge 6 ]` |
| C2 | **Deterministic**: segmenter run twice → byte-identical sidecar | `scripts/extract/segment-doc.py FIX > /tmp/a; scripts/extract/segment-doc.py FIX > /tmp/b; diff -q /tmp/a /tmp/b` |
| C3 | **Lossless**: concatenated section bodies reproduce the source text (no dropped content) | verifier strips section-anchor headings from sidecar, normalizes whitespace, diffs against normalized source → empty |
| C4 | **Anchored tree**: every section emits a heading with a positional range, ≥ one per source section | `[ "$(grep -cE '^#{1,6} .+\((lines\|pages) [0-9]+-[0-9]+\)$' SIDECAR)" -ge SECTIONS ]` |
| C5 | **Anti-gaming — machine-derived, not hand-authored**: regenerating the sidecar from the source byte-matches the committed sidecar (anchors cannot be faked) | `scripts/extract/segment-doc.py FIX | diff -q - tests/segment/expected-sidecar.md` |

Agent-side (driven by `claude -p`, composed into `scripts/smoke-all.sh`):

| # | Check | Shell predicate (intent) |
|---|---|---|
| C6 | **Summary tree**: post-ingest, the source's summary page is a hierarchy whose every leaf cites an anchor that **exists** in the sidecar | each `(source: raw/<slug>...#<anchor>)` in the summary page resolves to a `## …` heading-slug present in the sidecar (no broken anchors) |
| C7 | **Targeted retrieval (anti-gaming)**: a question answerable from exactly one section returns a correct, cited answer whose citation anchor is that **specific section**, not the whole doc | `grep -F '<section-specific-fact>' last-answer.md && grep -E 'raw/<slug>[^ ]*#<that-section-anchor>' last-answer.md` |

Regression guards:

| # | Check |
|---|---|
| R1 | `./scripts/preflight.sh` stays green |
| R2 | `./scripts/verify-extract.sh` stays green |
| R3 | `./scripts/smoke-all.sh` (existing checks) stays green |
| R4 | `AGENTS.md` schema version line unchanged; existing core-script shebangs intact |

## §4 Design (where each piece lives)

- **New:** `scripts/extract/segment-doc.py` — deterministic segmenter. Input: a source file (+ detected type). Output (stdout): sectioned markdown sidecar with `## <Title> (<range>)` anchors, each section's text below. Strategy ladder: PDF→ outline/bookmarks → heading-by-font-size → fixed page-window; text/md→ heading levels → fixed paragraph-window. Reuses tools `/wiki-extract` already probes (pdftotext/pymupdf); missing tool → `extraction_status: degraded`, never silent (repo rule).
- **New:** `scripts/verify-segment-doc.sh` + `tests/segment/{long-source.md, expected-sidecar.md}` — the C1–C5 oracle.
- **Edit:** `.claude/commands/wiki-extract.md` — route over-threshold sources through the segmenter; record `extraction_method: segment-doc` and the section count in frontmatter.
- **Edit:** `.claude/commands/wiki-ingest.md` (Step 3) — for a sectioned source, author the summary page as a tree of one-line section summaries, each citing its anchor; read the source **section-by-section**, never as one blob.
- **Edit:** `.claude/commands/wiki-query.md` (Step 1) — when a summary page is a section tree, read the tree, pick anchors, read only those sections from the sidecar.
- **Edit:** `AGENTS.md` — document the sectioned-sidecar + summary-tree convention under the raw-source / citation sections (no schema-version bump; additive).

## §5 Threshold

Over-threshold = long enough that flat ingest hurts. Use a **word-count** gate (generalizes across PDF/transcript/DOCX) with a sensible default (≈ 6,000 words) plus a PDF page-count shortcut (≥ 20 pages, OpenKB parity). Short sources keep today's flat-sidecar path untouched (C/R guards enforce no regression).

## §6 Stop / escalate

- If `pdftotext` AND `pymupdf` are both absent → segmenter exits with a degraded sidecar (flat blob + `extraction_status: degraded`) and a clear install hint; this is a pass, not a crash.
- Do not touch the unrelated uncommitted work on `main` (SELLING.md, package-wiki.sh, etc.).
