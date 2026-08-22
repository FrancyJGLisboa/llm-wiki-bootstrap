"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { spawn } = require("node:child_process");
const { fileURLToPath } = require("node:url");

const SUBJECT_PATTERN = /^[a-z0-9][a-z0-9-]{0,79}$/;
const WORKSPACE_PATTERN = /^[A-Za-z0-9][A-Za-z0-9 _-]{0,79}$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function isCompilerRoot(root) {
  return Boolean(root) && ["AGENTS.md", "scripts/add-evidence.py", "EVIDENCE-INBOX"].every((entry) =>
    fs.existsSync(path.join(root, entry))
  );
}

function validateSubject(value) {
  const normalized = String(value || "").trim().toLowerCase();
  if (!SUBJECT_PATTERN.test(normalized)) {
    throw new Error("Use a lowercase subject identifier such as northstar-feeds.");
  }
  return normalized;
}

function validateWorkspaceName(value) {
  const normalized = String(value || "").trim();
  if (!WORKSPACE_PATTERN.test(normalized) || normalized === "." || normalized === "..") {
    throw new Error("Use a short workspace name with letters, numbers, spaces, hyphens, or underscores.");
  }
  return normalized;
}

function validateDate(value) {
  const normalized = String(value || "").trim();
  const match = DATE_PATTERN.exec(normalized);
  if (!match) {
    throw new Error("Use a valid date in YYYY-MM-DD format.");
  }
  const [year, month, day] = normalized.split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (parsed.getUTCFullYear() !== year || parsed.getUTCMonth() !== month - 1 || parsed.getUTCDate() !== day) {
    throw new Error("Use a valid date in YYYY-MM-DD format.");
  }
  return normalized;
}

function validateUrl(value) {
  let parsed;
  try {
    parsed = new URL(String(value || "").trim());
  } catch {
    throw new Error("Enter a complete http:// or https:// URL.");
  }
  if (!["http:", "https:"].includes(parsed.protocol)) {
    throw new Error("Only http:// and https:// evidence URLs are supported.");
  }
  return parsed.toString();
}

function classifyClipboard(value) {
  const text = String(value || "").trim();
  if (!text) throw new Error("The clipboard is empty.");
  const lines = text.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  try {
    const urls = lines.map(validateUrl);
    return { kind: "urls", urls };
  } catch {
    return { kind: "text", text };
  }
}

function parseUriList(value) {
  const paths = [];
  for (const line of String(value || "").split(/\r?\n/)) {
    const item = line.trim();
    if (!item || item.startsWith("#")) continue;
    let uri;
    try { uri = new URL(item); } catch { continue; }
    if (uri.protocol === "file:") paths.push(fileURLToPath(uri));
  }
  return [...new Set(paths)];
}

function evidenceArgs(kind, payload) {
  if (kind === "paths") {
    if (!Array.isArray(payload) || payload.length === 0) throw new Error("Choose at least one file or folder.");
    return { args: payload.map((entry) => path.resolve(String(entry))), input: undefined };
  }
  if (kind === "text") {
    const title = String(payload?.title || "").trim();
    const text = String(payload?.text || "").trim();
    if (!title || !text) throw new Error("Pasted evidence needs both a title and text.");
    return { args: ["--text-stdin", "--title", title], input: `${text}\n` };
  }
  throw new Error(`Unsupported local evidence kind: ${kind}`);
}

function workflowPrompt(kind, values = {}) {
  const subject = values.subject ? validateSubject(values.subject) : undefined;
  switch (kind) {
    case "compile":
      return "Process all waiting evidence and update my context. Report each source as added, unchanged, degraded, or failed without claiming success for unsupported extraction. After validation succeeds, create the scoped compiler-owned checkpoint.";
    case "brief":
      return `Prepare and save a concise meeting brief for ${subject}. Include current decisions, recent change, active assumptions, unknowns, contradictions, and exact evidence.`;
    case "delta":
      return `Show and save the meaningful changes for ${subject} since ${validateDate(values.since)}. Separate new, changed, superseded, unresolved, and unchanged-but-material state.`;
    case "why": {
      const claim = String(values.claim || "").trim();
      if (!claim) throw new Error("Enter the conclusion you want explained.");
      return `Explain and save why the context supports this statement about ${subject}: ${claim}. Show the chronological evidence chain, classification, confidence, conflicts, and UNKNOWN when unsupported.`;
    }
    case "history":
      return `Reconstruct and save what was believed about ${subject} on ${validateDate(values.asOf)}. Keep historical and current claims distinct.`;
    case "review":
      return `Show and save only the exceptions that need human judgment for ${subject}: contradictions, ambiguous attribution, possible supersession, stale assumptions, unsupported material claims, and unknown owners.`;
    case "health":
      return `Run the decision-context health checks for ${subject} and save the diagnostic output. Do not invent an aggregate score.`;
    case "createProfile": {
      const goal = String(values.goal || "").trim();
      if (!goal || goal.length > 1000) throw new Error("Describe the kind of work this specialization should support.");
      return `Run the complete guided specialization builder in /ctx-create-profile for this goal: ${goal}. Ask only for missing domain meaning. Scaffold the profile with the deterministic tool, customize it from realistic synthetic examples, run technical and behavioral checks, show observable examples in ordinary language, and request explicit approval before activation. Do not ask me to edit schemas, tests, or Git. End with Add Evidence.`;
    }
    case "profileReadiness": {
      const profile = validateSubject(values.profile);
      return `Check specialization readiness for ${profile}. Run deterministic technical validation and behavioral coverage, save the readiness report, and explain only what needs attention. Do not activate unless a domain owner explicitly approved the observable examples.`;
    }
    default:
      throw new Error(`Unsupported workflow: ${kind}`);
  }
}

