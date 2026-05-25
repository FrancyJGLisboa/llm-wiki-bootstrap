# log.md

Append-only log of every `/wiki-ingest`, `/wiki-ask` promotion, and `/wiki-lint --apply` operation. Newest at top.

## 2026-05-25 09:00 — pitch artifact: docs/pitch-vscode.html

User asked how I'd present the project to a VSCode-only audience. Wrote the pitch in chat, then user asked if it was persisted as HTML. It wasn't. Created `docs/pitch-vscode.html` — self-contained single-file pitch in PT (audience = self / internal reference, per follow-up clarification).

- Single file, zero external dependencies (no CDN, no JS, no remote fonts).
- Dark/light theme via `prefers-color-scheme`.
- Print-friendly (`Cmd/Ctrl+P` → PDF).
- Content: hook, 30s premise, 5-step flow, AI-extension tier matrix (Cline > Continue/Roo/Cody > Copilot Chat > nothing), 4 concrete problems, honest caveats, 3 implicit principles, closing slide.
- README.md updated to list `docs/` in the project layout.

This is documentation, not part of the wiki layer — it lives in `docs/` because it's a one-shot artifact for external presentation, not a knowledge page that grows via ingest/lint. No frontmatter, no link convention. Pure HTML by user choice.

## 2026-05-25 08:45 — codified verification-gap honesty

User asked the sharp epistemic question: do the 7 steps actually happen, or are they just specified? Direct answer: the latter — no LLM has invoked `/wiki-ingest` in this project; the wiki was hand-written in the design conversation. To make this surface in the wiki itself rather than only in chat:

- Added "Verification status (as of 2026-05-25)" subsection to `wiki/operation-ingest.md`, naming what is and isn't tested.
- Added a new section at the top of `wiki/open-questions.md` under Operational questions, titled "The most important open question: do the 7 steps actually happen?".

No body content was changed in any other page; the existing 7-step descriptions stand as specifications. The wiki is now honest about which of its claims are demonstrated and which are aspirational.

## 2026-05-25 08:30 — second raw source (slide) + project-wide rename CHANGELOG.md → log.md

User shared the "What happens when you ingest a source" slide from the same video as a screenshot. The slide is **more prescriptive** than the spoken transcript in two places: it names the index file as `index.md` and the log file as `log.md`, and it adds that step 6's index entry is "a catalog entry with link and one-line summary."

