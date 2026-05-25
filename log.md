# log.md

Append-only log of every `/wiki-ingest`, `/wiki-query` promotion, and `/wiki-lint --apply` operation. Newest at top.

## 2026-05-25 15:30 — canary + verify-extract.sh: smoke test for first /wiki-extract

"Specified, not demonstrated" was the honest status of `/wiki-extract` after PR #1. This commit ships the smallest possible **shape** test: a known-good canary source + a shell verifier. The user runs `/wiki-extract` on the canary in their AI tool, then runs the verifier in shell to get a green/red signal on whether the produced output has the expected frontmatter and body. **Shape only — not semantics.**

- **New `tests/canary/canary-smoke-test.md`**: tiny plain-markdown source (~30 lines) used as the known-good input. Self-describing — explains what should happen and what shouldn't.
- **New `scripts/verify-extract.sh <slug>`**: pure bash verifier. Locates the produced `raw/<slug>.<ext>` or sidecar `<slug>.<ext>.md`, parses the frontmatter, checks that required fields (`source_url`, `source_type`, `fetched_at`, `extraction_method`) are non-empty, that `ingested_hash` is present-but-empty, and that body content exists. TTY-aware coloring, exit 0 on pass / 1 on fail / 2 on usage error.
- **Honest scope:** shape only. Verifier can catch: missing output file, malformed frontmatter, absent/empty required field, empty body. Verifier CANNOT catch: wrong `source_type` value, hallucinated `source_title`, `extraction_method` recorded incorrectly. Semantics need a human eye on `raw/<slug>.*`.
- **docs/QUICKSTART.md**: new "Smoke test (recommended)" section between "Before you start" and "The 5 operations" walking the user through the canary flow.
- **README.md**: project-layout tree updated with the new script and the `tests/canary/` directory.

Also in this commit: drift cleanup. The QUICKSTART operations table (separate from the per-tool sequences below it) still used the old verb names `fetch` and `ask` — leftover from PR #1's sed which only touched `wiki-fetch`/`wiki-ask` literals. Updated to `extract`/`query` to match the rest of the doc.

Verified on the working tree (without touching tracked files): 4 cases — no raw file → exit 1 with "Not ready" message; happy-path raw → exit 0 with all green; missing `extraction_method` → exit 1 with one fail line; malformed frontmatter (no closing `---`) → exit 1 with multiple failures. Cleanup confirmed `raw/` returned to its 3 tracked files.

## 2026-05-25 15:15 — scripts/wipe-meta-wiki.sh: clean-slate helper

Today's "start fresh" flow was three commands in QUICKSTART (`rm -rf wiki/*.md raw/* && touch wiki/index.md`) — easy to typo and easy to skip the index touch, leaving the next `/wiki-extract` confused. Added a single-command helper.

- **New `scripts/wipe-meta-wiki.sh`**: pure bash, mirrors `body-hash.sh`/`preflight.sh` style. Wipes `wiki/*.md` and `raw/*`, recreates `wiki/index.md` as a minimal stub with valid frontmatter, resets `log.md` to its header line.
- **Safety:** interactive `[y/N]` confirmation by default; `--yes` flag to skip. Inventories file counts before wiping so the user sees what's about to disappear.
- **Idempotent:** re-running on an empty wiki shows "nothing to do" and exits 0. (Actually re-wipes the stub index and rewrites it; functionally idempotent.)
- **Preserves:** AGENTS.md, README.md, all shims, `.claude/commands/`, `scripts/`, `docs/`, LICENSE — everything that isn't generated content.
- **README.md + AGENTS.md + docs/QUICKSTART.md:** replaced the three hand-rolled `rm -rf` instructions with the new script. Project-layout tree in README updated.

Verified on a `/tmp/` copy: before (23 wiki files, 3 raw files) → after wipe (only index.md stub remains; raw/ empty; log.md reset). Idempotence checked — second run with `--yes` produced same end state.

## 2026-05-25 15:00 — AGENTS.md: schema_version = 1 declared

Started declaring a schema version on `AGENTS.md` so future schema changes have a coordination marker. Today's `AGENTS.md` (as merged in PR #1, before this change) is retroactively designated as the version-1 baseline. Future bumps are reserved for breaking/behavior-changing edits.

