# Install and manage Context Workspace for VS Code

`Context Workspace` is a thin local interface for the compiler in this repository. It
does not replace the compiler, upload the context package, or require a model key.

## Build the managed VSIX

Requirements: Node.js 20+, npm, Python 3, Git, and the repository checkout.

```bash
./scripts/package-vscode-extension.sh
```

The build creates `dist/context-workspace-0.1.0.vsix`, embeds a clean compiler template,
normalizes archive metadata for byte-identical rebuilds, and verifies the package contents. It does not include the bootstrap's demo context,
development Git history, benchmark results, or dependency directory.

## Install on one laptop

```bash
code --install-extension dist/context-workspace-0.1.0.vsix
```

Alternatively, use **Extensions: Install from VSIX…** in VS Code. After installation,
open the **Context Workspace** icon and select **Create Compiler**.

The user still needs the organization's GitHub Copilot extension and entitlement for AI
chat. Context Workspace itself stores no GitHub token and calls no independent model API.

## Enterprise rollout

1. Build and verify the VSIX in CI from a reviewed tag.
2. Sign or checksum the artifact according to the organization's software-distribution
   policy.
3. Deploy the VSIX through the existing endpoint channel, such as Intune, Jamf, an
   internal software portal, or a managed VS Code extension policy.
4. Enable GitHub Copilot Chat and repository custom instructions under the enterprise's
   AI policies.
5. Pilot with a dedicated evidence classification and confirm which source types may be
   sent to Copilot before broad rollout.

GitHub documents centralized [Copilot enterprise policies](https://docs.github.com/en/copilot/concepts/policies)
and [enterprise-managed client settings](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/configure-enterprise-managed-settings).
VS Code documents both [VSIX installation](https://code.visualstudio.com/docs/configure/extensions/extension-marketplace#_install-from-a-vsix)
and [extension enterprise support](https://code.visualstudio.com/docs/enterprise/extensions).

## Permissions and data movement

The extension requires a trusted local workspace because it invokes the compiler's
versioned scripts. It can read the selected compiler, stage user-selected evidence, and
open generated outputs. It has no background watcher and no telemetry.

Local files and pasted text are staged locally. Pasted evidence travels through process
standard input, not a command-line argument. URL acquisition always shows the destination
host and requires explicit confirmation before AI chat performs the existing acquisition
workflow.

GitHub Copilot's processing and retention are governed by the organization's subscription,
policies, and configured exclusions. Review GitHub's current [content exclusion limitations](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/context/content-exclusion),
especially before using agent mode with sensitive evidence.

## Updates and rollback

The extension does not self-update. IT installs a new reviewed VSIX version. Keep the prior
artifact so rollback is one managed reinstall:

```bash
code --install-extension context-workspace-0.1.0.vsix --force
```

Compiler repositories remain independently versioned and usable if the extension is
removed.
