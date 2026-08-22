# Quickstart

The first useful action is **Add Evidence**. You do not need to learn extraction, compilation, or Git before using the workspace.

## VS Code + GitHub Copilot

1. Build and install the local extension:

   ```bash
   ./scripts/package-vscode-extension.sh
   code --install-extension dist/context-workspace-0.1.0.vsix
   ```

2. Open the **Context Workspace** sidebar and choose **Create Compiler**, or open an existing generated compiler.
3. Choose **Add Evidence**. Select files or folders, drop them on the sidebar, paste text, paste one or many links, or use `EVIDENCE-INBOX/`.
4. Choose **Prepare Brief**, **Show Changes**, **Explain Why**, **Historical State**, or **Review Exceptions**.

The extension delegates reasoning to AI chat already available in VS Code. It does not request a second API key or upload evidence by itself.

## AI chat without the extension

```bash
git clone https://github.com/FrancyJGLisboa/context-compiler-bootstrap bootstrap
./bootstrap/scripts/create-context-compiler.sh ./my-context
code ./my-context/AI-WORKSPACE.code-workspace
```

Tell the agent:

> Add this evidence and update my context.

Provide a path, folder, pasted text, URL, or files already placed in `EVIDENCE-INBOX/`. Then ask for the work product:

> Prepare me for the Northstar meeting.

The stable workflow behind that sentence is `/ctx-add`; `/ctx-extract` and `/ctx-compile` are advanced internal controls.

## What happens automatically

1. The original evidence is preserved.
2. Supported formats are normalized; unfamiliar formats are retained and marked for attention.
3. Only new or changed evidence is compiled.
4. Provenance, temporal state, and profile rules are validated.
5. A scoped local Git checkpoint is created for compiler-owned paths only.

No automatic push occurs. A failed checkpoint never discards successfully compiled local output.

## Try the Northstar demo

```bash
./scripts/create-context-compiler.sh /tmp/northstar-compiler
./scripts/stage-northstar.sh /tmp/northstar-compiler
code /tmp/northstar-compiler/AI-WORKSPACE.code-workspace
```

Ask the AI:

```text
Update my context from the evidence inbox.
Prepare a brief for Northstar Feeds.
What changed since June 1?
Why is BRL/USD 5.70 the current assumption?
What did we believe on June 30?
Show me only what needs review.
```

## Windows

Install [Git for Windows](https://git-scm.com/download/win) for Git Bash, `git`, `bash`, `awk`, and `openssl`. Install Python 3 for synthesis and verification. Open the generated `.code-workspace` in VS Code; compiler scripts run through Git Bash.

## Verify installation

```bash
./scripts/preflight.sh
./scripts/vscode-extension-regression.sh
```

For commands, automation, packaging, visualization, and MCP access, open [`../ADVANCED.md`](../ADVANCED.md).
