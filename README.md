# context-compiler-bootstrap

[![CI](https://github.com/FrancyJGLisboa/context-compiler-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/FrancyJGLisboa/context-compiler-bootstrap/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**An AI-workspace starter kit for creating and operating specialized, evidence-grounded context compilers.**

```text
context-compiler-bootstrap
        │ creates and configures
        ▼
specialized context compiler
        │ continuously compiles evidence
        ▼
usable context package
```

It is a factory, not the final compiler for every domain. A generated compiler turns changing evidence into current state, history, relationships, provenance, and explicit uncertainty. People consume briefs, semantic deltas, decisions, evidence chains, historical views, and review exceptions—not raw graph data.

The repository includes one reusable specialization: [`profiles/client-decision/`](profiles/client-decision/). Without an activated profile, the compiler remains generic.

## Start here

The friendliest path is the local **Context Workspace** extension for VS Code. It works with the GitHub Copilot subscription already available in VS Code; it stores no credentials, sends no telemetry, and does not call a separate model API.

```bash
./scripts/package-vscode-extension.sh
code --install-extension dist/context-workspace-0.1.0.vsix
```

Then use the Context Workspace sidebar:

1. **Create Compiler** — choose a local folder and optional profile.
2. **Add Evidence** — choose files or folders, drop them on the sidebar, paste text, paste one or many links, or put files in `EVIDENCE-INBOX/`.
3. Ask for the outcome: **Prepare Brief**, **Show Changes**, **Explain Why**, **Historical State**, or **Review Exceptions**.

No daily Git commands are required. After a successful validated update, the compiler creates a scoped local checkpoint containing only compiler-owned paths. It never pushes automatically.

Without the extension, open [`AI-WORKSPACE.code-workspace`](AI-WORKSPACE.code-workspace) and tell the AI:

> Add this evidence and update my context.

[`START-HERE.md`](START-HERE.md) is the one-page operating guide. [`ADVANCED.md`](ADVANCED.md) exposes compiler internals only when you want them.

## Evidence can arrive in any file

**Add Evidence accepts any regular local file.** The original is preserved before extraction begins. This is universal intake, not a claim that every format can be perfectly understood.

Common formats have dedicated paths: text, Markdown, HTML, JSON, CSV, PDF, DOCX, XLSX, screenshots and images, folders, pasted text, URLs, and YouTube captions. An unfamiliar binary is still preserved and reported as **needs attention** rather than silently discarded or falsely marked complete.

Every batch reports each item as **Added**, **Unchanged**, **Degraded**, or **Failed**, with a specific recovery action when needed. URL access always requires explicit confirmation because it crosses the local workspace boundary.

## Daily use

```text
new evidence
    ↓
choose, drop, paste, link, or inbox
    ↓
automatic normalization + incremental compilation + validation
    ↓
automatic local checkpoint
    ↓
brief / delta / why / history / review
```

Before a meeting, add the latest evidence and ask: **“Prepare me for the Northstar meeting.”** After new evidence arrives, ask: **“Add this call and show what changed for Northstar since August 1.”**

A decision-context delta separates meaningful change:

```text
NEW
Q1 soymeal coverage became an active decision.

CHANGED
Concern shifted from price downside to physical availability.

SUPERSEDED
BRL/USD 5.50 was replaced by approximately 5.70.

UNRESOLVED
Maximum acceptable open exposure remains UNKNOWN.
```

When someone challenges a conclusion, ask: **“Why do we think Northstar is increasingly concerned about Q1 soymeal availability?”** The answer resolves to exact evidence, speakers and roles, previous and current state, classification, confidence, and conflicts.

## What the compiler produces

| User need | Produced view |
|---|---|
| Prepare for a meeting | Concise current-state brief |
| Understand movement | Semantic delta |
| See active work | Decision list |
| Challenge a conclusion | Evidence chain |
| Reconstruct history | Point-in-time state |
| Maintain reliability | Exception queue and lint diagnostics |
| Feed another AI workflow | Structured claim and decision package |
| Audit changes | Scoped Git checkpoint and exact source anchors |

The durable product is the local, portable context package. VS Code and AI chat are its operating interface, not its storage layer.

## How the factory works

```bash
git clone https://github.com/FrancyJGLisboa/context-compiler-bootstrap bootstrap
./bootstrap/scripts/create-context-compiler.sh ./northstar-client-context
cd ./northstar-client-context
./scripts/use-profile.sh client-decision
```

A profile supplies domain language without contaminating the core:

```text
profiles/client-decision/
├── profile.json
├── COMPILATION.md
├── schemas/
├── vocabularies/
└── templates/
```

The client-decision profile defines ontology, evidence classes, controlled relations, speaker rules, temporal resolution, outputs, and exception-based review. The generic core continues to own extraction, provenance, compilation, linting, packaging, and incrementality.

To create another specialization, ask the agent:

> Create a `project-decision` profile based on `client-decision`. Represent architectural decisions, owners, constraints, alternatives, supersession, and unresolved risks. Keep project concepts out of the compiler core. Add fixtures and acceptance tests.

This is an LLM-assisted development kit, not yet a no-code profile generator. Creating a new domain still requires defining and testing its contract. Operating an existing compiler is deliberately simpler.

## Automatic rollback without Git chores

Successful mutating workflows run `./scripts/checkpoint-context.sh`. The checkpoint includes only `raw/`, `context/`, `BRIEFS/`, `REVIEWS/`, and `log.md`. It leaves unrelated staged work alone, treats a no-change update as a no-op, and warns without erasing compiled output if Git identity is unavailable. It commits locally only—review and push remain deliberate actions.

## Advanced controls

Ordinary users do not need these. They remain stable controls for automation and customization.

| Command | Purpose |
|---|---|
| `/ctx-add <evidence>` | Preserve, normalize, compile, validate, checkpoint |
| `/ctx-extract <source>` | Acquisition-only internal control |
| `/ctx-compile [source]` | Compilation-only internal control |
| `/ctx-query <question>` | Generic cited query |
| `/ctx-lint` | Generic semantic health check |
| `/client-brief <client>` | Current decision-ready view |
| `/client-delta <client> --since <date>` | Meaningful temporal change |
| `/client-why <claim>` | Inspectable evidence chain |

The old `/wiki-*` names remain backward-compatible forwarders. Existing generic-context workflows continue to work.

## Evidence and decision semantics

The client-decision profile distinguishes `OBSERVATION`, `FACT`, `ASSUMPTION`, `INFERENCE`, `DERIVATION`, and `UNKNOWN`. Material claims preserve source identifier, type, timestamp, speaker where applicable, exact evidence anchor, classification, and confidence where applicable.

Historical claims are not averaged away. Relations such as `updates`, `supersedes`, `confirms`, and `contradicts` preserve what was believed at a point in time and what replaced it. Client statements, internal research, external evidence, and compiler derivations remain separate.

## Reproducible demonstration

The synthetic Northstar Feeds corpus and independent gold answers exercise provenance, current and historical state, supersession, contradiction, decisions, assumptions, speaker attribution, absence refusal, multi-hop reasoning, and decision-context reconstruction.

```bash
./scripts/run-client-decision-demo.sh
./scripts/run-client-decision-benchmark.sh
./scripts/vscode-extension-regression.sh
```

`smoke-all.sh` — 48 deterministic checks wired into CI, including regression guards <!-- claim:smoke-guard-range -->R1–R44<!-- /claim -->. The retrieval evaluation compares against 10 binary checks without an LLM grader. Metrics and failures remain visible; the project does not claim universal superiority over RAG.

## Boundaries

This phase does not build a CRM, SaaS dashboard, vector-database rewrite, Outlook/Teams/Salesforce connector, background monitor, fine-tuned model, or hidden aggregate AI score. Filesystem-first, provenance-aware, temporal compilation remains the product identity.

## Documentation

- [`docs/QUICKSTART.md`](docs/QUICKSTART.md) — current first-use path.
- [`docs/VSCODE-EXTENSION.md`](docs/VSCODE-EXTENSION.md) — local and enterprise VSIX installation.
- [`docs/CONTEXT-COMPILER.md`](docs/CONTEXT-COMPILER.md) — category and architecture.
- [`docs/CLIENT-DECISION-PROFILE.md`](docs/CLIENT-DECISION-PROFILE.md) — specialization contract.
- [`docs/BENCHMARK.md`](docs/BENCHMARK.md) — benchmark methodology and results.
- [`ADVANCED.md`](ADVANCED.md) — implementation controls.

## License

MIT.
