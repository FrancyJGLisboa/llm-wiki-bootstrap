# Quickstart

You are inside a generated context compiler. Everything below runs here, with no
further downloads and no API key of its own.

## 0. Check the setup first

```bash
./scripts/preflight.sh
```

It must print **Ready.** `bash`, `awk`, `openssl`, `git`, and `python3` are hard
requirements — every intake and compile step shells out to `python3` by name. The
warnings below the hard requirements are format coverage (`pdftotext`, `pandoc`,
`xlsx2csv`, `yt-dlp`); the workspace runs without them, with the listed
degradations.

You also need an AI coding agent pointed at this folder — Claude Code, or VS Code
with GitHub Copilot. Nothing in `scripts/` compiles evidence on its own; the
compile step is a prompt the agent runs.

## 1. See it work before supplying your own material

A complete synthetic corpus ships with this workspace, so you can reach a real
answer before you have any evidence of your own:

```bash
./scripts/stage-northstar.sh .
```

Then open `AI-WORKSPACE.code-workspace` and ask the AI:

```text
Update my context, then prepare a brief for Northstar Feeds.
```

Then, to see the rest of the surface:

```text
What changed since June 1?
Why is BRL/USD 5.70 the current assumption?
What did we believe on June 30?
Show me only what needs review.
```

Northstar Feeds is fictional — every person, number, and event is synthetic. See
[`benchmarks/northstar/README.md`](benchmarks/northstar/README.md). To reset,
delete what it staged under `raw/` and `context/`.

## 2. Your own work

Say to the AI:

> Help me set up this workspace for my work.

Then add evidence. Use whichever is easiest — choose files or folders, paste text,
paste one or many links, or drop files into `EVIDENCE-INBOX/` — and say:

> Add this evidence and update my context.

Then ask for the work product: **Prepare me for the Northstar meeting**, **What
changed since August 1?**, **Why do we think X?**, **What did we believe on June
30?**, **Show me only what needs my judgment.** Results are saved under `BRIEFS/`
and `REVIEWS/`.

The stable workflow behind those sentences is `/ctx-add`; `/ctx-extract` and
`/ctx-compile` are advanced internal controls.

## 3. Specializations

This workspace ships one: `client-decision`. Activate it with

```bash
./scripts/use-profile.sh client-decision
```

or let `/ctx-start` do it. To teach the workspace a different kind of work, say:

> Create a specialization for tracking project decisions, alternatives, owners,
> constraints, supersession, and unresolved risks.

The agent asks at most five domain questions, builds and tests the profile,
previews observable results, and requests explicit approval before activation. It
never asks you to edit schemas, run tests, or use Git.

## What happens automatically

1. The original evidence is preserved.
2. Supported formats are normalized; unfamiliar formats are retained and marked
   for attention.
3. Only new or changed evidence is compiled.
4. Provenance, temporal state, and profile rules are validated.
5. A scoped local Git checkpoint is created for compiler-owned paths only.

No automatic push occurs. A failed checkpoint never discards successfully
compiled local output. Checkpoints stay silent until `git config user.name` and
`git config user.email` are set in this repo.

## Verify the workspace

```bash
./scripts/preflight.sh
./scripts/verify-guided-workspace.sh
```

Both are also available from the VS Code Command Palette under **Tasks: Run
Task** → *Context: Check setup* / *Context: Verify guided workspace*.

## Windows

Install [Git for Windows](https://git-scm.com/download/win) for Git Bash, `git`,
`bash`, `awk`, and `openssl`. Install Python 3 and make sure it is on PATH as
`python3` — the compiler invokes that exact name. Open
`AI-WORKSPACE.code-workspace` in VS Code; compiler scripts run through Git Bash.
The `wiki -> context` compatibility symlink may not be created on Windows; use
`context/` directly if `wiki/` is missing.

## Going further

For the full command surface, automation, packaging, visualization, and MCP
access, open [`ADVANCED.md`](ADVANCED.md). The canonical schema is
[`AGENTS.md`](AGENTS.md) — you do not need it for the workflow above.
