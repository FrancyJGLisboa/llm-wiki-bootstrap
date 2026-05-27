# GOAL: phase-2 KG sidecar + traversal in /query (sparser-fixture experiment first)

> Hand-off spec for an autonomous coding agent. Self-contained. The agent iterates until
> every check in §3 passes, using §6 as the loop and §7 as the stop rules.

## 1. Context — why this exists

Phase 1 (typed `## Related` verbs, see `.scratch/typed-wikilinks-semantic-viz/GOAL.md`)
returned a **null-result** on a Wikipedia-derived fixture: baseline 5/5 = typed 5/5.
The reading was that LLM inference from rich prose dominated whatever signal the
typed verbs added. The natural follow-up — "build a parallel knowledge graph anyway"
— is the wrong move *unless* we first prove the signal exists somewhere the prose
can't fake. **This spec exists to design and run that proof first, then conditionally
build the minimal KG infrastructure that the proof justifies.**

Hard pre-decision: this work proceeds in two ordered phases, with a **gate** between
them. The agent must STOP at the gate if the gate fails — do not build KG code on top
of a null-result.

- **Phase 2a (the experiment).** Build a hand-crafted **sparse-prose fixture** where
  the only path from question to multi-hop answer is through typed `## Related`
  edges; verify that baseline-stripped prose **fails** the new eval (C1–C3 below).
  If baseline still passes ≥ 60% of the new questions, the conclusion is "the LLM
  doesn't need typed structure" and phase 2b is **abandoned** (with a logged
  null-result, not a quietly-shipped KG).
- **Phase 2b (the build).** Only if Phase 2a's gate holds: ship the minimum-viable
  KG layer (JSONL sidecar at `wiki/_kg.jsonl` written by `/wiki-ingest`, read by
  `/wiki-query` for typed traversal). Re-run the eval; require typed ≥ baseline + 2
  on the sparse fixture to declare phase-2 a success.

Anti-failure-mode: this spec is structured so that a "build it anyway" agent
gets a red C5 and has to stop. The gate is in §3, not just in §6's iteration loop.

## 2. Definition of done (one sentence)

Either (a) phase 2a's sparse-prose eval shows baseline-stripped wiki fails ≥ 60% of
multi-hop questions AND phase 2b's KG sidecar + `/wiki-query` traversal lifts typed
runs by ≥ 2 over baseline on that same fixture, with no regression on the existing
Brazilian-ag fixture; OR (b) phase 2a's eval shows baseline still passes ≥ 60%, the
gate fails, and the null-result is logged in `log.md` with phase 2b explicitly
abandoned and the reason recorded.

Both outcomes are valid "done" states — the deliverable is the **conclusion**, not
the code.

## 3. Success checks — ALL green (the oracle)

The oracle has **two acceptance modes**: either the build-and-improve mode (M1) or
the gate-failed-and-logged mode (M2). The full oracle is `M1 OR M2`, with M2 acting
as the honest exit when the experiment says "don't build it."