- **New raw source:** `raw/karpathy-video-slide-ingest-pipeline.png` (binary) + `raw/karpathy-video-slide-ingest-pipeline.png.md` (sidecar with vision-extracted text + visual description). Hash `cfe8e91a`. Dogfoods the image-acquisition convention (binary + sidecar) for the first time.
- **Project-wide rename:** `CHANGELOG.md` → `log.md` to honor the source video. Touched 18 files: AGENTS.md, README.md, CLAUDE.md, GEMINI.md, .clinerules, .cursor/rules/llm-wiki.mdc, .github/copilot-instructions.md, all 5 .claude/commands/wiki-*.md, and 6 wiki/*.md pages. The rename is recorded in `wiki/source-attribution.md` as a video-aligned decision (previously a project deviation).
- **Refined `wiki/ingest-pipeline.md`** steps 6 and 7 to match the slide's exact wording: step 6 now says "catalog entry with link **and one-line summary**"; step 7 explicitly names `log.md`. Both steps now carry a second source citation pointing at the slide.
- **Created `wiki/karpathy-video-slide-ingest-pipeline-summary.md`** (`type: summary`, `source: video`) — per-source recap of the slide per the `ingest-pipeline`'s step 3 convention.
- **Created `wiki/karpathy-llm-wiki-video-transcript-summary.md`** (`type: summary`, `source: video`) — the missing summary page for the original transcript. Backfills a convention violation from the initial bootstrap (no summary page existed for the first source).
- **Updated `wiki/index.md`** with a new "Source summaries" section listing both summary pages.
- **Updated `wiki/source-attribution.md`** to add the slide as a second source and to record the `CHANGELOG.md → log.md` rename as video-aligned.
- **Updated raw frontmatter** on both sources: transcript's `ingested_pages` adds the new summary; slide sidecar's `ingested_hash`/`ingested_at`/`ingested_pages` populated.

Net: 2 raw sources, 23 wiki pages. Body hash of transcript unchanged (`3054546f`) — still skippable on next `/wiki-ingest`. Slide sidecar now has its `ingested_hash` populated.

## 2026-05-25 08:05 — follow-up: extracted "knowledge compounds" as a first-class page

User observation: the compounding-of-knowledge point (LLM doesn't restart from scratch per question; cross-refs pre-built) is one of the most important arguments in the video, but it was scattered across `core-idea`, `problem-with-naive-rag`, `operation-ingest`, and `query-as-write-loop` rather than living in a dedicated page.

- Created `wiki/knowledge-compounds.md` (`source: mixed`) — synthesizes the compounding thread from three angles (negative-RAG case, positive-wiki case, the per-source compounding effect) and names the two engines (ingest + query-as-write-loop). Citations to transcript timestamps 1:12-1:30, 1:36-1:55, 5:30-5:40.
- Updated `Related` sections in: `core-idea.md`, `problem-with-naive-rag.md`, `operation-ingest.md`, `query-as-write-loop.md`, `ingest-pipeline.md`, `division-of-labor.md`, `four-principles.md` — all now link to `knowledge-compounds`.
- Updated `wiki/index.md` under Foundations + the literal-reading-order list.
- Updated `raw/karpathy-llm-wiki-video-transcript.md` `ingested_pages` to include the new page. Body hash unchanged (`3054546f`), so future `/wiki-ingest` runs still skip the source.

This is the kind of follow-up `/wiki-lint` would surface as a "gap" — a heavily-referenced concept without its own page. The next time `/wiki-lint` runs, it should report zero such gaps for "compounding."

## 2026-05-25 07:10 — V2 multi-tool portability shims added

- Created `.cursor/rules/llm-wiki.mdc` — Cursor rules pointing at `AGENTS.md` + workflows.
- Created `.clinerules` — Cline shim.
- Created `.github/copilot-instructions.md` — GitHub Copilot shim.
- Created `CLAUDE.md` — shim for older Claude Code versions that load `CLAUDE.md` instead of `AGENTS.md`.
- Created `GEMINI.md` — shim for Gemini CLI.
- All shims reference `AGENTS.md` as canonical; they exist to give every tool's auto-loader something to discover. The Claude Code slash commands in `.claude/commands/wiki-*.md` remain the only first-class implementations; other tools invoke the same workflows via natural language.
- Updated `README.md` with the per-tool support matrix and revised project layout.

## 2026-05-25 06:45 — bootstrap (manual ingest)

Initial bootstrap of `llm-wiki-bootstrap`. The repository's first wiki was produced by an interactive design session rather than by `/wiki-ingest`, but the result honors the same conventions and the raw source is now ready for re-ingest at any time.

- Processed: `raw/karpathy-llm-wiki-video-transcript.md` (hash `3054546f`)
- Created:
  - `wiki/index.md` (navigation)
  - `wiki/core-idea.md`, `wiki/problem-with-naive-rag.md`, `wiki/three-layer-architecture.md` (foundations)
  - `wiki/layer-raw-sources.md`, `wiki/layer-wiki.md`, `wiki/layer-schema.md` (architecture)
  - `wiki/operation-ingest.md`, `wiki/operation-query.md`, `wiki/operation-lint.md`, `wiki/ingest-pipeline.md` (operations)
  - `wiki/division-of-labor.md`, `wiki/four-principles.md`, `wiki/query-as-write-loop.md`, `wiki/use-cases.md` (foundations)
  - `wiki/commands.md`, `wiki/implicit-constraints.md`, `wiki/open-questions.md`, `wiki/source-attribution.md`, `wiki/glossary.md` (analysis)
- Created (system files):
  - `AGENTS.md` (canonical schema)
  - `README.md` (install + quickstart)
  - `.claude/commands/wiki-init.md`, `wiki-fetch.md`, `wiki-ingest.md`, `wiki-ask.md`, `wiki-lint.md`
- Contradictions flagged: none
- Notes:
  - `raw/karpathy-llm-wiki-video-transcript.md` is a third-party YouTuber's walkthrough, not Karpathy's tweet verbatim. See `wiki/source-attribution.md`.
  - 6 pages marked `source: analysis`: 5 analytical content pages (commands, implicit-constraints, open-questions, source-attribution, glossary) plus 1 navigation page (index).
  - 3 pages marked `source: mixed` (layer-raw-sources, layer-wiki, layer-schema — video extraction + project-specific convention details).
  - 11 pages marked `source: video` (all literal extractions from the transcript).
  - The raw file's frontmatter has been updated with `ingested_hash`, `ingested_at`, and `ingested_pages` so future `/wiki-ingest` runs skip it unless the body changes.
  - `scripts/body-hash.sh` ships as the canonical hash algorithm. The recorded `ingested_hash` was computed via this script; future `/wiki-ingest` runs must use the same script (per AGENTS.md) for idempotence.
  - **Slash command runtime is NOT yet validated.** All five `.claude/commands/wiki-*.md` files exist and are well-formed, but no command has actually been invoked. The first real-session invocation will be the smoke test. The bootstrap of the wiki itself was done by direct file writes during the planning conversation, not by `/wiki-ingest`.
