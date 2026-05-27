# GOAL: typed wikilinks + semantic graph viz + multi-hop eval (phase 1)

> Hand-off spec for an autonomous coding agent. Self-contained. The agent iterates until
> every check in §3 passes, using §6 as the loop and §7 as the stop rules.

## 1. Context — why this exists

The current wiki is already a graph (pages = nodes, `[[wikilinks]]` = edges) but all
edges are untyped, so `/wiki-query` cannot reason over typed relations (e.g. "entities
founded before 1980 that produce soy") and the rendered D3 graph in
`scripts/visualize/graph.sh` carries no semantics. Some users want a parallel
knowledge graph (separate triplestore / RDF) to solve this — that's expensive and
introduces a second source of truth.

**User-confirmed decision (do not relitigate):** before considering a parallel KG,
add typed annotations *inside* the existing markdown — the **annotated `## Related`**
form (chosen syntax, locked) — plus semantic graph viz, then **measure** whether this
80%-cost path already kills the multi-hop problem. The eval is the deliverable; the
verdict (improvement / no-improvement) drives the phase-2 go/no-go on a parallel KG.

Chosen syntax (locked):
```
## Related
- [[embrapa]] founded-by-government-in 1973 — Brazilian R&D agency
- [[cerrado]] located-in — central biome where soy frontier moved
- [[plano-real]] enabled-by 1994 — stabilization plan that withdrew subsidies
```
- Parse rule: `- [[<target>]] <verb> [<attr>] — <prose>` where `<verb>` matches
  `[a-z][a-z0-9-]*` and `<attr>` is optional, one whitespace-delimited token.
- Backward-compat: a line without `<verb>` (the existing form
  `- [[other-page]] — why it relates`) is treated as implicit `related-to`.
- **Multi-link lines**: a `## Related` line containing more than one `[[…]]` token
  (e.g. `- [[operation-ingest]], [[operation-query]], [[operation-lint]] — …`) is
  *always* treated as implicit `related-to` for every link, regardless of what
  follows. Verbs only apply to single-target lines. This preserves backward-compat
  with the existing meta-wiki under `wiki/`.
- Hard constraint: pure CommonMark; no Obsidian/Dataview/rendering deps.

## 2. Definition of done (one sentence)

Typed-relation syntax is documented in `AGENTS.md`, a lint accepts it (and rejects
malformed verbs) without breaking any existing untyped page, the D3 graph viz carries
per-edge verbs and a per-verb filter UI, and a multi-hop eval harness has produced a
baseline-vs-typed report committed to `log.md` with a binary verdict.

## 3. Success checks — ALL green (the oracle)

| # | Check | How to verify |
|---|---|---|
| C1 | **PRIMARY REGRESSION ORACLE**: existing core pipeline is not regressed | `./scripts/smoke-all.sh` exits 0 (all 9 checks C1–C5 + R1–R4 still green) |
| C2 | Typed-link syntax documented in AGENTS.md | `grep -cE '^[[:space:]]*-[[:space:]]+\[\[[a-z][a-z0-9-]*\]\][[:space:]]+[a-z][a-z0-9-]*' AGENTS.md` ≥ 3 AND `grep -cE 'Typed relations\|verb:' AGENTS.md` ≥ 1 |
| C3 | Lint accepts typed entries AND rejects malformed verbs | `scripts/wiki-lint-typed-relations.sh tests/canary/typed-related-fixture/` exits 0; `scripts/wiki-lint-typed-relations.sh tests/canary/typed-related-fixture-bad/` exits ≠ 0 |
| C4 | **BACKWARD-COMPAT**: lint accepts the 27-page meta-wiki (untyped entries valid as implicit `related-to`) | `scripts/wiki-lint-typed-relations.sh wiki/` exits 0 |
| C5 | Graph carries per-edge `verb` field with ≥ 3 distinct values | `scripts/visualize/graph.sh tests/canary/typed-related-fixture/ > /tmp/g.html && grep -oE '"verb"[[:space:]]*:[[:space:]]*"[a-z][a-z0-9-]*"' /tmp/g.html \| sort -u \| wc -l` ≥ 3 |
| C6 | Graph HTML has a filter UI element keyed on verb | `awk '/<(script\|select)[ >]/,/<\/(script\|select)>/' /tmp/g.html \| grep -cE 'data-verb\|filterByVerb\|verb-filter'` ≥ 1 (the token must live inside a `<script>` or `<select>` block — portable BSD/gawk; replaces an earlier `\b` form that BSD awk rejects) |
| C7 | Eval harness runs and emits baseline + typed scores | `scripts/eval-multi-hop.sh > /tmp/eval-report.md; echo $?` is `0` AND `grep -cE '^(baseline\|typed):[[:space:]]+[0-9]+/[0-9]+' /tmp/eval-report.md` is `2` |
| C8 | **EVAL HONESTY**: fixture has real typed coverage AND questions have real signal | `awk '/^[[:space:]]*-[[:space:]]+\[\[[a-z][a-z0-9-]*\]\]/{t++; if (match($0, /\]\][[:space:]]+[a-z][a-z0-9-]*/)) v++} END {exit !(t>0 && v*100/t >= 60)}' $(find tests/eval/wiki-fixture -name '*.md')` exits 0 (≥ 60% of single-target Related lines have a verb) AND `grep -cE '^baseline-absent:[[:space:]]*true' tests/eval/multi-hop-questions.md` ≥ 2 (at least two questions are tagged as ones the baseline-stripped wiki cannot answer from prose alone) |
| C9 | Verdict logged to `log.md` AND installer still ships green | `grep -q 'phase-1 typed-relations eval' log.md` AND that log entry contains one of `improvement\|no-improvement\|null-result` AND `./scripts/verify-create-llm-wiki.sh` exits 0 |

The AND of C1–C9 is self-evaluable each turn with no human in the loop.

Negative-guard rows: C1 (no regression), C4 (no backward-compat break), C8 (no fixture
gaming), C9's installer half (no shipping-path break).

## 4. Scope — in / out + the boundary rule

**IN scope:**
- New `## Related` typed-line parser (regex-based, no AST).
- `scripts/wiki-lint-typed-relations.sh` (new): validates verb regex on the typed-line
  form; treats lines without a verb as implicit `related-to`.
- `scripts/visualize/graph.sh` + `scripts/visualize/graph-html.py`: extract verb per edge
  and emit a filter UI (`<select>` or checkbox group) in the rendered HTML.
- `scripts/eval-multi-hop.sh` (new): runs N (≥ 5) multi-hop questions on a fixture wiki
  *twice* — once against the wiki with typed `## Related` annotations removed
  (baseline), once with them present (typed) — and writes a single report file with
  two lines: `baseline: X/N`, `typed: Y/N`, plus a verdict.
- `tests/canary/typed-related-fixture/` (new): ≥ 3 small markdown pages with typed
  `## Related` entries covering ≥ 3 different verbs.
- `tests/canary/typed-related-fixture-bad/` (new): ≥ 1 page with malformed verb
  (e.g. `5badverb`, `Verb-With-Caps`, `verb with spaces`) — the only purpose is to
  make C3's reject side fire.
- `tests/eval/multi-hop-questions.md` (new): the 5–7 multi-hop questions used by
  `scripts/eval-multi-hop.sh`. Each entry: question text + the expected key fact
  tokens (used for binary grading) + a `baseline-absent: true|false` tag. See §5
  for the strict per-question format and the ≥ 2 `baseline-absent: true` rule.
- `tests/eval/wiki-fixture/` (new): a checked-in copy of `/tmp/llm-wiki-newuser-sim/wiki/`,
  the 6-page Brazilian-ag wiki built on 2026-05-27. The agent annotates this with
  typed `## Related` entries; the eval strips them on the baseline pass.
- `AGENTS.md`: a new "Typed relations" subsection under the existing
  "Link convention" — short, ≤ 30 lines, gives the parse rule + ≥ 3 examples.
- `log.md`: one new entry recording the eval run + verdict (the standard
  append-only log convention).

**OUT of scope:**
- Anything in §8.

**Boundary rule:** if a page in the existing `wiki/` (the 27-page meta-wiki) would
need to be *rewritten* (not just left alone) to pass C4, the line is OUT — fix the
lint instead so untyped lines stay valid. The conservative default on any other
boundary call is **leave it; don't force it**.

## 5. Concrete deliverable artifacts

| Path | ~Size | What it must do |
|---|---|---|
| `scripts/wiki-lint-typed-relations.sh` | ≤ 120 lines bash | Parse each `## Related` block in the given path (file or dir); for each `- [[target]] …` line, classify as typed (verb present and matches `[a-z][a-z0-9-]*`) or implicit (no verb token between `]]` and `—` / `--` / EOL). Exit non-zero if a typed line has a malformed verb; exit 0 otherwise. Stdout: one line per page summarising counts. |
| `scripts/eval-multi-hop.sh` | ≤ 200 lines bash | (1) Read `tests/eval/multi-hop-questions.md`. (2) Build a baseline fixture wiki by stripping verbs from all single-target `## Related` entries (regex: the verb token between `]]` and `—`/EOL is removed; multi-link lines are left alone since they were never typed). (3) Run each question through `claude -p "/wiki-query \"…\" --no-promote"` against baseline and again against the typed wiki, in temp dirs so neither is mutated. (4) For each Q, grep the answer for the expected-key-fact tokens declared in the question file; pass = all tokens present. (5) Print `baseline: X/N` and `typed: Y/N`, plus a one-line verdict (`improvement` if Y > X by ≥ 2, `null-result` if equal or off-by-one, `no-improvement` if Y < X). (6) Exit 0 if the harness completed (regardless of which way the verdict landed). |
| `tests/eval/multi-hop-questions.md` | ≤ 80 lines | 5–7 multi-hop questions. Per-question format: `### Q<n>` heading, body = the question, an `expects:` line with comma-separated tokens that must appear in the answer to count as passed, and a `baseline-absent: true\|false` line — `true` means the answer tokens are *not* present in the baseline-stripped fixture prose (so a passing baseline run for this Q would be evidence of LLM external knowledge / hallucination, not retrieval). **At least 2 questions must be tagged `baseline-absent: true`** — these are the ones the typed run is hypothesised to help on. The fixture wiki is **a copy of the Brazilian-ag wiki built during the 2026-05-27 new-user simulation** (originally at `/tmp/llm-wiki-newuser-sim/wiki/`); the agent commits the copy under `tests/eval/wiki-fixture/`. |
| `tests/canary/typed-related-fixture/` | 3 pages, ~10 lines each | Each page has a `## Related` section with ≥ 1 typed line; collectively ≥ 3 distinct verbs (e.g. `founded-by`, `located-in`, `enabled-by`). |
| `tests/canary/typed-related-fixture-bad/` | 1 page, ~10 lines | One `## Related` block with at least one structurally-malformed verb token. |
| `AGENTS.md` (modify) | +20–30 lines | New `### Typed relations` subsection under "Link convention". Parse rule + examples + backward-compat note (including the multi-link clause). |
| `scripts/visualize/graph.sh` / `graph-html.py` (modify) | Δ ≤ 80 lines | Parse the typed-line regex when emitting nodes/edges; attach `verb` to each edge JSON object; emit a filter UI in the HTML (`<select>` with verb options + a script that hides edges whose verb doesn't match). Implicit lines emit `verb: "related-to"`. |
| `scripts/installer-skeleton-manifest.txt` (modify) | +6–8 lines | Add the new lint script, eval script, eval-question file, and canary fixture paths so a fresh `create-llm-wiki.sh` ships them. |
| `log.md` (modify) | +1 entry | `## YYYY-MM-DD HH:MM — phase-1 typed-relations eval` with baseline/typed/verdict on one line and a one-line reading. |

## 6. The iteration loop the agent must follow

Each step ends with one of the C-checks. If the named check is red after **3 fix
attempts limited to that step's narrow scope**, revert that step and escalate (§7).
Commit one logical step per commit so the oracle is auditable in the diff log.

1. **Baseline.** Record the pre-change state: `./scripts/smoke-all.sh` exit code (must
   already be 0 — see §7), `git rev-parse HEAD`, output of `wc -l scripts/visualize/graph-html.py`. **If `smoke-all.sh` is already red on the starting commit, STOP — do not proceed.**
2. **AGENTS.md spec** → verify C2; if red, fix only the AGENTS.md examples block; do not broaden.
3. **Canary fixtures** (good + bad dirs) → spot-verify by `ls` and a quick read.
4. **Lint script** → verify C3 and C4. If C4 red, fix only the regex (untyped lines must pass); do not rewrite any existing wiki page.
5. **Graph: verb extraction** in `graph-html.py` → verify C5; if red, fix only the parser regex / JSON emission.
6. **Graph: filter UI** in the HTML template → verify C6; if red, fix only the HTML/JS block.
7. **Copy fixture wiki** — copy `/tmp/llm-wiki-newuser-sim/wiki/` to `tests/eval/wiki-fixture/` and commit (since `/tmp` is ephemeral). If the source directory is missing, see §7 stop conditions.
8. **Apply typed annotations** to the eval fixture wiki (≥ 60% of single-target `## Related` lines get a verb; ≥ 3 distinct verbs across the fixture) — needed for C8 to be honest.
9. **Eval harness** — write `scripts/eval-multi-hop.sh` + `tests/eval/multi-hop-questions.md` (≥ 2 questions tagged `baseline-absent: true`) → verify C7 and C8; if red, fix only the harness wiring / grading regex / question tagging — never tweak the questions to push the verdict.
10. **Run the eval, log the verdict** → verify the verdict half of C9.
11. **Installer manifest update** → add the new lint script, eval script, eval-question file, and canary fixture paths; verify the installer half of C9.
12. **Final gate.** Re-run `./scripts/smoke-all.sh` (C1) AND the full C1–C9 set. All green → done.

## 7. Stop / escalate conditions (do NOT push through these)

- **Baseline already red.** `./scripts/smoke-all.sh` exits non-zero on the starting commit → stop, report the failure; do not try to fix smoke as part of this work.
- **Ontology/syntax drift.** Any pressure to broaden the verb form (e.g. accept verbs with capitals, multi-word verbs, quoted attributes, nested relations) → stop and escalate. The locked form is `[a-z][a-z0-9-]*` plus one optional attr token. Do not redesign.
- **Backward-compat impossible.** If C4 (untyped wiki/ passes lint) cannot be met without rewriting existing pages → stop, report which pages, escalate. Rewriting is OUT of scope (see §8).
- **Rendering dependency creep.** If the filter UI requires anything beyond stdlib Python + vanilla JS in the emitted HTML (e.g. you reach for D3 plugins, lodash, an npm package, Obsidian syntax) → stop. Pure CommonMark + stdlib is a hard rule.
- **Eval harness can't run.** If `claude -p` fails repeatedly (timeout, missing CLI, rate limit) → stop, report; do not fake numbers.
- **Fixture missing.** If both `/tmp/llm-wiki-newuser-sim/wiki/` AND `tests/eval/wiki-fixture/` are absent → STOP and report. Do not synthesise a substitute fixture; the spec's eval signal depends on the specific Brazilian-ag content that was ingested in the 2026-05-27 simulation. Recovery: rerun the simulation per `.scratch/plug-and-play-curator-smoke/GOAL.md` to regenerate `/tmp/llm-wiki-newuser-sim/wiki/`, then resume.
- **Verdict ambiguity.** If `improvement` vs `no-improvement` lands inside the noise band (the harness's own spec calls "null-result" for off-by-one) → log it as `null-result` and stop. Don't gerrymander the question set to push the verdict.
- **A revert doesn't restore green.** If reverting the last step doesn't put `./scripts/smoke-all.sh` back to 0 → stop. Don't keep pulling threads.
- When in doubt → stop and report. Don't guess.

## 8. Non-goals (explicitly out of scope)

- A parallel knowledge graph / triplestore / RDF / SPARQL layer of any kind.
- Embeddings, vector DB, or any retrieval index.
- A controlled-vocabulary verb registry, enum, or schema validation beyond the regex
  `[a-z][a-z0-9-]*`. Verbs are open.
- Changes to `raw/` frontmatter or any extraction code (`/wiki-extract`).
- Changes to the `/wiki-query` command logic — the LLM-in-the-loop remains the reasoner.
  Typed relations help it because they're *in the markdown*, not because the command
  traverses a graph.
- Rewriting any existing wiki page to add typed annotations (except the eval fixture wiki, which is a copy under `tests/eval/`).
- New external dependencies — no `pip install`, `brew install`, `npm install`, etc. The
  hard requirements in `preflight.sh` must remain `bash awk openssl git` only.
- New slash commands (`/wiki-visualize`, `/wiki-relate`, etc.).
- Mass migration of the existing 27 meta-wiki pages to typed form.
- Cross-domain ontology (Schema.org, Wikidata, anything).

## 9. Real-data test inventory

- **Primary oracle:** `./scripts/smoke-all.sh` (covers C1) — runs the full 9-check
  smoke (LLM ingest + query + 4 regression guards) on the Quortex fixture; this is the
  unchanged behavior we must not regress.
- **Backward-compat oracle:** the 27-page meta-wiki under `wiki/` (covers C4) — must
  all parse cleanly under the new lint with no edits to the pages themselves.
- **Live smoke for new behavior:** `scripts/wiki-lint-typed-relations.sh tests/canary/typed-related-fixture/` (C3 good side) and `…/typed-related-fixture-bad/` (C3 bad side).
- **Graph smoke:** `scripts/visualize/graph.sh tests/canary/typed-related-fixture/` → grep for `"verb"` (C5) and for filter-UI tokens (C6).
- **Multi-hop eval (the deliverable's whole point):** `scripts/eval-multi-hop.sh` against `tests/eval/wiki-fixture/` (a copy of the Brazilian-ag wiki built during the new-user simulation on 2026-05-27, originally at `/tmp/llm-wiki-newuser-sim/wiki/` — the agent must copy this into the repo under `tests/eval/wiki-fixture/` and check it in, since `/tmp` is ephemeral; see §7 stop condition for the missing-fixture case). Covers C7, C8, and the verdict half of C9.
- **Installer regression:** `./scripts/verify-create-llm-wiki.sh` (covers the installer half of C9: the new lint + eval scripts + canary fixture + eval fixture must all be in the manifest and shipped to a fresh target without leaking dev-only content).

## Critical files

- **New:**
  - `scripts/wiki-lint-typed-relations.sh`
  - `scripts/eval-multi-hop.sh`
  - `tests/canary/typed-related-fixture/page-a.md`
  - `tests/canary/typed-related-fixture/page-b.md`
  - `tests/canary/typed-related-fixture/page-c.md`
  - `tests/canary/typed-related-fixture-bad/page-x.md`
  - `tests/eval/multi-hop-questions.md`
  - `tests/eval/wiki-fixture/` (copy of `/tmp/llm-wiki-newuser-sim/wiki/`, ≥ 5 pages)

- **Modified:**
  - `AGENTS.md` (+`### Typed relations` subsection under "Link convention")
  - `scripts/visualize/graph.sh`
  - `scripts/visualize/graph-html.py`
  - `scripts/installer-skeleton-manifest.txt` (+new lint/eval/canary entries)
  - `log.md` (+ one append-only entry with the verdict)

---

## Completion status (filled in at gate-close — 2026-05-27 14:00)

All 9 success checks GREEN (14/14 sub-asserts):

| # | Check | Result |
|---|---|---|
| C1 | `./scripts/smoke-all.sh` exit 0 | ✓ (5 + 4 sub-checks green) |
| C2 | AGENTS.md has ≥ 3 typed-line examples + the `Typed relations` keyword | ✓ (3 examples, 1 keyword) |
| C3 | Lint accepts `typed-related-fixture/` AND rejects `typed-related-fixture-bad/` | ✓ (good=0, bad=1) |
| C4 | Lint accepts the 27-page `wiki/` (backward-compat) | ✓ (108 implicit + 2 multi, 0 bad) |
| C5 | Graph carries ≥ 3 distinct verb values | ✓ (5 distinct: `derived-from`, `enabled-by`, `enables`, `located-in`, `related-to`) |
| C6 | Filter UI tokens live inside `<script>` or `<select>` | ✓ (5 token hits: `verb-filter`, `data-verb`, `filterByVerb`) |
| C7 | `eval-multi-hop.sh` exit 0 AND emits both `baseline:` and `typed:` lines | ✓ (exit 0, 2 score lines) |
| C8 | Fixture ≥ 60% typed AND ≥ 2 `baseline-absent: true` questions | ✓ (74% typed, 4 baseline-absent hits) |
| C9 | Verdict logged AND `verify-create-llm-wiki.sh` exit 0 | ✓ (log marker + verdict within `-A 5`; installer 5/5) |

**Verdict (the deliverable's actual payload): `null-result`** — baseline 5/5, typed 5/5, delta 0.

The eval failed to discriminate not because typed verbs are wrong, but because the LLM
inferred each kebab-case verb from prose + question framing alone, on a Wikipedia-rich
fixture. The phase-2 question is therefore *not* "do we need a parallel KG?" but
"do we need explicit graph traversal in `/wiki-query` AND a sparser-prose eval
fixture?" — both before, not just one or the other.

Full reading in `log.md` under `2026-05-27 14:00 — phase-1 typed-relations eval`.
