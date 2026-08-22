"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const Module = require("node:module");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

test("activates and registers every declared command", () => {
  const registered = new Set();
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "context-extension-activation-"));
  fs.mkdirSync(path.join(root, "scripts"));
  fs.mkdirSync(path.join(root, "EVIDENCE-INBOX"));
  fs.writeFileSync(path.join(root, "AGENTS.md"), "schema");
  fs.writeFileSync(path.join(root, "scripts/add-evidence.py"), "pass");
  let provider;
  class EventEmitter {
    constructor() { this.event = () => {}; }
    fire() {}
  }
  class TreeItem {
    constructor(label, collapsibleState) { this.label = label; this.collapsibleState = collapsibleState; }
  }
  const disposable = () => ({ dispose() {} });
  const vscode = {
    EventEmitter,
    ThemeIcon: class { constructor(id) { this.id = id; } },
    TreeItem,
    TreeItemCollapsibleState: { None: 0, Expanded: 2 },
    commands: {
      registerCommand(name) { registered.add(name); return disposable(); },
      executeCommand() { return Promise.resolve(); }
    },
    window: {
      createOutputChannel() { return { ...disposable(), info() {}, error() {}, show() {} }; },
      createTreeView(_id, options) { provider = options.treeDataProvider; return disposable(); },
      showErrorMessage() { return Promise.resolve(); }
    },
    workspace: {
      workspaceFolders: [{ uri: { fsPath: root } }],
      getConfiguration() { return { get(_name, fallback) { return fallback; } }; }
    }
  };
  const originalLoad = Module._load;
  Module._load = function(request, parent, isMain) {
    if (request === "vscode") return vscode;
    return originalLoad.call(this, request, parent, isMain);
  };
  try {
    const extensionPath = path.resolve(__dirname, "../../extensions/context-workspace");
    const extension = require(path.join(extensionPath, "extension.js"));
    extension.activate({ extensionPath, subscriptions: [] });
    const manifest = require(path.join(extensionPath, "package.json"));
    const declared = new Set(manifest.contributes.commands.map((item) => item.command));
    assert.deepEqual(registered, declared);
    const groups = provider.getChildren();
    assert.deepEqual(groups.map((item) => item.label), [
      "1 · SET UP", "2 · ADD & UPDATE", "3 · ASK & USE", "4 · REVIEW TRUST", "5 · ADVANCED"
    ]);
    assert.ok(groups.every((item) => item.collapsibleState === 2));
    assert.equal(provider.getChildren(groups[0])[0].label, "Create New Compiler");
    assert.equal(provider.getChildren(groups[1])[0].label, "Add Files or Folder");
    assert.equal(provider.getChildren(groups[2])[0].label, "Ask Anything");
  } finally {
    Module._load = originalLoad;
  }
});