| # | Check | How to verify |
|---|---|---|
| C1 | **PRIMARY REGRESSION ORACLE**: existing pipeline + the Brazilian-ag eval don't regress | `./scripts/smoke-all.sh` exits 0 AND `./scripts/eval-multi-hop.sh > /tmp/eval-rich.md && grep -q '^verdict: \(null-result\|improvement\)' /tmp/eval-rich.md` (i.e. on the rich-prose fixture, typed must not be *worse* than baseline) |
| C2 | Sparse-prose fixture exists, ≥ 5 pages, each ≤ 100 words of body prose | `find tests/eval/sparse-fixture -name '*.md' -type f \| wc -l` ≥ 5 AND the body-word counter passes: `awk 'BEGIN{ok=1} /^---$/{c++; next} c<2{next} /^## Related/{r=1; next} /^## /{r=0} !r{words+=NF} ENDFILE{if(words>100){print FILENAME": "words" words"; ok=0} words=0; c=0; r=0} END{exit !ok}' tests/eval/sparse-fixture/*.md` exits 0. (Tracking variables: `c` counts `---` delimiters — body starts at `c==2`; `r` is the `## Related` flag. The bare `c<2 {next}` skips frontmatter; the `## Related` branch flips `r=1` and the next `## ` flips it back. Body words outside Related are summed.) |
| C3 | Sparse-prose fixture has ≥ 2 distinct verbs across ≥ 8 typed Related lines | `awk '/^[[:space:]]*-[[:space:]]+\[\[[a-z][a-z0-9-]*\]\][[:space:]]+([a-z][a-z0-9-]*)/{if(match($0, /\]\][[:space:]]+[a-z][a-z0-9-]*/)){t++; verb=substr($0,RSTART+2); sub(/^[[:space:]]+/,"",verb); sub(/[[:space:]].*/,"",verb); v[verb]=1}} END{n=0; for(k in v)n++; exit !(t>=8 && n>=2)}' tests/eval/sparse-fixture/*.md` exits 0 |
| C4 | Sparse-prose multi-hop question set: ≥ 5 questions, all 2-hop or 3-hop, all `baseline-absent: true`, AND no expects-token is a verb literal AND every expects-token is absent from the *unstripped* fixture prose | (a) `grep -c '^### Q[0-9]\+' tests/eval/sparse-multi-hop-questions.md` ≥ 5; (b) `grep -c '^hops:[[:space:]]*[23]' tests/eval/sparse-multi-hop-questions.md` ≥ 5; (c) `grep -c '^baseline-absent:[[:space:]]*true' tests/eval/sparse-multi-hop-questions.md` ≥ 5 (every Q tagged); (d) `comm -12 <(grep -h '^expects:' tests/eval/sparse-multi-hop-questions.md \| sed 's/^expects://;s/,/\n/g' \| sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \| grep -v '^$' \| sort -u) <(awk '/^[[:space:]]*-[[:space:]]+\[\[[a-z][a-z0-9-]*\]\][[:space:]]+[a-z]/{if(match($0,/\]\][[:space:]]+[a-z][a-z0-9-]*/)){t=substr($0,RSTART+2); sub(/^[[:space:]]+/,"",t); sub(/[[:space:]].*/,"",t); print t}}' tests/eval/sparse-fixture/*.md \| sort -u) \| grep -qc .` produces zero overlap (no expects token IS a verb literal); (e) for every expects token, `grep -qiF "<token>" tests/eval/sparse-fixture/*.md` must be FALSE (the token is genuinely absent from the unstripped prose — a stricter condition than "absent from stripped prose" and easier to mechanically verify). |
| C5 | **THE GATE — baseline-stripped sparse fixture must FAIL** the new eval | `./scripts/eval-multi-hop-sparse.sh > /tmp/eval-sparse.md` exits 0 AND the report contains `baseline: X/N` where `X*100/N <= 40` (baseline passes at most 40% of questions). If baseline > 40% the experiment failed to discriminate and phase 2b is forbidden — see §6 step 5 and §7 stop conditions. **Frozen-by-design**: the question set must be set in §6 step 3 and never rewritten after step 5, including no token rephrasing — see §7. |
| C6 | **M1 only — KG sidecar generator** writes `wiki/_kg.jsonl` with ≥ 8 triples on the sparse fixture | `./scripts/wiki-to-kg.py tests/eval/sparse-fixture/ > /tmp/_kg.jsonl && grep -c '"subject"' /tmp/_kg.jsonl` ≥ 8 AND `head -1 /tmp/_kg.jsonl \| python3 -c 'import sys,json; t=json.loads(sys.stdin.read()); assert set(t) >= {"subject","verb","object"}'` exits 0 |
| C7 | **M1 only — `/wiki-query` consumes the KG**: spec file references the sidecar | `grep -c 'wiki/_kg.jsonl\|_kg.jsonl' .claude/commands/wiki-query.md` ≥ 1 AND the query-time procedure must instruct reading the sidecar BEFORE answering when the question involves multi-hop (token "multi-hop" or "traversal" in the spec) |
| C8 | **M1 only — sparse-fixture eval improves**: typed ≥ baseline + 2 | `./scripts/eval-multi-hop-sparse.sh > /tmp/eval-sparse.md` AND `awk -F': ' '/^baseline:/{b=$2; sub("/.*","",b)} /^typed:/{t=$2; sub("/.*","",t)} END{exit !(t-b >= 2)}' /tmp/eval-sparse.md` exits 0. **Pre-requisite to a valid C8 measurement**: the sparse eval script must generate `wiki/_kg.jsonl` in the *typed* work dir before invoking `claude -p`, AND must NOT generate one in the baseline work dir (see §5). Without this, C8 measures a typed run that's functionally identical to baseline and is invalid. |
| C9 | Verdict logged. EITHER `M1` (phase 2b shipped, with delta) OR `M2` (gate failed, phase 2b abandoned) | `grep -q 'phase-2 kg-traversal' log.md` AND `grep -A 5 'phase-2 kg-traversal' log.md \| grep -qE 'phase-2b-shipped\|phase-2b-abandoned-on-gate'` |
| C10 | **M2 only — gate-failed mode requires PROVABLE absence of KG artifacts** (anti-game guard) | M2 acceptance ALSO requires: `! test -f scripts/wiki-to-kg.py` AND `! test -f wiki/_kg.jsonl` AND `! grep -q '_kg\.jsonl' .claude/commands/wiki-query.md` AND `! grep -q '_kg\.jsonl' .claude/commands/wiki-ingest.md`. If the agent failed C5's gate but a KG artifact is present, M2 is invalid — there is no acceptable state. (This forces the §6 step 5 ordering: the gate is enforced by the absence check, not just the iteration loop.) |

