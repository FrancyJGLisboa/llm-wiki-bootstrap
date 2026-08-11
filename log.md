# log.md

Append-only log of every `/ctx-compile`, `/ctx-query` promotion, and `/ctx-lint --apply` operation. Newest at top. (Entries below 2026-08-08 use the old `/wiki-*` command names — they are history and are left as written.)

## 2026-08-11 — segmented-source anchors never resolved, and nothing checked

**Rationale.** `AGENTS.md` tells `/ctx-compile` to cite a segmented section with
its positional range dropped — `## Power Envelope (lines 13-19)` → `#power-envelope`.
`citation-audit.py` only ever slugified the whole heading, giving
`power-envelope-lines-13-19`. The schema and the resolver could never agree, and
the compiler was following the schema exactly.

Measured downstream on a 2,414-source corpus: **15,440 unresolvable citations,
82% of all failures**, none of them the compiler's fault. Eleven gates in that
repository ran green throughout, because no gate ran C1/C2 resolution over the
compiled root. A broken anchor fails silently — the page renders, names a real
file, and reads as sourced.

**The resolver was wrong, not the convention.** A line range belongs to one
segmentation run: an anchor carrying it breaks the moment the source is
re-segmented with a different word budget, which is precisely the fragility the
schema's form avoids. Both forms now resolve, so packages already citing the
full slug keep working. Ambiguity stays fatal — if dropping ranges makes two
headings collide, that is a coin flip, not a match.

**Regression test, and it fails without the fix.** `verify-citation-audit.sh`
gained a case running the real engine against the schema's own example, asserting
the range-dropped form resolves, the full form still resolves, and a nonexistent
heading still does not — the third clause being what stops the "fix" from being
a resolver that says yes. Reverting the one-line change turns it red.

**CITATION-FLOOR (R44), the gate whose absence caused this to run unnoticed.**
It runs the audit over the compiled root and fails when an anchor does not
resolve. Detection delegated wholesale to `citation-audit.py` — a second
implementation of "does this anchor resolve" would eventually disagree with the
first, and then a corpus is sound by one and broken by the other.

**Found by the gate it exposed.** `CTX-ROOT-ADOPTION` went 80 → 81 on the new
gate's own error message, which named the legacy root as a literal. Reworded
rather than baselined up — declared failure mode 2 of that gate, met for the
second time.

Suite 46 → 47. `verify-site-claims` and `gate-doc-claims` both billed for the
change, as designed.

## 2026-08-10 — the adapter blueprint moves upstream, where compilers are generated

**Rationale.** `new-corpus.sh` and `gate-adapter-contract.sh` were built in one
deployment while compiling a 2,413-document corpus. They are the machinery that
makes pointing a compiler at a NEW source a bounded job — and they were trapped
in the single deployment they were meant to generalise beyond. A freshly
generated compiler got none of it. They now ship in the installer manifest.

**What a new corpus costs, after this.** A `corpus-<name>.json` declaration and
two functions — `_catalog()` and `_fetch_one()`. Everything else is generic or
scaffolded, and `ADAPTER-CONTRACT` settles with an exit code whether the result
is something this compiler can actually compile.

**A name collision, resolved honestly.** `scripts/stage-corpus.py` already
existed here and was YouTube-transcript-specific despite the general name — down
to the padded/unpadded timestamp headings it emits. It is now
`stage-transcripts.py`, which is what it always was, and the corpus-agnostic
stager takes the general name. Its oracle (`verify-corpus-eval.sh`, R27) moved
with it and stays green.

**TWO BUGS THE PORT ITSELF EXPOSED**, both invisible in the source repo:

1. `new-corpus.sh` scaffolded a **0-byte daemon** and reported success. It sed'd
   from `gain-watchd.sh`, which exists only in the deployment it came from. A
   scaffolder whose output is empty is worse than one that fails, because the
   file looks written. The daemon is now a template
   (`templates/corpus/watchd.sh.tmpl`), a missing template is an error, and an
   empty result is refused. R43 checks the scaffold produces a non-empty, fully
   substituted, parseable adapter.

2. `gate-adapter-contract.sh` exited 2 in a freshly generated compiler, failing
   the installer's own I6 check, because there was no `corpus.json` yet. That
   conflated DECLARED-AND-BROKEN with NOT-DECLARED. A compiler may legitimately
   have no harvest adapter and feed `raw/` by hand through `/ctx-extract` — the
   same reasoning `ctx-lint-rules.sh` already applies to an absent `rules/`
   directory. An absent declaration is now clean and says so.

**New checks.** R42 (an adapter's output is compilable) and R43 (the scaffold
produces real files). The suite goes 44 -> 46; the bound `smoke-guard-range`
claim, the published page's count and README's all moved with it, because three
separate gates refused to let them drift.

**Files.** `scripts/{stage-corpus.py,new-corpus.sh,gate-adapter-contract.sh}`
(new), `scripts/stage-transcripts.py` (renamed), `templates/corpus/*.tmpl` (new),
`tests/gates/adapter-contract/**` (new), `scripts/installer-skeleton-manifest.txt`,
`scripts/smoke-all.sh`, `gates/baseline.tsv`, `scripts/gate-fixtures.tsv`,
`README.md`, `site/index.html`, `.github/workflows/ci.yml`.

## 2026-08-10 — schema v6: the schema can now describe a document corpus honestly

**Rationale.** v5 could compile a corpus of reports; it could not label one
truthfully. Both gaps were found by building a compiler over 2,413 USDA FAS GAIN
attaché reports, and both bite on day one of any document corpus.

**(a) `source: document`.** The page enum was `video | analysis | external |
mixed` — no value for a document. Compiling GAIN, the agent reasoned correctly
that a USDA report is neither a video nor its own analysis and wrote `external`
on every page: the value reserved for material fetched off the open web, and in a
closed-corpus deployment the value that means *contaminated*. 43 pages, each
citing its source perfectly, were indistinguishable from 43 pages pulled off a
search engine. The mislabel is invisible — the page is right, the citation
resolves, only the frontmatter lies.

**(b) `rule_domain: artifact | world`, and R-01 is now scoped to `artifact`.**
`rule_class` asks whether a rule has a checkable SHAPE. It does not ask whether
the rule has a checkable SUBJECT here. Compiling 279 reports harvested 540
deterministic rules, every one of the second kind:

    "A soybean meal import into Indonesia must hold a permit issued under the
     MOT 11/2026 and MOA 11/2026 licensing procedures."

Perfectly deterministic. Completely uncheckable in that package, which contains
no consignments — a gate for it would have nothing to open. All 540 defaulted to
`scope_include: ["wiki/**.md"]`; the same placeholder on every single rule is the
tell that the field was meaningless for them.

The cost was not theoretical. R-01's count then grows with every source ingested,
so the ratchet reddens on a schedule and gets bumped without being read — three
times in one session before the category error underneath was spotted. §1 of
docs/deterministic-gates.md is about rules the MAINTAINERS must obey; it quietly
assumed the output's rules are about the output. True for a repository, false for
a document corpus.

World rules are not excused: `/ctx-lint` counts and prints them every run, they
stay catalogued and citable, and one that declares a gate anyway still faces
R-02..R-07 in full.

**A dead fixture, found by making this change.** With `world` as the fallback the
dirty fixture's prose-only rule stopped firing R-01 — and the pair still went red,
so it looked fine. Two different checks were both labelled R-01: the real one and
the discarded-rule/`discard_reason` check. The label collision hid the loss. The
discarded check is now **R-00**, the prose-only fixture declares
`rule_domain: artifact` (which is what it tests), and the clean tree gained a
NEGATIVE CONTROL — an ungated world rule that must stay green, so the exemption is
proven to work rather than merely to exist.

**Migration for an older client: none required.** `rule_domain` defaults to
`world`, so an older `/ctx-compile` that never writes the field produces exactly
the new behaviour. `source: document` is opt-in and nothing validates the enum
mechanically. The one visible change is R-01 no longer firing on harvested rules —
deliberately.

