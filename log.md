# log.md

Append-only log of every `/wiki-ingest`, `/wiki-query` promotion, and `/wiki-lint --apply` operation. Newest at top.

## 2026-05-28 — /wiki-diagram (semantic output command)

Added `/wiki-diagram` (+ alias `/diagram`), the **semantic** member of the output tier: it takes a natural-language intent, retrieves relevant wiki pages (reusing `/wiki-query` discipline), scores all 8 diagram archetypes, presents a candidate menu, and on the user's pick generates a self-contained HTML poster to `diagrams/`. Distinct from `/wiki-visualize` (mechanical render of existing structure). Wiki-read-only; no web search/promotion by default.

- New: `.claude/commands/wiki-diagram.md` + alias `diagram.md`.
- Vendored (self-containment, no external skill dep): `templates/infographic/{archetypes.md, scoring-rubric.md, generator-contract.md, example-poster.html}` — from FrancyJGLisboa/Infographic-extractor. **License pending upstream** (add MIT/Apache to that repo).
- `.gitignore`: added `diagrams/`, `wiki-graph.html`, `anki.csv` (generated artifacts; also closes the prior litter gap from the visualize/flashcards tier).
- Manifest: 6 new files added to `scripts/installer-skeleton-manifest.txt` (verifier I4a).
- Docs: output-tier tables in AGENTS, README, README-FRESH, CLAUDE, GEMINI, copilot, clinerules, cursor, wiki/commands, QUICKSTART now list three commands, with the mechanical-vs-semantic boundary stated.

**Schema version: unchanged (v2)** — additive, opt-in. **Untested:** the command's prompt-body (retrieval + 8-lens scoring + HTML generation) is unrun; first real `/wiki-diagram` invocation is its smoke test.

## 2026-05-28 — output-command tier (/wiki-visualize, /wiki-flashcards)

Added two **output commands** that render/export an already-built wiki, sitting outside the five-command lifecycle loop. Both are read-only on `raw/` and `wiki/` (they write only new output artifacts) and are thin LLM dispatchers over existing scripts — no parsing logic reimplemented.

- New: `.claude/commands/wiki-visualize.md` + alias `visualize.md` — dispatch to `scripts/visualize/{graph,mermaid,slides,serve}.sh`.
- New: `.claude/commands/wiki-flashcards.md` + alias `flashcards.md` — wrap `scripts/wiki-to-anki.sh`.
- Manifest: added the 4 command files to `scripts/installer-skeleton-manifest.txt` so fresh installs ship them (verifier I4a).
- Docs: AGENTS.md, README.md, README-FRESH.md, CLAUDE.md, wiki/commands.md (+ cross-tool shims) now document the output tier alongside the five; resolved the dormant `/wiki-export` open question in wiki/commands.md.

**Schema version: unchanged (v2).** Per the AGENTS.md bump policy, new commands are a strictly opt-in addition (older clients simply lack them) — additive, not breaking, so no bump. Recorded here per the schema-versioning "record the change" guidance.

## 2026-05-27 17:45 — phase-2 kg-traversal

**verdict: phase-2b-abandoned-on-gate.** baseline 7/7 (100%, >> 40% threshold). C5 gate FAILED.

Implemented `.scratch/phase-2-kg-traversal/GOAL.md` Phase-2a only. New artifacts:

- `tests/eval/sparse-fixture/` — 7 hand-crafted pages of fictional supply-chain entities (zerlon, quirpal, bryntex, mordax, velnar, thalox, glivex). Each page body ≤ 100 words, no body sentence states direction or position. 8 typed `## Related` lines using 7 distinct verbs (feeds, powers, produces, ships-via, terminates-at, succeeds, replaces).
- `tests/eval/sparse-multi-hop-questions.md` — 7 multi-hop questions, all tagged `baseline-absent: true`, all `hops: 2` or `hops: 3`. Expects-tokens (`upstream`/`downstream`/`transitive`/`parallel`/`unreachable`) are NOT verb literals and are absent from the unstripped fixture prose (C4(d) + C4(e) both green).
- `scripts/eval-multi-hop-sparse.sh` — thin variant of `eval-multi-hop.sh` pointed at the sparse fixture. Stays sidecar-less in Phase 2a; would conditionally invoke `scripts/wiki-to-kg.py` in the typed work dir (only) if Phase 2b were active.

Gate result (`./scripts/eval-multi-hop-sparse.sh`):

- baseline: 7/7
- typed: 7/7
- delta: 0
- verdict: null-result on the eval itself; gate verdict: FAILED (baseline >> 40%)

**Reading.** The LLM extracts enough signal to answer the direction questions from sources the verb-strip does not touch:

1. **Connectivity survives stripping.** Stripped `## Related` lines keep slug-pair links — the baseline LLM still sees that zerlon connects to mordax, mordax connects to velnar, etc. Direction has to come from somewhere else, but only some-where else is needed.
2. **Page semantics leak through tags.** `tags: [sparse-fixture, alloy]` on zerlon, `tags: [..., vessel]` on mordax, `tags: [..., port]` on velnar are intact in both variants. The LLM uses tag semantics + world knowledge ("ore feeds refinery feeds alloy ships to port") to recover direction even without verbs.
3. **The question text is a teacher.** Every question names the verbs explicitly (`"Following only the forward supply edges (feeds, powers, produces, ships-via, terminates-at)"`). Even when those verbs are stripped from the markdown, the LLM reads the verb list in the prompt and applies it to the connections it sees.

Conclusion: **typed relations do not provide measurable retrieval signal even on a fixture engineered to need them.** The signal the typed graph carries is already encoded — redundantly — in connectivity + tags + question framing. A parallel KG layer would record what the LLM already infers. Not justified.

Decision per §7: **Phase 2b abandoned.** No `scripts/wiki-to-kg.py` written, no modifications to `.claude/commands/wiki-ingest.md` or `.claude/commands/wiki-query.md`, no `wiki/_kg.jsonl` artifact. C10 absence guards intentionally green.

**Future avenues (not pursued here, recorded for phase-3 design):**

- Strip tags AND verbs in the baseline (not just verbs) — would test whether tag semantics alone explain the result.
- Make question text neutral (do not name the verbs in the prompt) — would test whether the prompt is the teacher.
- Use questions whose answers require numerically combining attrs across hops (attrs get stripped; the LLM cannot reconstruct them from tags or world knowledge).
- Revisit the parallel-KG idea only after one of the above produces a measurably stricter discriminator.

The user-research signal recorded today — "users expect `/wiki-ingest` to create a KG" — is not addressed by this work and should not motivate building a KG on a null result. It is a phase-3 design input.