**Acceptance**:

- **M1 (build mode)**: C1 + C2 + C3 + C4 + C5 + C6 + C7 + C8 + C9 all green.
- **M2 (gate-failed mode)**: C1 + C2 + C3 + C4 + C9 + **C10** all green, AND C5 SPECIFICALLY FAILED (baseline > 40%). C10's absence checks are how the oracle proves the agent honored the stop — without them, M2 is unverifiable.

The oracle script in §9 evaluates `M1 OR M2`. C10 makes the modes mutually exclusive: under M1 the KG artifacts exist; under M2 they must not. Any state with C5 red AND any KG artifact present is rejected by both modes.

Negative-guard rows: C1 (no regression), C5-gate (no KG without proven signal), C10 (no smuggled-in KG artifacts under M2).

## 4. Scope — in / out + the boundary rule

**IN scope (Phase 2a, always):**
- Hand-crafted sparse-prose fixture at `tests/eval/sparse-fixture/` — ≥ 5 .md pages,
  each ≤ 100 words of body prose outside the `## Related` section. Pages describe
  abstract entities (NOT real-world ones — the goal is to deny the LLM external
  knowledge it can fall back on). Suggested domain: a fictional supply chain of
  invented entities (`zerlon`, `quirpal`, `bryntex` etc.) with typed relations
  between them. The pages must **not** contain any sentence that explicitly states
  a multi-hop fact; multi-hop must be derivable only by chaining `## Related` verbs.
- `tests/eval/sparse-multi-hop-questions.md` — 5–7 multi-hop questions, each tagged
  `hops: 2` or `hops: 3`, `expects: <tokens>`, and `baseline-absent: true` for
  *every* question (this fixture is built so all are baseline-absent).
- `scripts/eval-multi-hop-sparse.sh` — a thin variant of `eval-multi-hop.sh` that
  reads the new questions file and the sparse fixture. Reuse the verb-stripping logic
  from the existing harness; do not re-invent.