**Files.** `AGENTS.md` (enum, `rule_domain` section, version), `scripts/ctx-lint-rules.sh`,
`.claude/commands/ctx-compile.md`, `tests/gates/ctx-lint-rules/{clean,dirty}/**`,
`scripts/smoke-all.sh` (R4's version pin).

## 2026-08-08 — three enforcement gaps closed: the standing rule applied to this repo

**Rationale.** `docs/deterministic-gates.md` §1 says no deterministic rule stays
prose-only, and `/ctx-lint` R-01 enforces exactly that — on the compiler's
*output*. Three places in the compiler's own repo did not meet the standard. Two
were live bugs.

**1. A generated compiler could not package itself.** `scripts/package-wiki.sh`
ships in the installer skeleton and hard-sources `scripts/lib/ctx-root.sh`
(line 72), which was absent from `scripts/installer-skeleton-manifest.txt`. Every
repo built by `scripts/create-context-compiler.sh` exited 2 on its first
packaging attempt — the context package, the fifth property in
`docs/CONTEXT-COMPILER.md`, was unreachable from a generated compiler. Fixed by
adding the manifest row. An audit of every manifest-shipped script for unlisted
`lib/` dependencies found no others.

**2. The ratchet's registration check missed the directory `/ctx-gate` writes
to.** `scripts/gate-ratchet.sh` enforced "every gate owns a baseline row" over
`scripts/gate-*.sh` and `context/gates/*.sh`, but `/ctx-gate` writes to
`gates/<RULE-ID>.sh` (`scripts/new-gate.sh:38`). The first gate the compiler ever
generated for itself would have been exempt from the requirement
`gates/baseline.tsv` declares non-negotiable in its own header. Latent only
because `gates/` holds no `.sh` files yet. Two other call sites already had the
glob right (`gate-ratchet.sh:80`, `gate-fixtures.sh:141`), which is what marks it
a slip rather than a design choice.

It survived because the gate that catches unproven gates was itself unproven:
`tests/gates/ratchet/{clean,dirty}` existed and `--repo` worked, but
`scripts/gate-fixtures.tsv` had no row and `gate-fixtures.sh` excluded
`gate-ratchet.sh` by name as "recurses". That exclusion was over-broad — the
recursion only exists for the *default* invocation, which reads the real
baseline; in `--repo` mode it reads the fixture's, which lists stubs only.

The pre-existing dirty fixture could not have caught it either: it fails for
three other reasons, so it exits 1 whether or not `gates/` is scanned. Pinning
the fix needed a tree whose *only* defect is an unregistered `gates/*.sh` —
`tests/gates/ratchet/gates-arm-dirty/`. Verified by reverting the glob: the old
code reports "clean — none unregistered" on that tree while an unregistered gate
sits in it.

`gate-ratchet.sh` remains the one gate with no baseline row, now stated in
`gates/baseline.tsv` rather than left implicit: it has no `--count` mode, because
"count your own violations" is undefined for the script that reads the baseline,
and a row naming it would make it invoke itself once per run forever. Its
coverage is two fixture pairs instead.

**3. `CTX-ROOT-ADOPTION` (R41) — a new gate.** `AGENTS.md` tells new code to
resolve the compiled root with `ctx_root()`. Measured adoption on the day the
gate was written: 4 files called it, 41 files hardcoded `wiki/` on 80 non-comment
lines. `gate-context-root.sh` (R40) proves `ctx_root()` *resolves*; it states in
its own header that it proves nothing about the scripts that bypass it.

`scripts/gate-ctx-root.sh` counts hardcoded roots under `scripts/` and is
**ratcheted at 80, not migrated to 0** — `AGENTS.md` argues directly against a
bulk rewrite of the oracles that constitute this repo's safety net, and this gate
deliberately creates no pressure toward one. Five declared failure modes in the
header; a five-way mutation proof confirmed the fixture pair catches each break.
The negative controls (a commented path, and `meta-wiki/`-style names that must
not match) live in the **clean** tree on purpose: `gate-fixtures.sh` compares exit
codes only, so a control planted in a tree that already exits 1 proves nothing.

Wired as R41 via `--count` rather than a bare run: this is the first gate with a
nonzero baseline, so a bare run exits 1 by design and forever. R41 proves the gate
is operable, R36's ratchet enforces the threshold, R31 proves it discriminates.

**Not done, and why.** The plan called for adding a `RATCHET-NO-INCREASE` row to
`gates/baseline.tsv`. That would recurse infinitely — see the exception recorded
above.

**Three claim gates fired on this change, and each was answered by correcting the
claim rather than the gate.** `gate-doc-claims.sh` caught README's bound
`smoke-guard-range` still reading R1–R40; `verify-site-claims.sh` caught both
`site/index.html` and README still advertising 43 deterministic checks against a
suite that now runs 44. Adding a check to a repo that publishes its own numbers
is supposed to cost exactly this, and it did.

**Files.** `scripts/gate-ctx-root.sh` (new), `scripts/gate-ratchet.sh`,
`scripts/gate-fixtures.sh`, `scripts/gate-fixtures.tsv`,
`templates/gate-fixtures-fresh.tsv`, `gates/baseline.tsv`,
`scripts/installer-skeleton-manifest.txt`, `scripts/smoke-all.sh`,
`tests/gates/ctx-root/**` (new), `tests/gates/ratchet/gates-arm-dirty/**` (new),
`tests/gates/ratchet/clean/gates/RULE-9999.sh` (new), `AGENTS.md` (the ctx_root()
paragraph now names the gate that enforces it), `README.md` (bound claim
`smoke-guard-range` → R1–R41; check count → 44), `site/index.html` (check count
→ 44), `.github/workflows/ci.yml`.

## 2026-08-08 — schema v5: the commands are `/ctx-*`, the project is `context-compiler-bootstrap`

**Rationale.** The names had drifted from the thing. `/wiki-ingest` described the weakest part of what it does: the output carries provenance, typed relations, valid time, a portable bundle and its own verifier, and "wiki" named none of that. The canonical commands are now `/ctx-init`, `/ctx-extract`, `/ctx-compile`, `/ctx-query`, `/ctx-lint`, `/ctx-visualize`, `/ctx-flashcards`, `/ctx-diagram`, `/ctx-discover`. The project is renamed `llm-wiki-bootstrap` → `context-compiler-bootstrap`, and `scripts/create-llm-wiki.sh` → `scripts/create-context-compiler.sh`.

**Migration note: none required.** All nine `/wiki-*` names survive as forwarders that print one deprecation line and delegate to the canonical file; they are not scheduled for removal. `/ingest` still works alongside the new `/compile`. `scripts/create-llm-wiki.sh` remains as an `exec` forwarder. An older client that knows only the old names is fully functional.

**What was deliberately NOT renamed.** `raw/` (immutable evidence — the old name appears inside sources and stays there), `log.md` history below this entry, committed test fixtures whose bytes are asserted, `.scratch/` design records, and the wiki page `okf-vs-llm-wiki-bootstrap.md`, whose slug names the project as it was called when that comparison was made. Tooling scripts keep their `wiki-*` names (`wiki-to-kg.py`, `wiki-metrics.sh`, `wiki-lint-*.sh`) — they operate on the wiki layer, which is still called `wiki/`.

**Also in this change.** `docs/CONTEXT-COMPILER.md`'s Vocabulary section previously promised the opposite ("No identifier in this repo is named after the right-hand column ... they stay that way"); that paragraph is rewritten to say what changed and why, rather than quietly contradicted. Two new gates: `ALIAS-RESOLVES` (R37) proves every one of the 19 alias files resolves to an existing canonical command, and `EXEC-BIT-PRESERVED` (R38) catches the redirect-and-move rewrite that dropped `+x` from 55 scripts mid-rename.

## 2026-08-08 — valid-time contract satisfied: seven honest unknowns

The last red row on the package-quality scorecard. Every one of the seven raw sources now records an `asserted_at`, and every one of them records **`unknown`** — with a specific reason and a specific way to resolve it.

That is the honest answer, not an evasion. Each body was read looking for a passage that states the document's own date, and none has one. The near-miss is worth naming: the Devsplainers transcript says the OKF spec was published "On June 12th" — but that dates an **event the video reports**, not the video. It establishes only that the video postdates 2026-06-12, which is a lower bound, and writing a lower bound into a date field would be the same class of error as hand-writing a hash: a receipt nobody derived. The note records the bound instead. Two sources (the Google Cloud blog, the OKF spec) were fetched with `extraction_status: degraded`, so any dateline is in the part that never arrived — the note says so and names the fix. Two are synthetic fixtures with no real date and never will have one; those say "unknown by design". Copying `fetched_at` was never on the table — `/wiki-extract` forbids exactly that conflation.

**The append-only gate caught a first attempt.** The notes were originally written as YAML block scalars (`asserted_at_note: |` plus indented lines). `gate-raw-append-only.sh` authorises the `asserted_at` family as keys, but its diff parser only recognises one continuation shape — `- wiki/…` under `ingested_pages:` — so the indented note lines read as an unauthorised body edit and all six files were rejected. Correct behaviour from the gate given what it can express. Rewritten as single-line double-quoted scalars, so every added line is a recognised `key: value`; no gate change was needed, and the contract stayed as documented.

Frontmatter-only throughout: **every body hash is unchanged**, verified against `body-hash.sh` per file. No citation moved, no drift fired, nothing needed re-ingesting.

`asserted-at-audit.py` is clean in both default and `--all` mode (the latter also covers `canary-scanned.pdf.md`, which nothing cites yet and which default mode skips — annotated too, so the stricter mode passes as well).

**Scorecard: 10/11 → 11/11.** All eleven structural measures pass. Which is the floor, not the ceiling: it says the package is sound, not that it is useful. Tier 2 — the behavioural half — still has no measured numbers for this package.

- Updated: all 7 files in `raw/`, frontmatter only (`asserted_at`, `asserted_at_note`)
- Contradictions flagged: none

## 2026-08-08 — the commitment lint was quote-blind (one reader, four copies)

The new package-quality scorecard reported "4 of 6 cited sources lack an ingest commitment", and the obvious next move was to re-run `/wiki-ingest` on each. That would have been wrong, and expensive: **all four hashes were present, correct, and current.** Recomputing each with `scripts/body-hash.sh` matched the stored value exactly.

The four store the hash **unquoted** (`ingested_hash: d1d2986…`). `wiki-lint-commitment.sh` tested for it with `grep -q 'ingested_hash: "[0-9a-f]'` — a literal opening double-quote. Unquoted is valid YAML, and `scripts/commit-source.py` (the canonical writer) *reads* quote-optionally at line 101 while always *writing* the quoted form at line 116. Tolerant reading was already the intended contract; two readers just did not implement it.

The diagnosis was wrong in a second, worse way. The error text also claimed "hash-drift detection is disabled for this body". It is not — `wiki-lint-hash-drift.sh` reads the field through an awk helper that strips quotes. Verified empirically rather than by reading: tampering with two bodies in a temp copy, one quoted and one unquoted, produced `2 raw source(s) no longer match their ingest commitment`. Drift was being caught the whole time on exactly the sources the lint called uncommitted. Message corrected.

The same inline grep had been written **four** times — `wiki-lint-commitment.sh`, `wiki-metrics.sh`, `eval-retrieval.sh`, and `verify-retrieval-eval.sh`. The last one is the oracle for the third, and it reimplemented the predicate instead of calling it, which is precisely why the bug outlived its own test. Replaced with `scripts/lib/commitment.sh` — one `has_commitment()`, quote-agnostic, sidecar-aware, hex-validated (a non-hex value is a hand-written receipt and must not read as verified). Same reasoning as `body-hash.sh` being the one hasher: a second implementation of a shared predicate does not stay identical to the first.

`verify-metrics.sh`'s P1 fixture was all-quoted, which is how the bug survived. It now carries `committed-unquoted.md` with a bare hash, and `exp_ok/exp_total` moves 2/3 → 3/4. Mutation-tested: reverting the reader to quote-only makes the oracle report `committed=2/4`, i.e. it now fails.

Net effect on the scorecard: **9/11 → 10/11**, with no model calls, no writes to `raw/`, and no wiki pages rewritten. The remaining red row is the `asserted_at` gap on 6 sources, which is genuine debt.

- Created: `scripts/lib/commitment.sh` (added to `installer-skeleton-manifest.txt` — both callers ship in fresh installs)
- Updated: `scripts/wiki-lint-commitment.sh` (reader + corrected message), `scripts/wiki-metrics.sh`, `scripts/eval-retrieval.sh`, `scripts/verify-retrieval-eval.sh`, `scripts/verify-metrics.sh` (fixture)
- Contradictions flagged: none

## 2026-08-08 — context-compiler framing (positioning, no mechanical change)

"Wiki" names the shape of the output; it does not name the function of the system. Adopted **context compiler** as the category: *a context compiler transforms unstructured source material into a structured, provenance-aware, machine-navigable context package that LLMs can navigate, retrieve from, and reason over.* Every clause of that definition was already implemented and already gated — extract/segment/ingest for the transform, the page template and typed-relation grammar for structure, the citation + hash + entailment stack for provenance, `[[link]]`/KG/MCP for navigability, and `package-wiki.sh` + `MANIFEST` + the in-bundle verifier for the package. So this is a naming change, not a build change.

**The last clause was rewritten before shipping.** The draft read *"…that an LLM can reliably use."* That word promises what this layer cannot deliver: a compiler controls the artifact, not the model reading it, and a flawless package can still be misread. Replaced with three verbs — navigate, retrieve from, reason over — because each is a property of the artifact rather than of the reader, and each is already measured: R1 needle retrieval, R4 citation locus, M1/M2/M5 multi-hop, R5 stale evidence, M6 citation integrity. "Reliable" is a word to earn from a scorecard, not to assert in a definition.

So the scorecard now exists. `scripts/package-quality.sh` aggregates the **structural** half — eleven measures, no LLM, no network, recomputed on demand — from the tools that already owned each one (`citation-audit.py`, `corpus-health.py --json`, `wiki-lint-commitment.sh`, `wiki-lint-hash-drift.sh`, `asserted-at-audit.py`). Nothing is recomputed locally, for the same reason `body-hash.sh` is the one hasher: a second implementation of "count the citations" drifts from the gate that enforces it. The two tiers are kept apart on purpose — structural measures are **properties** and recompute for free; the `eval-*` family measures **events**, costs real model runs, and its numbers must carry a date (the rule `verify-site-claims.sh` already applies to every score on the public page). Printing them as one number would launder an event as a property.

It reports rather than gates by default (exit 0; `--strict` exits 1), because a repo with known debt must still be able to read its own numbers — and this repo has debt: **9 of 11 pass**, with 4 of 6 cited sources missing an ingest commitment and 6 sources missing `asserted_at`. That is the scorecard doing its job on its first run.

`scripts/verify-package-quality.sh` (Q1–Q7, wired as smoke R35) is the oracle, because a scorecard that only ever prints green launders debt as quality. It proves the thing still fails an unsound package, agrees with its own `--json`, never edits what it measures, and does not report a perfect score on an empty package. Q2 pins a real bug found in the first draft: `corpus-health.py` prints `thin (<2 related): 0`, whose *label* contains a 2, and a first-number grab reported the THRESHOLD as the count — a fully-linked package scored "2 thin". Fixed by reading `--json` fields instead of prose. Both mutations (reintroduce the bug; force the citation row green) were confirmed to make the oracle fail before it was wired in.

Adding R35 moved the suite 37 → 38, which `verify-site-claims.sh` caught immediately on `site/index.html` and `README.md` — the guard behaving exactly as designed. Counts updated in the same commit, along with the `smoke-guard-range` claim marker (R1–R34 → R1–R35).

New `docs/CONTEXT-COMPILER.md` defines the category independently of this repo's name: the definition, the five conformance properties with their verify scripts, the vocabulary mapping, and — stated up front rather than buried — the limit. The transform stage is LLM judgment and is not reproducible; determinism is scoped to the body-hash cache key, the synthesis artifacts, the OKF export, and the manifest. The guarantee on offer is verifiable output, not reproducible output.

Two features that look like exceptions are named instead of hidden. `/wiki-query` promotion writes into its own source tree mid-run — framed as **dependency resolution** (`npm install` fetching a missing dep during a build), since the fetched source goes through the same no-bare-URL, frontmatter, and entailment rules as any `/wiki-extract` acquisition. Flashcards, slides, diagrams, `/wiki-discover`, and `wiki/journal/` are a **viewer tier** over a built package, which is what `AGENTS.md` already said by calling them "not lifecycle steps".

`AGENTS.md` gained a `## Output format — the context package` section: packaging existed only in shell scripts and `docs/SELLING.md`, so the schema layer had no notion of its own distributable — the weakest-surfaced clause of the definition. No `/wiki-export` was added; `wiki/commands.md` records that a unified exporter was deliberately rejected in favour of a split output tier, and that stands. Schema version deliberately **not** bumped: no command, frontmatter, or layer rule changed, and `smoke-all.sh` pins the literal `**Schema version:** 4`.

- Created: `docs/CONTEXT-COMPILER.md`, `wiki/context-compiler.md`
- Updated: `README.md` (lead, packaging framing, vision), `AGENTS.md` (what-this-is + output format), `docs/EXPLAIN.md` (source-maps and npm-pack rows), `site/index.html`, `CLAUDE.md`, `GEMINI.md`, `.clinerules`, `.github/copilot-instructions.md`, `.cursor/rules/llm-wiki.mdc`, `wiki/index.md`, `wiki/core-idea.md`
- Unchanged on purpose: repo name, git remote, `/wiki-*` commands, `raw/` and `wiki/` paths, every script name, the bundle format
- Contradictions flagged: none

## 2026-07-24 — cross-modality retrieval eval (the measuring instrument)

"Can a bootstrapped wiki retrieve accurate, point-in-time info about anything?" was asserted, never measured — the existing evals cover multi-hop traversal and citation faithfulness, neither of which touches tabular or thread sources, and none of which has a time axis. Added `scripts/eval-retrieval.sh`: five binary checks (R1 needle retrieval per modality, R2 point-in-time as-of + current in one run, R3 refusal on absence, R4 citation locus, R5 stale evidence blocks the answer) run against a wiki built by the REAL installer and loaded through the REAL `/wiki-extract` → `/wiki-ingest` path — no hand-authored wiki fixture, because the gaps being hunted (tabular truncation past the 20-row preview, thread flattening) live in extract/ingest and a fixture would paper over exactly them.

Corpus is generated, not committed (`tests/eval/retrieval-corpus/gen-corpus.sh`, deterministic — the numbers are only comparable across runs if the input is fixed): a 1200-row CSV with the needle at row 947, a 14-message thread with the needle in message 11, a 24-section 11k-word report with the needle in section 21, and two vintages of one throughput figure (412 Q1 → 389 Q3) with the vintage stated in the body text, so the eval runs against today's schema with no `asserted_at` field. Every needle is a synthetic `NEEDLE-<MODALITY>-<hex>` planted past the boundary its extractor truncates at — unguessable from a preview and absent from pretraining, so it can only be produced by actually reaching it.

`scripts/cite-span.py` resolves a citation to its passage by importing `citation-audit.py`'s anchor grammar rather than reimplementing it (same reason `body-hash.sh` is the one hasher — a second copy would make the eval measure something the audit doesn't enforce). R4 is the Goodhart-hardened check: containment alone passes a whole-file cite, tight-span alone passes a cite of the wrong lines, so it demands one passage that does both.