- `AGENTS.md`: added `**Schema version:** 1 (introduced 2026-05-25)` line near the top. Added a "Schema versioning" section before "When in doubt" describing the bump policy (breaking-change bumps only; additive opt-in changes don't bump; no runtime enforcement V1).
- No code changes. Slash commands today don't read this field. It's a marker for humans reviewing diffs and for future tooling.

Migration impact: none. Existing slash commands continue to work unchanged.

## 2026-05-25 14:30 — scripts/preflight.sh: fail-fast tool & permissions check

User-side install today is `git clone && cd` — no health check. Failures of `/wiki-extract` only surface at first invocation, sometimes silently (e.g., missing `pandoc` falls back to `python-docx`, which the user may not have either). Added a preflight script that probes the environment before the user runs any slash command.

- **New `scripts/preflight.sh`**: pure bash (mirrors the style of `body-hash.sh`), TTY-aware coloring, platform-aware install hints (`brew` on Darwin, `apt`/`dnf`/`pacman` on Linux).
- **Three check tiers:**
  - Hard requirements (`bash`/`awk`/`openssl`/`git` + write permissions on `raw/` and `wiki/`) — fail fast with exit 1 if missing.
  - Recommended optional tools (`pdftotext`/`pandoc`/`xlsx2csv` + `python-docx`/`openpyxl` fallbacks) — warn only.
  - AI runtimes (`claude`/`cursor`/`code`/`copilot`/`gemini`) — informational.
- **Summary line** classifies extraction coverage: "Ready. Full first-try: ... Partial: ... Degraded: ...". Maps directly to the `extraction_method` matrix in `AGENTS.md`.
- **Manual-run only.** No auto-execution, no post-install hook, no agent-side invocation. The user runs it when they want a snapshot.
- **README.md**: new optional-but-recommended line under Install pointing at the script; project-layout tree updated.
- **AGENTS.md**: one-line mention near the `body-hash.sh` reference so the agent knows the script exists and can suggest it when users hit `extraction_status: failed`.
- **Verification:** ran on this host (macOS, partial tool coverage). All hard reqs green, summary correctly classifies PDF as full / XLSX as partial / DOCX as degraded. Piped output drops ANSI codes correctly. Exit code 0 when hard reqs met.

This PR stacks on PR #1 (`feat/extract-rename`) because the preflight references the renamed `/wiki-extract` and the new `extraction_method` matrix in `AGENTS.md`. Merge PR #1 first.

## 2026-05-25 10:45 — /wiki-extract gains DOCX / XLSX / CSV handlers + PDF LLM-vision fallback

Real new behavior in the (just-renamed) `/wiki-extract` command. Previous coverage was URL, plain text, image, and PDF-via-`pdftotext`. New coverage adds DOCX (via `pandoc`), XLSX (via `xlsx2csv`), CSV (passthrough + markdown-table preview), and an LLM-vision fallback path for PDF when `pdftotext` is missing or returns near-empty output.

- **`.claude/commands/wiki-extract.md`**: step 1 (format detection) and step 3 (acquisition) extended with the new formats. Step 4 (frontmatter spec) gains `extraction_method` and `extraction_status` fields. Tool-availability check (`command -v`) is now mandatory before invoking any optional binary.
- **`AGENTS.md`**: new "Supported source formats and extraction" subsection with the format → handler matrix. File-naming rule updated to cover DOCX/XLSX (binaries → sidecar) and CSV (tabular text → sidecar). Frontmatter YAML block updated with the two new fields and the new `source_type` values.
- **`wiki/commands.md`**: `/wiki-extract` spec rewritten to mirror the new behavior table; tool-policy paragraph added.
- **`wiki/open-questions.md`**: new top entry under "Operational questions" — "Are the new extraction handlers actually correct?" — listing concrete unknowns per format. Same posture as the existing "do the 7 steps actually happen?" entry.
- **`README.md`**, **`docs/EXPLAIN.md`**: one-line updates to the `/wiki-extract` row to mention multi-format support.
- **`docs/QUICKSTART.md`**: no content update needed (the rename sed already swept it; existing examples still work).

**Verification status:** all four new handlers (DOCX/XLSX/CSV/PDF-LLM-vision) are **specified, not demonstrated**. First real `/wiki-extract` on each format is the smoke test. Same as the 7-step pipeline.

**Principle preservation:** every shell binary is optional with a declared fallback (`pandoc`→`python-docx`, `xlsx2csv`→`openpyxl`, `pdftotext`→`llm-vision`). A user with zero shell tools installed gets degraded but functional extraction. BYO-AI guarantee intact.

## 2026-05-25 10:30 — verb rename: fetch→extract, ask→query

User-facing mental model survey: new users naturally describe the workflow as "extract content from this file" and "query the wiki," not "fetch" and "ask." Renamed the two slash commands and updated all references across the repo. Pure mechanical rename — no behavior change.

- **Renamed:** `.claude/commands/wiki-fetch.md` → `wiki-extract.md`
- **Renamed:** `.claude/commands/wiki-ask.md` → `wiki-query.md`
- **References updated in 22 other files** via `sed`: AGENTS.md, CLAUDE.md, GEMINI.md, .clinerules, .cursor/rules/llm-wiki.mdc, .github/copilot-instructions.md, README.md, docs/QUICKSTART.md, docs/EXPLAIN.md, docs/pitch-vscode.html, .claude/commands/wiki-init.md, .claude/commands/wiki-lint.md, wiki/commands.md, wiki/division-of-labor.md, wiki/glossary.md, wiki/index.md, wiki/ingest-pipeline.md, wiki/karpathy-llm-wiki-video-transcript-summary.md, wiki/layer-raw-sources.md, wiki/operation-query.md, wiki/query-as-write-loop.md, wiki/source-attribution.md, wiki/three-layer-architecture.md.
- **Strategy:** hard rename. Repo is V2 and runtime-untested with no external users — aliases would be permanent bloat.
- **Gate verified:** `grep -rEn 'wiki-(fetch|ask)\b' . --exclude-dir=.git` returns only historical references inside this log.md (the 2026-05-25 06:45 bootstrap entry, which records the original file names at creation time).
- **What did NOT change:** the 7-step ingest pipeline, the body-hash algorithm, the three-layer model, frontmatter conventions, or the command bodies' behavior. Two prompts now carry their new names internally (`/wiki-extract $ARGUMENTS` and `/wiki-query $ARGUMENTS`); everything else is identical.

Follow-up commits on this branch (`feat/extract-rename`) will (a) expand `/wiki-extract` to handle DOCX, XLSX, CSV with graceful tool-chain fallback, and (b) refresh docs prose where the rename diff isn't sufficient.

## 2026-05-25 09:35 — docs/QUICKSTART.md: per-tool first-use sequences

User asked: "will users get a fluid experience?" Honest answer was no, for most. Highest-leverage fix identified: a per-tool first-use guide. Built it.

- New `docs/QUICKSTART.md`, English, ~260 lines.
- Structure: prereqs (incl. what to do with the shipped meta-wiki — keep / wipe / archive) → 5-operation mental model → per-tool sequences for Claude Code, Copilot CLI, VSCode + Copilot Agent Mode, Cline, Cursor, "other tools" → expected output (with symptom→cause→fix table for partial pipeline execution) → recovery via git → cost expectations → honest caveat about untested runtime → quick reference card.
- Each per-tool section gives the **exact natural-language phrasing** to invoke each workflow, since non-Claude-Code tools don't have slash commands. This was friction #1 from the earlier honest assessment.
- "What success looks like" section addresses friction #3 (no expected-output gabarito) by listing concrete observable outcomes (1 summary page, 3-10 wiki pages, log.md entry, index updated).
- README.md gains a callout to QUICKSTART right after the install command, plus the file is listed in the project layout.

Still NOT addressed by this commit:
- The `/wiki-init --replace-content` affordance for wiping the meta-wiki cleanly (friction #2). For now QUICKSTART tells the user the manual command.
- Recovery beyond `git checkout` (no `--dry-run`, no rollback command). Documented as a caveat, not solved.
- The actual runtime untested-ness (friction #4 + #5). Cannot be solved without someone running the system.

## 2026-05-25 09:15 — fix: pitch HTML had outdated Copilot claim

User correction: I claimed "Copilot é conversacional, não agentic" in the AI-extension tier table. Wrong — (a) GitHub Copilot CLI is a standalone agentic CLI competing with Claude Code, (b) VSCode + Copilot in Agent Mode (shipped 2025) does multi-step autonomous work.

- Rewrote the AI-extension tier table in `docs/pitch-vscode.html`. New top tier (★★★★★) groups Copilot Agent Mode, Copilot CLI, and Cline as peers. Continue/Roo/Cody one step below. Copilot Chat classic (without Agent Mode) demoted to ★★★. "No AI extension" stays bottom.
- Added project memory `ai-tool-capability-claims` to enforce: don't make blanket capability claims about AI tools from training data; verify first. Indexed in `MEMORY.md`.
- README.md needed no change (it already listed Copilot CLI as a peer tool — I just contradicted myself in the pitch).

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
