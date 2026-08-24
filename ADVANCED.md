# Operator reference

Everything you can run, in one place. Two audiences, one document:

- **Operating a generated compiler** — sections 1–5. This file ships with every
  compiler, so it is available where the work happens.
- **Maintaining the bootstrap repository** — sections 6–8. Those commands exist only
  in the bootstrap clone; a generated compiler does not ship them.

Ordinary daily use needs none of this: say *"Add this evidence and update my context"*
and ask for what you need. `START-HERE.md` is that one-page guide. This file is for when
you want the controls.

Every command has a prefixed name (`/ctx-query`) and a short alias (`/query`). Both
resolve to the same procedure. Nine deprecated `/wiki-*` names still forward.

---

## 1. Bootstrap a new context compiler

Run from a clone of the bootstrap repository — or from any generated compiler, which
ships the installer and can create the next one itself.

```bash
git clone https://github.com/FrancyJGLisboa/context-compiler-bootstrap bootstrap
./bootstrap/scripts/create-context-compiler.sh ./my-context   # scaffold; refuses a non-empty target
cd ./my-context
./scripts/preflight.sh                                        # must print "Ready."
```

| Command | What it does |
|---|---|
| `scripts/create-context-compiler.sh <dir>` | Copy the skeleton named by `scripts/installer-skeleton-manifest.txt` into `<dir>`, seed FRESH templates, `git init`. No network, no API key. |
| `scripts/preflight.sh` | Report hard requirements (`bash`, `awk`, `openssl`, `git`, `python3`) and optional extractors. Exit 1 if anything hard is missing. |
| `scripts/verify-create-context-compiler.sh` | Prove the generated tree matches the manifest exactly, with a negative control. |
| `/ctx-init` (`/init`) | Scaffold the structure in place, idempotently. The installer already did this; use it only if you delete part of the tree. |

Prerequisites the installer cannot check for you: an AI coding agent pointed at the
folder (Claude Code, or VS Code with GitHub Copilot). Nothing in `scripts/` compiles
evidence on its own — the compile step is a prompt the agent runs.

## 2. Specializations

A profile supplies domain language without touching the generic core. One ships:
`client-decision`. Without an active profile the compiler stays generic.

| Command | What it does |
|---|---|
| `/ctx-start` (`/start`) | The entry point. Checks setup, resolves the active specialization, offers the demo when nothing is compiled yet, and ends with one next action. |
| `/ctx-create-profile` (`/create-profile`) | Build a new specialization through a guided interview: at most five domain questions, then scaffold, test, preview observable behaviour, take explicit approval, activate, checkpoint. |
| `scripts/use-profile.sh <profile>` | Activate a profile. Refuses a self-service profile that is not ready. |
| `scripts/profile-scaffold.py` | Create a non-overwriting profile package. |
| `scripts/profile-check.py --root . --profile <p>` | Validate the profile's portable-asset manifest. |
| `scripts/profile-resolve.py --root . --json` | Report which profile is active. |
| `scripts/profile-readiness.py --root . --profile <p>` | Report technical validity, behavioural coverage and domain-owner approval — separately, not as one score. |

## 3. See it work before supplying your own evidence

```bash
./scripts/stage-northstar.sh .
```

Then ask the AI: `Update my context, then prepare a brief for Northstar Feeds.`
Northstar Feeds is fictional; every person, number and event is synthetic.

| Command | What it does |
|---|---|
| `scripts/stage-northstar.sh <dir>` | Stage the synthetic corpus and activate `client-decision`. |
| `scripts/run-northstar-benchmark.sh instrument` | Keyless BM25 retrieval instrument over the gold set. Also `prepare`, `execute`, `score`. |
| `scripts/new-corpus.sh` | Scaffold your own corpus adapter from `templates/corpus/`. |

## 4. Evidence in, context out

`/ctx-add` is the single user-facing intake. The rest are stable internal controls.

| Command | What it does |
|---|---|
| `/ctx-add <evidence>` (`/add`) | Preserve, normalize, compile, validate, checkpoint. Accepts files, folders, pasted text, one or many URLs. |
| `/ctx-inbox` (`/inbox`) | Extract every new or changed file staged under `EVIDENCE-INBOX/`, then compile. |
| `/ctx-extract <source>` (`/extract`) | Acquisition only — URLs, PDF, DOCX, XLSX, CSV, images, YouTube captions, or `--text` for pasted content. Does not touch the compiled context. |
| `/ctx-compile [<raw-file>]` (`/compile`, `/ingest`) | The 7-step pipeline, then regenerate synthesis artifacts. Body-hash delta detection; idempotent on unchanged sources. |
| `/ctx-lint [--apply]` (`/lint`) | Broken links, orphans, contradictions, stale claims, unresolved questions, drifted raw sources, missing valid time. Reports by default. |
| `scripts/auto-ingest.sh` | Watch and compile automatically. Automation only — not part of daily use. |
| `scripts/checkpoint-context.sh` | Scoped local commit of compiler-owned paths. Never pushes. Runs automatically after a successful update. |
| `scripts/body-hash.sh <file>` | The canonical content hash. Do not reinvent it inline. |

