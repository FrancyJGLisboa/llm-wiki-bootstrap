# QUICKSTART — `llm-wiki-bootstrap`

From `git clone` to first useful answer in 5 minutes, across the supported AI tools.

## Table of contents

- [Before you start](#before-you-start)
- [The 5 operations (one paragraph each)](#the-5-operations)
- [Per-tool command sequences](#per-tool-command-sequences)
  - [Claude Code](#claude-code-first-class-slash-commands) (slash commands)
  - [Copilot CLI](#copilot-cli) (natural language + AGENTS.md auto-load)
  - [VSCode + Copilot Chat (Agent Mode)](#vscode--copilot-chat-agent-mode)
  - [Cline](#cline-vscode-extension)
  - [Cursor](#cursor)
  - [Other tools](#other-tools-continue--roo--cody--gemini-cli--codex)
- [What success looks like](#what-success-looks-like)
- [Recovery from a bad ingest](#recovery-from-a-bad-ingest)
- [Cost expectations](#cost-expectations-rough)
- [Honest caveat](#honest-caveat)

---

## Before you start

**1. Clone the repo** where you want your wiki to live:

```bash
git clone https://github.com/FrancyJGLisboa/llm-wiki-bootstrap my-wiki
cd my-wiki
```

**2. Decide what to do with the shipped meta-wiki.** This repo ships with a wiki *about* the LLM-wiki pattern itself (in `wiki/`), derived from `raw/karpathy-llm-wiki-video-transcript.md`. Pick one:

| Choice | Command | When |
|---|---|---|
| **Keep + add alongside** (recommended for first try) | (do nothing) | You're learning the pattern. The meta-wiki stays as a worked example. |
| **Wipe and start fresh** | `./scripts/wipe-meta-wiki.sh` (prompts; `--yes` to skip) | You already understand the pattern and want a clean slate. |
| **Archive to a reference folder** | `mkdir -p reference && git mv wiki reference/meta-wiki && mkdir wiki` | Best of both — keep the example, isolate your stuff. |

**3. Open the directory in your AI tool** of choice. Sections below cover each one.

---

## The 5 operations

You will use the same 5 operations regardless of tool:

| Operation | Purpose | When to run |
|---|---|---|
| **init** | Scaffold the directory structure (`raw/`, `wiki/`, `AGENTS.md`, `log.md`). Idempotent. | Once, only if you copied just `.claude/commands/` to a project. **Skip if you cloned this repo** — structure is already there. |
| **fetch** `<source>` | Pull a URL / local file / image into `raw/` with frontmatter. Does **not** touch `wiki/`. | Every time you have a new source to add. |
| **ingest** `[<raw-file>]` | Process `raw/` → `wiki/` using the 7-step pipeline. Detects deltas via body hash. | After every fetch (or after manually editing a raw file). |
| **ask** `<question>` | Read the wiki, synthesize an answer. Web-searches and promotes new knowledge as wiki pages on gaps. | Anytime you have a question. |
| **lint** `[--apply]` | Health-check the wiki (broken links, orphans, contradictions, stale claims, gaps). | Periodically, or when answers feel inconsistent. |

In Claude Code these are real slash commands. **In every other tool**, you invoke them by natural language and the AI agent follows the prompt body of the corresponding `.claude/commands/wiki-<name>.md` file (which acts as a portable workflow definition).

---

## Per-tool command sequences

### Claude Code (first-class slash commands)

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

**Gotchas:**
- Type `/` and you'll see the five `wiki-*` commands in the autocomplete.
- **Don't run `/wiki-init`** if you cloned this repo — the structure is already there.
- First ingest may take 30-90 seconds depending on source size.

---

### Copilot CLI

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

Same pattern as Cline / Cursor:

1. Tool auto-loads its respective shim (`.clinerules`, `.cursor/rules/`, `AGENTS.md`, `GEMINI.md`, `.github/copilot-instructions.md`).
2. Invoke workflows by natural language, referring to the corresponding `.claude/commands/wiki-<name>.md` file.

```
Read AGENTS.md. Then run wiki-extract on https://example.com/foo
following .claude/commands/wiki-extract.md.
```

(Then `wiki-ingest`, `wiki-query`, `wiki-lint` as needed.)

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

## Recovery from a bad ingest

The pipeline is not atomic. If `/wiki-ingest` produces garbage:

```bash
git status                  # see what was created/modified
git checkout -- wiki/       # discard all wiki changes
git checkout -- log.md
git checkout -- raw/<file>  # revert ingested_hash etc. if it was set
```

If you're partway through and want to keep some good changes:

```bash
git add wiki/<good-page>.md
git stash --keep-index
git stash drop
```

If the wiki was already committed and now you want to roll back:

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

## Honest caveat

**None of the slash commands have been runtime-tested in this repo yet.** The wiki you see was bootstrapped by direct file writes during the design conversation, not by `/wiki-ingest`. The first time *you* run `/wiki-ingest` is the smoke test.

If your output doesn't match the "What success looks like" section above, the prompt in `.claude/commands/wiki-<name>.md` likely needs refinement. File an issue at https://github.com/FrancyJGLisboa/llm-wiki-bootstrap/issues, or open a PR with the prompt improvement.

The exact verification gap is documented at `wiki/operation-ingest.md#verification-status` and listed as the top entry in `wiki/open-questions.md`.

---

## Quick reference card

```
clone                git clone <repo> my-wiki && cd my-wiki
fetch                /wiki-extract <url|file|image>
ingest               /wiki-ingest                      (no arg = process all raw/ with new/changed hash)
ask                  /wiki-query "<question>"            (--no-promote to skip auto-page-creation)
lint                 /wiki-lint                        (--apply to write proposed fixes)
recover              git checkout -- wiki/ log.md raw/<file>
```

(In tools without slash commands, replace `/wiki-X` with "run the wiki-X workflow per `.claude/commands/wiki-X.md`.")