function runProcess(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env || process.env,
      shell: false,
      windowsHide: true
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("error", reject);
    if (options.input !== undefined) child.stdin.end(options.input);
    else child.stdin.end();
    child.on("close", (code) => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(Object.assign(new Error(stderr.trim() || `${command} exited ${code}`), { code, stdout, stderr }));
    });
  });
}

function latestMarkdown(root, folders) {
  const candidates = [];
  for (const folder of folders) {
    const absolute = path.join(root, folder);
    if (!fs.existsSync(absolute)) continue;
    for (const name of fs.readdirSync(absolute)) {
      if (!name.endsWith(".md") || name === "README.md") continue;
      const file = path.join(absolute, name);
      const stat = fs.statSync(file);
      if (stat.isFile()) candidates.push({ file, modified: stat.mtimeMs });
    }
  }
  candidates.sort((a, b) => b.modified - a.modified || a.file.localeCompare(b.file));
  return candidates[0]?.file;
}

function resolveCitation(root, value) {
  const match = String(value || "").trim().match(/(?:source:\s*)?(raw\/[^#)\s]+)(?:#([^)]*))?/);
  if (!match) throw new Error("Paste a citation such as raw/source.md#anchor.");
  const rawRoot = path.resolve(root, "raw");
  const file = path.resolve(root, match[1]);
  if (file !== rawRoot && !file.startsWith(`${rawRoot}${path.sep}`)) throw new Error("Citations must resolve inside raw/.");
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) throw new Error(`Evidence file does not exist: ${match[1]}`);
  return { file, anchor: match[2] || "" };
}

function citationLine(file, anchor) {
  if (!anchor) return 0;
  const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
  const lineMatch = anchor.match(/^L?(\d+)(?:-L?\d+)?$/i);
  if (lineMatch) return Math.max(0, Math.min(lines.length - 1, Number(lineMatch[1]) - 1));
  const normalized = decodeURIComponent(anchor).toLowerCase();
  const exact = lines.findIndex((line) => line.toLowerCase().includes(normalized));
  if (exact >= 0) return exact;
  const heading = normalized.replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  const headingLine = lines.findIndex((line) => line.replace(/^#+\s*/, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") === heading);
  return Math.max(0, headingLine);
}

function copyCompilerTemplate(template, destination) {
  const target = path.resolve(destination);
  if (!fs.existsSync(template)) throw new Error("The embedded compiler template is missing. Reinstall the extension.");
  if (fs.existsSync(target) && fs.readdirSync(target).length > 0) throw new Error("Choose an empty destination folder.");
  fs.mkdirSync(target, { recursive: true });
  fs.cpSync(template, target, { recursive: true, errorOnExist: true, force: false });
  const contextRoot = path.join(target, "context");
  const legacyRoot = path.join(target, "wiki");
  if (fs.existsSync(contextRoot) && !fs.existsSync(legacyRoot)) {
    try {
      fs.symlinkSync(process.platform === "win32" ? contextRoot : "context", legacyRoot, process.platform === "win32" ? "junction" : "dir");
    } catch {
      // `context/` remains authoritative when policy blocks the legacy alias.
    }
  }
  return target;
}

module.exports = {
  citationLine,
  classifyClipboard,
  copyCompilerTemplate,
  evidenceArgs,
  isCompilerRoot,
  latestMarkdown,
  parseUriList,
  resolveCitation,
  runProcess,
  validateDate,
  validateSubject,
  validateWorkspaceName,
  validateUrl,
  workflowPrompt
};