**IN scope (Phase 2b, *only if* C5's gate holds):**
- `scripts/wiki-to-kg.py` — stdlib Python; walks a wiki dir, parses single-target
  typed `## Related` lines, emits JSONL with shape
  `{"subject": "<page-slug>", "verb": "<verb>", "object": "<target-slug>", "attr": "<attr-or-null>", "source_page": "<path>", "source_line": <int>}`.
  Multi-link lines and untyped lines emit `verb: "related-to"`, `attr: null`.
- `.claude/commands/wiki-ingest.md` — append one step (the 8th in the existing
  pipeline): "**8. KG sidecar.** If any wiki page contains typed `## Related` lines,
  run `python3 scripts/wiki-to-kg.py wiki/ > wiki/_kg.jsonl` and overwrite the
  sidecar. Append `_kg.jsonl: N triples` to the log entry."
- `.claude/commands/wiki-query.md` — add a step before answering: "**If `wiki/_kg.jsonl`
  exists AND the question involves a multi-hop relationship (the answer requires
  chaining ≥ 2 typed-relation hops), read the sidecar in full, build the implicit
  triple graph, and use it explicitly in the answer's reasoning. Cite triples as
  `(kg: subject -[verb]-> object @ source_page:source_line)`."

**OUT of scope:**
- Any database, triplestore, RDF, SPARQL, GraphQL, or external graph library.
  Pure JSONL + LLM-in-the-loop traversal.
- Auto-generating typed verbs at ingest time (the LLM still chooses verbs from prose;
  the KG just *records* what's already in the markdown).
- Changing the existing rich-prose fixture or any wiki page outside the new sparse
  fixture.
- Cross-page contradiction detection over the KG (a fine phase-3 idea; not here).
- Visualization changes (graph.sh already filters by verb; that's enough).
- Schema-version bump (the KG sidecar is a derived artifact, not part of the
  user-facing schema).

**Boundary rule:** when a design call comes up that could touch the OUT list, take
the conservative path — leave it; don't force it. The experiment is the deliverable;
elaboration of the KG layer is later work.

## 5. Concrete deliverable artifacts

Always produced (Phase 2a):

| Path | ~Size | What it must do |
|---|---|---|
| `tests/eval/sparse-fixture/*.md` | 5–7 files, each ≤ 100 prose words | Fictional-entity sparse-prose wiki. Each page: title, 2–4 sentences of prose, then a `## Related` section with 2–4 typed entries. Pages are connected so the typed `## Related` graph contains at least one 3-hop path used by a question. |
| `tests/eval/sparse-multi-hop-questions.md` | ≤ 80 lines | 5–7 multi-hop questions in the existing format (`### Q<n>`, `expects:`, `baseline-absent:`) plus a new `hops: 2\|3` line. All tagged `baseline-absent: true`. |
| `scripts/eval-multi-hop-sparse.sh` | ≤ 100 lines | Reuses the existing `eval-multi-hop.sh` logic; takes `FIXTURE_DIR` and `QUESTIONS` as variables and points at the sparse paths. Emits the same `baseline: X/N` / `typed: Y/N` / `verdict:` lines. **Critical additional behaviour for a valid C8 measurement (Phase-2b only)**: in the *typed* work dir, after copying sparse-fixture pages, the harness MUST also run `python3 scripts/wiki-to-kg.py <typed-work-dir>/wiki/ > <typed-work-dir>/wiki/_kg.jsonl` so the typed `/wiki-query` invocation has a sidecar to read. In the *baseline* work dir, the harness MUST NOT generate `_kg.jsonl` — the baseline run is the verb-stripped, KG-less control. The script must skip the typed-side KG generation step when `scripts/wiki-to-kg.py` doesn't exist yet (Phase-2a only); in that mode both variants run sidecar-less, which is the C5 gate measurement. |

Conditionally produced (Phase 2b, only if C5's gate holds):

| Path | ~Size | What it must do |
|---|---|---|
| `scripts/wiki-to-kg.py` | ≤ 150 lines Python (stdlib) | Walks `<input_dir>` recursively for `*.md`. For each `## Related` section, parse single-target typed lines into `(subject=page-stem, verb, object=target-stem, attr)` triples. Multi-link and untyped lines emit `verb: related-to, attr: null`. Output one JSON object per line on stdout. CLI: `wiki-to-kg.py <input_dir> [--out <path>]`. |
| `.claude/commands/wiki-ingest.md` (modify) | +5 lines | Append step 8 (KG sidecar regeneration). Idempotent: if no typed lines exist, the sidecar is still written but empty (zero triples), and `_kg.jsonl: 0 triples` is logged. |
| `.claude/commands/wiki-query.md` (modify) | +8 lines | Add the "read `wiki/_kg.jsonl` when multi-hop" step before answering. Cite KG triples in the answer when used. |
| `scripts/installer-skeleton-manifest.txt` (modify) | +1 line (Phase 2b) | Add `scripts/wiki-to-kg.py` so fresh installs ship it. Sparse fixture and sparse eval are dev-only — NOT shipped (they exist to support this experiment, not for fresh users to run). |

`log.md` entry — always produced, with verdict tag.

## 6. The iteration loop the agent must follow

Each step ends with one of the C-checks. If the named check is red after **3 fix
attempts limited to that step's narrow scope**, revert that step and escalate (§7).
Commit one logical step per commit so the diff trail tracks the experiment honestly.

1. **Baseline.** `./scripts/smoke-all.sh` exit 0; `./scripts/eval-multi-hop.sh > /tmp/baseline-rich.md` exit 0 (the Brazilian-ag eval still produces a verdict). Record the C1 evidence. **If smoke-all is already red, STOP — do not proceed.**
2. **Sparse-fixture pages** → verify C2 + C3. If C2 (≤ 100 words) red, trim prose, do not add pages. If C3 (≥ 2 verbs / ≥ 8 lines) red, add edges, do not add prose.
3. **Sparse questions** → verify C4. Every Q is `hops: 2` or `hops: 3` and `baseline-absent: true`. If you cannot construct a Q where the answer token is genuinely absent from the prose, the fixture's prose is too rich — go back to step 2 and prune.
4. **Sparse eval harness** → write `scripts/eval-multi-hop-sparse.sh` as a thin variant.
5. **THE GATE** → run the sparse eval on the *current* wiki (no KG yet, no `/wiki-query` changes). Verify C5: baseline ≤ 40%. If C5 red (baseline > 40%), **STOP — log M2 (gate failed) in log.md per §7 and exit**. Do NOT proceed to step 6.
6. **(M1 only) KG generator** → write `scripts/wiki-to-kg.py`. Verify C6.
7. **(M1 only) Ingest hook** → modify `wiki-ingest.md` to call the generator. Verify by re-running an ingest path and checking `wiki/_kg.jsonl` exists.
8. **(M1 only) Query hook** → modify `wiki-query.md` to read the sidecar on multi-hop. Verify C7.
9. **(M1 only) Re-run sparse eval** → verify C8 (typed - baseline ≥ 2).
10. **Log the verdict** → C9. Either `phase-2b-shipped (baseline X/N, typed Y/N, delta D)` or `phase-2b-abandoned-on-gate (baseline X/N > 40%, KG infrastructure not built)`.
11. **(M1 only) Installer manifest** → add `scripts/wiki-to-kg.py`; re-run `verify-create-llm-wiki.sh`. Sparse fixture stays dev-only.
12. **Final gate.** Verify the full M1 or M2 set per §3.

## 7. Stop / escalate conditions (do NOT push through these)

- **Baseline already red.** `smoke-all.sh` exits non-zero on the starting commit → stop, report; do not fix smoke as part of this work.
- **THE C5 GATE FAILS (baseline > 40% on sparse fixture).** This is the most important stop. STOP, do NOT build any KG code. Log the M2 verdict to `log.md` (template: "phase-2 kg-traversal — phase-2b-abandoned-on-gate. baseline X/N (> 40% threshold). conclusion: typed relations do not provide measurable retrieval signal even on a fixture engineered to need them. no parallel KG infrastructure justified at this time. revisit when fixture / question design admits a stricter test."). Exit with C9 green and the rest of the M1-only checks deliberately unmet.
- **Question gerrymandering temptation.** If iteration on the question set makes C5 pass when it didn't before, STOP and escalate — that's the agent gaming the gate. The questions should be set in step 3 and frozen by step 5.
- **Prose creep.** If you find yourself adding prose to the sparse fixture to make a question answerable for the LLM, STOP — that defeats the experiment.
- **External dependency drift.** Any urge to reach for a graph DB, RDF library, or new pip package → STOP. The OUT list is hard.
- **KG-not-multi-hop pathway.** If you're tempted to make `/wiki-query` read `_kg.jsonl` on every query (not just multi-hop), STOP. The hook is scoped to multi-hop queries — broader scope is phase 3.
- **A revert doesn't restore green.** If reverting the last step doesn't put `smoke-all.sh` back to 0 → stop. Don't keep pulling threads.
- When in doubt → stop and report. Don't guess.

## 8. Non-goals (explicitly out of scope)

- Any external database, triplestore, RDF, SPARQL, GraphQL, embedding store, or vector index.
- A controlled-vocabulary registry of verbs.
- Auto-extraction of typed verbs at ingest time (the LLM still writes verbs from prose during `/wiki-ingest` — the KG just records what's in the markdown).
- Schema-version bump (KG sidecar is a derived artifact).
- New slash commands.
- Bidirectional or implicit-inverse edge synthesis (we don't auto-generate `is-credited-for: B` from `A serves: B`).
- Cross-source contradiction detection over the KG.
- Updating the Brazilian-ag fixture or any existing wiki page outside the sparse fixture.
- A `/wiki-visualize` style sidecar viewer for the KG.
- Migrating Phase 1's `tests/eval/wiki-fixture/` to a KG-aware form. That fixture's role is REGRESSION evidence (C1); leave it alone.

## 9. Real-data test inventory

- **Primary regression oracles** (C1): `./scripts/smoke-all.sh` (the 9-check smoke
  on the Quortex fixture) and `./scripts/eval-multi-hop.sh` (the existing eval on the
  Brazilian-ag fixture). Both must remain green / non-worse.
- **New fixture for the experiment**: `tests/eval/sparse-fixture/` (hand-crafted,
  fictional-entity, sparse-prose) + `tests/eval/sparse-multi-hop-questions.md`. The
  sparse eval is the only place where C5–C8 are decided.
- **One-shot oracle**: run `./scripts/eval-multi-hop-sparse.sh > /tmp/eval-sparse.md` first to decide M1 vs M2; then run the full §3 sweep.

## Critical files

- **New (always):**
  - `tests/eval/sparse-fixture/page-{1..5+}.md`
  - `tests/eval/sparse-multi-hop-questions.md`
  - `scripts/eval-multi-hop-sparse.sh`
- **New (only on M1):**
  - `scripts/wiki-to-kg.py`
- **Modified (only on M1):**
  - `.claude/commands/wiki-ingest.md` (+ step 8 — KG sidecar regeneration)
  - `.claude/commands/wiki-query.md` (+ multi-hop sidecar-read step)
  - `scripts/installer-skeleton-manifest.txt` (+ `scripts/wiki-to-kg.py`)
- **Modified (always — the verdict entry):**
  - `log.md`

---

## `/goal` completion-condition string

The oracle is a disjunction (M1 OR M2). Self-evaluable by the agent each turn from
files and exit codes alone, no human in the loop.

```
paste into /goal

EITHER (M1 — KG built and improves):

  `./scripts/smoke-all.sh` exits 0
  AND `./scripts/eval-multi-hop.sh > /tmp/eval-rich.md && grep -qE '^verdict: (null-result|improvement)' /tmp/eval-rich.md` (rich-prose fixture not regressed)
  AND `find tests/eval/sparse-fixture -name '*.md' -type f | wc -l` is ≥ 5
  AND C2 awk body-word counter exits 0 on the sparse fixture (every page ≤ 100 body words)
  AND C3 awk verb counter exits 0 on the sparse fixture (≥ 2 distinct verbs, ≥ 8 typed lines)
  AND C4 (a) ≥ 5 `### Q*` headings AND (b) ≥ 5 `hops: 2|3` lines AND (c) ≥ 5 `baseline-absent: true` lines AND (d) zero overlap between expects-tokens and verb literals AND (e) every expects-token is absent from the unstripped fixture prose
  AND `./scripts/eval-multi-hop-sparse.sh > /tmp/eval-sparse.md` exits 0 AND baseline X/N satisfies X*100/N ≤ 40
  AND `./scripts/wiki-to-kg.py tests/eval/sparse-fixture/ | grep -c '"subject"'` ≥ 8
  AND `grep -q '_kg\.jsonl' .claude/commands/wiki-query.md`
  AND `awk` on /tmp/eval-sparse.md shows typed - baseline ≥ 2
  AND `grep -q 'phase-2 kg-traversal' log.md` AND grep -A 5 finds `phase-2b-shipped`

OR (M2 — gate failed, honest abandonment):

  `./scripts/smoke-all.sh` exits 0
  AND `./scripts/eval-multi-hop.sh > /tmp/eval-rich.md && grep -qE '^verdict: (null-result|improvement)' /tmp/eval-rich.md`
  AND C2, C3, C4 (a–e) all green (same as M1)
  AND `./scripts/eval-multi-hop-sparse.sh > /tmp/eval-sparse.md` exits 0 AND baseline X/N satisfies X*100/N > 40 (gate FAILED)
  AND `grep -q 'phase-2 kg-traversal' log.md` AND grep -A 5 finds `phase-2b-abandoned-on-gate`
  AND `! test -f scripts/wiki-to-kg.py`
  AND `! test -f wiki/_kg.jsonl`
  AND `! grep -q '_kg\.jsonl' .claude/commands/wiki-query.md`
  AND `! grep -q '_kg\.jsonl' .claude/commands/wiki-ingest.md`
```

M1 ⊻ M2: the two modes are mutually exclusive by C10's absence checks. Any state
where C5's gate failed AND any KG artifact exists is rejected by *both* modes.

---

## Adversarial-pass results (recorded — 2026-05-27)

`code-reviewer` subagent attacked this draft. Six findings (1 CRITICAL + 4 HIGH +
1 MEDIUM); all applied. Highlights:

- **C2 word-counter bug**: original `!c||c>=2 {next}` skipped body and counted
  frontmatter — inverse of intent. Fixed to `c<2 {next}` with `/^---$/{c++; next}`
  so the delimiter doesn't fall through.
- **Verb-literal gaming**: agent could write Q's whose expects-token IS the verb
  ("what verb does the wiki use…?") — passing baseline-absent trivially. Fixed with
  C4(d): zero overlap allowed between expects-tokens and verb literals in the fixture.
- **baseline-absent not mechanically verified**: original spec accepted the
  annotation on trust. Fixed with C4(e): every expects-token must be absent from the
  unstripped prose (stricter than absent-from-stripped, mechanically checkable).
- **M2 unverifiable**: "C6/C7/C8 not attempted" was unprovable from the oracle.
  Fixed with C10: M2 requires *positive absence* of `wiki-to-kg.py`, `_kg.jsonl`,
  and `_kg.jsonl` references in the ingest/query specs.
- **Typed eval invalid without KG sidecar**: `eval-multi-hop-sparse.sh` never
  generated the sidecar in the typed work dir. Fixed in §5: spec now mandates the
  generator runs in typed, but never in baseline.
- **Step ordering only advisory**: C10's absence check makes the ordering
  mechanically enforced — not just a §7 prose plea.

