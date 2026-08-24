# Quickstart

One path. Follow it top to bottom; it is the same path `README.md`, `START-HERE.md`,
and a generated workspace's own README describe.

## 1. Generate a compiler

**Prerequisites:** `git`, `bash`, `awk`, `openssl`, and `python3` on PATH under that
exact name, plus an AI coding agent — Claude Code, or VS Code with GitHub Copilot.
Nothing here compiles evidence on its own; the compile step is a prompt the agent runs.
No API key of its own, no telemetry.

```bash
git clone https://github.com/FrancyJGLisboa/context-compiler-bootstrap bootstrap
./bootstrap/scripts/create-context-compiler.sh ./my-context
cd ./my-context
./scripts/preflight.sh          # must print "Ready." before you go further
```

## 2. See it work, before supplying anything of your own

```bash
./scripts/stage-northstar.sh .
```

Open `AI-WORKSPACE.code-workspace` and ask the AI:

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

Northstar Feeds is fictional — every person, number, and event is synthetic
([`../benchmarks/northstar/README.md`](../benchmarks/northstar/README.md)).

## 3. Your own work

Add evidence however is easiest — choose files or folders, paste text, paste one or
many links, or drop files into `EVIDENCE-INBOX/` — then say:

> Add this evidence and update my context.

Then ask for the work product: **Prepare me for the Northstar meeting**, **What changed
since <your date>?**, **Why do we think X?**, **What did we believe on <your date>?**, **Show
me only what needs my judgment.** Results are saved under `BRIEFS/` and `REVIEWS/`.

The stable workflow behind those sentences is `/ctx-add`; `/ctx-extract` and
`/ctx-compile` are advanced internal controls. You do not need `AGENTS.md` for any of
the above — it is the schema, written for the AI tool.

## 4. Specializations

One ships: `client-decision` (activated for you by step 2). To teach the workspace a
different kind of work, choose **Create Specialization** in the Context Workspace
sidebar, or just say:

> Create a specialization for tracking project decisions, alternatives, owners,
> constraints, supersession, and unresolved risks.

The agent asks at most five domain questions, builds and tests the profile, previews
observable results, and requests explicit approval before activation. It never asks you
to edit schemas, run tests, or use Git.

## What happens automatically

1. The original evidence is preserved.
2. Supported formats are normalized; unfamiliar formats are retained and marked for attention.
3. Only new or changed evidence is compiled.
4. Provenance, temporal state, and profile rules are validated.
5. A scoped local Git checkpoint is created for compiler-owned paths only.

No automatic push occurs. A failed checkpoint never discards successfully compiled
local output. Checkpoints stay silent until `git config user.name` and
`git config user.email` are set in the generated repo.

## Verify an installation

```bash
./scripts/preflight.sh
./scripts/verify-guided-workspace.sh
```

Both are also on the VS Code Command Palette under **Tasks: Run Task**.

## Windows

Install [Git for Windows](https://git-scm.com/download/win) for Git Bash, `git`,
`bash`, `awk`, and `openssl`. Install Python 3 and make sure it is on PATH as `python3`
— the compiler invokes that exact name. Open the generated `.code-workspace` in VS
Code; compiler scripts run through Git Bash. The `wiki -> context` compatibility
symlink may not be created on Windows; use `context/` directly if `wiki/` is missing.

## Optional — the Context Workspace VS Code extension

A local sidebar for the same actions, using the GitHub Copilot subscription already in
VS Code. It stores no credentials, sends no telemetry, and does not call a separate
model API. **It is not on the Marketplace — you build the VSIX yourself, which
additionally needs Node 20+, npm, network access, and the `code` CLI:**

```bash
./scripts/package-vscode-extension.sh                          # in the bootstrap clone
code --install-extension dist/context-workspace-0.1.0.vsix
```

See [`VSCODE-EXTENSION.md`](VSCODE-EXTENSION.md).

## Going further

For automation, packaging, visualization, and MCP access, open
[`../ADVANCED.md`](../ADVANCED.md).