Graders live in `scripts/lib/eval-common.sh` so `scripts/verify-retrieval-eval.sh` (E1–E6, wired as smoke R23) can exercise them with no LLM and no spend: corpus determinism, needles past the first-40-lines boundary, and — the point — that whole-file, wrong-line, and oversized-but-containing citations all FAIL. An eval whose graders are unverified reports a perfect score on a broken system. Holdout: `tests/eval/retrieval-questions-holdout.md` plus `gen-corpus.sh --holdout` (plain-text meeting notes, own needle, supersession twist), never run by default, never in CI, never to be "fixed" by editing. Smoke now 28 checks, all green. The eval itself has NOT been run yet — that costs `claude -p` invocations and is the next step.

## 2026-07-26 — first eval run came back VOID; hardened the instrument

Ran `scripts/eval-retrieval.sh` for real. It printed `retrieval score: 6/12` (R1 3/3, R2 2/2, R3 1/1, R4 0/5, R5 inconclusive) and that number is **not a measurement** — recorded here because a plausible score from a broken harness is the most expensive artifact this project can produce.

Three faults, in ascending order of importance. (1) `/wiki-ingest` died on a transient `API Error: 529 Overloaded`, leaving `wiki/` at one empty stock `index.md`; `claude_p()` now retries once on 5xx/overload/rate-limit. (2) The question loop ends `done < "$tmp_q"`, so every nested `claude -p` inherited stdin pointed at `questions.tsv` and swallowed the later eval questions into the first one's prompt — the model said so in its own answer. All three invocation sites now pin `</dev/null`. (3) The one that matters: with an empty wiki, `/wiki-query` answered all six questions **correctly by reading `raw/` directly**, and disclosed it. So R1 and R2 scored full marks while measuring "an agent can grep a CSV" — a false pass straight through the middle of the loss function, on the checks that exist to prove wiki retrieval.

Fix for (3) is two-part, because detection and visibility are different problems. A VOID gate refuses to score when `wiki/` has <= 1 page or no raw source carries a real `ingested_hash` — it prints why and exits 3 instead of spending on queries that cannot measure the thing. And a `via` column tags every answer `wiki` / `raw-only` / `unknown`, so a raw bypass stays visible once the wiki *is* populated, which the gate alone would not catch. `verify-retrieval-eval.sh` grows E7 for both, negative-tested: deleting the gate fails it, unpinning stdin at one of three sites fails it.

Also `--work=DIR`: state persists outside a temp dir and install/extract/ingest/each-question are skipped when already complete, so a kill costs the current stage instead of the whole run, and answers on disk re-grade for free when a grader changes. Two prior runs were lost to kills before this existed.

Worth recording against the prediction made before the run — R1-csv fail, R2 fail both legs, R1-email unknown: every needle came back correct from raw text alone, across CSV row 947, email message 11, report section 21, and both report vintages. That is evidence about the agent's reading, and none about the wiki's retrieval. The run designed to measure the wiki passed without the wiki existing.

## 2026-07-26 — second run: R1 3/3 via wiki, and three more grader faults

Re-ran with ingest healthy: 7 raw files, 14 wiki pages, every answer tagged `via: wiki`. First genuine signal — **R1 3/3**, needles retrieved through the wiki across CSV row 947, email message 11 and report section 21; **R4 2/5**, with the email needle earning a tight correct locus (`raw/thread-q3-planning.eml.md#L120-L127`) and the CSV and report needles not. Those two numbers stand.

Three more faults found, all in the instrument. (1) `--work` resumability poisoned the corpus: R5 corrupts `capacity-report-q1.md` (412 -> 999) and the marker files let a resumed run re-ingest the *mutated* body, committing `ingested_hash` over it — so R5 is structurally unscoreable and the as-of question silently changes answer. R5 now snapshots and restores the file, and a `.mutated` marker surviving a kill forces a clean re-extract on the next run. (2) R2-asof PASSED with a headline of **999 GB/day** — the wrong figure — because `expects` was a document-wide substring search and `412` appeared eight paragraphs down in a caveat about the drift. (3) R3-absent FAILED on a textbook refusal: "No Q2 2026 sustained throughput figure exists in this wiki" matched no marker, because every marker required "for"/"in" straight after the noun.

Fix for (2) is per-question, not grader-wide: both vintage questions now carry a headline-anchored `forbids-pattern` (`^[^a-zA-Z0-9]{0,4}(389|999)`). Scoping `expects` to the first N lines was tried first and is strictly worse — it fails answers that open with a preamble while still passing the buried case it was written for. Reverted, and the reasoning is in the grader so it is not retried. E3b/E3c/E5b cover all three; oracle is E1-E7 across 12 checks.

Re-graded verdicts (cached answers, no spend — the point of `--work`): R1 3/3, R2 1/2 (asof now correctly FAILS), R3 1/1, R4 2/5, R5 inconclusive. R2-asof leading with the raw's *current* value rather than the figure of record on the asked-for date is the missing `asserted_at` axis showing up as a measurement rather than an assertion.

One process note worth more than any of the above: the first re-grade run reported R1 0/3, which was wrong — the ad-hoc loop ran under zsh, which does not word-split unquoted `$expects` on `IFS=','`, so multi-token expectations collapsed into one literal. The eval itself is `#!/usr/bin/env bash` and unaffected. Grader changes get verified by re-running the oracle or `bash -c`, never by a zsh one-liner.

## 2026-07-27 — R4: 0/7 -> 7/7. The spec gap was the whole story.

Re-ran after the `/wiki-query` citation-contract fix. 9 raw files, 14 wiki pages, every answer `via: wiki`.

**R4 went from 0/7 to 7/7.** Three runs of zero had pointed at the model; the defect was an instruction that never asked for the citation. With the form stated, every answer emitted it, and the loci are tight and correct — `raw/sales-2026.csv#L948` for the CSV needle at row 947, `raw/thread-q3-planning.eml#L120-L127` for the email needle in message 11, `raw/field-report.md#instrumentation-debt-lines-1043-1098` for the report needle in section 21. Nothing about the model's retrieval changed between the 0/7 run and this one.

Everything measured passed: **R1 3/3, R2 4/4 (both capacity legs and both silent-memo legs), R4 7/7 — 7/7 questions, 14/14 including citations.**

**R3 and R5 are INCONCLUSIVE, not failures.** Both answer files contained `You've hit your session limit · resets 10:40am`. The run hit the account cap on its last two questions. The E8 machinery added earlier the same day caught the API-error family but not this phrasing, so both were scored FAIL — again indistinguishable in the report from a refusal defect and a drift-detection defect. `RETR_BROKEN_MARKERS` now covers session/usage/quota/credit-balance/login forms, and E8 asserts the exact string that bit. Re-graded from cached answers at no cost: 7/7 measured, 2 inconclusive.

That is the third distinct way a non-answer has been scored as a capability failure (529 overload, ENOTFOUND, session cap). The pattern is worth stating plainly: any transport failure that returns text will be graded as text unless something explicitly recognises it, and every such mis-grade looks exactly like the system being bad at its job.

**Entities remain unmeasured.** `eval-entities.sh` reports NO ENTITIES CAPTURED against this wiki, and the cause is timing, not capability: the run started 06:49:32 and Step 3.5 was committed 06:56:46. The run's own installed copy of `wiki-ingest.md` contains no Step 3.5, so entity capture was never requested. N6 earned itself here — reporting "the section was never written" instead of "E1 0% recall" is the difference between a scheduling note and a false bug report. Needs one fresh extract+ingest once the session cap resets.

## 2026-07-27 — R4 root cause was a spec gap; entity extraction (phase 2) instrumented

**R4's 0/5, 0/5, 0/7 was never the model.** `/wiki-query`'s output template asked for `- Wiki:` and `- Web:` and never asked for an inline `(source: raw/<file>#<anchor>)` at all. Answers that emitted one were improvising, so the shape varied per run: a backticked path, the path merged into a wikilink parenthesis, or provenance listed only in the Sources block. Every one is unverifiable, because `citation-audit.py` locates evidence by grepping the literal `(source:` form. The provenance was real and tight every time — the last run cited `raw/retry-budget-memo-feb.md#L20-L22`, exactly right — it just was not in the contracted shape. Three runs of evidence pointed at the model; the defect was in the instruction.

`/wiki-query` now states the form literally, adds a `- Raw:` line, tabulates the near-miss shapes that actually occurred with why each fails, and requires the narrowest anchor (a citation resolving to 60 lines gestures at a document; one resolving to 2 proves a claim). Guarded by `verify-query-citation-contract.sh` (Q1-Q5, smoke R25). Q5 is the load-bearing check: it round-trips the taught form through the grader's real extractor, so contract and audit cannot drift apart silently and send R4 back to zero with no visible cause.

**Phase 2 (entities) is instrumented but not yet measured.** Design decision: entities feed the EXISTING KG rather than a parallel store. `type: entity` is already a page type and `wiki-to-kg.py` already builds edges from `## Related` links, so a second entity store would be two sources of truth that disagree — the failure the drift lint exists to prevent. Step 4 already handled entities but gated page creation on "2+ raws OR structurally important", which is why a person who made one decision in one email was never captured at all. New Step 3.5 captures entities as cited bullets in an `## Entities` section on the summary page; promotion to a full page still respects Step 4's threshold. That gets contextualization without a page per person.

The spec names what is NOT an entity, in a table, because listing every capitalized phrase is the failure mode: it looks thorough, doubles the noise, and makes entity retrieval useless — a list where everything is an entity identifies nothing.

`scripts/eval-entities.sh` scores it deterministically against a gold set already present in the corpus (the five `From:` authors in the email thread) and planted decoys (Title Case section headings from the field report). E1 recall >= 80%, E2 decoy capture <= 20%, E3 provenance >= 80% resolvable to a containing passage <= 10 lines. E1 and E2 are each other's mitigation and are never to be read separately: recall alone is won by dumping every capitalized token, precision alone by emitting the two obvious names. `verify-entity-eval.sh` (N1-N7, smoke R26) builds a wiki that plays each strategy and asserts it LOSES.

Two portability traps hit while building, both worth recording because they produce silent wrong numbers rather than errors: BSD `sed` has no `\|` alternation (GNU extension), so name extraction returned the whole bullet and E3 read 0% on correct data; and `grep -q` under `pipefail` closes the pipe, the producer takes SIGPIPE, and the pipeline reports failure on correct output. Both now covered by N7 and by N6's variable-capture pattern.

Smoke 29 -> 31 checks (R25, R26), all green. The entity numbers are NOT measured yet — that needs an ingest run against the new Step 3.5.

## 2026-07-27 — T2 run: as-of survives without prose, and the eval mis-scored a correct answer

Ran the eval against the T2 pair. 9 raw files, 16 wiki pages, every answer `via: wiki`.

**The extract contract holds.** `/wiki-extract` populated `asserted_at` on all 7 sources unprompted and reasoned correctly about each: end-of-period for the two capacity reports (2026-03-31, 2026-09-30), the bare `Published:` line for both memos, the thread's last message date for the `.eml`, and `unknown` + a note for the two genuinely undated sources (`field-report.md`, `sales-2026.csv.md`). `fetched_at` was 2026-07-27 on every file and appears in **zero** `asserted_at` fields — the A5 false pass was not taken once. All 7 anchors resolve to a passage containing their stated date.

**T2-silent-asof PASSED.** "As of 2026-03-01, the ingest retry budget was 3 attempts per message", citing `raw/retry-budget-memo-feb.md#L20-L22`. As-of reasoning survives with no relational prose to lean on — which is what T2 existed to find out, and the answer is yes.

**T2-silent-current "FAILED" and the answer was right.** The run happened 2026-07-27; the second memo was dated 2026-09-22, two months in the FUTURE. The system answered 3 attempts, explained that only the February memo was in effect, flagged the future date as an anomaly worth chasing with the author, and recorded the two memos as a genuine contradiction. My question demanded 7. A corpus with fixed dates cannot ask about "now" — the question has to be answerable from the documents alone, with no reference to when the eval runs. Both dates moved into the past and both "now" questions rewritten to "the most recently published …". E9 now fails the oracle if a `now` question reappears, and it immediately caught a second instance I had not noticed: `R2-current` had the same defect and had been passing only because the Q3 report's prose says "supersedes … as the current number" — the relational prose was covering for a future-dated document. Exactly the dependency T2 was built to expose.

