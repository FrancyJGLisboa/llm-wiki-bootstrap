---
description: Process raw/ into wiki/ via the 7-step pipeline, then regenerate synthesis artifacts. Detects deltas via body hash; idempotent on unchanged sources.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [<raw-file>]
---

You are executing `/ctx-compile $ARGUMENTS` from the `context-compiler-bootstrap` system. Your job is to integrate raw sources into the wiki using the 7-step pipeline.

## Resolve the optional profile first

If `scripts/profile-resolve.py` exists, run `python3 scripts/profile-resolve.py --root . --json`
before determining scope. If it exits 2, report the setup error and stop
without writing. When it reports `"active": false`, or when the resolver script
is absent, follow this document's generic contract exactly.

When it reports `client-decision`, read the resolved manifest and
`profiles/client-decision/COMPILATION.md` completely. In addition to generic pages, emit
exactly one deterministic shard per processed source at
`context/claims/by-source/<source-id>.jsonl`, then run:

```bash
python3 scripts/claim-validate.py --root . context/claims/by-source/<source-id>.jsonl
```

Claims preserve the exact raw anchor/span, source metadata, evidence class, and speaker
attribution. Temporal replacement needs an explicit controlled relation; recency alone
is not supersession. Questions, hypotheticals, and qualified agreements are not beliefs.
Use UNKNOWN when evidence is absent.

Update only decision JSON and Markdown projections whose supporting claim IDs changed,
and regenerate exception review artifacts. Keep sorted deterministic output; never
rewrite unaffected shards or decisions. A no-op validates existing claims and regenerates
views byte-identically.

## Read first

**Run from the wiki root** — the directory holding `raw/`, `wiki/`, `AGENTS.md`, and `log.md`. If `raw/` and `wiki/` are absent you are not in a wiki: tell the user to run `/ctx-init` first (or `cd` into their wiki), then stop.

Read `wiki/index.md` (what already exists) and `log.md` (recent activity). You don't need to re-read all of `AGENTS.md` — the page template you'll write is inlined below; consult `AGENTS.md` → "Wiki page convention" only for edge cases.

If `scripts/profile-resolve.py` exists, resolve the optional profile before you start:

```bash
python3 scripts/profile-resolve.py --json
```

- If it reports `"active": false`, continue with the generic pipeline below.
- If it reports `"profile": "client-decision"`, read `profiles/client-decision/COMPILATION.md` before Step 1 and keep the generic pipeline intact **plus** the profile-specialized outputs in Step 4.6.
- Never activate or switch profiles implicitly while compiling. `context-profile.json` is the opt-in boundary.
- If the resolver script is absent, continue with the generic pipeline below; older installs remain valid no-profile compilers.

## Determine scope

- If `$ARGUMENTS` is empty: walk all files in `raw/`. For each, compute the current body hash by running **`scripts/body-hash.sh <file>`** (this is the canonical algorithm — do NOT recompute the hash inline with `sha256sum`, `shasum`, or a different awk pattern, or idempotence will break). Skip files whose `ingested_hash` in frontmatter matches the current hash.
- If `$ARGUMENTS` names a specific file: process only that file, regardless of hash.

If nothing to process: print "No changes to ingest.", **still run Step 8 (synthesis) below**, then exit — other commands (`/ctx-query` promote, `/ctx-lint --apply`) may have changed `wiki/` since the last synthesis, so the dashboards must be refreshed even on a no-op ingest. If `raw/` is **empty** (no sources at all), add: "Next: run `/ctx-extract <source>` to acquire a source, then `/ctx-compile` again."

## Page template (every page you create or update in steps 3–4)

Inlined so you don't have to cross-reference `AGENTS.md`. Pure CommonMark — no Obsidian callouts/dataview.

