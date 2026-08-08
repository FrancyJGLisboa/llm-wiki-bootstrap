# context-compiler-bootstrap

[![CI](https://github.com/FrancyJGLisboa/context-compiler-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/FrancyJGLisboa/context-compiler-bootstrap/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**A context compiler for LLMs.** It turns unstructured sources — PDFs, articles, transcripts, spreadsheets, screenshots — into a **structured, provenance-aware, machine-navigable context package** your AI tool can navigate, retrieve from, and reason over. You curate raw sources and ask questions; the LLM does all the writing, cross-linking, and upkeep. Five slash commands, run entirely from your AI coding tool. No UI, no SaaS, no Obsidian, no vector DB. The pattern is Andrej Karpathy's; the compiler framing is spelled out in [`docs/CONTEXT-COMPILER.md`](docs/CONTEXT-COMPILER.md).

![/ctx-query returning a cited answer from the demo wiki that ships in this repo](assets/demo.gif)

> A replay of a real `/ctx-query` against the shipped demo wiki — the answer text is verbatim; terminal timing is illustrative. Reproduce it yourself with the block below (zero setup).

## Quick start — first answer in one block

**You need one thing:** an agentic AI tool on your `$PATH`. The reference path is [Claude Code](https://docs.anthropic.com/claude/code) (`claude`); [other tools work too](#tool-support). Then:

```bash
git clone https://github.com/FrancyJGLisboa/context-compiler-bootstrap my-wiki
cd my-wiki && claude          # open Claude Code in the repo
```

The repo ships with a working demo wiki, so the **very first command already returns an answer — zero setup:**

```
/ctx-query "what is an llm-wiki, and why not just use RAG?"   # answered from the shipped wiki
```

That's the whole pitch: you just queried a knowledge base nobody hand-wrote. Now make it yours — start building your own:

```
/ctx-extract https://example.com/some-article   # pull a source into raw/
/ctx-compile                                       # integrate it into the wiki
/ctx-query "what does that article say about X?"  # ask — answers now include your source
```

That's the whole loop. The wiki that ships here is *meta* — a wiki about the LLM-wiki pattern itself ([`wiki/index.md`](wiki/index.md)), there as a working example. **Make it yours:** keep adding sources alongside it, or [start from a clean slate](#starting-your-own-wiki-clean-slate).

> **The block above is the one and only start-here.** Not on Claude Code? [`docs/QUICKSTART.md`](docs/QUICKSTART.md) has the same loop as a command sequence for Cursor, Cline, Copilot, Gemini, and Codex — plus a [VS Code + Copilot fast path](docs/QUICKSTART.md#fastest-path-vs-code--github-copilot--mac-or-windows). **On Windows?** Do the [one-time 5-minute setup](docs/QUICKSTART.md#windows-setup-one-time--5-minutes) (Git Bash + Python) so the toolchain runs.

## Install details

### Starting your own wiki (clean slate)

The clone above keeps the demo content (a meta-wiki about the LLM-wiki pattern — a handy worked example). To generate a clean skeleton with **no demo content** instead:

```bash
git clone https://github.com/FrancyJGLisboa/context-compiler-bootstrap tmp
tmp/scripts/create-context-compiler.sh ~/my-wiki   # fresh skeleton, no demo content
                                           # refuses to clobber a non-empty target
rm -rf tmp
cd ~/my-wiki
./scripts/preflight.sh                     # confirm hard requirements + optional tools
git add -A && git commit -m "chore: bootstrap llm-wiki"   # installer already ran `git init`
claude                                     # open Claude Code in the new wiki
```

Then, inside Claude Code:

```
/ctx-extract https://example.com/some-article     # pull a source into raw/
/ctx-compile                                       # integrate every un-ingested raw/ file
/ctx-query "what does that article say about X?"  # ask
```

The skeleton ships the slash commands and an empty `raw/` + a stub `wiki/index.md`, so this works immediately — no `/ctx-init` needed. The installer is manifest-driven (`scripts/installer-skeleton-manifest.txt`) and verified by `scripts/verify-create-context-compiler.sh`.

**The compiler's output format is a portable context package.** `scripts/package-wiki.sh` builds a versioned, hash-manifested bundle that refuses to ship a wiki failing its own citation gates, and carries its own verifier inside — so a recipient confirms integrity offline, needing nothing from you. That makes a curated wiki a transferable asset; [`docs/SELLING.md`](docs/SELLING.md) covers one thing you can do with that (schema, packaging, the raw-rights rule).

### Optional: confirm your full setup

Just trying it out? Skip this. When you want to confirm the whole pipeline works on your machine, run:

```bash
./scripts/preflight.sh    # hard reqs (bash/awk/openssl/git) + which extract formats work first-try
./scripts/smoke-all.sh    # full pipeline (extract → ingest → query) on a fictitious fixture; 13 binary checks
```

`preflight.sh` tells you in advance which `/ctx-extract` formats your environment supports first-try (PDF needs `pdftotext`; DOCX needs `pandoc`; XLSX needs `xlsx2csv` — each has a fallback, but knowing in advance avoids surprises).

`smoke-all.sh` drives `claude -p` on a small fixture, asks the wiki a question, and confirms the answer recalls the fact and cites the source. First run takes ~30–60s (LLM); subsequent runs sub-second (idempotent via body-hash). All 13 green = your install works end-to-end. Spec at [`.scratch/plug-and-play-curator-smoke/GOAL.md`](.scratch/plug-and-play-curator-smoke/GOAL.md).

**For the per-tool first-use sequence (which commands to type, in order, in each AI tool), see [`docs/QUICKSTART.md`](docs/QUICKSTART.md).** For the *mental model* — three layers, five commands, and the build-system analogy mapped to things you already know — see [`docs/EXPLAIN.md`](docs/EXPLAIN.md). For *what category this is and how to tell a real one from a folder of notes*, see [`docs/CONTEXT-COMPILER.md`](docs/CONTEXT-COMPILER.md).

### Tool support

The project ships shim files for every major agentic tool. Whatever you use, the AI will load the schema automatically:

| Tool | Shim file (already in repo) | Invocation | Status |
|---|---|---|---|
| Claude Code (modern) | `AGENTS.md` (canonical) | `/ctx-init`, `/ctx-extract`, etc. — real slash commands | **e2e-verified** (driven by `scripts/smoke-all.sh`) |
| Claude Code (legacy) | `CLAUDE.md` | same as modern | e2e-verified |
| Cursor | `.cursor/rules/context-compiler.mdc` | natural language: "run ctx-compile" | Documented, not yet e2e-verified |
| Cline (VSCode) | `.clinerules` | natural language | Documented, not yet e2e-verified |
| GitHub Copilot | `.github/copilot-instructions.md` | natural language | Documented, not yet e2e-verified |
| Gemini CLI | `GEMINI.md` | natural language | Documented, not yet e2e-verified |
| OpenAI Codex | `AGENTS.md` (canonical — auto-loads) | natural language | Documented, not yet e2e-verified |

The shim files all point at `AGENTS.md` as the canonical schema and at `.claude/commands/ctx-*.md` as the workflow definitions. Tools without first-class slash commands (Cursor, Cline, Copilot, Gemini, Codex) invoke the workflows by natural language; the LLM follows the prompt body of the corresponding command file step-by-step.

**"Documented, not yet e2e-verified"** means: the shim file ships, the natural-language workflow is specified, and the pattern is expected to work — but the smoke harness only drives Claude Code, so these paths have not been observed end-to-end by the project. If you use one of these tools and something does not work, that is a reportable bug — please open an issue.

**Verify your tool in one command.** `scripts/smoke-tool.sh <tool>` (`claude`/`codex`/`gemini`/`copilot`) drives that CLI through a real ingest→query loop in a throwaway wiki and asserts the agent built a citing wiki page and recalled a planted fact — with the raw source deleted before the query, so the answer must come from the wiki, not a re-read. It **skips cleanly** (exit 3) if the CLI isn't installed. `claude` passes today; if your tool passes, that row has earned "e2e-verified" — please open a PR flipping it (and attach the run).

## The five slash commands

Every command has both a prefixed form (`/ctx-extract`) and a short alias (`/extract`). The short forms are the ones you'll actually type once you're inside a fresh installed repo; the prefixed form is there for global use where namespace collisions matter. Both resolve to the exact same procedure.

| Prefixed | Short | What it does |
|---|---|---|
| `/ctx-init` | `/init` | Scaffold the wiki structure (raw/, wiki/, AGENTS.md, README.md, log.md). Idempotent. Use only if you copied just `.claude/commands/` into an existing project — cloning this repo already gives you the structure. |
| `/ctx-extract <urls-or-files>` | `/extract` | Pull **one or many** URLs / local files (PDF, DOCX, XLSX, CSV, image, or plain text) into `raw/` with frontmatter. Bulk mode: pass multiple sources space- or newline-separated and they're all extracted in one pass with a consolidated OK/Degraded/Failed summary at the end. Parses binary content to markdown when a handler exists. Also accepts **pasted inline text** via `--text [--title "..."] <content>` (single source, never whitespace-split). Does **not** touch `wiki/`. |
| `/ctx-compile [<raw-file>]` | `/ingest` | Process `raw/` → `wiki/` using the 7-step pipeline. Detects deltas via hash; idempotent on unchanged sources. |
| `/ctx-query <question>` | `/query` | Answer from the wiki; web-search and auto-promote new knowledge if there's a gap. `--no-promote` suppresses promotion. **`--visual [html\|pdf\|png]`** also emits a diagram of the answer, archetype auto-picked from the query (same design system as `/ctx-diagram`). |
| `/ctx-lint [--apply]` | `/lint` | Health-check: broken links, orphans, contradictions, stale claims, gaps. Reports by default; `--apply` writes proposed fixes. |

Full spec at [`wiki/commands.md`](wiki/commands.md).

### Output commands

Two more commands render or export an **already-built** wiki — they sit outside the acquire→maintain loop above and are read-only on `raw/` and `wiki/` (they only write new output files).

| Prefixed | Short | What it does |
|---|---|---|
| `/ctx-visualize [graph\|mermaid\|slides\|serve] [target]` | `/visualize` | Render the wiki as an interactive D3 graph (default), MARP slides, or mermaid images, or serve it locally. Thin wrapper over `scripts/visualize/*`; checks `python3`/`npx` and prints install hints. |
| `/ctx-flashcards [dir]` | `/flashcards` | Export every `## Flashcards` section to an Anki-importable CSV. Wraps `scripts/wiki-to-anki.sh`. |
| `/ctx-diagram "<intent>"` | `/diagram` | Synthesize an audience-targeted diagram from an intent — retrieve relevant pages, score the 8 archetypes, you pick, it generates a self-contained HTML poster. Output to `diagrams/`. |

`/ctx-visualize` is **mechanical** (renders the structure that already exists); `/ctx-diagram` is **semantic** (composes a new poster by reasoning over a query). See the diagram contracts in `templates/infographic/`.

**Optional: typed relations.** Inside `## Related`, you can attach a verb to a link — `- [[embrapa]] founded-by 1973 — Brazilian R&D agency`. Pure CommonMark; backward-compat with untyped lines. Verb regex: `[a-z][a-z0-9-]*`. Validate with `./scripts/wiki-lint-typed-relations.sh wiki/`; the graph viz colours and filters edges by verb. Full spec in [`AGENTS.md`](AGENTS.md) → "Typed relations". An empirical eval (`scripts/eval-multi-hop.sh`) measures whether typed verbs improve `/ctx-query` recall over the same wiki with verbs stripped — see [`.scratch/typed-wikilinks-semantic-viz/GOAL.md`](.scratch/typed-wikilinks-semantic-viz/GOAL.md) for the methodology and current null-result on a Wikipedia-derived fixture.

## Visualize your wiki

From inside your AI tool, just run `/ctx-visualize` (alias `/visualize`) — it dispatches to the right backend and checks the required tool is installed. Or call the scripts directly:

```bash
./scripts/visualize/graph.sh wiki/ > graph.html   # interactive D3 force graph (no install)
./scripts/visualize/serve.sh                     # browse the wiki + graph locally
```

Five opt-in wrappers under `scripts/visualize/`: a Python+D3 graph generator (zero dependencies), plus `slides.sh`, `mermaid.sh`, `serve.sh` (MARP / mermaid-CLI / local HTTP), and `render.sh` (HTML poster → PDF/PNG, used by `/ctx-query --visual` and `/ctx-diagram --pdf/--png`; graceful fallback to HTML when no browser/Node). All open source; no Obsidian required. Heavier alternatives (Quartz, mdBook, SilverBullet) covered in [`docs/VISUALIZATION.md`](docs/VISUALIZATION.md).

## Executable context — rules the compiler enforces

Most of what a source says is knowledge. Some of it is a **rule**, and rules are
worth treating differently, because prose is a *soft* constraint on an LLM: it
can be misread, lost under a longer instruction, or sincerely reported as
followed when it wasn't. Every one of those failures is silent.

```
"Don't do X"          →  interpretation  →  self-report
gates/RULE-0007.sh    →  exit 0 | 1 | 2  →  an artifact you can look at
```

So `/ctx-compile` separates the two. Every rule it finds is classified once:

| Class | Means | What happens to it |
|---|---|---|
| `deterministic` | A script with an exit code can settle it | Becomes a gate under `gates/` |
| `heuristic` | Needs judgement — "forecasts must be readable" | Stays a rule page; a reviewer's job |
| `unverifiable` | Nothing could check it, even in principle | Recorded in `rules/discarded/` **with the reason** |

**The standing rule: no deterministic rule stays prose-only.** `/ctx-lint`
reports `R-01` for any rule classified deterministic that still has
`gate: none`.

Building the gate is a separate, deliberate step:

```
/ctx-rules --scan-context    # what rules exist, and which are gateable?
/ctx-gate RULE-0007          # build the gate for one of them
/ctx-lint                    # R-01 clear?
```

`/ctx-gate` will not take your word for it. Before a gate counts as built it
must fail on a committed fixture that violates the rule, pass on a clean one,
survive five mutations, and **declare three ways to violate the rule it does
not catch** — because an author who can't name their gate's blind spots has only
observed that it passes. It refuses outright to build a gate whose detection
would need an LLM call: that answers differently on the same input tomorrow, so
it can't be ratcheted and its green means nothing.

Two things stop this from becoming decoration:

- **`gate-fixtures.sh`** runs every gate against both its fixtures on every CI
  run, requiring exactly 1 then exactly 0. A gate that never fires is
  indistinguishable from a broken one, and an unfixtured gate is a violation, not
  a skip.
- **`gates/baseline.tsv`** is a ratchet: counts may not go up, and you are never
  asked to fix the past. Scope exclusions and suppressions count in the same
  number, so routing around a gate is possible but never quiet.

Gates and their fixtures travel inside `scripts/package-wiki.sh` bundles, so a
recipient gets the checks, not just pages describing them. Full doctrine in
[`docs/deterministic-gates.md`](docs/deterministic-gates.md) — which ships into
every wiki you create.

## MCP access (optional)

Expose this wiki over the Model Context Protocol so any MCP-aware AI client — Claude Desktop, Claude Code, Cursor, ChatGPT Desktop, etc. — can read it (and optionally write to it) without slash-command indirection. Uses [`@bitbonsai/mcpvault`](https://github.com/bitbonsai/mcpvault), which works on any markdown directory with no Obsidian dependency. BM25 search built in.

```bash
./scripts/mcp-server.sh        # foreground stdio server pointed at wiki/
```

For client config snippets (Claude Desktop, Claude Code, Cursor) and the recommended read-only posture, see [`docs/MCP.md`](docs/MCP.md).

## Flashcards (optional)

Any wiki page may declare a `## Flashcards` section with `Q: …` / `A: …` bullet pairs. Export to an Anki-importable CSV with `/ctx-flashcards` (alias `/flashcards`) from inside your AI tool, or run the script directly:

```bash
./scripts/wiki-to-anki.sh > anki.csv
```

The page slug becomes the Anki tag for that card. See the convention notes in [`AGENTS.md`](AGENTS.md).

## A typical session

```
# add a source
/ctx-extract https://example.com/some-article

# integrate it
/ctx-compile

# commit before the next ingest — git is your rollback (no atomic writes inside the pipeline)
git add wiki/ log.md raw/
git commit -m "ingest: <source title>"

# ask the wiki something
/ctx-query "what does this article say about X?"

# periodically tidy up
/ctx-lint
```

Commit-per-ingest is the recommended discipline: `/ctx-compile` touches many files (a summary page, several concept pages, the index, `log.md`, raw-file frontmatter) and is not atomic. If a future ingest goes sideways, `git checkout -- wiki/ log.md raw/<file>` is your only clean recovery path. Skip the commit and the rollback also rolls back the good ingest before it.

## Make it yours

The shipped wiki content is illustrative — it's a wiki *about* the LLM-wiki pattern, derived from the YouTube transcript in `raw/karpathy-llm-wiki-video-transcript.md`. To start your own:

1. **Keep it as reference and add alongside:** drop your own sources into `raw/`, run `/ctx-compile`. Your pages live next to the meta-wiki content.
2. **Replace it:** `./scripts/wipe-meta-wiki.sh` (prompts for confirmation; `--yes` to skip). Wipes `wiki/*.md` and `raw/*`, resets `wiki/index.md` and `log.md` to minimal stubs.

The `AGENTS.md` schema is project-agnostic — it works the same whether the wiki is about LLM-wikis, trading, M&A, your team's roadmap, or anything else.

## Project layout

<details>
<summary>Full repository tree (click to expand)</summary>

```
.
├── AGENTS.md                       # canonical schema (read by AI tools) — schema v2
├── CLAUDE.md                       # shim → points to AGENTS.md
├── GEMINI.md                       # shim → points to AGENTS.md
├── README.md                       # this file (dev-side) — the one and only entry point
├── log.md                          # append-only log of ingests, schema bumps, infra changes
├── .claude/
│   └── commands/                   # Claude Code slash commands (canonical + aliases)
│       ├── ctx-init.md
│       ├── ctx-extract.md
│       ├── ctx-compile.md
│       ├── ctx-rules.md            # inventory + triage rules (writes no code)
│       ├── ctx-gate.md             # build a gate behind the mutation proof
│       ├── ctx-query.md
│       └── ctx-lint.md
├── .cursor/
│   └── rules/
│       └── context-compiler.mdc    # Cursor shim
├── .clinerules                     # Cline shim
├── .github/
│   └── copilot-instructions.md     # GitHub Copilot shim
├── docs/
│   ├── QUICKSTART.md               # per-tool first-use guide (start here after cloning)
│   ├── EXPLAIN.md                  # mental model for devs: build-system analogy, dev-mapped verbs
│   ├── CONTEXT-COMPILER.md         # the category: definition, five properties, what it is not
│   ├── MCP.md                      # optional MCP read surface (Claude Desktop / Cursor / etc.)
│   ├── VISUALIZATION.md            # graph view, slides, mermaid render, local server — no Obsidian
│   └── pitch-vscode.html           # self-contained pitch page (PT, internal reference)
├── scripts/
│   ├── body-hash.sh                # canonical SHA-256 over a raw file's body
│   ├── preflight.sh                # environment & dependency check (run before first /ctx-extract)
│   ├── wipe-meta-wiki.sh           # remove shipped meta-wiki content for a clean start
│   ├── verify-extract.sh           # shape-check /ctx-extract output
│   ├── wiki-to-anki.sh             # export ## Flashcards sections to Anki CSV
│   ├── verify-wiki-to-anki.sh      # shape-check the Anki exporter
│   ├── mcp-server.sh               # launch @bitbonsai/mcpvault pointed at wiki/
│   ├── smoke-build.sh              # LLM-driven build phase (drives claude -p)
│   ├── smoke-check.sh              # pure-shell asserts C1–C5 on the smoke artifacts
│   ├── smoke-all.sh                # umbrella: build + check + <!-- claim:smoke-guard-range -->R1–R40<!-- /claim --> regression guards
│   ├── r3-obsidian-patterns.txt    # patterns file for the no-Obsidian-syntax check
│   ├── create-context-compiler.sh          # manifest-driven installer for a fresh skeleton
│   ├── verify-create-context-compiler.sh   # oracle for the installer (I2–I7)
│   ├── installer-skeleton-manifest.txt # single source of truth for what ships fresh
│   └── visualize/                  # opt-in OSS visualization wrappers
│       ├── graph.sh                # bash wrapper around graph-html.py
│       ├── graph-html.py           # stdlib-only D3 force-graph generator
│       ├── slides.sh               # MARP-CLI wrapper (npx)
│       ├── mermaid.sh              # mermaid-CLI wrapper (npx)
│       ├── serve.sh                # python3 -m http.server wrapper
│       ├── render.sh               # HTML poster → PDF/PNG (chrome/puppeteer; graceful fallback)
│       └── verify-visualizers.sh   # smoke harness (V1–V5 + render checks)
├── templates/
│   ├── journal-entry.md            # template for wiki/journal/YYYY-MM-DD-*.md entries
│   └── README-fresh.md             # installer ships this as a fresh wiki's README.md (no demo content)
├── tests/
│   ├── canary/                     # tiny known-good fixtures (shape-level smokes)
│   │   ├── canary-smoke-test.md
│   │   ├── canary-csv.csv
│   │   ├── canary-flashcards.md
│   │   ├── graph-fixture/          # 4 nodes / 4 edges flat fixture (V2 graph smoke)
│   │   └── graph-fixture-nested/   # 2 nodes / 1 edge nested fixture (V2b recursion smoke)
│   ├── smoke/                      # end-to-end smoke (Phase Coherence fixture + outputs)
│   │   ├── smoke-source.md
│   │   ├── expected-query.md
│   │   └── output/baseline-wiki.txt
│   └── installer-output/           # temp dirs the installer verifier writes to (gitignored)
├── raw/                            # immutable source material (you curate)
│   ├── karpathy-llm-wiki-video-transcript.md
│   ├── karpathy-video-slide-ingest-pipeline.png
│   ├── karpathy-video-slide-ingest-pipeline.png.md
│   └── smoke-source.md             # ingest-demonstrated smoke source
└── wiki/                           # the wiki itself (LLM-owned)
    ├── index.md                    # start here (dev meta-wiki)
    ├── index-FRESH.md              # stub used by the installer for fresh skeletons
    ├── core-idea.md
    ├── ... (25 more pages, including the 4 smoke-derived pages: quortex-protocol, dr-alma-voss, phase-coherence-engineering, smoke-source-summary)
    ├── glossary.md
    └── journal/                    # user-owned, time-stamped observations (schema-v2 exception)
```

</details>

## Vision — context that ships with receipts

Everyone building for agents has landed on the same insight: a model with a
well-organized directory of markdown beats a model with a vector store, because
the structure itself routes attention. That insight is about *operating* a body
of context. It leaves the harder question open — **who builds the folders, and
who keeps them true?** Hand-authoring works for fifty files and stops working at
five hundred sources. That's a build problem, and this is the build system for
it.

So the output isn't a pile of notes you hope are accurate: **every claim is
mechanically traceable to a source, faithfulness is enforced at write-time, and
the whole package is portable and verifiable — not a service you rent.** That's
the moat. The markdown is trivially copied (like an ebook); the verified
provenance is not.

Note what the definition does *not* claim. An earlier draft ended "…that an LLM
can **reliably** use," and that word was wrong: a compiler controls the
artifact, not the model reading it, and a flawless package can still be
misread. Navigability, retrievability, and reasoning support *are* properties of
the artifact — so they get measured instead of asserted. Run
`./scripts/package-quality.sh` for the structural half (free, no LLM, no
network); the `eval-*` family measures the behavioural half at the cost of real
model runs. "Reliable" is a word to earn from a scorecard, not to put in a
definition.

The vision is falsifiable — these are the binary checks that say we're living it:

1. Every wiki claim cites a raw anchor that resolves. (`scripts/citation-audit.py` — zero BAD)
2. Every claim is entailed by its cited source. (the C3 entailment gate at ingest — applies to raw-source-backed claims, judged against local raw evidence; web-url-cited claims are not entailment-checked)
3. A third party can verify a bundle with only what's inside it. (`scripts/verify-bundle.sh` — no seller infra)
4. It runs with no app, viewer, or account. (pure CommonMark, slash commands)
5. Every claim-bearing page carries provenance — none leak unsourced. (`citation-audit.py --coverage`)

A change that can't answer "yes" to the relevant checks is drifting off-vision.
Supporting features (causal graph, discovery, flashcards, diagrams) earn their
weight only by inheriting these guarantees.

## Principles this project honors

1. **Explicit.** Everything in markdown. No hidden embeddings, no opaque memory.
2. **Yours.** Local files. Portable. You decide what stays and what goes.
3. **File-over-app.** Pure CommonMark. Works with `cat`, `grep`, `git`, any viewer. **No Obsidian dependency** (or any other viewer).
4. **BYO AI.** Any LLM that supports file read/write and (optionally) web search.

See `wiki/four-principles.md` for the full account.

## Status

V2. Multi-tool shims for Claude Code, Cursor, Cline, Copilot CLI, Gemini CLI, and Codex are all in place. Real slash commands exist only for Claude Code; other tools invoke the workflows by natural language using the same prompt bodies.

**The Claude Code happy path is verified end-to-end.** Three harnesses guard it. `scripts/smoke-all.sh` — 43 deterministic checks (extract → ingest → query, body-hash idempotence, installer, the eval, monitoring, and package-quality oracles, plus the prompt-purity, raw-append-only, and ratchet gates) — runs locally and is wired into [CI](.github/workflows/ci.yml) on every push (`--no-build`, no API key needed); a full local run adds the LLM build phase's own checks on top. The suite counts its passes rather than printing a literal, so losing a check moves the number. `scripts/eval-onboarding.sh` drives `claude -p` as a brand-new user through a fresh wiki and confirms they reach the correct answer from a source they just ingested. `scripts/eval-retrieval.sh` builds a fresh wiki from a generated corpus and scores retrieval against 10 binary checks — needle recall per modality, point-in-time answers, refusal on absence, citation locus, stale-evidence detection, multi-valued scoped answers, graph-traversable supersession, clarify-on-ambiguity, feedback-loop composition, and citation integrity — each graded deterministically (no LLM grader; see `tests/eval/retrieval-questions.md`), with a held-out question set (`--holdout`) as the anti-Goodhart control. Latest run: 32/35, the losses being one fabricated citation anchor and one citation pointing into frontmatter rather than body text. `scripts/eval-scale.sh` reruns that whole eval at increasing corpus sizes with deterministic distractor filler: quality held from 19 to 495 pages (20/21 → 21/21) while median file reads per answer fell from 3 to 0, and the holdout passed 4/4 at 495 pages. Every grader is itself verified with no LLM and no spend by `scripts/verify-retrieval-eval.sh` (E1–E16), `verify-scale-eval.sh` (F1–F7), and `verify-loops.sh` (L1–L6) — an eval nobody checks measures nothing. The other tools' shims (Cursor, Cline, Copilot, Gemini, Codex) ship and follow the same prompt bodies by natural language, but are not yet driven by the harness — if one misbehaves, that's a reportable bug.

## License

MIT — see [LICENSE](LICENSE).
