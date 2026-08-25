# context-compiler-bootstrap

[![CI](https://github.com/FrancyJGLisboa/context-compiler-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/FrancyJGLisboa/context-compiler-bootstrap/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**A context compiler turns a pile of documents into a set of dated, sourced statements — so you can ask what is true now, what was true then, and how we know.**

This repository is the kit. What it produces is a context compiler of your own.

**Why you would want one.** Documents record events; they do not hold a view. When
someone asks "why do we think that?", the answer is spread across twenty files and has
changed over time — so the view gets rebuilt by hand, slightly differently, every time.
Search answers "where is this mentioned?", not "what do we believe now, and what
replaced what?", and it starts from nothing on every question. A compiler does the work
once, when each source arrives, because sources arrive far less often than questions.

[**What this is, in plain language →**](docs/WHAT-IS-THIS.md)

```text
context-compiler-bootstrap
        │ creates and configures
        ▼
specialized context compiler
        │ continuously compiles evidence
        ▼
usable context package
```

The kit is not the final compiler for every domain. A generated compiler turns changing evidence into current state, history, relationships, provenance (which exact passage each statement rests on), and explicit uncertainty. People consume briefs, semantic deltas (what changed in meaning, not which bytes changed), decisions, evidence chains, historical views, and review exceptions—not raw graph data.

The repository includes one reusable specialization: [`profiles/client-decision/`](profiles/client-decision/). Without an activated profile, the compiler remains generic.

## Start here

**Prerequisites:** `git`, `bash`, `awk`, `openssl`, and `python3` on PATH under that
exact name, plus an AI coding agent pointed at the folder — Claude Code, or VS Code
with GitHub Copilot. Nothing here compiles evidence on its own; the compile step is a
prompt the agent runs. There is no API key of its own and no telemetry.

```bash
git clone https://github.com/FrancyJGLisboa/context-compiler-bootstrap bootstrap
./bootstrap/scripts/create-context-compiler.sh ./my-context
cd ./my-context
./scripts/preflight.sh          # must print "Ready." before you go further
```

Keep the `bootstrap` clone if you want to generate more compilers later — though a
generated compiler ships the installer too, so it can create the next one itself.

### See it work in two minutes, before supplying your own material

A complete synthetic corpus ships with every generated compiler, so you can reach a
real answer before you have any evidence of your own:

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
([`benchmarks/northstar/README.md`](benchmarks/northstar/README.md)).

### Then your own work

Open the workspace and tell the AI:

> Add this evidence and update my context.

Provide a path, folder, pasted text, URL, or files already placed in
`EVIDENCE-INBOX/`. Then ask for the outcome: **Prepare Brief**, **Show Changes**,
**Explain Why**, **Historical State**, or **Review Exceptions**.

No daily Git commands are required. After a successful validated update, the compiler
creates a scoped local checkpoint containing only compiler-owned paths. It never pushes
automatically. Checkpoints stay silent until `git config user.name` and
`git config user.email` are set in the generated repo.

You do not need `AGENTS.md` for any of the above — it is the canonical schema, written
for the AI tool rather than for you. [`START-HERE.md`](START-HERE.md) is the one-page
operating guide; [`ADVANCED.md`](ADVANCED.md) exposes compiler internals only when you
want them; [`docs/QUICKSTART.md`](docs/QUICKSTART.md) is this same path in more detail.

### Optional — the Context Workspace VS Code extension

A local sidebar for the same actions. It works with the GitHub Copilot subscription
already available in VS Code; it stores no credentials, sends no telemetry, and does
not call a separate model API. **It is not on the Marketplace — you build the VSIX
yourself, which additionally needs Node 20+, npm, network access, and the `code` CLI:**

```bash
./scripts/package-vscode-extension.sh                          # in the bootstrap clone
code --install-extension dist/context-workspace-0.1.0.vsix
```

Then use the sidebar: **Create Compiler** → **Create Specialization** (only if the
included profile does not fit) → **Add Evidence** → ask for the outcome. See
[`docs/VSCODE-EXTENSION.md`](docs/VSCODE-EXTENSION.md).

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

Before a meeting, add the latest evidence and ask: **“Prepare me for the Northstar meeting.”** After new evidence arrives, ask: **“Add this call and show what changed for Northstar since <your date>.”**

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

## Create a specialization through conversation

Choose **Create Specialization** and describe the work:

> Track project decisions, alternatives, owners, constraints, supersession, and unresolved risks.

The AI asks at most five short questions about evidence, important concepts and changes,
useful outputs, and exceptions needing judgment. It then owns the technical work:

1. Safely scaffold the profile without modifying the generic core.
2. Create realistic, clearly labelled synthetic examples and separate gold expectations.
3. Test current state, provenance, temporal supersession, contradiction, absence refusal, and no-op behavior.
4. Show observable example outputs and apply the domain expert's corrections.
5. Record explicit approval, activate the specialization, checkpoint it locally, and end at **Add Evidence**.

Readiness is not a mysterious score. It separately reports technical package validity,
behavioral coverage, and domain-owner approval. The AI cannot declare the domain semantics
correct by itself; approval belongs to the person who understands the work.

## How the factory works underneath

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

The conversational builder performs the equivalent of asking the agent:

> Create a `project-decision` profile based on `client-decision`. Represent architectural decisions, owners, constraints, alternatives, supersession, and unresolved risks. Keep project concepts out of the compiler core. Add fixtures and acceptance tests.

This is an agent-assisted self-service builder, not a magical domain-discovery system.
The domain expert describes meaning, corrects examples, and approves behavior; the agent
handles schemas, vocabularies, fixtures, tests, validation, activation, and Git.

## Automatic rollback without Git chores

Successful mutating workflows run `./scripts/checkpoint-context.sh`. The checkpoint includes only compiler-owned evidence, compiled context, profiles and activation state, generated briefs/reviews, and `log.md`. It leaves unrelated staged work alone, treats a no-change update as a no-op, and warns without erasing compiled output if Git identity is unavailable. It commits locally only—review and push remain deliberate actions.

## Advanced controls

Ordinary users do not need these — say *"Add this evidence and update my context"* and
ask for what you need. They remain stable controls for automation and customization.

**[`ADVANCED.md`](ADVANCED.md) is the complete operator reference:** all 22 commands and
every script, grouped by what you are trying to do — bootstrap a new compiler, manage
specializations, run the demo, get evidence in, ask for work, render and export, and
(bootstrap repo only) maintain the suite and its gates. It ships with every generated
compiler, so it is available where the work happens. A gate (`COMMAND-DOCUMENTED`, R46)
fails CI if a shipped command is missing from it.

The ones you are most likely to want:

| Command | Purpose |
|---|---|
| `/ctx-start` | Entry point — checks setup, resolves the specialization, gives one next action |
| `/ctx-add <evidence>` | Preserve, normalize, compile, validate, checkpoint |
| `/ctx-query <question>` | Generic cited query |
| `/ctx-lint` | Generic semantic health check |
| `/ctx-create-profile` | Build a new specialization through a guided interview |
| `/client-brief <client>` | Current decision-ready view |
| `/client-delta <client> --since <date>` | Meaningful temporal change |
| `/client-why <claim>` | Inspectable evidence chain |

Every command has a prefixed name and a short alias (`/ctx-query` = `/query`). The old
`/wiki-*` names remain backward-compatible forwarders; existing workflows keep working.

## Evidence and decision semantics

The client-decision profile distinguishes `OBSERVATION`, `FACT`, `ASSUMPTION`, `INFERENCE`, `DERIVATION`, and `UNKNOWN`. Material claims preserve source identifier, type, timestamp, speaker where applicable, exact evidence anchor, classification, and confidence where applicable.

Historical claims are not averaged away. Relations such as `updates`, `supersedes`, `confirms`, and `contradicts` preserve what was believed at a point in time and what replaced it. Client statements, internal research, external evidence, and compiler derivations remain separate.

## Reproducible demonstration

The synthetic Northstar Feeds corpus and independent gold answers exercise provenance, current and historical state, supersession, contradiction, decisions, assumptions, speaker attribution, absence refusal, multi-hop reasoning, and decision-context reconstruction.

```bash
./scripts/create-context-compiler.sh /tmp/northstar-compiler   # generate a clean compiler
./scripts/stage-northstar.sh /tmp/northstar-compiler           # stage the synthetic corpus
./scripts/run-northstar-benchmark.sh instrument                # keyless BM25 retrieval instrument
./scripts/vscode-extension-regression.sh                       # extension surface (needs Node + npm)
```

Open `/tmp/northstar-compiler/AI-WORKSPACE.code-workspace` and ask for a brief. The
first three commands need no API key and no LLM.

`smoke-all.sh` — 51 deterministic checks wired into CI, including regression guards <!-- claim:smoke-guard-range -->R1–R47<!-- /claim -->. The retrieval evaluation compares against 10 binary checks without an LLM grader. Metrics and failures remain visible; the project does not claim universal superiority over RAG.

## Boundaries

This phase does not build a CRM, SaaS dashboard, vector-database rewrite, Outlook/Teams/Salesforce connector, background monitor, fine-tuned model, or hidden aggregate AI score. Filesystem-first, provenance-aware, temporal compilation remains the product identity.

## Documentation

- [`docs/QUICKSTART.md`](docs/QUICKSTART.md) — current first-use path.
- [`docs/VSCODE-EXTENSION.md`](docs/VSCODE-EXTENSION.md) — local and enterprise VSIX installation.
- [`docs/CONTEXT-COMPILER.md`](docs/CONTEXT-COMPILER.md) — category and architecture.
- [`profiles/client-decision/COMPILATION.md`](profiles/client-decision/COMPILATION.md) — specialization contract.
- [`benchmarks/northstar/README.md`](benchmarks/northstar/README.md) — benchmark corpus and methodology.
- [`ADVANCED.md`](ADVANCED.md) — implementation controls.

## License

MIT.