**R5 "FAILED" on an API error.** The answer file contained `API Error: Unable to connect to API (ENOTFOUND)`; the drift logic was never exercised. Graded as FAIL, which in the report is indistinguishable from the system serving a stale claim — the same class of defect as scoring an empty wiki. `retr_answer_broken` now detects API/network/empty answers, the eval marks them INCONCLUSIVE and excludes them from the denominator rather than counting them as losses, and the report says how many were excluded. E8 covers it. The `.r5-pristine` restore did work: raw/ was back to 412 and the drift lint clean afterwards, so the poisoning fix from yesterday holds.

**R4 0/7.** Third consecutive run at zero, and the cause is confirmed as format, not provenance: the T2 answer cited `raw/retry-budget-memo-feb.md#L20-L22` — exactly the right locus — but wrapped as ``([[page]], source: `raw/…`)`` rather than the bare `(source: raw/…)` that AGENTS.md hard rule 4 mandates and `retr_citations` greps for. The provenance is real and tight every time; the emitted format is not the contracted one. Still out of scope here, still not to be fixed by loosening the grader, and now with three runs of evidence behind it.

Oracle: E1–E9, 12+ checks. Smoke 29 green.

## 2026-07-26 — valid time: `asserted_at` enforced (timestamps phase 1 of 2)

The clean run's R2 pass was load-bearing on luck: the corpus states its vintage in prose ("reporting period", "figure of record for Q1", "supersedes ... as the current number"), so an as-of answer could be assembled from phrases without any vintage reasoning. Delete those clauses and the capability goes with them, because nothing structured carried the document's own date. `fetched_at` is transaction time only.

Added the valid-time axis. `asserted_at` is the date the DOCUMENT claims for its content, and it is never silently absent: either an ISO date plus `asserted_at_source` — an anchor into that file's own body where the date appears, resolved through `citation-audit.py`'s grammar, with the date required to be inside the passage — or the literal `unknown` plus `asserted_at_note` saying why. `unknown` is a first-class answer on purpose: plenty of real sources have no discoverable date, and a lint that blocked them would push authors to fabricate one. What is forbidden is silence.

The check that earns the design is A5. Copying `fetched_at` into `asserted_at` is the cheapest possible false pass — 100% field coverage, zero information, and every as-of query silently defeated. The mandatory anchor is what prices it out: a date that must resolve to a passage stating it costs more to fake than to read off the page. A5 asserts both the rejection and that the message names the pattern, so the next author to try it is told why.