## 5. Asking for work

### Generic

| Command | What it does |
|---|---|
| `/ctx-query <question>` (`/query`) | Answer from the compiled context with citations; web-search and promote on a gap (`--no-promote` to suppress). `--visual html\|pdf\|png` also emits a diagram. |
| `/ctx-discover` (`/discover`) | Surface non-obvious structure — multi-hop causal chains, hub concepts, the widest connection, open questions, tensions. Key-free graph analysis. |
| `/ctx-rules` (`/rules`) | Inventory and triage rules found in the material; classify deterministic / heuristic / unverifiable. Writes no code. |

### Client-decision specialization

Each takes a client and accepts `--save` to write the result under `BRIEFS/` or `REVIEWS/`.

| Command | What it does |
|---|---|
| `/client-brief <client>` | Current, evidence-grounded decision brief. |
| `/client-delta <client> --since <date>` | Semantic change: NEW, CHANGED, SUPERSEDED, UNRESOLVED. |
| `/client-decisions <client>` | Current or point-in-time decision projections. |
| `/client-assumptions <client>` | Currently active, evidence-grounded assumptions. |
| `/client-why <claim>` | The exact evidence chain — source, speaker, prior and current state, classification, confidence, conflicts. |
| `/client-review <client>` | Exception-only queue: what genuinely needs human judgment. |
| `/client-lint <client>` | Transparent decision-context health diagnostics. |

### Rendering and export

Read-only on `raw/` and the compiled context; they only write new output files.

| Command | What it does |
|---|---|
| `/ctx-visualize [graph\|mermaid\|slides\|serve]` (`/visualize`) | Interactive D3 graph (default), MARP slides, mermaid images, or a local server. |
| `/ctx-diagram "<intent>"` (`/diagram`) | Compose a poster by reasoning over the context: retrieve, score the 8 archetypes, you pick, it writes self-contained HTML to `diagrams/`. |
| `/ctx-flashcards [dir]` (`/flashcards`) | Export every `## Flashcards` section to an Anki-importable CSV. |
| `scripts/package-wiki.sh` | Build a portable, verifiable bundle. Check one with `scripts/verify-bundle.sh`. |
| `scripts/mcp-server.sh` | Expose the compiled context to any MCP-aware client. See `docs/MCP.md`. |
| `scripts/wiki-metrics.sh` | Size, link density and coverage numbers. |

---

## 6. Maintaining the bootstrap repository

**These do not ship into a generated compiler.** They exist only in the bootstrap clone.

| Command | What it does |
|---|---|
| `scripts/smoke-all.sh [--no-build]` | The full suite. `--no-build` skips the LLM phase and is what CI runs. |
| `scripts/eval-onboarding.sh [--min-score N]` | Drive `claude -p` as a brand-new user and score the on-ramp out of 5. |
| `scripts/eval-multi-hop.sh`, `eval-retrieval.sh`, `eval-corpus.sh`, `eval-scale.sh` | Keyless measurement harnesses; the deliverable is the number. |
| `scripts/quality.sh --ci` | Shell and duplication quality gate. |
| `scripts/package-vscode-extension.sh` | Build the VSIX. Needs Node 20+, npm, network. |

## 7. Gates and the ratchet

| Command | What it does |
|---|---|
| `/ctx-gate` (`/gate`) | Turn a deterministic rule into a proven gate: contract, committed fixtures, five-way mutation proof, three declared blind spots, then CI wiring. |
| `scripts/new-gate.sh <RULE-ID>` | Scaffold a gate from `templates/gate/`. |
| `scripts/gate-fixtures.sh` | Every gate must fail its violating fixture and pass its clean one. An unfixtured gate is an unproven one. |
| `scripts/gate-ratchet.sh` | No gate's violation count may go up. Suppressions count as violations. |
| `scripts/gate-reachable.sh` | Every oracle is reachable from CI. An unwired gate reads as coverage and never fires. |
| `scripts/gate-doc-paths.sh` | A path named in a doc must resolve, and an asset a shipped doc or script depends on must itself ship. |
| `scripts/gate-doc-claims.sh` | A structural number stated in prose is recomputed, never typed. |

Gate doctrine is in `docs/deterministic-gates.md`. Run any gate with `--count` for the
ratchet's tally form.

## 8. Where things live

| Path | Contents |
|---|---|
| `EVIDENCE-INBOX/`, `BRIEFS/`, `REVIEWS/` | The only folders daily work touches. |
| `raw/` | Immutable source material. Only the three `ingested_*` frontmatter fields are ever written back. |
| `context/` | Compiled context. `wiki/` is a compatibility symlink and may be absent on Windows. |
| `profiles/` | Specialization contracts. |
| `AGENTS.md` | The canonical schema, written for the AI tool. You do not need it to operate the compiler. |
| `log.md` | Append-only record of every compile, promotion and lint-apply. |

The friendly workspace hides machinery from the VS Code Explorer; it does not remove or
lock it. To see everything, open the repository folder normally instead of
`AI-WORKSPACE.code-workspace`, or edit `files.exclude` in workspace settings.
