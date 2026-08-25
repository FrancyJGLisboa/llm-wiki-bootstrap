# The context compiler

> Looking for the short version? [`WHAT-IS-THIS.md`](WHAT-IS-THIS.md) explains this
> in plain language, for anyone. This file is the full argument, written for a
> reader who wants to know where the compiler analogy holds and where it breaks.

> **A context compiler transforms unstructured source material into a
> structured, provenance-aware, machine-navigable context package that LLMs can
> navigate, retrieve from, and reason over.**

The last clause is deliberately three verbs rather than one adjective. An
earlier draft ended *"…that an LLM can reliably use,"* and that word was wrong:
a compiler controls the artifact, not the model that reads it. A flawless
package can still be misread. **Reliability is not a property this layer can
promise** — but navigability, retrievability, and reasoning support are
properties of the artifact, and each one is measurable. See
[Measuring the package](#measuring-the-package).

This document defines that as a **category**, and shows that
`context-compiler-bootstrap` is a reference implementation of it. The category is the
point: the name of this repo, or of any other one, is incidental.

---

## Why the term

Everyone building for agents has converged on the same insight from different
directions: an LLM with a well-organized directory of Markdown outperforms an
LLM with a vector store, because the *structure itself* routes attention. Files
and folders are an ontology the model already knows how to read.

That insight is about **operating** a body of context. It leaves the harder
question untouched:

> Who builds the folders, and who keeps them true?

Hand-authoring works up to a few dozen files. It stops working at 500 PDFs,
3,000 web pages, meeting transcripts, contradictory sources, and updated
versions of documents you already summarized. At that point the problem is no
longer "how do I give this context to the model" but **"how do I continuously
turn information into good context?"**

That is a build problem. It has an input language, a transformation, a target
representation with a schema, a cache, and a validation pass. Which is to say:
it is a compiler.

## Compiler-inspired, not formal — read this first

This is an analogy with a hard limit, and it's better stated up front than
discovered by a skeptical reader.

**There is no AST, and the transform is not reproducible.** The middle of the
pipeline — reading a source, deciding which concepts it introduces, writing the
summary, choosing which existing pages to update — is model judgment
(`.claude/commands/ctx-compile.md`, steps 2–5). Run it twice on the same input
and you get two defensible outputs, not identical bytes. `AGENTS.md` is careful
about this already: it scopes its determinism claim narrowly, to the synthesis
layer only.

So the guarantee on offer is **not** *reproducible output*. It is *verifiable
output*. What is deterministic, and mechanically checked:

| Guarantee | Mechanism |
|---|---|
| Incremental rebuild | `scripts/body-hash.sh` — SHA-256 over the post-frontmatter body; unchanged source is a no-op |
| Derived artifacts | `scripts/synthesize/all.sh` — identical inputs produce byte-identical output, so a no-change run leaves git clean (`AGENTS.md`, "Synthesis artifacts") |
| Interchange export | `scripts/wiki-to-okf.py` — asserted byte-identical on rerun, read-only on source |
| Package integrity | `MANIFEST` — SHA-256 per file, `LC_ALL=C` sorted, verified offline by `scripts/verify-bundle.sh` |
| Every rule above | ~36 `scripts/verify-*.sh` and `scripts/gate-*.sh` oracles, all reachable from `scripts/smoke-all.sh` (enforced by `scripts/gate-reachable.sh`) |

A conventional compiler earns trust by being deterministic. A context compiler
earns it by making every claim in the output traceable to a byte range in the
input, and by failing the build when that breaks. Different mechanism, same
job.

---

## The five properties

A system is a context compiler if it has all five. Each is stated as a
conformance question, with this repo's answer. A sixth — **enforcement** — is
listed after them, and is deliberately *not* part of the definition; see the
note there.

### 1. Transformation — is there an input language and a build step?

*Does heterogeneous, unstructured material get parsed and normalized into
something with a shape, or is the output hand-authored?*

`/ctx-extract` is the front end: a format-dispatch table (URL, YouTube, PDF,
DOCX, XLSX, CSV, image, plain text) where each format has a primary handler, a
fallback chain, and a recorded `extraction_method`. Extraction never fails
silently — a failure still writes a sidecar with `extraction_status: failed`
and an install hint. Long sources go through `scripts/extract/segment-doc.py`,
a deterministic segmenter that turns a 200-page PDF into an anchored section
tree.

`/ctx-compile` is the build: a 7-step pipeline (read → extract concepts,
entities, claims → write the summary page → update concept/entity pages → flag
contradictions → update the index → append the log), followed by a mechanical
regeneration of derived artifacts.

The two stages are cleanly separated by ownership, the way a front end and a
back end are: `/ctx-extract` never touches `wiki/`; `/ctx-compile` never
writes to `raw/` except three commitment fields in frontmatter, as its last
action.

**Verified by:** `scripts/verify-extract.sh`, `scripts/verify-segment-doc.sh`.

### 2. Target schema — does the output have a specification?

*Could a third party validate the output without asking you what it should look
like?*

`AGENTS.md` is the spec: a page template (frontmatter, `## Definition / TL;DR`,
body, `## Related`, `## Open questions`), a closed `type` enum
(`concept | entity | summary | analysis | navigation | journal`), a
single-regex typed-relation grammar
(`- [[<target>]] <verb> [<attr>] — <prose>`), and a canonical causal
vocabulary of five verbs with a direction table and explicit synonym rejection.

The schema is enforced, not merely described: `/ctx-lint` check 7 catches
schema drift, and every page carrying claims must have at least two resolving
`## Related` links.

**Verified by:** `scripts/wiki-lint-typed-relations.sh`,
`scripts/wiki-lint-causal.sh`.

### 3. Provenance — does the output point back at the input?

*Can you take any sentence in the output and land on the bytes it came from?*

This is the property that most distinguishes a context compiler from a folder
of notes, and it is the most heavily engineered part of this repo.

- Every non-trivial claim carries an inline `(source: raw/<file>#<anchor>)`.
  The literal form matters, because `scripts/citation-audit.py` matches that
  exact shape — `ctx-query.md` documents four near-miss forms that fail.
- Anchors are load-bearing: every leaf anchor must resolve to a real heading in
  the source sidecar.
- Web sources must be **snapshotted into `raw/` before being cited**. A bare
  URL citation is a deterministic violation, because a link rots and can never
  be entailment-checked.
- Sources carry both transaction time (`fetched_at`) and valid time
  (`asserted_at`), with an explicit rule against conflating them.
- Claims are entailment-checked at *write* time — SUPPORTED / UNSUPPORTED /
  CONTRADICTED — and the gate **fails closed**: no judge available means the
  build stops, not that it proceeds unchecked.
- `gate-raw-append-only.sh` distinguishes a legitimate re-extraction from an
  agent quietly editing the evidence to match a claim it already wrote.

The dev analogy is **source maps**: the compiled artifact knows which region of
which source file each fragment came from, and the build fails if that mapping
breaks.

**Verified by:** `scripts/citation-audit.py`,
`scripts/verify-citation-coverage.sh`, `scripts/verify-hash-drift.sh`,
`scripts/verify-asserted-at.sh`, `scripts/gate-raw-append-only.sh`,
`scripts/verify-no-bare-urls.sh`.

### 4. Navigability — can a machine traverse it without embeddings?

*Can a model find what it needs by following structure, rather than by
similarity search?*

Links are `[[kebab-case]]` and resolve by **string match with no rendering
dependency** — no Obsidian, no viewer, no index server. From that one
convention the repo materializes a real graph: `scripts/wiki-to-kg.py` emits
`{source, verb, target}` triples, `scripts/wiki-graph-walk.py` answers
`--causes-of` / `--effects-of` / `--path`, and `wiki/knowledge-graph.json` is
regenerated from the same parser the visualizer uses, so the JSON and the
picture can never diverge.

At read time, `/ctx-query` walks the section tree and reads only the cited
sections of a long source rather than the whole file, routes temporal questions
through a supersession check, and refuses to answer when its citations span
fewer than two distinct assertion dates.

An MCP read surface (`docs/MCP.md`, `scripts/mcp-server.sh`) exposes the same
package to any MCP client with BM25 over `wiki/` — no embeddings anywhere in
the system.

**Verified by:** `scripts/verify-graph-walk.sh`, `scripts/verify-synthesize.sh`,
`scripts/verify-query-citation-contract.sh`,
`scripts/verify-query-temporal-contract.sh`.

### 5. Packaging — is the output a portable, verifiable artifact?

*Can you hand the result to someone else and have them confirm it's intact,
without contacting you?*

This is the clause that turns a directory into a **context package**.

`scripts/package-wiki.sh` builds the bundle from an **include list, never an
exclude list**, so junk cannot leak in by omission. It refuses to package a
wiki that fails its own gates: every raw file hashes cleanly, every wiki page
has the required frontmatter, every citation resolves, and every claim-bearing
page is sourced — because *a wiki of uncited claims would otherwise package
clean*. It refuses symlinks, since a portable asset must not depend on host
paths. It emits a `MANIFEST` of SHA-256s and, optionally, a detached GPG
signature.

The verifier **ships inside the bundle**. The recipient runs
`./scripts/verify-bundle.sh` and needs nothing from the producer.

**Verified by:** `scripts/verify-bundle.sh` (B1–B5),
`scripts/verify-bundle-roundtrip.sh` — which builds a package, tampers with it
four ways, and asserts each tamper is caught.

---

## The sixth property — enforcement (outside the definition)

**Not part of the definition.** A system with the five properties above is a
context compiler whether or not it has this one. Enforcement is listed here
because it is the axis along which a context compiler stops being a very good
filing system, and because leaving it out of the five is the honest position:
plenty of useful compiled context is purely descriptive.

**The question.** When a source states a *rule* rather than a fact, does the
output only describe the rule — or does it also check it?

The distinction is not academic, and it is sharpest for LLM consumers. Prose in
a schema file is a **soft** constraint: the model can misread it, lose it under
a longer instruction, or sincerely report compliance it did not achieve. Every
one of those failure modes is silent. A script with an exit code is a **hard**
constraint: it is either 0 or it is not.

```
"Don't do X"          ->  interpretation  ->  self-report
gates/RULE-0007.sh    ->  exit 0 | 1 | 2  ->  artifact
```

Which means the useful test is not *did the agent follow the rule* but *what
shows that it did*. Trust the context less; verify the consequences more.

**How this repo answers it.** `/ctx-compile` step 2.5 separates normative
statements from knowledge and classifies each `deterministic` / `heuristic` /
`unverifiable`. Deterministic rules become gates via `/ctx-gate`, behind a
five-way mutation proof and three declared blind spots. `/ctx-lint` R-01 reports
any deterministic rule still enforced by prose alone.

**Three things that keep this from being theatre**, each of which is a way the
idea fails when implemented carelessly:

1. **A gate that never fires is indistinguishable from a broken gate.** So every
   gate ships with a fixture that must exit 1 and one that must exit 0, and
   `gate-fixtures.sh` checks both directions on every gate, every run. An
   unfixtured gate is a violation, not a skip.
2. **A script that asks an LLM whether the rule holds is not a deterministic
   gate.** It is a heuristic in a script costume: it can answer differently on
   the same input tomorrow, so it cannot ratchet and its green proves nothing.
   `/ctx-gate` refuses to build one.
3. **Classifying a rule is not enforcing it.** A rule sitting in
   `rules/deterministic/` with no gate is worse than an unclassified one — the
   page reads like a control while nothing checks it. That is what R-01 is for.

**Where it stops.** Only some rules are deterministic. "Forecasts must be
readable" is real and no exit code will ever settle it; it stays a rule page and
a reviewer's job. A compiler that pretended otherwise would be claiming
enforcement it does not have — the failure this property exists to prevent, in
the other direction.

## Two things that look like exceptions

### Dependency resolution — the compiler can fetch a missing source

`/ctx-query` answers from the package. On a gap, it web-searches, snapshots
the result into `raw/`, and promotes a new or updated page — writing into its
own source tree mid-run.

A traditional compiler doesn't do that. A **package manager** does: `npm
install` resolves a missing dependency during a build and then the build
proceeds. That is the right frame here. The fetched source is not special-cased
— it goes through the same no-bare-URL rule, the same frontmatter spec, and the
same entailment gate as anything acquired by `/ctx-extract`. A gap in the
package is treated as an unresolved dependency, and resolving it is a build
action, not a shortcut around one.

`--no-promote` turns it off when you want a read-only query.

### The viewer tier — flashcards, slides, diagrams, journals

`/ctx-visualize`, `/ctx-flashcards`, `/ctx-diagram`, `/ctx-discover`, and
the user-owned `wiki/journal/` directory are **not compiler stages**. They are
viewers and exporters that consume an already-built package. `AGENTS.md`
already quarantines them as "not lifecycle steps" and holds them read-only on
`raw/` and `wiki/`.

They exist because a context package is **human-readable as well as
machine-navigable** — that is a property of pure CommonMark, not a compromise
of the compiler model. A build system that also has an HTML backend is still a
build system.

---

## Measuring the package

The definition claims three verbs, so the three verbs have to be measurable.
They split into two tiers, and the split matters: **one tier is a property of
the artifact and recomputes on demand; the other is an event and must carry a
date.**

### Tier 1 — structural, recomputed, no LLM and no network

These are properties of the package itself. They are true or false right now,
they cost nothing to check, and they run in CI on every push. `scripts/package-quality.sh`
aggregates them into one report.

| Measure | Computed by |
|---|---|
| Citation resolution — every `(source: …)` lands on a real anchor | `scripts/citation-audit.py` |
| Citation coverage — no claim-bearing page is unsourced | `scripts/citation-audit.py --coverage` |
| Citation density — citations per claim-bearing page | `scripts/corpus-health.py` |
| Ingest commitment — every cited source carries a derived `ingested_hash` | `scripts/wiki-lint-commitment.sh` |
| Hash drift — no cited body changed since the ingest that cited it | `scripts/wiki-lint-hash-drift.sh` |
| Valid time — sources carry a traceable `asserted_at`, unknowns explicit | `scripts/asserted-at-audit.py` |
| Navigability — orphan rate, thin-page count, hub concentration, graph diameter | `scripts/corpus-health.py` |
| Transcription check — verbatim overlap between wiki and raw (synthesis, not copying) | `scripts/corpus-health.py` |

A high score here does not prove the package is *useful*. It proves it is
*sound* — that nothing in it is unverifiable, unattributed, or unreachable.
That is the floor, and the floor is enforceable.

### Tier 2 — behavioral, measured by an eval run, dated

These require driving a real model against a real corpus, so they cost
`claude -p` invocations and they are **events, not properties**. A number here
without a date is meaningless, which is the same rule
`scripts/verify-site-claims.sh` already applies to every score claim on the
public page.

| Measure | Measured by |
|---|---|
| Retrieval recall, per modality | `eval-retrieval.sh` R1 (needle planted past each extractor's truncation boundary) |
| Point-in-time correctness | `eval-retrieval.sh` R2 |
| Refusal on absence | `eval-retrieval.sh` R3 |
| Citation locus — the cite is tight *and* containing | `eval-retrieval.sh` R4 |
| Stale-evidence detection | `eval-retrieval.sh` R5 |
| Multi-hop and supersession | `eval-retrieval.sh` M1, M2, M5 |
| Citation integrity under load | `eval-retrieval.sh` M6 |
| Entity recall / precision | `eval-entities.sh` |
| Citation faithfulness (entailment) | `eval-citation-faithfulness.sh` |
| Behaviour at scale | `eval-scale.sh` |
| Cold-start onboarding | `eval-onboarding.sh` |

Every grader is itself verified with no LLM and no spend — an eval nobody
checks measures nothing. A held-out question set (`--holdout`) is the
anti-Goodhart control: never run by default, never in CI, never to be "fixed"
by editing.

### Passive measurement

`scripts/wiki-metrics.sh` records integrity numbers for *real* operations, not
just eval runs, appending a machine-readable line to `log.md` per ingest or
query. The numbers are computed by code and never narrated by the model — a
line the agent wrote from memory is an assertion, not a measurement.
`scripts/wiki-flows.sh` turns that record into a time series.

### On the word "reliable"

If the two tiers both hold, and hold across runs, "reliable" stops being a
marketing adjective and becomes a measured property of the artifact — with a
number, a date, and a reproducible command behind it. Until then the definition
claims only what the compiler controls.

## What a context compiler is not

**Not RAG.** RAG defers the work to query time: embed, similarity-search,
retrieve top-k chunks, hope they're relevant. A context compiler does the work
once, at ingest, and writes the synthesis to disk. Queries then become reading,
not guessing. The cost moves from every query to every source — which is the
right place for it, because sources arrive far less often than questions.
(See `wiki/problem-with-naive-rag.md`.)

**Not a second brain.** A second brain is hand-authored: you write the notes,
you maintain the links, you notice the contradictions. A context compiler has
an input language and a build step. You curate *sources*; the build produces
the notes, the links, and the contradiction flags — and a gate fails when they
stop being true.

**Not an agent framework.** It sits *below* agents and emits what they consume.
The seam is deliberate and already implemented: `docs/MCP.md` exposes the
package read-only to Claude Code, Claude Desktop, Cursor, or any MCP client.
One capable model reading a well-compiled package beats a fleet of specialized
agents reading a badly organized one — but that is an argument about runtimes,
and this is the layer underneath.

## Where it sits

```
     PDFs · articles · transcripts · spreadsheets · screenshots · APIs
                                  │
                                  ▼
                        ┌───────────────────┐
                        │  CONTEXT COMPILER │
                        │                   │
                        │  extract          │  front end
                        │  segment          │  lexing
                        │  ingest           │  the build
                        │  cross-link       │  linking
                        │  cite             │  source maps
                        │  lint             │  semantic analysis
                        │  package          │  emit
                        └─────────┬─────────┘
                                  │
                                  ▼
                          CONTEXT PACKAGE
                    (markdown + graph + MANIFEST)
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
        Claude Code            Cursor            MCP client /
        (local repo)                             hosted runtime
```

The runtime layer — multi-user deployment, permissions, shared sessions,
governance — is a different product, and a good one. It presumes a package
worth deploying. This is the layer that produces the package.

## Vocabulary

A reading aid for anyone who thinks in compilers.

**This section used to say the opposite.** Until schema v5 it read: *"No
identifier in this repo is named after the right-hand column — the commands are
`/wiki-*` and the directories are `raw/` and `wiki/`, and they stay that way."*
The reasoning was that naming things after an analogy invites the analogy to be
taken literally, and the file spends a whole section (*Compiler-inspired, not
formal*) warning against exactly that.

That reasoning still holds for the *analogy*. It stopped holding for the
*names*, because the names had drifted from the thing. `/wiki-ingest` described
the weakest part of what it does; the output carries provenance, typed
relations, valid time, a portable bundle and its own verifier, and — since v5 —
extracted rules with executable gates. "Wiki" named the least of that. The
commands are now `/ctx-*`; every `/wiki-*` name still works as a forwarder.

The caution the old paragraph was protecting is worth keeping in the reader's
head: the right-hand column is a *reading aid*, not a claim that this is a
compiler in the formal sense. Read the section above before leaning on it.

| In this repo | Compiler term |
|---|---|
| `raw/` | source tree |
| `/ctx-extract` | front end — acquire, parse, normalize |
| `scripts/extract/segment-doc.py` | lexing — anchored section tree over a long source |
| `/ctx-compile` | the build — source → target representation |
| `wiki/` | target representation (the emitted context) |
| `scripts/body-hash.sh` | build-cache key / incremental compilation |
| `/ctx-lint` | semantic analysis — errors and warnings |
| synthesis artifacts | derived artifacts / linker output |
| `scripts/verify-*.sh`, `gate-*.sh` | conformance suite |
| `/ctx-query` (promote) | dependency resolution — fetch missing source, rebuild |
| `scripts/package-wiki.sh` | packager — emits the distributable |
| the bundle + `MANIFEST` | **the context package** |
| `log.md` | build log |
| flashcards / slides / diagrams | viewer tier — consumers of a built package |

## Reference implementation

| Clause of the definition | Implemented by | Verified by |
|---|---|---|
| transforms unstructured source material | `/ctx-extract`, `scripts/extract/segment-doc.py`, `/ctx-compile` 7-step pipeline | `verify-extract.sh`, `verify-segment-doc.sh` |
| structured | page template, `type` enum, typed-relation grammar, causal vocabulary (`AGENTS.md`) | `wiki-lint-typed-relations.sh`, `wiki-lint-causal.sh` |
| provenance-aware | `(source: raw/<file>#<anchor>)`, raw frontmatter spec, `body-hash.sh`, `asserted_at`, write-time entailment gate | `citation-audit.py`, `verify-citation-coverage.sh`, `verify-hash-drift.sh`, `verify-asserted-at.sh`, `gate-raw-append-only.sh` |
| machine-navigable | `[[kebab-case]]` links, `wiki-to-kg.py`, `wiki-graph-walk.py`, `knowledge-graph.json`, MCP surface | `verify-graph-walk.sh`, `verify-synthesize.sh`, `gate-reachable.sh` |
| context package | `scripts/package-wiki.sh` (G1–G4, `MANIFEST`, optional GPG) | `verify-bundle.sh`, `verify-bundle-roundtrip.sh` |
| LLMs can navigate, retrieve from, and reason over | citation + temporal contracts, read-floor gate, faithfulness gate — and the eval suite that measures each verb | `verify-query-citation-contract.sh`, `verify-query-temporal-contract.sh`, `verify-faithfulness-gate.sh`, `eval-retrieval.sh` |
| **rules the system enforces, not only describes** (the sixth property — outside the definition) | `type: rule` pages under `wiki/rules/{deterministic,heuristic,discarded}/`, `/ctx-compile` steps 2.5 + 4.5, `/ctx-rules`, `/ctx-gate`, gates under `gates/` with committed fixture pairs, `gates/baseline.tsv` | `ctx-lint-rules.sh` (R-01/R-02/R-05/R-06), `gate-fixtures.sh` (every gate fails its violating fixture and passes its clean one), `gate-ratchet.sh` (§6 ratchet; suppressions counted) |

## See also

- [`EXPLAIN.md`](EXPLAIN.md) — the same idea for a developer who just cloned the
  repo, mapped onto `make`, `npm`, and `eslint`.
- [`../AGENTS.md`](../AGENTS.md) — the schema: layers, page template, citation
  grammar, output format.
- [`MCP.md`](MCP.md) — exposing a built package to a runtime.
- [`SELLING.md`](SELLING.md) — one thing you can do with a portable, verifiable
  package: sell it.
- [`../wiki/problem-with-naive-rag.md`](../wiki/problem-with-naive-rag.md) — why
  the work moves to ingest time.