```markdown
---
title: <Title Case>
type: concept | entity | summary | analysis | navigation
source: document | video | analysis | external | mixed   # `document` for a raw/ corpus; `external` means web-fetched
updated: YYYY-MM-DD
tags: [...]
---

# <Title>

## Definition / TL;DR
1-3 sentences. What this page is about.

## Body
Free-form prose. Inline `[[wiki-links]]` to related pages, and `(source: <raw-file>#<anchor>)` for any non-trivial claim.

## Related
- [[other-page]] — why it relates
- [[another-page]] — why it relates

## Open questions on this page
- ... (consumed by /ctx-lint)
```

The `## Related` section needs **≥ 2** `[[links]]` so the page joins the web (navigation/journal pages are exempt — see `AGENTS.md`). Cite anchors by source type: `#heading-name` (markdown/article), `#L5-L10` (line range), `#2:01` (video timestamp).

## The 7-step pipeline (run per raw file)

For each raw file that needs processing:

### Step 1 — Read the raw source

Read the file. For binaries (image, PDF), read the sidecar `.md` instead.

**If the sidecar is segmented** (frontmatter `segmented: true`): it is a section tree — a sequence of `#{level} <Title> (lines A-B | pages N-M)` anchors built by `segment-doc.py`. Skim the headings first to grasp the shape, then read **only the sections you need**, section by section. Do not load the whole blob into context — avoiding that is the entire point of segmentation (no context rot on a long doc).

### Step 2 — Extract key information

Identify: concepts (ideas, terms, patterns), entities (people, tools, places, datasets), claims (statements that could be true or false), data points (numbers, dates, quotes).

When the active profile is `client-decision`, extract the same evidence through the additional lens of `subject × decision × time`. Separate at least:

- direct observations from the source
- normalized facts strongly entailed by the source
- subject assumptions used for planning or reasoning
- explicit unknowns that remain unknown
- candidate decisions, variables, triggers, constraints, risks, and questions
- temporal change signals such as replacement, contradiction, confirmation, narrowing, or broadening

Do not flatten an analyst statement, a client question, a hypothetical, or a qualified agreement into a client assumption.

### Step 2.5 — Harvest normative statements

Most of a source is knowledge. Some of it is **rules** — constraints on what
something must or must not do. Separate them here, because they get different
treatment: knowledge is written to be understood, a rule is written to be
enforced.

Scan the material for obligation. The reliable markers: `must`, `must not`,
`never`, `always`, `shall`, `may only`, `only if`, `required`, `prohibited`,
`no later than`, `at most`, `at least`, `before <event>`, `cannot exceed`.

For each candidate, apply the triage in `AGENTS.md` → "Rules and executable
context" and write down the class **with the reason**:

- **DETERMINISTIC** — a parser, a schema check, or a command with an exit code
  could settle it. State the exact detection mechanism now, in one line. If you
  cannot state it, it is not deterministic.
- **HEURISTIC** — settling it needs judgement ("forecasts must be reasonable").
  Real, but no exit code can decide it.
- **UNVERIFIABLE** — nothing could check it, even in principle.

Three rules for this step, all of which exist because the failure is silent:

1. **Only rules the source actually states.** Do not add best practices you
   happen to know. A rule with no citable passage is your opinion wearing the
   source's authority.
2. **Do not write any code here.** A gate is only real once it has failed on a
   violating fixture, and that proof belongs to `/ctx-gate`. Emitting a gate
   script from this step would manufacture exactly the never-fires gate the
   whole discipline exists to prevent.
3. **Keep the unverifiable ones.** They go to `wiki/rules/discarded/` with a
   `discard_reason`. Dropping them silently is indistinguishable from never
   having read them.

### Step 3 — Write a summary page

Create or update `wiki/<source-slug>-summary.md` with `type: summary`, `source: <type>` (matching the raw's `source_type` family — `video` for video-transcript, `external` for fetched web pages, etc.), and the source's main takeaways. Cite the raw inline with `(source: raw/<filename>#<anchor>)`.

**For a segmented source** (`segmented: true`): write the summary `## Body` as a **section tree** — a nested bullet outline mirroring the sidecar's heading hierarchy, **one line per node** summarizing that section, each ending with its anchor `(source: raw/<slug>.<ext>.md#<section-slug>)`. The `<section-slug>` is the kebab-case of the heading title **with the `(lines …)`/`(pages …)` range dropped** (e.g. `## Power Envelope (lines 13-19)` → `#power-envelope`). This compact tree — not a wall of prose — is what `/ctx-query` later walks to fetch only the relevant section. Every leaf's anchor MUST correspond to a real heading in the sidecar (no invented anchors).

### Step 3.5 — Capture entities on the summary page

Every summary page carries an `## Entities` section listing the **named things** the source refers to, each with its own citation:

```markdown
## Entities

- Dan Okafor — closed out the cutover date decision (source: raw/thread-q3-planning.eml#L118-L125)
- NEEDLE-EML-4c2d80 — ticket the cutover date was filed under (source: raw/thread-q3-planning.eml#L118-L125)
```

This is what makes a source *contextualizable* rather than just summarized: who acted, which org, which ticket, which dataset. Step 4's "2+ raws OR structurally important" threshold governs whether an entity earns its own `type: entity` page — but capture is not optional, and it happens here even for a name that appears exactly once. A person who made a decision in one email is the reason that decision can later be attributed at all.

**What counts as an entity:** people, organizations, named tools and systems, datasets, identifiers (ticket/issue/order IDs), named places, named events. Something a reader could point at outside this document.

**What does NOT**, no matter how it is capitalized:

| not an entity | why |
|---|---|
| `## Instrumentation Debt`, `## Capacity Headroom` | section headings — Title Case is formatting, not a name |
| "Sustained Throughput", "Batch Window" | metrics and concepts; these are `type: concept` if anything |
| the document's own title | it is the source, not a thing the source mentions |
| "The Platform Team" with no proper name | unnamed group; capture the named owner if one exists |

Listing every capitalized phrase is the failure mode this table exists to prevent. It looks thorough, doubles the wiki's noise, and makes entity retrieval useless — a list where everything is an entity identifies nothing. When unsure, leave it out: a missed entity is recoverable by re-ingest, a wiki full of phantom entities is not.

Every line needs a real `(source: raw/<file>#<anchor>)` anchored at the passage that names the entity — same form and same narrowness rule as every other citation. An uncited entity is an assertion that something was mentioned, which is exactly what the wiki exists not to do.

### Step 4 — Update existing entity / concept pages

For each concept and entity from step 2:
- Glob `wiki/` to see if a matching page exists.
- If yes: read it, decide what to add, append the new claim with citation. **Do not duplicate existing content.**
- If no AND the concept/entity is referenced by 2+ raws OR is structurally important: create a new `wiki/<slug>.md` with `type: concept` or `type: entity`.
- Cross-link: every page that mentions another covered page should `[[wiki-link]]` to it.
- **Encode causation, don't bury it.** When the source states that one thing *causes / leads to / enables / prevents / contributes to* another, write that `## Related` link with a **canonical causal verb** — `causes`, `caused-by`, `enables`, `prevents`, or `contributes-to` (form: `- [[effect]] causes — <prose>`; put the inverse on the effect's page as `- [[cause]] caused-by — <prose>`). Do NOT flatten cause→effect into a plain `related-to`, and do NOT invent synonyms (`results-in`, `due-to`, `enabled-by`) — `scripts/wiki-lint-causal.sh` rejects those. These canonical edges are what let `/ctx-query` answer "what caused X / what does X enable / how does A connect to B" by graph traversal (see `AGENTS.md` → "Causal relations"). A multi-step causal story should become a *chain* of canonical edges across pages, not one lump.
- **Type the links you already narrated, and let loops close.** Two failure modes to catch before leaving this step — both observed in real ingests: (1) a `## Related` line whose own prose narrates causation ("led to", "in response to", "drives", "feeds", "pressures", "accelerated") while the link itself is untyped — the prose knows the direction, the graph doesn't; retype it with the canonical verb. (2) Stopping one leg short of a cycle: when the source describes feedback (A pressures B, B responds by strengthening A), author EVERY leg — cycles are a payoff, not an error; `scripts/wiki-loops.py` reports them as reinforcing or balancing (an odd number of `prevents` legs flips the sign), and a loop you leave open is invisible to it. Self-check before Step 5: `python3 scripts/wiki-to-kg.py wiki/ --causal-only | wc -l` — a causally-rich source batch yielding near-zero causal edges means this bullet was skipped, not that the sources lacked causation.
- **Encode supersession, don't bury it.** When a newer source replaces an older same-subject source's claim as the current value — even when no prose says so and the only evidence is two same-titled sources with different `Published:`/valid-time dates — author the typed edge on the newer source's page: `- [[old-page]] supersedes — <prose, name both dates>`, and the inverse on the older page: `- [[new-page]] superseded-by — <prose>`. Exactly these two verbs — no synonyms (`replaces`, `obsoletes`, `deprecates`, `replaced-by`), or the edge is invisible to traversal. Supersession is NOT contradiction: the older claim stays correct for its own period, so a clean vintage succession is never CONTRADICTION-flagged and neither body is rewritten. These edges are what let `/ctx-query` answer "what replaced X" by graph walk instead of prose-hunting.

### Step 4.5 — Write rule pages

For each rule harvested in step 2.5, write
`wiki/rules/<class>/RULE-<NNNN>-<slug>.md` using the frontmatter spec in
`AGENTS.md` → "Rules and executable context".

Allocate `rule_id` by scanning existing pages for the highest `RULE-NNNN` and
incrementing. **Ids are never reused**, including for deleted rules — a gate,
a fixture directory, and a baseline row all key off the id, and recycling one
silently re-points three other things.

Non-negotiable on every rule page:

- **`gate: none`.** Always, at compile time, for every class. Filing the rule
  and building its gate are separate acts by design; `/ctx-gate <RULE-ID>` does
  the second one, behind the mutation proof.
- **`rule_domain`** — write it explicitly, do not lean on the default:
  - `world` for anything harvested from a source that constrains external
    reality (a shipment, a filing, a blend level, a tariff window). For a
    document corpus this is almost always the answer, because a rule extracted
    from a report is a rule about the world the report describes.
  - `artifact` only when the rule constrains *this package* — a page, a
    frontmatter field, a build output — so a script could be run against
    something actually present. R-01 demands a gate for these and only these.

  Guessing `artifact` is the expensive direction, and quiet: it makes the
  rule-integrity count grow with every source ingested, so the ratchet reddens on
  a schedule and gets bumped without being read. If you cannot name what in this
  repository a gate would open and inspect, the answer is `world`.
- **`scope_include`** — meaningful only for `artifact` rules. Do not emit a
  placeholder like `["wiki/**.md"]` on a world rule to fill the field: a scope
  naming files the rule has nothing to say about is worse than an absent one,
  because it reads as a considered decision.
- **A real citation** — `(source: raw/<file>#<anchor>)` anchored at the passage
  that states the rule, not at the document generally. This is the whole basis
  for a gate's authority; without it a gate enforces something nobody can trace.
- **`statement`** in one sentence, in the imperative. If it takes two sentences,
  it is two rules.
- **`detection`** for deterministic rules only — the mechanism, not the
  intention. "Compare max(asserted_at) against declared_cutoff" is a mechanism;
  "check the dates are right" is not.
- **`discard_reason`** on anything in `wiki/rules/discarded/`.

Then link the rule into the graph like any other page: `## Related` with typed
edges to the concepts and entities it constrains (`- [[forecast-methodology]]
constrains — ...`), and a link back from the source summary page.

**Report at the end of this step** how many rules were found per class. A source
full of `must` that yields zero rules means this step was skipped, not that the
source was permissive.

### Step 4.6 — Emit profile outputs (only when a profile is active)

If the resolved profile is `client-decision`, write the additional machine outputs below **without replacing** the generic wiki pages above.

1. Write source-scoped claim shards to `context/claims/by-source/<source-id>.jsonl`.
   - Use the contracts in `profiles/client-decision/COMPILATION.md` and `profiles/client-decision/schemas/claim.schema.json`.
   - Every durable claim must preserve `source.id`, `source.type`, `source.path`, `source.timestamp`, `source.anchor`, `source.evidence_span`, and speaker fields when attributable.
   - Claim classes are exactly `observation`, `fact`, `assumption`, `inference`, `derivation`, and `unknown`.
   - `inference` requires numeric confidence. `unknown` is valid output and must stay explicit.
   - Speaker attribution is load-bearing: never convert an analyst assertion, client question, hypothetical, agreement, or qualified agreement into a client belief.
   - Use explicit temporal relations only: `supersedes`, `updates`, `confirms`, `contradicts`, `narrows`, `broadens`.

2. Validate the shard mechanically before moving on:

   ```bash
   python3 scripts/claim-validate.py --root . context/claims/by-source/<source-id>.jsonl
   ```

   Fix every validation error immediately. Do not leave an invalid shard behind.

3. Update decision projections under `context/decisions/<client-slug>/<decision-slug>.json` whenever the source materially changes a decision state.
   - Use `profiles/client-decision/schemas/decision.schema.json`.
   - The projection must reference supporting claim IDs rather than rephrasing unsupported content.
   - Omit or leave `null` for unknown optional fields. Never complete them from judgment.
   - Preserve history: current state and historical states must remain distinct instead of collapsing into one summary.

4. Treat contradictions and possible supersession as reviewable state, not forced resolution.
   - Contradictions stay visible in both the wiki pages and the claim graph.
   - A newer claim does not supersede an older one unless the evidence supports that relation; recency alone is not enough.
   - When speaker or supersession resolution is ambiguous, add the appropriate review trigger rather than guessing.

### Step 5 — Flag contradictions

If a new claim from this source disagrees with an existing claim in the wiki, **flag it visibly** in both pages. Do not silently overwrite either. Use this **exact** line format (a CommonMark blockquote — `/ctx-lint` matches the literal token `CONTRADICTION FLAGGED`):

```markdown
> CONTRADICTION FLAGGED YYYY-MM-DD: <one-line description>. Contradicts [[other-page]], which says <their claim>.
```

Worked example — `wiki/fluid-bed-roaster.md` gains, and `wiki/drum-roaster.md` gains the mirror:

```markdown
> CONTRADICTION FLAGGED 2026-05-30: this source says fluid-bed roasting is faster for light roasts. Contradicts [[drum-roaster]], which says drum roasting reaches first crack sooner.
```

Add the mirror flag to the page it points at so the contradiction is visible from both sides.

### Step 5.5 — Faithfulness gate (verify claims against evidence before committing)

After writing/updating the pages for this source, verify every cited claim actually holds
against its `raw/` evidence — don't trust your own paraphrase. Run the gate over the pages
you created or updated in this ingest:

```bash
scripts/wiki-faithfulness-gate.sh --mode ingest wiki/<changed-page>.md [wiki/<more>.md ...]
```

It reuses `scripts/citation-audit.py` to extract each `(source: raw/<file>#<anchor>)` claim,
judges it against the cited passage (SUPPORTED / UNSUPPORTED / CONTRADICTED), and applies:

- **CONTRADICTED, or a broken citation → the gate exits non-zero (blocks).** Fix the
  offending claim — rewrite it to match the evidence, or drop the citation if the source
  doesn't support it — then re-run the gate **once**. If it still blocks, leave that page
  out of this ingest and tell the user, rather than committing an unfaithful claim.
- **UNSUPPORTED → the gate appends a `FAITHFULNESS UNVERIFIED` marker** to the claim's line
  (line count preserved) and passes. Leave the marker in place — `/ctx-lint` surfaces it
  later. Don't hand-delete it; cite better evidence or rephrase if you want it gone.

The entailment judgment uses the `claude` CLI. C3 entailment inherently needs an LLM, so
this is a **write-time gate** (ingest + promote), not a keyless-CI check: the deterministic
floor that CI/offline enforces is the citation audit (C1/C2, plus `--coverage`), **not**
entailment. With no judge available the gate **fails closed (exit 3)** rather than passing
unchecked — install the `claude` CLI, or pass `--allow-unjudged` to proceed on the citation
floor only (it prints a loud `FAITHFULNESS UNVERIFIED` warning so the gap is visible). This
is the BYO-agent analogue of the existing `eval-citation-faithfulness.sh` measurement, run
as a gate on the specific pages this ingest touched.

Follow-ups (deferred, not built here): a per-page `entailment: judged|skipped` frontmatter
marker, and a git pre-commit hook template that runs this gate.

### Step 6 — Update the index

Read `wiki/index.md`. Add new pages to the appropriate section. Remove links to pages that were deleted (rare). Keep the existing organization.

### Step 7 — Append to the changelog

**First, record the integrity numbers — by running the script, not by writing them from memory:**

```bash
bash scripts/wiki-metrics.sh ingest
```

That appends one machine-readable line to `log.md` (`committed=N/M`, pages, sources) which `scripts/wiki-flows.sh` later trends per month. **Read its output.** If `committed` is below `N/N`, you skipped the frontmatter commitment on some source in Step 6 — go back and finish it, because every citation into an uncommitted body is unverifiable and the drift lint is blind to it. Never hand-write this line: a number the model recalled is an assertion, not a measurement.

Then append your prose entry (newest at top) to `log.md`:

```markdown
## YYYY-MM-DD HH:MM — /ctx-compile

- Processed: raw/<file> (hash <8-char-prefix>)
- Created: wiki/<file>, wiki/<file>
- Updated: wiki/<file>, wiki/<file>
- Contradictions flagged: none | <description>
```

## After all steps for a file

Update the raw file's frontmatter:
- `ingested_hash:` set to the body hash you computed via `scripts/body-hash.sh`
- `ingested_at:` set to current timestamp (format: `YYYY-MM-DD HH:MM`)
- `ingested_pages:` set to the array of wiki files this raw touched (created or updated)

## Step 8 — Regenerate synthesis artifacts (once, after all files)

After the per-file loop — and **also on the "No changes to ingest" path** — run the
synthesis regenerator exactly once:

```bash
./scripts/synthesize/all.sh
```

This is a **mechanical, deterministic** pass (no LLM work): it aggregates markers
you already wrote into four standing artifacts and rewrites them only if their
content changed.

- `wiki/open-questions-dashboard.md` — every `## Open questions on this page` section, grouped by page
- `wiki/tensions.md` — every `> CONTRADICTION FLAGGED` flag (step 5), newest first
- `wiki/decision-timeline.md` — reverse-chronological `log.md` activity timeline
- `wiki/knowledge-graph.json` — the `[[link]]` graph as deterministic JSON (reuses the `/ctx-visualize` parser)

These four are **generated, not authored**: never hand-edit them, never cite them as
sources, and don't count them when deciding what to create in step 4 — they are
overwritten on every run. If `scripts/synthesize/all.sh` is absent (older wiki), skip
this step and tell the user to re-scaffold with `scripts/create-context-compiler.sh` to pick it up.

For an active client-decision profile, finish by validating all emitted shards and
running profile health diagnostics:

```bash
python3 scripts/claim-validate.py --root . context/claims/by-source
python3 scripts/client-context.py --root . lint --json
```

These deterministic scripts validate authored claims; they do not call an LLM or judge
entailment.

## What you must NOT do

- Edit anything in `raw/` other than the frontmatter fields `ingested_hash`, `ingested_at`, `ingested_pages`.
- Skip the changelog entry.
- Hand-edit the four Step-8 synthesis artifacts — they are regenerated mechanically.
- Use Obsidian-specific syntax in any wiki page.
- Promote orphan information (claims that don't relate to anything else) into their own page just to have something. Better: skip them and let lint surface gaps.

## Output

End with a status report listing files processed, files skipped (and why), and pages created/updated. Then point the user at the verification loop: "Next: run `/ctx-query \"what does <source> say about <topic>?\"` to verify the ingest." Suggest `/ctx-lint` if you flagged contradictions or noticed gaps.
