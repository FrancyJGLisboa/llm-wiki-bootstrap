"use strict";

const path = require("node:path");
const vscode = require("vscode");
const core = require("./src/core");

const JOURNEY = [
  ["1 · SET UP", "Create or teach a compiler", "rocket", [
    ["Create New Compiler", "Start a clean context workspace", "contextWorkspace.createCompiler", "new-folder"],
    ["Open Another Compiler", "Switch to an existing context workspace", "contextWorkspace.openCompiler", "folder-opened"],
    ["Create Specialization", "Teach it another kind of work", "contextWorkspace.createSpecialization", "sparkle"],
    ["Check Specialization", "Validate examples before activation", "contextWorkspace.checkSpecialization", "checklist"]
  ]],
  ["2 · ADD & UPDATE", "Point at evidence; the agent compiles it", "files", [
    ["Add Files or Folder", "Choose or drop evidence here", "contextWorkspace.addEvidence", "add"],
    ["Paste Text or Links", "Use clipboard text or URLs", "contextWorkspace.addClipboard", "clippy"],
    ["Process Evidence Inbox", "Compile files already waiting", "contextWorkspace.processInbox", "inbox"]
  ]],
  ["3 · ASK & USE", "Query the ready context in natural language", "comment-discussion", [
    ["Ask Anything", "Ask a natural-language question", "contextWorkspace.askContext", "comment"],
    ["Prepare Brief", "Current decisions, changes, assumptions, unknowns", "contextWorkspace.prepareBrief", "preview"],
    ["Show Changes", "Meaningful movement since a date", "contextWorkspace.showChanges", "diff"],
    ["Explain Why", "Inspect a conclusion's evidence chain", "contextWorkspace.explainWhy", "references"],
    ["Historical State", "Reconstruct what was believed on a date", "contextWorkspace.historicalState", "history"]
  ]],
  ["4 · REVIEW TRUST", "Inspect exceptions and source evidence", "verified", [
    ["Review Exceptions", "Only items needing human judgment", "contextWorkspace.reviewExceptions", "issues"],
    ["Check Context Health", "Citation, temporal, stale, unknown diagnostics", "contextWorkspace.checkHealth", "shield"],
    ["Open Source Evidence", "Jump to a cited local source", "contextWorkspace.openCitation", "link-external"]
  ]],
  ["5 · ADVANCED", "Inspect the machinery only when needed", "tools", [
    ["Open Advanced Controls", "Commands, files, automation, packaging", "contextWorkspace.openAdvanced", "settings-gear"]
  ]]
];

class ActionProvider {
  constructor(getRoot) {
    this.getRoot = getRoot;
    this.changed = new vscode.EventEmitter();
    this.onDidChangeTreeData = this.changed.event;
  }
  refresh() { this.changed.fire(); }
  getTreeItem(value) { return value; }
  getChildren(parent) {
    if (!this.getRoot()) {
      return [
        treeItem("Create Compiler", "Start a new local context workspace", "contextWorkspace.createCompiler", "new-folder"),
        treeItem("Open Compiler", "Use an existing context workspace", "contextWorkspace.openCompiler", "folder-opened")
      ];
    }
    if (parent?.children) return parent.children.map((value) => treeItem(...value));
    return JOURNEY.map(([label, description, icon, children]) => groupItem(label, description, icon, children));
  }
}

function groupItem(label, description, icon, children) {
  const value = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.Expanded);
  value.tooltip = `${label} — ${description}`;
  value.iconPath = new vscode.ThemeIcon(icon);
  value.children = children;
  return value;
}

function treeItem(label, description, command, icon) {
  const value = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.None);
  value.tooltip = `${label} — ${description}`;
  value.iconPath = new vscode.ThemeIcon(icon);
  value.command = { command, title: label };
  return value;
}

