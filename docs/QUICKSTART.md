# QUICKSTART — `llm-wiki-bootstrap`

From `git clone` to first useful answer in 5 minutes, across the supported AI tools.

## Fastest path (Claude Code)

```bash
git clone https://github.com/FrancyJGLisboa/llm-wiki-bootstrap my-wiki
cd my-wiki && claude
```

Then, inside Claude Code:

```
/wiki-query "what is an llm-wiki?"   # instant answer from the shipped demo wiki — no setup
/wiki-extract <your-url>             # add your own source
/wiki-ingest                          # integrate it
/wiki-query "..."                    # ask about it
```

That's the loop. Everything below is depth — per-tool setup, the optional smoke test, cost, recovery. Skip to [The 5 operations](#the-5-operations) if you just want the commands.

---

## Table of contents

- [Before you start](#before-you-start)
- [Smoke test (optional)](#smoke-test-optional--confirm-your-setup)
- [The 5 operations (one paragraph each)](#the-5-operations)
- [Schema v2 extras (journal, Flashcards, MCP)](#schema-v2-extras-journal-flashcards-mcp)
- [Per-tool command sequences](#per-tool-command-sequences)
  - [Claude Code](#claude-code-first-class-slash-commands) (slash commands)
  - [Copilot CLI](#copilot-cli) (natural language + AGENTS.md auto-load)
  - [VSCode + Copilot Chat (Agent Mode)](#vscode--copilot-chat-agent-mode)
  - [Cline](#cline-vscode-extension)
  - [Cursor](#cursor)
  - [Other tools](#other-tools-continue--roo--cody--gemini-cli--codex)
- [Visualize your wiki](#visualize-your-wiki)
- [What success looks like](#what-success-looks-like)
- [Commit per ingest (and recovery)](#commit-per-ingest-and-recovery)
- [Cost expectations](#cost-expectations-rough)
- [Status](#status)

---

## Before you start

**1. Clone the repo** where you want your wiki to live:

```bash
git clone https://github.com/FrancyJGLisboa/llm-wiki-bootstrap my-wiki
cd my-wiki
```

**2. Decide what to do with the shipped meta-wiki.** This repo ships with a wiki *about* the LLM-wiki pattern itself (in `wiki/`), derived from `raw/karpathy-llm-wiki-video-transcript.md`, plus 4 smoke-derived pages about a fictitious technical concept used to demonstrate the ingest pipeline. **Just trying it? Do nothing — "keep + add alongside" (below) lets you start immediately.** When you commit to your own wiki, pick one:

| Choice | Command | When |
|---|---|---|
| **Use the installer to generate a fresh skeleton** (recommended) | `./scripts/create-llm-wiki.sh ~/my-wiki` (manifest-driven; clean repo, no demo content) | You want to start your own wiki without doing a wipe. Cleanest path. |
| **Keep + add alongside** | (do nothing) | You're learning the pattern. The meta-wiki + smoke stay as worked examples. |
| **Wipe and start in-place** | `./scripts/wipe-meta-wiki.sh` (prompts; `--yes` to skip) | Edge case; the installer is preferable. |
| **Archive to a reference folder** | `mkdir -p reference && git mv wiki reference/meta-wiki && mkdir wiki` | Best of both — keep the example, isolate your stuff. |

**3. Open the directory in your AI tool** of choice. Sections below cover each one.

---

## Smoke test (optional — confirm your setup)

**Just trying it out? Skip to [The 5 operations](#the-5-operations).** When you want confidence the whole thing works on your machine, two layers of smoke help: the umbrella for "does the whole pipeline run here"; the shape-check fixtures for "does `/wiki-extract` produce the right frontmatter shape for format X."

### End-to-end umbrella (Claude Code required)

```bash
./scripts/smoke-all.sh
```

Runs the full pipeline: `claude -p` ingests a fictitious technical source (under `tests/smoke/`), queries it, and 9 binary checks (5 smoke + 4 regression guards) assert that ingest produced wiki pages with the right anchors, `log.md` has the entry, `/wiki-query` recalled the fact and cited the source, and no schema/script invariants regressed. First run ~30-60s (LLM); subsequent runs sub-second (idempotent via body-hash). All 9 green = your install works end-to-end.

### Shape-check smokes (per-format)

Verify that `/wiki-extract` produces output with the right shape in your environment for individual formats. Three known-good fixtures ship with the repo.

```
/wiki-extract tests/canary/canary-smoke-test.md     # plain-text path
./scripts/verify-extract.sh canary-smoke-test

/wiki-extract tests/canary/canary-csv.csv           # CSV path
./scripts/verify-extract.sh canary-csv

./scripts/verify-wiki-to-anki.sh                    # Anki exporter shape
```

`verify-extract.sh` checks shape only — wrong `source_type`, hallucinated `source_title` etc. will slip past. For semantics, eyeball the produced `raw/` file directly.

---

## The 5 operations

You will use the same 5 operations regardless of tool. Each one has two interchangeable Claude-Code slash-command forms: a short alias (`/extract`) and the prefixed canonical (`/wiki-extract`). Use whichever feels natural.

| Operation | Slash command | Purpose | When to run |
|---|---|---|---|
| **init** | `/init` or `/wiki-init` | Scaffold the directory structure (`raw/`, `wiki/`, `AGENTS.md`, `log.md`). Idempotent. | Once, only if you copied just `.claude/commands/` to a project. **Skip if you cloned this repo or used the installer** — structure is already there. |
| **extract** `<sources>` | `/extract` or `/wiki-extract` | Pull **one or many** URLs / local files (PDF, DOCX, XLSX, CSV, image, plain text) into `raw/` with frontmatter. Multi-source mode: paste several URLs or paths in one shot, get a consolidated OK/Degraded/Failed summary. Does **not** touch `wiki/`. | Every time you have new sources to add. Bulk mode is the realistic onboarding moment: paste 10 URLs at once. |
| **ingest** `[<raw-file>]` | `/ingest` or `/wiki-ingest` | Process `raw/` → `wiki/` using the 7-step pipeline. Detects deltas via body hash. | After every extract (or after manually editing a raw file). |
| **query** `<question>` | `/query` or `/wiki-query` | Read the wiki, synthesize an answer. Web-searches and promotes new knowledge as wiki pages on gaps. | Anytime you have a question. |
| **lint** `[--apply]` | `/lint` or `/wiki-lint` | Health-check the wiki (broken links, orphans, contradictions, stale claims, gaps). | Periodically, or when answers feel inconsistent. |

In Claude Code these are real slash commands. **In every other tool**, you invoke them by natural language and the AI agent follows the prompt body of the corresponding `.claude/commands/wiki-<name>.md` file (which acts as a portable workflow definition). The short-form alias files (`.claude/commands/{init,extract,ingest,query,lint}.md`) are thin delegators that point the AI at the canonical file — both names work identically.

---

## Schema v2 extras (journal, Flashcards, MCP)

Schema v2 (bumped 2026-05-26) added three opt-in extensions. None changes the three-layer model or the five slash commands.

| Extension | What it is | How to use |
|---|---|---|
| **Journal entries** | A user-owned exception under `wiki/journal/<YYYY-MM-DD>-<slug>.md`. `/wiki-ingest` is forbidden from rewriting these. Template at `templates/journal-entry.md`. Cross-link to concept pages with `[[wiki-links]]`. Useful for time-stamped observations that should feed back into theory. | Copy the template, fill in body, drop into `wiki/journal/`. Use `[[]]` to link to existing concept pages. `/wiki-lint` catches broken links automatically. |
| **Flashcards** | Any wiki page may declare a `## Flashcards` section with Q/A pairs. Exported to Anki-importable CSV by `./scripts/wiki-to-anki.sh > anki.csv`. Slug becomes the Anki tag. | Add the section to any page, run the exporter, import the CSV in Anki. |
| **MCP read surface** | Optional. `./scripts/mcp-server.sh` launches `@bitbonsai/mcpvault` against `wiki/` so any MCP-aware client (Claude Desktop, Cursor, ChatGPT Desktop, etc.) can read + search the wiki without slash commands. BM25 search built in. | See [`MCP.md`](MCP.md) for per-client config snippets. |
| **Typed relations** | Lines inside `## Related` can carry a verb (kebab-case) + optional attribute: `- [[embrapa]] founded-by 1973 — Brazilian R&D agency`. Verb regex: `[a-z][a-z0-9-]*`. Untyped and multi-link lines collapse to implicit `related-to` for backward compat. Pure CommonMark, no rendering dependency. Graph viz colours and filters edges by verb. Empirical eval at `scripts/eval-multi-hop.sh` measures whether typed verbs actually improve `/wiki-query` recall vs. the same wiki with verbs stripped. | Add verbs to `## Related` lines as you ingest, validate with `./scripts/wiki-lint-typed-relations.sh wiki/`, regenerate the graph with `./scripts/visualize/graph.sh wiki/ > graph.html` to see verb-coloured edges + the verb-filter dropdown. Run the eval before deciding to invest in a parallel knowledge graph. Full spec in `AGENTS.md` → "Typed relations". |

---

## Per-tool command sequences

### Claude Code (first-class slash commands)

> **Status: e2e-verified.** This path is driven by `scripts/smoke-all.sh` on every change.

The most fluent setup. Slash commands appear in the autocomplete menu.

```bash
cd my-wiki
claude          # open Claude Code in this directory
```

Inside the Claude session, in order:

```
/wiki-extract https://example.com/some-article
/wiki-ingest
/wiki-query "what does this article say about <topic>?"
```

Periodically (e.g., once a week of active use):

```
/wiki-lint
```

Render or export the wiki whenever you like (both are read-only on your wiki):

```
/wiki-visualize          # interactive D3 graph of the whole wiki
/wiki-flashcards         # export ## Flashcards sections to anki.csv
/wiki-diagram "status of X for management"   # synthesize an audience-targeted poster
```

**Gotchas:**
- Type `/` and you'll see the `wiki-*` commands in the autocomplete — the five lifecycle commands plus the three output commands (`/wiki-visualize`, `/wiki-flashcards`, `/wiki-diagram`).
- **Don't run `/wiki-init`** if you cloned this repo — the structure is already there.
- First ingest may take 30-90 seconds depending on source size.

---

### Copilot CLI

> **Status: documented, not yet e2e-verified.** The shim ships (`.github/copilot-instructions.md` + `AGENTS.md`) and the workflow is specified, but only Claude Code is driven by the smoke harness. The path below is expected to work; if it does not, please [open an issue](https://github.com/FrancyJGLisboa/llm-wiki-bootstrap/issues).

`AGENTS.md` is auto-loaded by Copilot CLI on session start. Slash commands from `.claude/commands/` are not auto-discovered (Copilot CLI is a different CLI). You invoke workflows by natural language, referring to the workflow file.

```bash
cd my-wiki
copilot         # opens Copilot CLI in this directory
```

Inside the session:

```
Read AGENTS.md to learn this project's conventions. Then fetch
https://example.com/some-article into raw/ as described in
.claude/commands/wiki-extract.md.
```

After fetch:

```
Run the wiki-ingest workflow. The workflow steps are in
.claude/commands/wiki-ingest.md — follow them exactly.
```

Ask:

```
Wiki-ask: "what does the article say about <topic>?"
Use the workflow in .claude/commands/wiki-query.md.
```

Lint:

```
Run wiki-lint per .claude/commands/wiki-lint.md. Report issues
but don't apply fixes yet.
```

**Gotchas:**
- You'll explicitly reference the `.claude/commands/wiki-*.md` files in your first invocations. After a few rounds Copilot internalizes the pattern.
- Cost-monitor your session — agentic loops can run long.

---

### VSCode + Copilot Chat (Agent Mode)

> **Status: documented, not yet e2e-verified.** The shim ships (`.github/copilot-instructions.md`) and the workflow is specified, but only Claude Code is driven by the smoke harness. If this path does not work, please [open an issue](https://github.com/FrancyJGLisboa/llm-wiki-bootstrap/issues).

Agent Mode (shipped 2025) is what makes Copilot Chat capable of running the workflows. Classic Copilot Chat won't autonomously do multi-step ingest.

1. Open the directory:
   ```bash
   code my-wiki
   ```
2. Open the Copilot Chat panel (Ctrl+Shift+I / Cmd+Shift+I).
3. **Toggle Agent Mode** in the chat panel.

Then in the chat:

```
Read AGENTS.md to learn this project's conventions. Then fetch
https://example.com/some-article into raw/ following
.claude/commands/wiki-extract.md.
```

Next message:

```
Now run the wiki-ingest workflow per .claude/commands/wiki-ingest.md.
Show me each step.
```

Ask:

```
Wiki-ask: <your question>. Follow .claude/commands/wiki-query.md.
```

Lint:

```
Run wiki-lint per .claude/commands/wiki-lint.md.
```

**Gotchas:**
- Agent Mode required. Classic Copilot Chat will reply with answers but not execute multi-step file edits autonomously.
- Copilot also reads `.github/copilot-instructions.md` (ships in this project) on each session — that confirms the workflow names exist.
- Agent Mode may pause for tool-call approval — that's expected; click approve.

---

### Cline (VSCode extension)

> **Status: documented, not yet e2e-verified.** The shim ships (`.clinerules`) and the workflow is specified, but only Claude Code is driven by the smoke harness. If this path does not work, please [open an issue](https://github.com/FrancyJGLisboa/llm-wiki-bootstrap/issues).

Cline is open-source, free, and agentic by default. Best fit for users who want a Claude-Code-like loop without paying for Copilot.

1. Install Cline from the VSCode marketplace if you don't have it.
2. Open the directory:
   ```bash
   code my-wiki
   ```
3. Open the Cline panel (sidebar icon).

Cline auto-reads `.clinerules` (ships in this project) at the start of every task. First task:

```
Fetch https://example.com/some-article into raw/ per the
wiki-extract workflow defined in .claude/commands/wiki-extract.md.
```

Next task:

```
Run wiki-ingest. Follow the 7-step pipeline in
.claude/commands/wiki-ingest.md.
```

Ask:

```
Wiki-ask: <your question>.
```

Lint:

```
Run wiki-lint.
```

**Gotchas:**
- Cline is fully autonomous within a task — it keeps going until done. Watch the cost meter.
- Each new Cline task re-reads `.clinerules` from scratch.

---

### Cursor

> **Status: documented, not yet e2e-verified.** The shim ships (`.cursor/rules/llm-wiki.mdc`, `alwaysApply: true`) and the workflow is specified, but only Claude Code is driven by the smoke harness. If this path does not work, please [open an issue](https://github.com/FrancyJGLisboa/llm-wiki-bootstrap/issues).

Cursor auto-loads `.cursor/rules/llm-wiki.mdc` (ships in this project, `alwaysApply: true`) on every session.

1. Open the directory:
   ```bash
   cursor my-wiki      # or via Cursor UI
   ```
2. Open the chat (Cmd+L / Ctrl+L). Use Composer / Agent mode if available — closest analog to Cline's autonomy.

Invocations same shape as Cline:

```
Fetch https://example.com/some-article into raw/ following the
wiki-extract workflow.
```

```
Run wiki-ingest.
```

```
Wiki-ask: <your question>.
```

```
Run wiki-lint.
```

**Gotchas:**
- Cursor's built-in slash commands (if your version has them) are **not** the project's wiki-* commands. The project's "commands" are natural-language workflows here.
- If using non-Agent / non-Composer mode, you may need to invoke step-by-step rather than expecting full autonomy.

---

### Other tools (Continue / Roo / Cody / Gemini CLI / Codex)

> **Status: documented, not yet e2e-verified.** Gemini CLI reads `GEMINI.md`, Codex reads `AGENTS.md` (canonical), and the rest read the existing shims. Only Claude Code is driven by the smoke harness. If a path does not work, please [open an issue](https://github.com/FrancyJGLisboa/llm-wiki-bootstrap/issues).

Same pattern as Cline / Cursor:

1. Tool auto-loads its respective shim (`.clinerules`, `.cursor/rules/`, `AGENTS.md`, `GEMINI.md`, `.github/copilot-instructions.md`).
2. Invoke workflows by natural language, referring to the corresponding `.claude/commands/wiki-<name>.md` file.

```
Read AGENTS.md. Then run wiki-extract on https://example.com/foo
following .claude/commands/wiki-extract.md.
```

(Then `wiki-ingest`, `wiki-query`, `wiki-lint` as needed.)

---

## Visualize your wiki

Four opt-in, open-source visualization wrappers under `scripts/visualize/`. None requires Obsidian.

```bash
./scripts/visualize/graph.sh wiki/ > graph.html        # interactive D3 graph (pure Python; no install)
open graph.html
./scripts/visualize/slides.sh wiki/some-page.md        # turn a page into MARP slides (npx)
./scripts/visualize/mermaid.sh wiki/some-page.md       # render mermaid blocks to PNG (npx)
./scripts/visualize/serve.sh wiki                      # browse wiki + graph via http://localhost:8000
./scripts/visualize/verify-visualizers.sh              # smoke harness (graph always runs; slides/mermaid skip-when-absent)
```

The graph generator is stdlib-only Python — runs everywhere `python3` is available. The other three wrap `npx` packages (downloaded on first run, cached after). See [`VISUALIZATION.md`](VISUALIZATION.md) for the full guide and heavier alternatives (Quartz, mdBook, SilverBullet).

---

## What success looks like

After your **first `wiki-extract` + `wiki-ingest`** on a ~5-page article, expect:

- A new file in `raw/` with frontmatter populated (`source_url`, `fetched_at`, `ingested_hash` no longer empty).
- **3 to 10 new pages in `wiki/`:**
  - 1 summary page named like `<source-slug>-summary.md`, with `type: summary`.
  - Several concept and/or entity pages, with `type: concept` or `type: entity`.
  - Updates to any existing pages whose concepts overlap with the new source.
- `wiki/index.md` updated with the new pages listed.
- A fresh entry at the top of `log.md` listing what changed.

### Symptoms of partial pipeline execution

| Symptom | Likely cause | Fix |
|---|---|---|
| Only 1 wiki page created | LLM skipped step 4 ("update existing pages") | Re-prompt: *"You only created 1 page. The pipeline says one source touches 10-15 pages. Re-run wiki-ingest and update all relevant concept pages."* |
| No summary page | Step 3 skipped | Re-prompt: *"No summary page was created. Per step 3 of `.claude/commands/wiki-ingest.md`, every source needs a `<slug>-summary.md` page."* |
| No `log.md` entry | Step 7 skipped | Re-prompt: *"You didn't append to log.md. Per step 7, every ingest must log what changed."* |
| Broken `[[wiki-links]]` | LLM linked to pages that don't exist | Run `wiki-lint`. It'll list broken links; choose to create stubs or remove. |

---

## Commit per ingest (and recovery)

### Prevention: commit after every successful ingest

`/wiki-ingest` is **not atomic**. It touches a summary page, several concept pages, the index, `log.md`, and the raw-file frontmatter. If a later ingest goes sideways, your only clean rollback path is `git`. Skip the commit and rollback also reverts the good ingest before it.

Recommended discipline (already shown in the README's "A typical session"):

```bash
/wiki-ingest <raw-file-or-no-arg>

# inspect briefly — does wiki/ look right? does log.md have an entry?
git status
git diff wiki/index.md log.md

# commit before the next ingest
git add wiki/ log.md raw/
git commit -m "ingest: <source title>"
```

One ingest = one commit. Treat `/wiki-ingest` as the analog of `make` for the wiki: each successful run is a checkpoint worth pinning.

### Recovery: when an ingest produces garbage

If you have not committed yet, revert the working tree:

```bash
git status                  # see what was created/modified
git checkout -- wiki/       # discard all wiki changes
git checkout -- log.md
git checkout -- raw/<file>  # revert ingested_hash etc. if it was set
```

If you are partway through and want to keep some good changes:

```bash
git add wiki/<good-page>.md
git stash --keep-index
git stash drop
```

If the bad ingest was already committed (because you ran two ingests back-to-back without committing between them — the exact failure mode the "commit per ingest" rule above prevents), roll back the commit:

```bash
git log --oneline           # find the last good commit
git revert <bad-commit>     # creates a revert commit (safer than reset --hard)
```

Then pick a smaller / cleaner source for your next try.

---

## Cost expectations (rough)

For one source of ~5,000 words, on a modern frontier model:

| Operation | Approx. tokens |
|---|---|
| `wiki-extract` | 1k (mostly the source body) |
| `wiki-ingest` (7 steps, 5-10 pages touched) | 50k - 100k |
| `wiki-query` (depends on wiki size + whether web search fires) | 5k - 20k |
| `wiki-lint` (depends on wiki size) | 20k - 50k |

These are estimates. **Heavy users should set token / cost limits in their tool** (most agentic CLIs and IDE extensions have them). Run a single small source first to calibrate cost-per-ingest for your model + your typical source size.

---

## Status

**The 7-step `/wiki-ingest` pipeline is now demonstrated end-to-end** (2026-05-26). The smoke at `./scripts/smoke-all.sh` runs `/wiki-ingest` + `/wiki-query` against a fictitious technical fixture (under `tests/smoke/`); the resulting 4 wiki pages (with fictitious anchors) and the corresponding `log.md` entry are committed in the repo as empirical evidence the pipeline executes correctly on a fresh source. Per the resolution note in `wiki/open-questions.md`, this closes what was previously the project's top open question.

What's still untested:

- **Per-tool slash-command parity.** Only Claude Code (via `claude -p`) drove the smoke. Cursor / Copilot CLI / VSCode + Copilot Chat / Cline / Gemini CLI / Codex paths in this guide rely on the natural-language shim approach — they likely work but haven't been observed end-to-end.
- **DOCX / XLSX / PDF-LLM-vision** extraction handlers in `/wiki-extract`. The shape-check fixtures (`canary-smoke-test.md`, `canary-csv.csv`) cover only plain-text and CSV. The other formats are specified, not demonstrated.
- **Concurrency.** The video mentions parallel ingest agents; no locking or conflict resolution defined yet.

If your output for a real source doesn't match "What success looks like" above, the prompt in `.claude/commands/wiki-<name>.md` may need refinement for your tool. File an issue at https://github.com/FrancyJGLisboa/llm-wiki-bootstrap/issues, or open a PR with the prompt improvement.

---

## Quick reference card

```
clone                git clone https://github.com/FrancyJGLisboa/llm-wiki-bootstrap my-wiki && cd my-wiki
fetch                /wiki-extract <url|file|image>
ingest               /wiki-ingest                      (no arg = process all raw/ with new/changed hash)
ask                  /wiki-query "<question>"            (--no-promote to skip auto-page-creation)
lint                 /wiki-lint                        (--apply to write proposed fixes)
recover              git checkout -- wiki/ log.md raw/<file>
```

(In tools without slash commands, replace `/wiki-X` with "run the wiki-X workflow per `.claude/commands/wiki-X.md`.")