`scripts/asserted-at-audit.py` (reuses `wikitext.parse_frontmatter` and `citation-audit.py`'s `resolve_anchor` — a second copy of either would let the lint accept anchors the citation audit rejects), `scripts/wiki-lint-asserted-at.sh`, oracle `scripts/verify-asserted-at.sh` A1–A11, smoke **R24**, `/wiki-lint` check 9, `/wiki-extract` step 4 populates all three fields, installer manifest. Smoke now 29 checks, all green. Prose date forms are accepted ("March 31, 2026" satisfies `2026-03-31`) — an ISO-only lint would force authors to edit `raw/`, which hard rule 1 forbids. Frontmatter-only writes leave the body hash untouched, so this does not trip the drift lint.

T2 corpus pair added: `retry-budget-memo-feb/sep.md`, identical bodies apart from one figure, a bare `Published:` line, and no "supersedes"/"current"/quarter names anywhere — verified zero relational cues. Two questions (`T2-silent-asof`, `T2-silent-current`) with headline-anchored forbids. Honest limit, recorded so it is not overclaimed later: the date still lives in the body, so T2 does not prove the `asserted_at` FIELD is load-bearing — a source with no date anywhere would be unsatisfiable, since `/wiki-extract` would correctly record `unknown`. T2 proves the narrower thing: as-of survives with no relational scaffolding to lean on.

Not yet run against T2 — that costs a full extract+ingest and is the next step. Phase 2 (entity extraction, checks E1–E3, feeding the existing KG rather than a parallel entity store) is not started. The `AGENTS.md` schema addition is a patch at `scratchpad/agents-md-asserted-at.patch`; context-gate blocks agent writes to that file.

## 2026-07-26 — clean run: 7/12, and point-in-time actually works

First run where all five checks were measured on one honestly-ingested corpus — fresh install, no cached stage, `capacity-report-q1.md` ingested at 412 so R5's mutation had a real commitment to violate. 7 raw files, 11 wiki pages, every answer `via: wiki`.

**R1 3/3** (second independent sample), **R2 2/2**, **R3 1/1**, **R5 1/1**, **R4 0/5**. Score 7/12 — numerically identical to the contaminated run and completely different in meaning.

**R2 is the correction.** The prior run's failure was called evidence that point-in-time does not work; that was an artifact of the poisoned corpus. On clean data the as-of leg leads with "Sustained throughput as of 2026-04-15 was 412 GB/day" and the current leg with 389, both right, in one run. The honest scope of that capability: the corpus states its vintage in body text ("period through 2026-03-31", "supersedes Q1"), so the wiki is reasoning about vintage from *content*, not from a valid-time axis. It works because the documents self-describe. A silently-revised document with no stated vintage would still defeat it, and that is what an `asserted_at` field would fix — so the gap is narrower than claimed but real.

**R5 passes convincingly, not incidentally.** The answer names both hash prefixes (`21dca3d0…` vs recorded `2a394578…`), identifies the edit as uncommitted and post-ingest, refuses to serve the 999, prescribes `/wiki-ingest` if intentional, and explicitly declines to `git checkout` away the user's working-tree change. The drift commitment added earlier today is enforced at query time, not just by the lint.

**R4 0/5 is a format-compliance defect, not a missing-provenance defect, and R4 currently conflates the two.** The provenance is present and tight — the email needle is cited as `raw/thread-q3-planning.eml#L118-L125` — but rendered inside a `Sources:` list in backticks instead of the inline `(source: raw/<file>#<anchor>)` form that AGENTS.md hard rule 4 mandates. Only 1 of 7 answers used the required form here; the previous run used it more often. So the finding is that the inline citation convention is applied **inconsistently across runs**, which `citation-audit.py` cannot catch either since it only inspects committed wiki pages, not query output. Fixing this belongs in `/wiki-query`'s output contract, and R4 should keep failing until it lands — a grader taught to also accept the backticked Sources form would launder the violation exactly the way restamping `ingested_hash` launders drift.

## 2026-07-24 — hash-drift lint (ingest commitments enforced)

`ingested_hash` was written but never re-checked: re-extract a source (or hand-edit a sidecar) and every `(source: raw/<file>#<anchor>)` citation keeps resolving to text that no longer supports the claim. `/wiki-lint` check 4 is page age, check 7 is frontmatter fields, and `citation-audit.py` only proves the target exists — nothing compared the body against its commitment. Added `scripts/wiki-lint-hash-drift.sh` (recomputes via `body-hash.sh`, the canonical hasher; names the drifted file, both hash prefixes, and the `ingested_pages` now at risk), its oracle `scripts/verify-hash-drift.sh` (H1–H5), and wired both in: `/wiki-lint` check 8 (fix = re-run `/wiki-ingest`, never restamp the hash — that launders the drift), smoke R22 (H5 gates the repo's real `raw/`), installer manifest. Not-yet-ingested sources (`ingested_hash: ""`) are skipped — that's `/wiki-ingest`'s job, and noise there would train users to ignore the lint. Smoke now 27 checks, all green.

## 2026-07-07 06:20 — /wiki-ingest

- Processed: raw/okf-spec-v0-1.md (hash 7d4121ee)
- Processed: raw/google-cloud-okf-blog.md (hash 8d5556f6)
- Processed: raw/devsplainers-okf-llm-wiki-video-transcript.md (hash d1d2986d)
- Created: wiki/okf-spec-v0-1-summary.md, wiki/google-cloud-okf-blog-summary.md, wiki/devsplainers-okf-llm-wiki-video-transcript-summary.md, wiki/open-knowledge-format.md, wiki/okf-vs-llm-wiki-bootstrap.md
- Updated: wiki/core-idea.md, wiki/division-of-labor.md, wiki/index.md
- Contradictions flagged: none
- Faithfulness gate: 42/43 SUPPORTED; 1 UNSUPPORTED marker on okf-vs-llm-wiki-bootstrap.md:43 (moat→three-layer paraphrase, anchor #6:15 — left for /wiki-lint per contract)
- Note: both OKF web sources are `extraction_status: degraded` (blog partial, spec condensed) — full-page WebFetch blocked by context-gate egress hook this session. Re-extract from a fresh session to upgrade to verbatim.

## 2026-06-22 — vision hardening wave 7 (path-traversal confinement)

Closing wave 6's allowlist exposed a path-traversal hole: `(source: raw/../secret.txt#L1)` passed both `--no-bare-urls` (prefix `raw/`) and C1/C2 (read a file *outside* `raw/`, earned coverage) — defeating the "snapshotted in raw/" invariant. Fixed at both points in `citation-audit.py` (stdlib `os.path`): `_is_allowed_target` normalizes (`normpath`) and requires the target to stay under `raw/` (so `raw/../x`→reject, `raw//x`→ok); C1 confines `realpath(rawpath)` to be inside `realpath(raw_dir)` (escape → c1=False, doesn't resolve). Also reject NUL/control-char citation targets in both `_is_allowed_target` and `audit()` before `realpath` (an embedded NUL raised `ValueError`, crashing the gate) — now flagged + non-resolving, no crash. Follow-up noted: apply the same confine-to-dir everywhere a wiki string becomes a path (bundle/kg/anki).

## 2026-06-22 — vision hardening wave 6 (bare-url guard → allowlist)

Re-audit found Wave 5's `--no-bare-urls` closed the web-cite gap by name, not by class: it matched only `://`-scheme and literal `www.`, so protocol-less / bare-host / uppercase cites (`(source: cnn.com/x)`, `(source: example.com)`, `(source: WWW.x/y)`) bypassed it. Inverted to an **allowlist**: an inline `(source: X)` is legal only if X is `raw/<file>[#anchor]` or exactly `analysis`; everything else is flagged by construction (no URL parsing). The check now also runs in the faithfulness gate's **ingest** mode (was promote-only). Removed the dead regex. This closes the last HIGH gap.

## 2026-06-22 — vision hardening wave 5 (web sources must snapshot to raw/)

Closed V2 gap 3 (web claims invisible to the gate). Promoted web findings can no longer be cited with a bare `(source: <url>)` — the receipts rule now extends to the web: a web source must be snapshotted into `raw/` (via `/wiki-extract`) before citing, so the claim is raw-backed, coverage-counted, and entailment-checkable. New deterministic guard `citation-audit.py --no-bare-urls` (flags `(source: …://…)` / `www.`, leaves `(source: analysis)` and `raw/` alone), wired as smoke **R20** (25 checks) and as a promote-mode floor in the faithfulness gate (bare-url page → exit 3). `/wiki-query` promote prose + AGENTS.md updated; `verify-no-bare-urls.sh` added. The actual fetch stays LLM-driven (CI has no network); the guard is the keyless mechanical enforcement.

## 2026-06-22 — vision hardening waves 2–4 (gate, features, discover, edges)

Re-audit raised the vision from 72%→88%→(targeting ≥99%). Wave 2: faithfulness gate fails CLOSED (exit 3) with no judge (`--allow-unjudged` opt-out + loud warning); `/wiki-query` promote path now invokes the gate before synthesis; flashcards carry a Source column; KG stamps causal edges `sourced:true/false`; diagram contract requires raw-anchored footers. Wave 3: CI gains R18 (bundle round-trip) + R19 (real-wiki coverage gate), R3 scoped to `*.md` + block-HTML patterns (22→24 checks). Wave 4 (closing re-audit residuals): **`wiki-discover.py` now reads the `sourced` flag and marks causal chains resting on uncited edges `⚠ [unsourced]`** (was a real HIGH leak — KG stamped the flag but discover ignored it); flashcard citation is now card-local (closed the sticky-citation laundering bypass); `citation-audit.py` skips fenced code blocks and no longer false-flags empty/frontmatter-only pages; verify-bundle success line + README + SELLING + ci.yml label all corrected to not overclaim.

## 2026-06-22 — vision hardening wave 1 (floor + coverage + bundle)

Adversarial audit of the 6 vision checks (72% achieved) drove fixes. Floor/coverage (`citation-audit.py`): skip frontmatter when matching citations; `page_frontmatter` returns {} on an unclosed fence (no self-exempt); timestamp anchors match on a token boundary (not substring); reject line-ranges inside frontmatter; fail C2 on duplicate-slug ambiguity; **anchorless whole-file cites no longer count toward `--coverage`** (a bare file cite could exempt a page of fabrications); `journal` added to `EXEMPT_TYPES`. Bundle: package-wiki gains **G4 coverage gate**, verify-bundle gains **B5**; both refuse symlinks; verify-bundle hard-fails on missing python3 and runs faithfulness checks over the full tree even under `--post-use`; optional `WIKI_SIGN_KEY` detached signature; buyer-facing wording downgraded from "faithfulness" to "citation integrity" (C3 entailment is a write-time seller attestation, not reproducible offline). New `verify-bundle-roundtrip.sh`.

- **Wiki content:** `karpathy-video-slide-ingest-pipeline-summary.md` re-cited with `#body-verbatim-numbered-0107` (was an anchorless whole-file cite the stricter coverage gate correctly flagged).

## 2026-06-22 — citation-coverage gate (vision check #5)

Added the inverse of the citation-audit floor: instead of "do citations resolve?", **"does every claim-bearing page carry one?"**. `scripts/citation-audit.py --coverage` lists pages with no resolving `(source: raw/...)` citation and exits 1 if any exist (R17 in `smoke-all.sh`, test: `scripts/verify-citation-coverage.sh`). Two exemptions: `type: navigation` (structural pages point inward) and a new optional `provenance: none` frontmatter knob for meta pages that make no external claims.

- **Marked `provenance: none`:** `commands.md`, `glossary.md`, `source-attribution.md`, `synthesis-artifacts.md` — each already self-declares as `source: analysis` design/interpretation, not external claims. (The other 7 `source: analysis` pages cite raw and stay gated.)
- **Schema:** additive/opt-in field documented in AGENTS.md; no version bump (per the bump policy).
- **Why:** codifies the project vision — "a second brain that ships with receipts" — as a deterministic gate, so no feature can quietly add unsourced claims. See README "Vision".

## 2026-06-09 — schema v2 → v3: synthesis layer

Added a **mechanical synthesis layer**. `/wiki-ingest` (Step 8), `/wiki-query` (on promote), and `/wiki-lint --apply` now regenerate four derived artifacts via `scripts/synthesize/all.sh`: `wiki/open-questions-dashboard.md`, `wiki/tensions.md`, `wiki/decision-timeline.md`, and `wiki/knowledge-graph.json`. Generation is deterministic (byte-identical on no change) and does **no LLM work** — it only aggregates markers the LLM already wrote (`## Open questions` sections, `> CONTRADICTION FLAGGED` flags, `log.md` headers, `[[links]]`). The graph JSON reuses `scripts/visualize/graph-html.py --json` (the same parser `/wiki-visualize` uses), so JSON and rendered graph can't diverge.

This **partially and deliberately re-introduces** aggregate-view machinery cut on 2026-06-08 (`a76196f`, "infrastructure ahead of single-user demand") — but only the narrow, deterministic, zero-LLM-cost core, and pushed onto the read/write-completion path rather than as bespoke per-source LLM synthesis. Did **not** restore the causal-KG, factory, or self-updating-brain layers.

- **Added:** `scripts/synthesize/{build.py,all.sh}`, `scripts/verify-synthesize.sh`, `--json` mode on `graph-html.py`, manifest entries, AGENTS.md "Synthesis artifacts" section.
- **Migration note for older clients:** a wiki scaffolded before v3 has no `scripts/synthesize/all.sh`; commands skip Step 8 silently (the four artifacts simply won't exist/update). Re-scaffold with `scripts/create-llm-wiki.sh` to adopt it. No frontmatter or layer-ownership rules changed; the four artifacts are additive `type: navigation` pages + one JSON.

## 2026-06-08 — fix stale verification note in operation-ingest.md

Corrected a stale "honesty note" that claimed the 7-step ingest pipeline was **specified, not demonstrated** and that `/wiki-ingest` had **never been invoked**. Both are false: `scripts/smoke-build.sh` drives `claude -p "/wiki-ingest raw/smoke-source.md"` in a real session and `scripts/smoke-all.sh` runs it in CI on every push (C1 confirms the follow-up query reaches the right answer); `scripts/eval-onboarding.sh` exercises extract→ingest→query independently. Flipped `wiki/operation-ingest.md` lines 40–52 to "demonstrated end-to-end and CI-gated," preserving the honest nuance that the original karpathy-derived meta-wiki pages were hand-bootstrapped (only the smoke-fixture pages were machine-ingested) and the residual per-step granularity unknowns. The `diagrams/ingest-pipeline.*` poster (gitignored, regenerable) carried the same stale line and was corrected locally; it will regenerate correctly from the fixed source.

## 2026-06-08 — cut to core (factory + brain + causal removed)

Trimmed the system to the core that earns its keep over "a folder + Claude": **init / extract / ingest / query / lint** + the **output commands** (visualize / flashcards / diagram) + the blank-wiki **installer** (`create-llm-wiki.sh`). Rationale: value-vs-cost review concluded the scale machinery was infrastructure ahead of single-user demand. Full prior system recoverable at git tag **`archive/full-system-v1`**.

- **Removed — factory:** `/wiki-new` `/wiki-skill` `/wiki-registry` (+ `new`/`wikis` aliases), `scripts/{new-wiki,registry,verify-multi-wiki,verify-skill-install}.sh`, `templates/skill/`. Smoke R5/R10 dropped.
- **Removed — self-updating brain:** `/wiki-learn` (+ `learn`), and this branch's brain/scale guards: `scripts/privacy-scan.sh`, `scripts/hooks/pre-commit`, `scripts/wiki-near-duplicates.py`, their verifiers + fixtures. Smoke R12/R13 dropped; `core.hooksPath` wiring removed from the installer.
- **Removed — causal layer:** `scripts/{wiki-lint-causal.sh,wiki-to-kg.py,wiki-graph-walk.py,verify-causal.sh,eval-causal.sh}`, `templates/causal-vocab.txt`, causal fixtures, `raw/causal-smoke-source.md`, causal step 1.5 in `wiki-query.md` + authoring prose in `wiki-ingest.md` + the "Causal relations" section in `AGENTS.md`. Smoke R11 dropped.
- **Smoke is now 13 checks** (C1–C5 + R1–R8, renumbered contiguous); `jscpd` ceiling tightened 3.25% → 2.5% (post-cut duplication ~1.9%). `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` + README/QUICKSTART/EXPLAIN + `wiki/commands.md`/`glossary.md` updated to core-only.
- **Kept (degrade gracefully):** the typed-relations evals (`eval-multi-hop*`) still reference the removed `wiki-to-kg.py` behind an `[ -f ]` guard, so they run sidecar-less. `presentations/lseg-sales/` (a deck for the removed skill feature) left untouched as a separate artifact.

## 2026-06-01 — conversion pass: prove it runs, show it, one start-here, CI

First-visitor → adoption polish. The decisive change: the README no longer says "Runtime behaviour is untested" — because it now *is* tested. The Claude Code happy path is proven end-to-end (`scripts/eval-onboarding.sh` drives `claude -p` as a fresh newcomer through extract→ingest→query and confirms they reach the right answer). Durable wins: C1 (pipeline reaches the correct answer) reliably green, and C2 (one unambiguous start-here) structurally fixed by the README-FRESH move. The post-change run scored 5/5; C3 (agent write-before-read) and C4 (AGENTS.md probe) have run-to-run variance, so treat 5/5 as a ceiling, not a guarantee.

- **README hero rewrite** — one 10-second pitch, a real demo GIF (`assets/demo.gif`, a genuine `/wiki-query` against the shipped wiki, recorded via asciinema→agg), CI + License badges, and a single copy-paste "first answer in one block." Disclaimers and the meta-wiki keep/wipe decision moved below the fold.
- **Removed the "untested" disclaimer**, replaced with the truth: the happy path is verified by `smoke-all.sh` (14 deterministic checks, in CI) + `eval-onboarding.sh`.
- **One start-here** — moved `README-FRESH.md` → `templates/README-fresh.md`. There is now exactly one README at the repo root; the fresh-wiki template no longer reads as a competing entry point (this is what flipped onboarding check C2). Updated consumers: `create-llm-wiki.sh`, `verify-create-llm-wiki.sh` (R8 still green), `eval-onboarding.sh` judge path, README tree.
- **CI** — new `.github/workflows/ci.yml` runs `scripts/smoke-all.sh --no-build` (new flag: skip the LLM build phase, verify committed artifacts + R1–R9; no API key / no `claude` needed). Badge on README line 1.
- No schema change. Deferred (not done): launch kit, per-tool smoke expansion, `/wiki-verify`, CONTRIBUTING/issue templates, release tag.

## 2026-05-29 — visual answers: /wiki-query --visual (html/pdf/png)

`/wiki-query` can now return a **diagram of its answer** alongside the text, in html / pdf / png, reusing the vendored Infographic-extractor archetype system (no new design system). This ships into generated wikis (it's an operating command), so any produced wiki can answer visually.

- New `scripts/visualize/render.sh <html> --pdf|--png` — HTML poster → PDF/PNG. Detection: system headless browser (Chrome/Chromium/Edge/Brave, PATH or macOS app bundle) → Node+puppeteer (temp project, fetches its own Chromium) → **fail-soft** (keep HTML, print install hint, nonzero). PDF single-page (height fit to content); PNG full-page @2×. Functionally verified end-to-end via the puppeteer path (real 152 KB PDF, 1600×2048 PNG). A `RENDER_DISABLE=1` seam lets the oracle test fail-soft deterministically.
- `.claude/commands/wiki-query.md` — added `--visual [html|pdf|png]` + `--archetype <name>` and **Step 5.5**: score all 8 archetypes against the synthesized answer, **auto-pick** the top (override with `--archetype`), generate a self-contained HTML poster to `diagrams/query-<slug>.html` per the generator-contract, then render to pdf/png via `render.sh`. Text answer is always produced; visual is additive; footer cites wiki pages + any web URLs used.
- `.claude/commands/wiki-diagram.md` — consistency: `--pdf`/`--png` now also run `render.sh`.
- `scripts/installer-skeleton-manifest.txt` — ships `scripts/visualize/render.sh` into generated wikis (installer oracle still green; `templates/infographic/*` + `wiki-diagram` already shipped).
- `scripts/visualize/verify-visualizers.sh` — render.sh existence + deterministic fail-soft check always; functional PDF smoke when a system browser is present (puppeteer not auto-probed — too heavy).
- Docs: AGENTS.md, README.md, README-FRESH.md (ships to generated wikis), docs/VISUALIZATION.md (new render.sh §), docs/QUICKSTART.md, and the 5 cross-tool shims now document `--visual` / `render.sh`.

**Schema version: unchanged (v2).** Additive, opt-in — `--visual` is a new optional flag; no per-wiki schema change.

## 2026-05-29 — multi-wiki factory (/wiki-new, /wiki-registry)

Added a **factory tier**: the repo can now generate *other* domain-shaped wikis and track them in a local catalog. Built **additively** on the proven single-wiki installer — `scripts/create-llm-wiki.sh`, `scripts/installer-skeleton-manifest.txt`, and `scripts/verify-create-llm-wiki.sh` were left byte-for-byte unchanged (the installer oracle still passes).

- New scripts (factory-only; **not** added to the manifest, so generated wikis remain leaves): `scripts/new-wiki.sh` (composes `create-llm-wiki.sh` with workspace placement + registry), `scripts/registry.sh` (owner of `registry.jsonl` — add/mark-seeded/list/prune over JSONL, no `jq`/`python3`), `scripts/verify-multi-wiki.sh` (oracle M1–M5).
- New commands (factory-only): `.claude/commands/wiki-new.md` (+ alias `new.md`), `.claude/commands/wiki-registry.md` (+ alias `wikis.md`).
- **Layout:** workspace default `${LLM_WIKI_WORKSPACE:-~/llm-wikis}`, each wiki its own git repo, `registry.jsonl` at the workspace root; `--target <path>` escape hatch registers an out-of-workspace wiki by absolute path (`in_workspace:false`).
- **Generate-on-demand domains:** no hand-authored domain content ships. `/wiki-new --domain "<desc>"` scaffolds deterministically, then the LLM authors a `## Domain conventions` section + navigation index + 3–5 seed pages. Seed pages are `source: analysis` with an interpretive disclaimer (no fabricated `(source: raw/...)` citations) — enforced by the M4 oracle.
- **Verification:** `verify-multi-wiki.sh` green on M1–M3 (deterministic scaffold+register, enumerate+drift, escape-hatch+refuse-clobber) **plus a committed edge battery E1–E9** (default-workspace resolution, missing `--domain`, relative `--target` absolutization, adversarial-domain JSON-escaping/injection resistance, empty-registry listing, `mark-seeded`/`has` error paths, non-slug rejection, duplicate-name fail-fast). M4–M5 (seeded schema-validity + domain relevance) green on a real `/wiki-new` run, and the oracle correctly reds intentional defects (broken link, unlinked seed, provenance gap). A **4-domain generator battery** (medieval guild economics, kubernetes operators, competitive bouldering, grief counseling) all passed M4–M5, and the **verify-and-fix loop** was demonstrated end to end (inject broken link → red → fix → green). Both `/wiki-new` and `/wiki-registry` command bodies were exercised as real slash-command invocations.

**Schema version: unchanged (v2).** The per-wiki schema is untouched; this is a new tier of factory commands that sits outside the generated wikis. Additive, opt-in — no bump per the AGENTS.md policy.

**Deferred (phase 2):** `snapshot` (freeze a built wiki into a reusable static template), a remote/published registry, and recursive factories (generated wikis that can themselves generate).

## 2026-05-28 — /wiki-diagram (semantic output command)

Added `/wiki-diagram` (+ alias `/diagram`), the **semantic** member of the output tier: it takes a natural-language intent, retrieves relevant wiki pages (reusing `/wiki-query` discipline), scores all 8 diagram archetypes, presents a candidate menu, and on the user's pick generates a self-contained HTML poster to `diagrams/`. Distinct from `/wiki-visualize` (mechanical render of existing structure). Wiki-read-only; no web search/promotion by default.

- New: `.claude/commands/wiki-diagram.md` + alias `diagram.md`.
- Vendored (self-containment, no external skill dep): `templates/infographic/{archetypes.md, scoring-rubric.md, generator-contract.md, example-poster.html}` — from FrancyJGLisboa/Infographic-extractor. **License pending upstream** (add MIT/Apache to that repo).
- `.gitignore`: added `diagrams/`, `wiki-graph.html`, `anki.csv` (generated artifacts; also closes the prior litter gap from the visualize/flashcards tier).
- Manifest: 6 new files added to `scripts/installer-skeleton-manifest.txt` (verifier I4a).
- Docs: output-tier tables in AGENTS, README, README-FRESH, CLAUDE, GEMINI, copilot, clinerules, cursor, wiki/commands, QUICKSTART now list three commands, with the mechanical-vs-semantic boundary stated.

**Schema version: unchanged (v2)** — additive, opt-in. **Untested:** the command's prompt-body (retrieval + 8-lens scoring + HTML generation) is unrun; first real `/wiki-diagram` invocation is its smoke test.

## 2026-05-28 — output-command tier (/wiki-visualize, /wiki-flashcards)

Added two **output commands** that render/export an already-built wiki, sitting outside the five-command lifecycle loop. Both are read-only on `raw/` and `wiki/` (they write only new output artifacts) and are thin LLM dispatchers over existing scripts — no parsing logic reimplemented.

- New: `.claude/commands/wiki-visualize.md` + alias `visualize.md` — dispatch to `scripts/visualize/{graph,mermaid,slides,serve}.sh`.
- New: `.claude/commands/wiki-flashcards.md` + alias `flashcards.md` — wrap `scripts/wiki-to-anki.sh`.
- Manifest: added the 4 command files to `scripts/installer-skeleton-manifest.txt` so fresh installs ship them (verifier I4a).
- Docs: AGENTS.md, README.md, README-FRESH.md, CLAUDE.md, wiki/commands.md (+ cross-tool shims) now document the output tier alongside the five; resolved the dormant `/wiki-export` open question in wiki/commands.md.

**Schema version: unchanged (v2).** Per the AGENTS.md bump policy, new commands are a strictly opt-in addition (older clients simply lack them) — additive, not breaking, so no bump. Recorded here per the schema-versioning "record the change" guidance.

## 2026-05-27 17:45 — phase-2 kg-traversal

**verdict: phase-2b-abandoned-on-gate.** baseline 7/7 (100%, >> 40% threshold). C5 gate FAILED.

Implemented `.scratch/phase-2-kg-traversal/GOAL.md` Phase-2a only. New artifacts:

- `tests/eval/sparse-fixture/` — 7 hand-crafted pages of fictional supply-chain entities (zerlon, quirpal, bryntex, mordax, velnar, thalox, glivex). Each page body ≤ 100 words, no body sentence states direction or position. 8 typed `## Related` lines using 7 distinct verbs (feeds, powers, produces, ships-via, terminates-at, succeeds, replaces).
- `tests/eval/sparse-multi-hop-questions.md` — 7 multi-hop questions, all tagged `baseline-absent: true`, all `hops: 2` or `hops: 3`. Expects-tokens (`upstream`/`downstream`/`transitive`/`parallel`/`unreachable`) are NOT verb literals and are absent from the unstripped fixture prose (C4(d) + C4(e) both green).
- `scripts/eval-multi-hop-sparse.sh` — thin variant of `eval-multi-hop.sh` pointed at the sparse fixture. Stays sidecar-less in Phase 2a; would conditionally invoke `scripts/wiki-to-kg.py` in the typed work dir (only) if Phase 2b were active.

Gate result (`./scripts/eval-multi-hop-sparse.sh`):

- baseline: 7/7
- typed: 7/7
- delta: 0
- verdict: null-result on the eval itself; gate verdict: FAILED (baseline >> 40%)

**Reading.** The LLM extracts enough signal to answer the direction questions from sources the verb-strip does not touch:

1. **Connectivity survives stripping.** Stripped `## Related` lines keep slug-pair links — the baseline LLM still sees that zerlon connects to mordax, mordax connects to velnar, etc. Direction has to come from somewhere else, but only some-where else is needed.
2. **Page semantics leak through tags.** `tags: [sparse-fixture, alloy]` on zerlon, `tags: [..., vessel]` on mordax, `tags: [..., port]` on velnar are intact in both variants. The LLM uses tag semantics + world knowledge ("ore feeds refinery feeds alloy ships to port") to recover direction even without verbs.
3. **The question text is a teacher.** Every question names the verbs explicitly (`"Following only the forward supply edges (feeds, powers, produces, ships-via, terminates-at)"`). Even when those verbs are stripped from the markdown, the LLM reads the verb list in the prompt and applies it to the connections it sees.

Conclusion: **typed relations do not provide measurable retrieval signal even on a fixture engineered to need them.** The signal the typed graph carries is already encoded — redundantly — in connectivity + tags + question framing. A parallel KG layer would record what the LLM already infers. Not justified.

Decision per §7: **Phase 2b abandoned.** No `scripts/wiki-to-kg.py` written, no modifications to `.claude/commands/wiki-ingest.md` or `.claude/commands/wiki-query.md`, no `wiki/_kg.jsonl` artifact. C10 absence guards intentionally green.

**Future avenues (not pursued here, recorded for phase-3 design):**

- Strip tags AND verbs in the baseline (not just verbs) — would test whether tag semantics alone explain the result.
- Make question text neutral (do not name the verbs in the prompt) — would test whether the prompt is the teacher.
- Use questions whose answers require numerically combining attrs across hops (attrs get stripped; the LLM cannot reconstruct them from tags or world knowledge).
- Revisit the parallel-KG idea only after one of the above produces a measurably stricter discriminator.

The user-research signal recorded today — "users expect `/wiki-ingest` to create a KG" — is not addressed by this work and should not motivate building a KG on a null result. It is a phase-3 design input.

C1 regression-oracle: `./scripts/smoke-all.sh` exit 0; `./scripts/eval-multi-hop.sh` on the rich-prose Brazilian-ag fixture verdict `null-result` (no regression vs. phase-1's 5/5 = 5/5).

## 2026-05-27 14:00 — phase-1 typed-relations eval

**verdict: null-result** (baseline 5/5, typed 5/5, delta 0).

Implemented `.scratch/typed-wikilinks-semantic-viz/GOAL.md` (annotated `## Related` lines with optional verb + attr; pure CommonMark; backward-compat preserved by treating untyped and multi-link lines as implicit `related-to`). New `scripts/wiki-lint-typed-relations.sh` validates the verb regex (`[a-z][a-z0-9-]*`). `scripts/visualize/graph-html.py` extended: per-edge `verb` field in the JSON, a `<select id="verb-filter">` UI + `filterByVerb()` JS handler + per-verb edge colouring via `d3.schemeCategory10`.

Fixture: 6-page Brazilian-agriculture wiki built during the 2026-05-27 new-user simulation, frozen at `tests/eval/wiki-fixture/`. Typed verbs applied to 14/19 single-target Related lines (74%); 6 distinct verbs (`researches-for`, `defined-by`, `credit-for`, `complement-of`, `enables`, `summarized-in`). Verb tokens were chosen to be absent from the baseline prose (0 hits each) so stripping them removes a real signal.

Eval (`scripts/eval-multi-hop.sh`, 5 multi-hop questions, 3 tagged `baseline-absent: true`):

- baseline: 5/5
- typed: 5/5
- delta: 0

**Reading:** typed verbs alone did not improve `/wiki-query` accuracy on this fixture. The LLM is smart enough to infer the typed relationship from surrounding prose context even when the verb token is stripped — on Q1-Q3 (the `baseline-absent` set), the baseline LLM still produced the exact kebab-case verb (`enables`, `credit-for`, `complement-of`) via paraphrase + format-mimicry of the question. On a Wikipedia-derived wiki with rich prose, the marginal information added by typed verbs is dominated by what the prose already encodes implicitly.

**Implications for phase-2 (parallel knowledge graph):**

1. Typed-verb-in-markdown is not enough on its own; the eval signal is masked by LLM inference from prose.
2. Either the eval needs sparser-prose fixtures (so typed verbs are the only path to the answer), or phase 2 must add **explicit graph traversal** to `/wiki-query` (the LLM gets the typed-relation graph as a separate retrieved structure, not just inline markdown).
3. The null-result is itself the answer to the original "do we need a parallel KG?" question: on rich-prose wikis, typed verbs are redundant; on sparse-prose wikis or for multi-hop queries beyond the LLM's inference horizon, they may help — but only when paired with traversal logic, not just syntax.

All 9 success checks (C1–C9) green; installer regression (`verify-create-llm-wiki.sh`) and core smoke (`smoke-all.sh`) both still exit 0. `scripts/installer-skeleton-manifest.txt` extended by 13 lines so the new lint, eval harness, fixture, and canary tests ship in fresh installs.

## 2026-05-26 10:56 — visualization toolchain landed

Three-iteration build (per `.scratch/visualization-tools/GOAL.md`) shipping `scripts/visualize/` — a bespoke Python+D3 graph generator (stdlib only, no npm), plus `npx`-wrapped slides (`marp-cli`), mermaid (`mermaid-cli`), and a `python3 -m http.server` wrapper. Includes `tests/canary/graph-fixture/` (4 nodes/4 edges, flat) and `tests/canary/graph-fixture-nested/` (2 nodes/1 edge with `sub/leaf.md` — anti-gaming against non-recursive parsers). Oracle at `scripts/visualize/verify-visualizers.sh` runs 5 sub-checks; skip-when-absent semantics for the npx tools. Documented in `docs/VISUALIZATION.md`; recommended heavier alternatives (Quartz, mdBook, SilverBullet) noted but not bundled. `scripts/installer-skeleton-manifest.txt` extended (44 lines) so visualizers ship in fresh installs. First end-to-end run: all 5 smokes green on a machine with both marp-cli and mermaid-cli reachable via npx. No schema change.

## 2026-05-26 09:17 — installer toolchain landed

Per `.scratch/installer-fresh-skeleton/GOAL.md`. New: `scripts/create-llm-wiki.sh` (manifest-driven scaffolder generating a fresh repo at `<target-dir>`), `scripts/verify-create-llm-wiki.sh` (oracle: I3 manifest iteration + I4 tree-shape + content tripwire + frontmatter parse + I5 target preflight + I4(d) template substitution), `scripts/installer-skeleton-manifest.txt` (single source of truth, 31 lines initially, later extended), `README-FRESH.md` and `wiki/index-FRESH.md` (fresh-skeleton templates), `tests/installer-output/.gitignore`. Removes the `wipe-meta-wiki.sh` step from the new-user flow. Post-adversarial-pass revisions to the spec: I4 reformulated from negative-spot-list (gameable by wholesale cp -R) to positive-shape + content-tripwire + frontmatter-parse triple; I4(d) added to byte-match installed README.md/wiki/index.md against FRESH templates. No schema change.

## 2026-05-26 08:00 — smoke infrastructure landed

Per `.scratch/plug-and-play-curator-smoke/GOAL.md`. New: `scripts/smoke-build.sh` (LLM-driven, idempotent via `body-hash.sh`), `scripts/smoke-check.sh` (pure-shell asserts C1–C5), `scripts/smoke-all.sh` (umbrella: build + check + 4 regression guards), `scripts/r3-obsidian-patterns.txt` (patterns file for the no-Obsidian-syntax guard, avoids backtick quoting hazards in shell), `tests/smoke/smoke-source.md` (fictitious Phase Coherence Engineering fixture with Quortex protocol / Dr. Alma Voss / 47 phase rotations anchors), `tests/smoke/expected-query.md`, `tests/smoke/.gitignore`. Adversarial-pass introduced C5 (`ingested_hash` populated cryptographic proof) — without it, an agent could hand-author log.md + last-answer.md to satisfy 6 of 8 checks without running `claude -p`. First smoke run produced the 06:52 `/wiki-ingest` entry below — the empirical demonstration that the 7-step pipeline executes correctly. No schema change.

## 2026-05-26 06:52 — /wiki-ingest

- Processed: raw/smoke-source.md (hash ba2159c8)
- Created: wiki/smoke-source-summary.md, wiki/quortex-protocol.md, wiki/dr-alma-voss.md, wiki/phase-coherence-engineering.md
- Updated: wiki/index.md
- Contradictions flagged: none (smoke fixture's domain is disjoint from the existing meta-wiki about the LLM-wiki pattern; nothing to disagree with)

`wiki/quortex-protocol.md` carries the literal "Quortex" and "47 phase rotations" anchors required by smoke check C2.

## 2026-05-26 05:30 — schema bump 1 → 2

Three additions to the schema landed together. Each is opt-in on its own, but the journal exception introduces a new rule on `/wiki-ingest` behavior — by the bump policy in AGENTS.md, that's a behavior-changing edit and requires a version bump even though no v1 client would currently violate it in default repos.

- **Journal exception (`wiki/journal/`)**: new user-owned directory. Files there are not rewritten by `/wiki-ingest`. New `type: journal` value added to the page-type enum. Template at `templates/journal-entry.md`. The directory is reserved by an empty `.gitkeep`; entries are created by the user, not the LLM.
- **`## Flashcards` content convention**: any wiki page may declare Q/A pairs in a `## Flashcards` section. Exporter at `scripts/wiki-to-anki.sh` emits an Anki-importable CSV with the page slug as the card tag. Canary fixture at `tests/canary/canary-flashcards.md`; smoke test via `scripts/verify-wiki-to-anki.sh`.
- **Optional MCP read surface**: `scripts/mcp-server.sh` launches `@bitbonsai/mcpvault` pointed at `wiki/`, exposing read/search/write tools to any MCP-aware client. Setup details in `docs/MCP.md`. Pure addition; does not change the three-layer model or the slash commands. `scripts/preflight.sh` now reports whether `npx` is available.

**Migration note for v1 clients.** A v1 client that scans `wiki/**/*.md` without journal awareness will see entries under `wiki/journal/` as ordinary `wiki/` files. If such a client runs `/wiki-ingest` autonomously and decides a journal entry needs rewriting (e.g., as part of step 4 "update existing pages"), it could clobber user-authored content. Mitigations until clients upgrade: (a) ingest sources from `raw/`, not from journal entries, (b) if running v1 ingest on a repo that has journal entries, snapshot `wiki/journal/` first, (c) `/wiki-lint` is unaffected — link-checking still works against journal entries.

## 2026-05-25 17:15 — backfill extraction_method on legacy raws

Gap surfaced during PR #3's smoke-test batch: the two raw files shipped before PR #1 (`karpathy-llm-wiki-video-transcript.md` and `karpathy-video-slide-ingest-pipeline.png.md`) predate the `extraction_method` frontmatter field, so running `verify-extract.sh` on them fails the "extraction_method required" check. This is a one-time human-authorized migration to bring the legacy raws up to schema_version 1.

- **`raw/karpathy-llm-wiki-video-transcript.md`**: added `extraction_method: passthrough`. The transcript was pasted into the conversation that bootstrapped the project (per its own `notes:` field) — passthrough is the closest match in the enum (raw text imported as-is, no parser).
- **`raw/karpathy-video-slide-ingest-pipeline.png.md`**: added `extraction_method: llm-vision`. The slide is a binary PNG; its sidecar was produced by vision extraction (per the 2026-05-25 08:30 entry below).
- Both edits are in the YAML frontmatter only; **body content unchanged**. Body hashes were recomputed via `scripts/body-hash.sh` and verified identical to the recorded `ingested_hash` — idempotence preserved, `/wiki-ingest` will still skip both files.

**Hard-rule note:** modifying files in `raw/` normally violates the LLM's read-only rule on that layer. This migration is treated as a one-time maintainer-authorized edit (not an autonomous LLM act). Future cases where the LLM's `/wiki-extract` writes `extraction_method` on a *new* raw file are fine and unrelated.

**Follow-up gap surfaced during this commit:** the verifier's `ingested_hash` check warns "/wiki-extract should leave this empty" — accurate for fresh extract output, but noisy on files already processed by `/wiki-ingest` (the normal post-ingest state). Not fixed here to keep this PR's scope minimal. Tracked for next iteration.

## 2026-05-25 17:00 — verify-extract.sh: surface extraction_status visually

Gap surfaced during the prior session's smoke-test batch: the DOCX-degraded run produced a sidecar with `extraction_status: failed`, but the verifier reported "Passed. Shape checks all green." with no visual indication that extraction actually failed. Shape was fine — but the user reading the verifier output wouldn't know they need to install pandoc.

- `scripts/verify-extract.sh`: new check block after `ingested_hash`. When `extraction_status` is present in the frontmatter, emit `✓` for `ok`, `⚠` for `degraded` / `failed`, `⚠` (with "unknown value" message) for anything else. Exit code unchanged on degraded/failed (shape is still fine — the warn is the signal).
- Docstring updated to document the new behavior in the "Scope" section.

Tested on 4 synthetic frontmatter values: `failed` → ⚠, `ok` → ✓, `degraded` → ⚠, `bogus` → ⚠ (unknown). Exit code 0 in all cases.

## 2026-05-25 16:50 — tests/canary/canary-csv.csv: tracked CSV fixture

Smoke-tested the CSV path of `/wiki-extract` end-to-end this session. The fixture used (5-row world-cities CSV) was a one-shot file in working tree; promoting it to a tracked fixture so the smoke test is reproducible.

- `tests/canary/canary-csv.csv` — 5 data rows + header. Plain ASCII. Designed to exercise the ≤100-row markdown-table render branch.
- Sibling to `tests/canary/canary-smoke-test.md` (plain-text fixture from PR #3). Same purpose: known-good input for the verifier.

The smoke test flow (per `docs/QUICKSTART.md`):

```
/wiki-extract tests/canary/canary-csv.csv   # in AI tool
./scripts/verify-extract.sh canary-csv      # in shell
```

Expected: `raw/canary-csv.csv` (copy) + `raw/canary-csv.csv.md` (sidecar with `extraction_method: csv-passthrough` and a markdown table of the 5 cities). Verifier green.

## 2026-05-25 15:30 — canary + verify-extract.sh: smoke test for first /wiki-extract

"Specified, not demonstrated" was the honest status of `/wiki-extract` after PR #1. This commit ships the smallest possible **shape** test: a known-good canary source + a shell verifier. The user runs `/wiki-extract` on the canary in their AI tool, then runs the verifier in shell to get a green/red signal on whether the produced output has the expected frontmatter and body. **Shape only — not semantics.**

- **New `tests/canary/canary-smoke-test.md`**: tiny plain-markdown source (~30 lines) used as the known-good input. Self-describing — explains what should happen and what shouldn't.
- **New `scripts/verify-extract.sh <slug>`**: pure bash verifier. Locates the produced `raw/<slug>.<ext>` or sidecar `<slug>.<ext>.md`, parses the frontmatter, checks that required fields (`source_url`, `source_type`, `fetched_at`, `extraction_method`) are non-empty, that `ingested_hash` is present-but-empty, and that body content exists. TTY-aware coloring, exit 0 on pass / 1 on fail / 2 on usage error.
- **Honest scope:** shape only. Verifier can catch: missing output file, malformed frontmatter, absent/empty required field, empty body. Verifier CANNOT catch: wrong `source_type` value, hallucinated `source_title`, `extraction_method` recorded incorrectly. Semantics need a human eye on `raw/<slug>.*`.
- **docs/QUICKSTART.md**: new "Smoke test (recommended)" section between "Before you start" and "The 5 operations" walking the user through the canary flow.
- **README.md**: project-layout tree updated with the new script and the `tests/canary/` directory.

Also in this commit: drift cleanup. The QUICKSTART operations table (separate from the per-tool sequences below it) still used the old verb names `fetch` and `ask` — leftover from PR #1's sed which only touched `wiki-fetch`/`wiki-ask` literals. Updated to `extract`/`query` to match the rest of the doc.

Verified on the working tree (without touching tracked files): 4 cases — no raw file → exit 1 with "Not ready" message; happy-path raw → exit 0 with all green; missing `extraction_method` → exit 1 with one fail line; malformed frontmatter (no closing `---`) → exit 1 with multiple failures. Cleanup confirmed `raw/` returned to its 3 tracked files.

## 2026-05-25 15:15 — scripts/wipe-meta-wiki.sh: clean-slate helper

Today's "start fresh" flow was three commands in QUICKSTART (`rm -rf wiki/*.md raw/* && touch wiki/index.md`) — easy to typo and easy to skip the index touch, leaving the next `/wiki-extract` confused. Added a single-command helper.

- **New `scripts/wipe-meta-wiki.sh`**: pure bash, mirrors `body-hash.sh`/`preflight.sh` style. Wipes `wiki/*.md` and `raw/*`, recreates `wiki/index.md` as a minimal stub with valid frontmatter, resets `log.md` to its header line.
- **Safety:** interactive `[y/N]` confirmation by default; `--yes` flag to skip. Inventories file counts before wiping so the user sees what's about to disappear.
- **Idempotent:** re-running on an empty wiki shows "nothing to do" and exits 0. (Actually re-wipes the stub index and rewrites it; functionally idempotent.)
- **Preserves:** AGENTS.md, README.md, all shims, `.claude/commands/`, `scripts/`, `docs/`, LICENSE — everything that isn't generated content.
- **README.md + AGENTS.md + docs/QUICKSTART.md:** replaced the three hand-rolled `rm -rf` instructions with the new script. Project-layout tree in README updated.

Verified on a `/tmp/` copy: before (23 wiki files, 3 raw files) → after wipe (only index.md stub remains; raw/ empty; log.md reset). Idempotence checked — second run with `--yes` produced same end state.

## 2026-05-25 15:00 — AGENTS.md: schema_version = 1 declared

Started declaring a schema version on `AGENTS.md` so future schema changes have a coordination marker. Today's `AGENTS.md` (as merged in PR #1, before this change) is retroactively designated as the version-1 baseline. Future bumps are reserved for breaking/behavior-changing edits.

- `AGENTS.md`: added `**Schema version:** 1 (introduced 2026-05-25)` line near the top. Added a "Schema versioning" section before "When in doubt" describing the bump policy (breaking-change bumps only; additive opt-in changes don't bump; no runtime enforcement V1).
- No code changes. Slash commands today don't read this field. It's a marker for humans reviewing diffs and for future tooling.

Migration impact: none. Existing slash commands continue to work unchanged.

## 2026-05-25 14:30 — scripts/preflight.sh: fail-fast tool & permissions check

User-side install today is `git clone && cd` — no health check. Failures of `/wiki-extract` only surface at first invocation, sometimes silently (e.g., missing `pandoc` falls back to `python-docx`, which the user may not have either). Added a preflight script that probes the environment before the user runs any slash command.

- **New `scripts/preflight.sh`**: pure bash (mirrors the style of `body-hash.sh`), TTY-aware coloring, platform-aware install hints (`brew` on Darwin, `apt`/`dnf`/`pacman` on Linux).
- **Three check tiers:**
  - Hard requirements (`bash`/`awk`/`openssl`/`git` + write permissions on `raw/` and `wiki/`) — fail fast with exit 1 if missing.
  - Recommended optional tools (`pdftotext`/`pandoc`/`xlsx2csv` + `python-docx`/`openpyxl` fallbacks) — warn only.
  - AI runtimes (`claude`/`cursor`/`code`/`copilot`/`gemini`) — informational.
- **Summary line** classifies extraction coverage: "Ready. Full first-try: ... Partial: ... Degraded: ...". Maps directly to the `extraction_method` matrix in `AGENTS.md`.
- **Manual-run only.** No auto-execution, no post-install hook, no agent-side invocation. The user runs it when they want a snapshot.
- **README.md**: new optional-but-recommended line under Install pointing at the script; project-layout tree updated.
- **AGENTS.md**: one-line mention near the `body-hash.sh` reference so the agent knows the script exists and can suggest it when users hit `extraction_status: failed`.
- **Verification:** ran on this host (macOS, partial tool coverage). All hard reqs green, summary correctly classifies PDF as full / XLSX as partial / DOCX as degraded. Piped output drops ANSI codes correctly. Exit code 0 when hard reqs met.

This PR stacks on PR #1 (`feat/extract-rename`) because the preflight references the renamed `/wiki-extract` and the new `extraction_method` matrix in `AGENTS.md`. Merge PR #1 first.

## 2026-05-25 10:45 — /wiki-extract gains DOCX / XLSX / CSV handlers + PDF LLM-vision fallback

Real new behavior in the (just-renamed) `/wiki-extract` command. Previous coverage was URL, plain text, image, and PDF-via-`pdftotext`. New coverage adds DOCX (via `pandoc`), XLSX (via `xlsx2csv`), CSV (passthrough + markdown-table preview), and an LLM-vision fallback path for PDF when `pdftotext` is missing or returns near-empty output.

- **`.claude/commands/wiki-extract.md`**: step 1 (format detection) and step 3 (acquisition) extended with the new formats. Step 4 (frontmatter spec) gains `extraction_method` and `extraction_status` fields. Tool-availability check (`command -v`) is now mandatory before invoking any optional binary.
- **`AGENTS.md`**: new "Supported source formats and extraction" subsection with the format → handler matrix. File-naming rule updated to cover DOCX/XLSX (binaries → sidecar) and CSV (tabular text → sidecar). Frontmatter YAML block updated with the two new fields and the new `source_type` values.
- **`wiki/commands.md`**: `/wiki-extract` spec rewritten to mirror the new behavior table; tool-policy paragraph added.
- **`wiki/open-questions.md`**: new top entry under "Operational questions" — "Are the new extraction handlers actually correct?" — listing concrete unknowns per format. Same posture as the existing "do the 7 steps actually happen?" entry.
- **`README.md`**, **`docs/EXPLAIN.md`**: one-line updates to the `/wiki-extract` row to mention multi-format support.
- **`docs/QUICKSTART.md`**: no content update needed (the rename sed already swept it; existing examples still work).

**Verification status:** all four new handlers (DOCX/XLSX/CSV/PDF-LLM-vision) are **specified, not demonstrated**. First real `/wiki-extract` on each format is the smoke test. Same as the 7-step pipeline.

**Principle preservation:** every shell binary is optional with a declared fallback (`pandoc`→`python-docx`, `xlsx2csv`→`openpyxl`, `pdftotext`→`llm-vision`). A user with zero shell tools installed gets degraded but functional extraction. BYO-AI guarantee intact.

## 2026-05-25 10:30 — verb rename: fetch→extract, ask→query

User-facing mental model survey: new users naturally describe the workflow as "extract content from this file" and "query the wiki," not "fetch" and "ask." Renamed the two slash commands and updated all references across the repo. Pure mechanical rename — no behavior change.

- **Renamed:** `.claude/commands/wiki-fetch.md` → `wiki-extract.md`
- **Renamed:** `.claude/commands/wiki-ask.md` → `wiki-query.md`
- **References updated in 22 other files** via `sed`: AGENTS.md, CLAUDE.md, GEMINI.md, .clinerules, .cursor/rules/llm-wiki.mdc, .github/copilot-instructions.md, README.md, docs/QUICKSTART.md, docs/EXPLAIN.md, docs/pitch-vscode.html, .claude/commands/wiki-init.md, .claude/commands/wiki-lint.md, wiki/commands.md, wiki/division-of-labor.md, wiki/glossary.md, wiki/index.md, wiki/ingest-pipeline.md, wiki/karpathy-llm-wiki-video-transcript-summary.md, wiki/layer-raw-sources.md, wiki/operation-query.md, wiki/query-as-write-loop.md, wiki/source-attribution.md, wiki/three-layer-architecture.md.
- **Strategy:** hard rename. Repo is V2 and runtime-untested with no external users — aliases would be permanent bloat.
- **Gate verified:** `grep -rEn 'wiki-(fetch|ask)\b' . --exclude-dir=.git` returns only historical references inside this log.md (the 2026-05-25 06:45 bootstrap entry, which records the original file names at creation time).
- **What did NOT change:** the 7-step ingest pipeline, the body-hash algorithm, the three-layer model, frontmatter conventions, or the command bodies' behavior. Two prompts now carry their new names internally (`/wiki-extract $ARGUMENTS` and `/wiki-query $ARGUMENTS`); everything else is identical.

Follow-up commits on this branch (`feat/extract-rename`) will (a) expand `/wiki-extract` to handle DOCX, XLSX, CSV with graceful tool-chain fallback, and (b) refresh docs prose where the rename diff isn't sufficient.

## 2026-05-25 09:35 — docs/QUICKSTART.md: per-tool first-use sequences

User asked: "will users get a fluid experience?" Honest answer was no, for most. Highest-leverage fix identified: a per-tool first-use guide. Built it.

- New `docs/QUICKSTART.md`, English, ~260 lines.
- Structure: prereqs (incl. what to do with the shipped meta-wiki — keep / wipe / archive) → 5-operation mental model → per-tool sequences for Claude Code, Copilot CLI, VSCode + Copilot Agent Mode, Cline, Cursor, "other tools" → expected output (with symptom→cause→fix table for partial pipeline execution) → recovery via git → cost expectations → honest caveat about untested runtime → quick reference card.
- Each per-tool section gives the **exact natural-language phrasing** to invoke each workflow, since non-Claude-Code tools don't have slash commands. This was friction #1 from the earlier honest assessment.
- "What success looks like" section addresses friction #3 (no expected-output gabarito) by listing concrete observable outcomes (1 summary page, 3-10 wiki pages, log.md entry, index updated).
- README.md gains a callout to QUICKSTART right after the install command, plus the file is listed in the project layout.

Still NOT addressed by this commit:
- The `/wiki-init --replace-content` affordance for wiping the meta-wiki cleanly (friction #2). For now QUICKSTART tells the user the manual command.
- Recovery beyond `git checkout` (no `--dry-run`, no rollback command). Documented as a caveat, not solved.
- The actual runtime untested-ness (friction #4 + #5). Cannot be solved without someone running the system.

## 2026-05-25 09:15 — fix: pitch HTML had outdated Copilot claim

User correction: I claimed "Copilot é conversacional, não agentic" in the AI-extension tier table. Wrong — (a) GitHub Copilot CLI is a standalone agentic CLI competing with Claude Code, (b) VSCode + Copilot in Agent Mode (shipped 2025) does multi-step autonomous work.

- Rewrote the AI-extension tier table in `docs/pitch-vscode.html`. New top tier (★★★★★) groups Copilot Agent Mode, Copilot CLI, and Cline as peers. Continue/Roo/Cody one step below. Copilot Chat classic (without Agent Mode) demoted to ★★★. "No AI extension" stays bottom.
- Added project memory `ai-tool-capability-claims` to enforce: don't make blanket capability claims about AI tools from training data; verify first. Indexed in `MEMORY.md`.
- README.md needed no change (it already listed Copilot CLI as a peer tool — I just contradicted myself in the pitch).

## 2026-05-25 09:00 — pitch artifact: docs/pitch-vscode.html

User asked how I'd present the project to a VSCode-only audience. Wrote the pitch in chat, then user asked if it was persisted as HTML. It wasn't. Created `docs/pitch-vscode.html` — self-contained single-file pitch in PT (audience = self / internal reference, per follow-up clarification).

- Single file, zero external dependencies (no CDN, no JS, no remote fonts).
- Dark/light theme via `prefers-color-scheme`.
- Print-friendly (`Cmd/Ctrl+P` → PDF).
- Content: hook, 30s premise, 5-step flow, AI-extension tier matrix (Cline > Continue/Roo/Cody > Copilot Chat > nothing), 4 concrete problems, honest caveats, 3 implicit principles, closing slide.
- README.md updated to list `docs/` in the project layout.

This is documentation, not part of the wiki layer — it lives in `docs/` because it's a one-shot artifact for external presentation, not a knowledge page that grows via ingest/lint. No frontmatter, no link convention. Pure HTML by user choice.

## 2026-05-25 08:45 — codified verification-gap honesty

User asked the sharp epistemic question: do the 7 steps actually happen, or are they just specified? Direct answer: the latter — no LLM has invoked `/wiki-ingest` in this project; the wiki was hand-written in the design conversation. To make this surface in the wiki itself rather than only in chat:

- Added "Verification status (as of 2026-05-25)" subsection to `wiki/operation-ingest.md`, naming what is and isn't tested.
- Added a new section at the top of `wiki/open-questions.md` under Operational questions, titled "The most important open question: do the 7 steps actually happen?".

No body content was changed in any other page; the existing 7-step descriptions stand as specifications. The wiki is now honest about which of its claims are demonstrated and which are aspirational.

## 2026-05-25 08:30 — second raw source (slide) + project-wide rename CHANGELOG.md → log.md

User shared the "What happens when you ingest a source" slide from the same video as a screenshot. The slide is **more prescriptive** than the spoken transcript in two places: it names the index file as `index.md` and the log file as `log.md`, and it adds that step 6's index entry is "a catalog entry with link and one-line summary."

- **New raw source:** `raw/karpathy-video-slide-ingest-pipeline.png` (binary) + `raw/karpathy-video-slide-ingest-pipeline.png.md` (sidecar with vision-extracted text + visual description). Hash `cfe8e91a`. Dogfoods the image-acquisition convention (binary + sidecar) for the first time.
- **Project-wide rename:** `CHANGELOG.md` → `log.md` to honor the source video. Touched 18 files: AGENTS.md, README.md, CLAUDE.md, GEMINI.md, .clinerules, .cursor/rules/llm-wiki.mdc, .github/copilot-instructions.md, all 5 .claude/commands/wiki-*.md, and 6 wiki/*.md pages. The rename is recorded in `wiki/source-attribution.md` as a video-aligned decision (previously a project deviation).
- **Refined `wiki/ingest-pipeline.md`** steps 6 and 7 to match the slide's exact wording: step 6 now says "catalog entry with link **and one-line summary**"; step 7 explicitly names `log.md`. Both steps now carry a second source citation pointing at the slide.
- **Created `wiki/karpathy-video-slide-ingest-pipeline-summary.md`** (`type: summary`, `source: video`) — per-source recap of the slide per the `ingest-pipeline`'s step 3 convention.
- **Created `wiki/karpathy-llm-wiki-video-transcript-summary.md`** (`type: summary`, `source: video`) — the missing summary page for the original transcript. Backfills a convention violation from the initial bootstrap (no summary page existed for the first source).
- **Updated `wiki/index.md`** with a new "Source summaries" section listing both summary pages.
- **Updated `wiki/source-attribution.md`** to add the slide as a second source and to record the `CHANGELOG.md → log.md` rename as video-aligned.
- **Updated raw frontmatter** on both sources: transcript's `ingested_pages` adds the new summary; slide sidecar's `ingested_hash`/`ingested_at`/`ingested_pages` populated.

Net: 2 raw sources, 23 wiki pages. Body hash of transcript unchanged (`3054546f`) — still skippable on next `/wiki-ingest`. Slide sidecar now has its `ingested_hash` populated.

## 2026-05-25 08:05 — follow-up: extracted "knowledge compounds" as a first-class page

User observation: the compounding-of-knowledge point (LLM doesn't restart from scratch per question; cross-refs pre-built) is one of the most important arguments in the video, but it was scattered across `core-idea`, `problem-with-naive-rag`, `operation-ingest`, and `query-as-write-loop` rather than living in a dedicated page.

- Created `wiki/knowledge-compounds.md` (`source: mixed`) — synthesizes the compounding thread from three angles (negative-RAG case, positive-wiki case, the per-source compounding effect) and names the two engines (ingest + query-as-write-loop). Citations to transcript timestamps 1:12-1:30, 1:36-1:55, 5:30-5:40.
- Updated `Related` sections in: `core-idea.md`, `problem-with-naive-rag.md`, `operation-ingest.md`, `query-as-write-loop.md`, `ingest-pipeline.md`, `division-of-labor.md`, `four-principles.md` — all now link to `knowledge-compounds`.
- Updated `wiki/index.md` under Foundations + the literal-reading-order list.
- Updated `raw/karpathy-llm-wiki-video-transcript.md` `ingested_pages` to include the new page. Body hash unchanged (`3054546f`), so future `/wiki-ingest` runs still skip the source.

This is the kind of follow-up `/wiki-lint` would surface as a "gap" — a heavily-referenced concept without its own page. The next time `/wiki-lint` runs, it should report zero such gaps for "compounding."

## 2026-05-25 07:10 — V2 multi-tool portability shims added

- Created `.cursor/rules/llm-wiki.mdc` — Cursor rules pointing at `AGENTS.md` + workflows.
- Created `.clinerules` — Cline shim.
- Created `.github/copilot-instructions.md` — GitHub Copilot shim.
- Created `CLAUDE.md` — shim for older Claude Code versions that load `CLAUDE.md` instead of `AGENTS.md`.
- Created `GEMINI.md` — shim for Gemini CLI.
- All shims reference `AGENTS.md` as canonical; they exist to give every tool's auto-loader something to discover. The Claude Code slash commands in `.claude/commands/wiki-*.md` remain the only first-class implementations; other tools invoke the same workflows via natural language.
- Updated `README.md` with the per-tool support matrix and revised project layout.

## 2026-05-25 06:45 — bootstrap (manual ingest)

Initial bootstrap of `llm-wiki-bootstrap`. The repository's first wiki was produced by an interactive design session rather than by `/wiki-ingest`, but the result honors the same conventions and the raw source is now ready for re-ingest at any time.

- Processed: `raw/karpathy-llm-wiki-video-transcript.md` (hash `3054546f`)
- Created:
  - `wiki/index.md` (navigation)
  - `wiki/core-idea.md`, `wiki/problem-with-naive-rag.md`, `wiki/three-layer-architecture.md` (foundations)
  - `wiki/layer-raw-sources.md`, `wiki/layer-wiki.md`, `wiki/layer-schema.md` (architecture)
  - `wiki/operation-ingest.md`, `wiki/operation-query.md`, `wiki/operation-lint.md`, `wiki/ingest-pipeline.md` (operations)
  - `wiki/division-of-labor.md`, `wiki/four-principles.md`, `wiki/query-as-write-loop.md`, `wiki/use-cases.md` (foundations)
  - `wiki/commands.md`, `wiki/implicit-constraints.md`, `wiki/open-questions.md`, `wiki/source-attribution.md`, `wiki/glossary.md` (analysis)
- Created (system files):
  - `AGENTS.md` (canonical schema)
  - `README.md` (install + quickstart)
  - `.claude/commands/wiki-init.md`, `wiki-fetch.md`, `wiki-ingest.md`, `wiki-ask.md`, `wiki-lint.md`
- Contradictions flagged: none
- Notes:
  - `raw/karpathy-llm-wiki-video-transcript.md` is a third-party YouTuber's walkthrough, not Karpathy's tweet verbatim. See `wiki/source-attribution.md`.
  - 6 pages marked `source: analysis`: 5 analytical content pages (commands, implicit-constraints, open-questions, source-attribution, glossary) plus 1 navigation page (index).
  - 3 pages marked `source: mixed` (layer-raw-sources, layer-wiki, layer-schema — video extraction + project-specific convention details).
  - 11 pages marked `source: video` (all literal extractions from the transcript).
  - The raw file's frontmatter has been updated with `ingested_hash`, `ingested_at`, and `ingested_pages` so future `/wiki-ingest` runs skip it unless the body changes.
  - `scripts/body-hash.sh` ships as the canonical hash algorithm. The recorded `ingested_hash` was computed via this script; future `/wiki-ingest` runs must use the same script (per AGENTS.md) for idempotence.
  - **Slash command runtime is NOT yet validated.** All five `.claude/commands/wiki-*.md` files exist and are well-formed, but no command has actually been invoked. The first real-session invocation will be the smoke test. The bootstrap of the wiki itself was done by direct file writes during the planning conversation, not by `/wiki-ingest`.