C1 regression-oracle: `./scripts/smoke-all.sh` exit 0; `./scripts/eval-multi-hop.sh` on the rich-prose Brazilian-ag fixture verdict `null-result` (no regression vs. phase-1's 5/5 = 5/5).

## 2026-05-27 14:00 — phase-1 typed-relations eval

**verdict: null-result** (baseline 5/5, typed 5/5, delta 0).

Implemented `.scratch/typed-wikilinks-semantic-viz/GOAL.md` (annotated `## Related` lines with optional verb + attr; pure CommonMark; backward-compat preserved by treating untyped and multi-link lines as implicit `related-to`). New `scripts/wiki-lint-typed-relations.sh` validates the verb regex (`[a-z][a-z0-9-]*`). `scripts/visualize/graph-html.py` extended: per-edge `verb` field in the JSON, a `<select id="verb-filter">` UI + `filterByVerb()` JS handler + per-verb edge colouring via `d3.schemeCategory10`.

Fixture: 6-page Brazilian-agriculture wiki built during the 2026-05-27 new-user simulation, frozen at `tests/eval/wiki-fixture/`. Typed verbs applied to 14/19 single-target Related lines (74%); 6 distinct verbs (`researches-for`, `defined-by`, `credit-for`, `complement-of`, `enables`, `summarized-in`). Verb tokens were chosen to be absent from the baseline prose (0 hits each) so stripping them removes a real signal.

Eval (`scripts/eval-multi-hop.sh`, 5 multi-hop questions, 3 tagged `baseline-absent: true`):

- baseline: 5/5
- typed: 5/5
- delta: 0

**Reading:** typed verbs alone did not improve `/wiki-query` accuracy on this fixture. The LLM is smart enough to infer the typed relationship from surrounding prose context even when the verb token is stripped — on Q1-Q3 (the `baseline-absent` set), the baseline LLM still produced the exact kebab-case verb (`enables`, `credit-for`, `complement-of`) via paraphrase + format-mimicry of the question. On a Wikipedia-derived wiki with rich prose, the marginal information added by typed verbs is dominated by what the prose already encodes implicitly.

**Implications for phase-2 (parallel knowledge graph):**

1. Typed-verb-in-markdown is not enough on its own; the eval signal is masked by LLM inference from prose.
2. Either the eval needs sparser-prose fixtures (so typed verbs are the only path to the answer), or phase 2 must add **explicit graph traversal** to `/wiki-query` (the LLM gets the typed-relation graph as a separate retrieved structure, not just inline markdown).
3. The null-result is itself the answer to the original "do we need a parallel KG?" question: on rich-prose wikis, typed verbs are redundant; on sparse-prose wikis or for multi-hop queries beyond the LLM's inference horizon, they may help — but only when paired with traversal logic, not just syntax.

All 9 success checks (C1–C9) green; installer regression (`verify-create-llm-wiki.sh`) and core smoke (`smoke-all.sh`) both still exit 0. `scripts/installer-skeleton-manifest.txt` extended by 13 lines so the new lint, eval harness, fixture, and canary tests ship in fresh installs.

## 2026-05-26 10:56 — visualization toolchain landed

Three-iteration build (per `.scratch/visualization-tools/GOAL.md`) shipping `scripts/visualize/` — a bespoke Python+D3 graph generator (stdlib only, no npm), plus `npx`-wrapped slides (`marp-cli`), mermaid (`mermaid-cli`), and a `python3 -m http.server` wrapper. Includes `tests/canary/graph-fixture/` (4 nodes/4 edges, flat) and `tests/canary/graph-fixture-nested/` (2 nodes/1 edge with `sub/leaf.md` — anti-gaming against non-recursive parsers). Oracle at `scripts/visualize/verify-visualizers.sh` runs 5 sub-checks; skip-when-absent semantics for the npx tools. Documented in `docs/VISUALIZATION.md`; recommended heavier alternatives (Quartz, mdBook, SilverBullet) noted but not bundled. `scripts/installer-skeleton-manifest.txt` extended (44 lines) so visualizers ship in fresh installs. First end-to-end run: all 5 smokes green on a machine with both marp-cli and mermaid-cli reachable via npx. No schema change.

## 2026-05-26 09:17 — installer toolchain landed

Per `.scratch/installer-fresh-skeleton/GOAL.md`. New: `scripts/create-llm-wiki.sh` (manifest-driven scaffolder generating a fresh repo at `<target-dir>`), `scripts/verify-create-llm-wiki.sh` (oracle: I3 manifest iteration + I4 tree-shape + content tripwire + frontmatter parse + I5 target preflight + I4(d) template substitution), `scripts/installer-skeleton-manifest.txt` (single source of truth, 31 lines initially, later extended), `README-FRESH.md` and `wiki/index-FRESH.md` (fresh-skeleton templates), `tests/installer-output/.gitignore`. Removes the `wipe-meta-wiki.sh` step from the new-user flow. Post-adversarial-pass revisions to the spec: I4 reformulated from negative-spot-list (gameable by wholesale cp -R) to positive-shape + content-tripwire + frontmatter-parse triple; I4(d) added to byte-match installed README.md/wiki/index.md against FRESH templates. No schema change.

## 2026-05-26 08:00 — smoke infrastructure landed

Per `.scratch/plug-and-play-curator-smoke/GOAL.md`. New: `scripts/smoke-build.sh` (LLM-driven, idempotent via `body-hash.sh`), `scripts/smoke-check.sh` (pure-shell asserts C1–C5), `scripts/smoke-all.sh` (umbrella: build + check + 4 regression guards), `scripts/r3-obsidian-patterns.txt` (patterns file for the no-Obsidian-syntax guard, avoids backtick quoting hazards in shell), `tests/smoke/smoke-source.md` (fictitious Phase Coherence Engineering fixture with Quortex protocol / Dr. Alma Voss / 47 phase rotations anchors), `tests/smoke/expected-query.md`, `tests/smoke/.gitignore`. Adversarial-pass introduced C5 (`ingested_hash` populated cryptographic proof) — without it, an agent could hand-author log.md + last-answer.md to satisfy 6 of 8 checks without running `claude -p`. First smoke run produced the 06:52 `/wiki-ingest` entry below — the empirical demonstration that the 7-step pipeline executes correctly. No schema change.

## 2026-05-26 06:52 — /wiki-ingest

- Processed: raw/smoke-source.md (hash ba2159c8)
- Created: wiki/smoke-source-summary.md, wiki/quortex-protocol.md, wiki/dr-alma-voss.md, wiki/phase-coherence-engineering.md
- Updated: wiki/index.md
- Contradictions flagged: none (smoke fixture's domain is disjoint from the existing meta-wiki about the LLM-wiki pattern; nothing to disagree with)

`wiki/quortex-protocol.md` carries the literal "Quortex" and "47 phase rotations" anchors required by smoke check C2.

## 2026-05-26 05:30 — schema bump 1 → 2

Three additions to the schema landed together. Each is opt-in on its own, but the journal exception introduces a new rule on `/wiki-ingest` behavior — by the bump policy in AGENTS.md, that's a behavior-changing edit and requires a version bump even though no v1 client would currently violate it in default repos.

- **Journal exception (`wiki/journal/`)**: new user-owned directory. Files there are not rewritten by `/wiki-ingest`. New `type: journal` value added to the page-type enum. Template at `templates/journal-entry.md`. The directory is reserved by an empty `.gitkeep`; entries are created by the user, not the LLM.
- **`## Flashcards` content convention**: any wiki page may declare Q/A pairs in a `## Flashcards` section. Exporter at `scripts/wiki-to-anki.sh` emits an Anki-importable CSV with the page slug as the card tag. Canary fixture at `tests/canary/canary-flashcards.md`; smoke test via `scripts/verify-wiki-to-anki.sh`.
- **Optional MCP read surface**: `scripts/mcp-server.sh` launches `@bitbonsai/mcpvault` pointed at `wiki/`, exposing read/search/write tools to any MCP-aware client. Setup details in `docs/MCP.md`. Pure addition; does not change the three-layer model or the slash commands. `scripts/preflight.sh` now reports whether `npx` is available.

**Migration note for v1 clients.** A v1 client that scans `wiki/**/*.md` without journal awareness will see entries under `wiki/journal/` as ordinary `wiki/` files. If such a client runs `/wiki-ingest` autonomously and decides a journal entry needs rewriting (e.g., as part of step 4 "update existing pages"), it could clobber user-authored content. Mitigations until clients upgrade: (a) ingest sources from `raw/`, not from journal entries, (b) if running v1 ingest on a repo that has journal entries, snapshot `wiki/journal/` first, (c) `/wiki-lint` is unaffected — link-checking still works against journal entries.

## 2026-05-25 17:15 — backfill extraction_method on legacy raws

Gap surfaced during PR #3's smoke-test batch: the two raw files shipped before PR #1 (`karpathy-llm-wiki-video-transcript.md` and `karpathy-video-slide-ingest-pipeline.png.md`) predate the `extraction_method` frontmatter field, so running `verify-extract.sh` on them fails the "extraction_method required" check. This is a one-time human-authorized migration to bring the legacy raws up to schema_version 1.

- **`raw/karpathy-llm-wiki-video-transcript.md`**: added `extraction_method: passthrough`. The transcript was pasted into the conversation that bootstrapped the project (per its own `notes:` field) — passthrough is the closest match in the enum (raw text imported as-is, no parser).
- **`raw/karpathy-video-slide-ingest-pipeline.png.md`**: added `extraction_method: llm-vision`. The slide is a binary PNG; its sidecar was produced by vision extraction (per the 2026-05-25 08:30 entry below).
- Both edits are in the YAML frontmatter only; **body content unchanged**. Body hashes were recomputed via `scripts/body-hash.sh` and verified identical to the recorded `ingested_hash` — idempotence preserved, `/wiki-ingest` will still skip both files.

**Hard-rule note:** modifying files in `raw/` normally violates the LLM's read-only rule on that layer. This migration is treated as a one-time maintainer-authorized edit (not an autonomous LLM act). Future cases where the LLM's `/wiki-extract` writes `extraction_method` on a *new* raw file are fine and unrelated.

**Follow-up gap surfaced during this commit:** the verifier's `ingested_hash` check warns "/wiki-extract should leave this empty" — accurate for fresh extract output, but noisy on files already processed by `/wiki-ingest` (the normal post-ingest state). Not fixed here to keep this PR's scope minimal. Tracked for next iteration.

## 2026-05-25 17:00 — verify-extract.sh: surface extraction_status visually

Gap surfaced during the prior session's smoke-test batch: the DOCX-degraded run produced a sidecar with `extraction_status: failed`, but the verifier reported "Passed. Shape checks all green." with no visual indication that extraction actually failed. Shape was fine — but the user reading the verifier output wouldn't know they need to install pandoc.

- `scripts/verify-extract.sh`: new check block after `ingested_hash`. When `extraction_status` is present in the frontmatter, emit `✓` for `ok`, `⚠` for `degraded` / `failed`, `⚠` (with "unknown value" message) for anything else. Exit code unchanged on degraded/failed (shape is still fine — the warn is the signal).
- Docstring updated to document the new behavior in the "Scope" section.

Tested on 4 synthetic frontmatter values: `failed` → ⚠, `ok` → ✓, `degraded` → ⚠, `bogus` → ⚠ (unknown). Exit code 0 in all cases.

## 2026-05-25 16:50 — tests/canary/canary-csv.csv: tracked CSV fixture

Smoke-tested the CSV path of `/wiki-extract` end-to-end this session. The fixture used (5-row world-cities CSV) was a one-shot file in working tree; promoting it to a tracked fixture so the smoke test is reproducible.

- `tests/canary/canary-csv.csv` — 5 data rows + header. Plain ASCII. Designed to exercise the ≤100-row markdown-table render branch.
- Sibling to `tests/canary/canary-smoke-test.md` (plain-text fixture from PR #3). Same purpose: known-good input for the verifier.

The smoke test flow (per `docs/QUICKSTART.md`):

```
/wiki-extract tests/canary/canary-csv.csv   # in AI tool
./scripts/verify-extract.sh canary-csv      # in shell
```

Expected: `raw/canary-csv.csv` (copy) + `raw/canary-csv.csv.md` (sidecar with `extraction_method: csv-passthrough` and a markdown table of the 5 cities). Verifier green.

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
