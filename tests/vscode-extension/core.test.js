"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const core = require("../../extensions/context-workspace/src/core");

test("recognizes only a compiler root with all required boundaries", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "context-extension-root-"));
  assert.equal(core.isCompilerRoot(root), false);
  fs.mkdirSync(path.join(root, "scripts"));
  fs.mkdirSync(path.join(root, "EVIDENCE-INBOX"));
  fs.writeFileSync(path.join(root, "AGENTS.md"), "schema");
  fs.writeFileSync(path.join(root, "scripts/add-evidence.py"), "pass");
  assert.equal(core.isCompilerRoot(root), true);
});

test("validates subjects, dates, and evidence URLs", () => {
  assert.equal(core.validateSubject(" Northstar-Feeds "), "northstar-feeds");
  assert.equal(core.validateWorkspaceName("Northstar Decisions"), "Northstar Decisions");
  assert.equal(core.validateDate("2026-08-22"), "2026-08-22");
  assert.equal(core.validateUrl("https://example.com/report.pdf"), "https://example.com/report.pdf");
  assert.throws(() => core.validateSubject("../../escape"));
  assert.throws(() => core.validateWorkspaceName("../escape"));
  assert.throws(() => core.validateDate("2026-02-31"));
  assert.throws(() => core.validateUrl("file:///etc/passwd"));
});

test("builds safe local evidence arguments for paths and pasted text", () => {
  assert.deepEqual(core.evidenceArgs("paths", ["./one.pdf"]), { args: [path.resolve("./one.pdf")], input: undefined });
  assert.deepEqual(core.evidenceArgs("text", { title: "Call note", text: "Evidence" }), { args: ["--text-stdin", "--title", "Call note"], input: "Evidence\n" });
  assert.throws(() => core.evidenceArgs("text", { title: "", text: "Evidence" }));
});

test("classifies clipboard text and URL batches without treating mixed prose as links", () => {
  assert.deepEqual(core.classifyClipboard("https://example.com/a\nhttps://example.com/b"), {
    kind: "urls",
    urls: ["https://example.com/a", "https://example.com/b"]
  });
  assert.deepEqual(core.classifyClipboard("Market note\nhttps://example.com/source"), {
    kind: "text",
    text: "Market note\nhttps://example.com/source"
  });
  assert.throws(() => core.classifyClipboard("  "), /empty/);
});

test("parses unique local file URI drops and ignores comments and remote schemes", () => {
  const value = "# comment\r\nfile:///tmp/report.pdf\r\nhttps://example.com/report\r\nfile:///tmp/report.pdf";
  assert.deepEqual(core.parseUriList(value), ["/tmp/report.pdf"]);
});

test("generates outcome-oriented prompts with evidence discipline", () => {
  assert.match(core.workflowPrompt("brief", { subject: "northstar-feeds" }), /Prepare and save/);
  assert.match(core.workflowPrompt("delta", { subject: "northstar-feeds", since: "2026-08-01" }), /superseded/);
  assert.match(core.workflowPrompt("why", { subject: "northstar-feeds", claim: "availability matters" }), /UNKNOWN/);
  assert.match(core.workflowPrompt("history", { subject: "northstar-feeds", asOf: "2026-06-30" }), /historical and current/);
  assert.match(core.workflowPrompt("review", { subject: "northstar-feeds" }), /human judgment/);
  assert.match(core.workflowPrompt("createProfile", { goal: "Track project decisions" }), /guided specialization builder/);
  assert.match(core.workflowPrompt("createProfile", { goal: "Track project decisions" }), /observable examples/);
  assert.match(core.workflowPrompt("profileReadiness", { profile: "project-decision" }), /technical validation/);
});

test("copies an embedded compiler only into an empty destination", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "context-extension-copy-"));
  const template = path.join(root, "template");
  const destination = path.join(root, "workspace");
  fs.mkdirSync(template);
  fs.mkdirSync(path.join(template, "context"));
  fs.writeFileSync(path.join(template, "START-HERE.md"), "start");
  assert.equal(core.copyCompilerTemplate(template, destination), destination);
  assert.equal(fs.readFileSync(path.join(destination, "START-HERE.md"), "utf8"), "start");
  if (process.platform !== "win32") assert.equal(fs.readlinkSync(path.join(destination, "wiki")), "context");
  assert.throws(() => core.copyCompilerTemplate(template, destination), /empty/);
});

test("finds the newest generated markdown and ignores README placeholders", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "context-extension-output-"));
  fs.mkdirSync(path.join(root, "BRIEFS"));
  fs.writeFileSync(path.join(root, "BRIEFS/README.md"), "placeholder");
  fs.writeFileSync(path.join(root, "BRIEFS/brief.md"), "brief");
  assert.equal(core.latestMarkdown(root, ["BRIEFS"]), path.join(root, "BRIEFS/brief.md"));
});

test("resolves only raw citations and locates line, heading, or timestamp anchors", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "context-extension-citation-"));
  fs.mkdirSync(path.join(root, "raw"));
  const source = path.join(root, "raw", "call.md");
  fs.writeFileSync(source, "# Opening\n\n## Q1 Availability\n\n03:50 Concern increased\n");
  assert.deepEqual(core.resolveCitation(root, "(source: raw/call.md#Q1-Availability)"), { file: source, anchor: "Q1-Availability" });
  assert.equal(core.citationLine(source, "Q1-Availability"), 2);
  assert.equal(core.citationLine(source, "03:50"), 4);
  assert.equal(core.citationLine(source, "L3-L4"), 2);
  assert.throws(() => core.resolveCitation(root, "raw/../AGENTS.md#x"));
});

test("runs commands without shell interpretation", async () => {
  const result = await core.runProcess(process.execPath, ["-e", "process.stdout.write(process.argv[1])", "$(not-executed)"]);
  assert.equal(result.stdout, "$(not-executed)");
  await assert.rejects(core.runProcess(process.execPath, ["-e", "process.exit(7)"]), (error) => error.code === 7);
  const stdin = await core.runProcess(process.execPath, ["-e", "process.stdin.pipe(process.stdout)"], { input: "private evidence" });
  assert.equal(stdin.stdout, "private evidence");
});