function activate(context) {
  const output = vscode.window.createOutputChannel("Context Workspace", { log: true });
  let selectedRoot;
  const workspaceRoot = () => {
    if (selectedRoot && core.isCompilerRoot(selectedRoot)) return selectedRoot;
    for (const folder of vscode.workspace.workspaceFolders || []) {
      if (core.isCompilerRoot(folder.uri.fsPath)) return folder.uri.fsPath;
    }
    return undefined;
  };
  const provider = new ActionProvider(workspaceRoot);
  let handleEvidenceDrop = async () => {};
  const dragAndDropController = {
    dragMimeTypes: [],
    dropMimeTypes: ["text/uri-list", "files"],
    async handleDrop(_target, transfer) { await handleEvidenceDrop(transfer); }
  };
  const tree = vscode.window.createTreeView("contextWorkspace.actions", { treeDataProvider: provider, dragAndDropController });
  context.subscriptions.push(output, tree);

  const register = (name, handler) => context.subscriptions.push(vscode.commands.registerCommand(name, async (...args) => {
    try {
      return await handler(...args);
    } catch (error) {
      output.error(error?.stack || String(error));
      const choice = await vscode.window.showErrorMessage(`Context Workspace: ${error.message || error}`, "Show details");
      if (choice === "Show details") output.show(true);
      return undefined;
    }
  }));

  const requireRoot = async () => {
    const root = workspaceRoot();
    if (root) return root;
    const choice = await vscode.window.showInformationMessage("Open or create a context compiler first.", "Create Compiler", "Open Compiler");
    if (choice === "Create Compiler") await vscode.commands.executeCommand("contextWorkspace.createCompiler");
    if (choice === "Open Compiler") await vscode.commands.executeCommand("contextWorkspace.openCompiler");
    return undefined;
  };

  const openChat = async (prompt) => {
    await vscode.env.clipboard.writeText(prompt);
    try {
      await vscode.commands.executeCommand("workbench.action.chat.open", { query: prompt });
    } catch {
      try {
        await vscode.commands.executeCommand("workbench.action.chat.open");
        await vscode.window.showInformationMessage("The request is copied. Paste it into AI chat to continue.");
      } catch {
        await vscode.window.showWarningMessage("The request is copied, but AI chat is unavailable. Ask your VS Code administrator to enable GitHub Copilot Chat, then paste the request.");
      }
    }
  };

  const runWorkflow = async (kind, values, destinationFolders) => {
    const root = await requireRoot();
    if (!root) return;
    const before = core.latestMarkdown(root, destinationFolders);
    await openChat(core.workflowPrompt(kind, values));
    const action = await vscode.window.showInformationMessage("The request is ready in AI chat. Complete it there; saved results will appear in this workspace.", "Open latest saved result");
    if (action === "Open latest saved result") {
      const latest = core.latestMarkdown(root, destinationFolders) || before;
      if (latest) await vscode.window.showTextDocument(vscode.Uri.file(latest), { preview: false });
      else await vscode.window.showInformationMessage("No saved result exists yet. Complete the request in AI chat first.");
    }
  };

  const askSubject = () => vscode.window.showInputBox({
    title: "Who or what is this about?",
    prompt: "Use the compiler's subject identifier",
    placeHolder: "northstar-feeds",
    validateInput: (value) => validationMessage(core.validateSubject, value)
  });
  const askDate = (title) => vscode.window.showInputBox({
    title,
    placeHolder: "2026-08-01",
    validateInput: (value) => validationMessage(core.validateDate, value)
  });

  register("contextWorkspace.getStarted", () => vscode.commands.executeCommand("workbench.action.openWalkthrough", "context-compiler.context-workspace#contextWorkspace.onboarding"));
  register("contextWorkspace.refresh", () => provider.refresh());
  register("contextWorkspace.openCompiler", async () => {
    const picked = await vscode.window.showOpenDialog({ title: "Open a context compiler", canSelectFiles: false, canSelectFolders: true, canSelectMany: false });
    if (!picked?.[0]) return;
    if (!core.isCompilerRoot(picked[0].fsPath)) throw new Error("That folder is not a context compiler. Choose one containing AGENTS.md and EVIDENCE-INBOX.");
    selectedRoot = picked[0].fsPath;
    provider.refresh();
    await vscode.commands.executeCommand("vscode.openFolder", picked[0], false);
  });
  register("contextWorkspace.createCompiler", async () => {
    const picked = await vscode.window.showOpenDialog({ title: "Choose where to create the compiler", canSelectFiles: false, canSelectFolders: true, canSelectMany: false });
    if (!picked?.[0]) return;
    const name = await vscode.window.showInputBox({ title: "Name the context workspace", placeHolder: "Northstar Context", validateInput: (value) => validationMessage(core.validateWorkspaceName, value) });
    if (!name) return;
    const destination = path.join(picked[0].fsPath, core.validateWorkspaceName(name));
    const override = vscode.workspace.getConfiguration("contextWorkspace").get("bootstrapPath", "");
    await vscode.window.withProgress({ location: vscode.ProgressLocation.Notification, title: "Creating context workspace…", cancellable: false }, async () => {
      if (override) await core.runProcess(path.join(override, "scripts/create-context-compiler.sh"), [destination], { cwd: override });
      else {
        core.copyCompilerTemplate(path.join(context.extensionPath, "resources/compiler-template"), destination);
        await core.runProcess("git", ["init", "-q"], { cwd: destination });
      }
    });
    selectedRoot = destination;
    const profile = await vscode.window.showQuickPick(["Client decisions", "Generic research"], { title: "What should this workspace understand?" });
    if (profile === "Client decisions") await core.runProcess(path.join(destination, "scripts/use-profile.sh"), ["client-decision"], { cwd: destination });
    await vscode.commands.executeCommand("vscode.openFolder", vscode.Uri.file(destination), false);
  });

  const stageAndCompile = async (request) => {
    const root = await requireRoot();
    if (!root) return;
    const python = vscode.workspace.getConfiguration("contextWorkspace").get("pythonPath", "python3");
    await vscode.window.withProgress({ location: vscode.ProgressLocation.Notification, title: "Adding evidence…", cancellable: false }, async () => {
      const result = await core.runProcess(python, [path.join(root, "scripts/add-evidence.py"), "--root", root, "--json", ...request.args], { cwd: root, input: request.input });
      const summary = JSON.parse(result.stdout);
      output.info(`Evidence staged: ${summary.staged.length}; unchanged: ${summary.unchanged.length}`);
    });
    await openChat(core.workflowPrompt("compile"));
    await vscode.window.showInformationMessage("Evidence is preserved. Extraction has not completed until AI chat reports added, unchanged, degraded, or failed for each source.");
  };

  handleEvidenceDrop = async (transfer) => {
    const dropped = new Set();
    const uriList = transfer.get("text/uri-list");
    if (uriList) for (const file of core.parseUriList(await uriList.asString())) dropped.add(file);
    for (const [, entry] of transfer) {
      const file = entry.asFile?.();
      if (file?.uri?.scheme === "file") dropped.add(file.uri.fsPath);
    }
    if (dropped.size === 0) throw new Error("No local files were found in that drop. Use Paste or Add Links for clipboard content and URLs.");
    await stageAndCompile(core.evidenceArgs("paths", [...dropped]));
  };

  const addLocalEvidence = async () => {
    const picked = await vscode.window.showOpenDialog({ title: "Choose evidence", canSelectFiles: true, canSelectFolders: true, canSelectMany: true });
    if (picked?.length) await stageAndCompile(core.evidenceArgs("paths", picked.map((uri) => uri.fsPath)));
  };
  register("contextWorkspace.addEvidence", addLocalEvidence);
  register("contextWorkspace.addLocalEvidence", addLocalEvidence);
  register("contextWorkspace.addPastedText", async () => {
    const title = await vscode.window.showInputBox({ title: "Evidence title", placeHolder: "Procurement call — August 22" });
    if (!title) return;
    const text = await vscode.window.showInputBox({ title: "Paste evidence", prompt: "The text stays local and is passed through standard input.", ignoreFocusOut: true });
    if (text) await stageAndCompile(core.evidenceArgs("text", { title, text }));
  });
  const acquireUrls = async (urls) => {
    const hosts = [...new Set(urls.map((url) => new URL(url).hostname))];
    const consent = await vscode.window.showWarningMessage(`Acquire ${urls.length} source${urls.length === 1 ? "" : "s"} from ${hosts.join(", ")}? Each source will be fetched over the network and preserved locally.`, { modal: true }, "Acquire");
    if (consent === "Acquire") await openChat(`Add these URLs as evidence and update my context:\n${urls.join("\n")}\nPreserve every fetched source locally. Report added, unchanged, degraded, and failed separately.`);
  };
  register("contextWorkspace.addClipboard", async () => {
    const clipboard = core.classifyClipboard(await vscode.env.clipboard.readText());
    if (clipboard.kind === "urls") return acquireUrls(clipboard.urls);
    const title = await vscode.window.showInputBox({ title: "Title this clipboard evidence", placeHolder: "Procurement call — August 22" });
    if (title) await stageAndCompile(core.evidenceArgs("text", { title, text: clipboard.text }));
  });
  register("contextWorkspace.addUrl", async () => {
    const root = await requireRoot();
    if (!root) return;
    const value = await vscode.window.showInputBox({ title: "Evidence URL", placeHolder: "https://example.com/report.pdf", validateInput: (input) => validationMessage(core.validateUrl, input) });
    if (!value) return;
    const url = core.validateUrl(value);
    await acquireUrls([url]);
  });
  register("contextWorkspace.processInbox", () => runWorkflow("compile", {}, ["BRIEFS", "REVIEWS"]));
  register("contextWorkspace.askContext", async () => {
    const question = await vscode.window.showInputBox({
      title: "Ask your compiled context",
      prompt: "Ask naturally. Answers must cite local evidence and say UNKNOWN when unsupported.",
      placeHolder: "What changed, what is currently believed, and why?",
      ignoreFocusOut: true
    });
    if (question) await runWorkflow("query", { question }, ["BRIEFS"]);
  });
  register("contextWorkspace.createSpecialization", async () => {
    const goal = await vscode.window.showInputBox({
      title: "What should this workspace help people understand and decide?",
      prompt: "Describe the work in ordinary language. The AI will ask only for missing domain meaning.",
      placeHolder: "Track project decisions, alternatives, owners, constraints, and unresolved risks",
      ignoreFocusOut: true
    });
    if (goal) await runWorkflow("createProfile", { goal }, ["REVIEWS"]);
  });
  register("contextWorkspace.checkSpecialization", async () => {
    const profile = await vscode.window.showInputBox({
      title: "Which specialization should be checked?",
      placeHolder: "project-decision",
      validateInput: (value) => validationMessage(core.validateSubject, value)
    });
    if (profile) await runWorkflow("profileReadiness", { profile }, ["REVIEWS"]);
  });
  register("contextWorkspace.prepareBrief", async () => { const subject = await askSubject(); if (subject) await runWorkflow("brief", { subject }, ["BRIEFS"]); });
  register("contextWorkspace.showChanges", async () => { const subject = await askSubject(); if (!subject) return; const since = await askDate("Show changes since"); if (since) await runWorkflow("delta", { subject, since }, ["BRIEFS"]); });
  register("contextWorkspace.explainWhy", async () => { const subject = await askSubject(); if (!subject) return; const claim = await vscode.window.showInputBox({ title: "Which conclusion should be explained?", placeHolder: "Q1 availability is becoming a concern" }); if (claim) await runWorkflow("why", { subject, claim }, ["BRIEFS"]); });
  register("contextWorkspace.historicalState", async () => { const subject = await askSubject(); if (!subject) return; const asOf = await askDate("Reconstruct state on"); if (asOf) await runWorkflow("history", { subject, asOf }, ["BRIEFS"]); });
  register("contextWorkspace.reviewExceptions", async () => { const subject = await askSubject(); if (subject) await runWorkflow("review", { subject }, ["REVIEWS"]); });
  register("contextWorkspace.checkHealth", async () => { const subject = await askSubject(); if (subject) await runWorkflow("health", { subject }, ["REVIEWS"]); });
  register("contextWorkspace.openCitation", async () => {
    const root = await requireRoot();
    if (!root) return;
    const value = await vscode.window.showInputBox({ title: "Open evidence citation", prompt: "Paste a source citation from a brief or evidence chain", placeHolder: "raw/northstar-call.md#q1-availability" });
    if (!value) return;
    const citation = core.resolveCitation(root, value);
    const document = await vscode.workspace.openTextDocument(vscode.Uri.file(citation.file));
    const editor = await vscode.window.showTextDocument(document, { preview: false });
    const line = core.citationLine(citation.file, citation.anchor);
    const position = new vscode.Position(line, 0);
    editor.selection = new vscode.Selection(position, position);
    editor.revealRange(new vscode.Range(position, position), vscode.TextEditorRevealType.InCenter);
  });
  register("contextWorkspace.openAdvanced", async () => { const root = await requireRoot(); if (root) await vscode.window.showTextDocument(vscode.Uri.file(path.join(root, "ADVANCED.md")), { preview: false }); });
}

function validationMessage(validator, value) {
  try { validator(value); return undefined; }
  catch (error) { return error.message; }
}

function deactivate() {}

module.exports = { activate, deactivate };
