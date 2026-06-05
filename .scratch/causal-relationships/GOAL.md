---
name: causal-relationships
status: ready-for-agent
created: 2026-06-05
---

# Causal relationships as a real capability in llm-wiki-bootstrap

> Make causal links a first-class, operational part of the wiki — **authored** at ingest, **validated** at lint, **materialized** into a queryable KG, **reasoned over** multi-hop at query time, and **proven** to beat a causal-stripped baseline. Today causality is only *expressible* (an open-vocab verb on a `## Related` line) and *renderable* (the A5-causal-chain diagram archetype); nothing detects, requires, or traverses it.

## §1 Context

The system already has a **typed-relations** substrate (AGENTS.md → "Typed relations"): a `## Related` line may carry a verb — `- [[target]] <verb> [<attr>] — prose`. But the vocabulary is open, `wiki-lint-typed-relations.sh` validates only the regex *shape* of the verb (not its meaning), `/wiki-ingest`'s page template emits the plain untyped form, `/wiki-query` does plain LLM-over-markdown retrieval (no graph), and there is **no KG** (`scripts/wiki-to-kg.py` does not exist; the only references are a conditional in `eval-multi-hop-{sparse,sealed}.sh` and a now-historical phase-3 anti-gaming rule in `.scratch/phase-3-sealed-channels/GOAL.md`). The single "causal" feature in the repo, `A5-causal-chain`, is a *diagram* lens that lays an answer out as cause→effect — it does not detect causality.

**Why this change is being made.** Causal questions ("what caused X?", "what are the downstream effects of Y?") are the highest-value multi-hop queries a knowledge base can answer, and the typed-relations substrate is 80% of the way there. This iteration closes the loop across all five layers and — per the repo's own evidentiary standard — *proves* the capability discriminates against a baseline rather than merely existing.

**Intended outcome.** A new `scripts/verify-causal.sh` deterministic umbrella exits 0 (lint + KG checks), `scripts/eval-causal.sh` shows typed-causal beats a causal-stripped baseline, and the prior `smoke-all.sh` umbrella stays green (15/15).

## §2 Definition of done (one sentence)

Running `scripts/verify-causal.sh && scripts/smoke-all.sh --no-build > /dev/null` exits 0 — the causal lint accepts canonical causal edges and rejects non-canonical causal synonyms, `scripts/wiki-to-kg.py` materializes exactly the fixture's causal triples using stdlib only without mutating `wiki/`, and no prior guard regresses — AND, run locally with the `claude` CLI, `scripts/eval-causal.sh` reports `typed − baseline ≥ 2` on causal questions while a `/wiki-ingest`→`/wiki-query` smoke shows a canonical causal edge authored and a multi-hop causal chain answered.

## §3 Success checks (the oracle)

The five approved checks (C1 author · C2 validate · C3 materialize · C4 reason · C5 prove), plus regression guards. **C2, C3, and the regression/negative guards are deterministic (CI-able, no key)** and form the per-turn `/goal` completion condition. **C1, C4, C5 are LLM-gated** — they drive `claude -p` and are run locally as the final acceptance gate (the repo's existing pattern: deterministic guards in CI, LLM checks local — cf. `eval-onboarding.sh`).

### /goal completion condition (deterministic, self-evaluable each turn)

`scripts/verify-causal.sh && scripts/smoke-all.sh --no-build > /dev/null`

> **Timing note:** the condition is evaluated only at the final integration step (§6 step 8). Earlier steps gate on the narrow Verify predicate in their own §6 entry. The regression half (`smoke-all`) may go transiently red between steps that add files and the step that syncs `installer-skeleton-manifest.txt` — expected, not a stop condition.

### Deterministic checks (C2, C3 + guards)

| # | Check | How to verify (shell predicate) |
|---|---|---|
| **C2** | Causal lint accepts canonical, rejects non-canonical causal synonyms (forcing a real synonym→canonical map, not a one-string grep), and leaves `wiki/` clean | `scripts/wiki-lint-causal.sh tests/canary/causal-fixture/` exits **0** AND `! scripts/wiki-lint-causal.sh tests/canary/causal-fixture-bad/` (bad fixture exits **≠0**) AND `scripts/wiki-lint-causal.sh wiki/` exits **0**. The bad fixture contains **≥3 distinct synonyms mapping to ≥2 different canonicals** (`results-in → causes`, `due-to → caused-by`, `enabled-by → caused-by`); the lint's stderr must name **each** offending verb with its **correct** canonical (assert all three suggestion strings appear), so a lint that only special-cases one synonym fails. Mirrors the R7 good/bad/wiki idiom (`smoke-all.sh:124-126`). |
| **C3a** | KG materializes **exactly** the fixture's causal triples (not just the right count — non-hardcodable) | `python3 scripts/wiki-to-kg.py tests/canary/causal-fixture/ > /tmp/kg.jsonl` exits 0; every line is an object with keys `source,verb,target`; the **exact set** of `(source,verb,target)` tuples with `verb` ∈ `templates/causal-vocab.txt` equals the frozen step-1 topology (asserted by a `python3 -c` that loads both and compares sets, not lengths). **Input-sensitivity guard:** `python3 scripts/wiki-to-kg.py --causal-only tests/canary/causal-fixture-bad/` emits **0** causal triples (the bad fixture's verbs are all non-canonical synonyms) — a constant-output builder fails this. |
| **C3b** | KG build is stdlib-only and read-only on the wiki | `python3 -c "import ast,sys; t=ast.parse(open('scripts/wiki-to-kg.py').read()); mods={(n.module or '').split('.')[0] for n in ast.walk(t) if isinstance(n,ast.ImportFrom)}|{a.name.split('.')[0] for n in ast.walk(t) if isinstance(n,ast.Import) for a in n.names}; sys.exit(1 if (mods - sys.stdlib_module_names - {''}) else 0)"` exits 0 (uses `sys.stdlib_module_names` so any stdlib module is accepted and only a genuine third-party import fails) AND the content-unchanged guard G3 holds. |
| **G1** (negative) | No schema bump | `grep -q '\*\*Schema version:\*\* 2' AGENTS.md` (AGENTS.md:3 — the exact form the repo uses, mirroring `smoke-all.sh:88`'s R4 check) AND `! grep -q '\*\*Schema version:\*\* 3' AGENTS.md`. Causal is a vocabulary + tooling layer at v2, not a schema change. |
| **G2** (negative) | KG never auto-written at ingest | `! grep -rn '_kg.jsonl' .claude/commands/wiki-ingest.md` (ingest must NOT auto-emit the sidecar — it's a query-time/build-time artifact, kept out of the content-hash path). |
| **G3** (negative) | No protected content mutated | `[ -z "$(git status --porcelain wiki/ scripts/body-hash.sh scripts/lib/eval-common.sh)" ]` — existing wiki pages, the canonical hasher, and the reused eval lib are byte-unchanged AND no untracked sidecar was written beside them. (`git status --porcelain` catches untracked files that `git diff --quiet` misses.) **Precondition:** the loop must start from a clean, committed working tree — `scripts/lib/eval-common.sh` and the rest of the prior dedup/quality-gate work must be committed first, or G3 reports them as `??` and a dirty baseline is a §7 stop condition. |
| **R1** | Prior smoke umbrella stays green | `scripts/smoke-all.sh --no-build > /dev/null` exits 0 (15 deterministic checks at baseline → 16 after R11 is wired in step 6; the predicate only asserts exit 0, but the four hardcoded count strings must be bumped — see §6 step 6). |
| **R2** | Installer manifest in sync | `scripts/verify-create-llm-wiki.sh > /dev/null` exits 0 after the new shipped files are appended to `installer-skeleton-manifest.txt`. |
| **R3** | Typed-relations lint unbroken | `scripts/wiki-lint-typed-relations.sh tests/canary/typed-related-fixture/ >/dev/null` exits 0 AND bad fixture still exits ≠0 (the causal lint is additive, not a replacement). |

### LLM-gated checks (C1, C4, C5 — local acceptance gate)

| # | Check | How to verify |
|---|---|---|
| **C1** | Ingest authors a canonical causal edge | After `claude -p '/wiki-ingest raw/causal-smoke-source.md'` against a source with an explicit causal claim, the produced `wiki/*.md` page's `## Related` matches `grep -E '^- \[\[[a-z0-9-]+\]\] (causes\|caused-by\|enables\|prevents\|contributes-to)( \|$)'` (≥1 hit). Source must state cause→effect in prose; the page must encode it as a canonical causal edge, not implicit `related-to`. |
| **C4** | Query reasons over a causal chain multi-hop | `claude -p '/wiki-query "what ultimately caused <terminal effect> in the causal fixture?"'` against a wiki with `wiki/_kg.jsonl` present returns an answer containing every intermediate node of the K-edge chain (expects-tokens all present, case-insensitive). The same question without `_kg.jsonl` + with causal verbs stripped is the C5 baseline. |
| **C5** | Typed-causal beats causal-stripped baseline (the real-capability proof) | `scripts/eval-causal.sh` exits 0 and its report shows `delta` = `typed − baseline ≥ 2` (or `verdict: improvement`). Baseline = same fixture with causal verbs stripped (`eval_strip_related … 0`) and no `_kg.jsonl`; typed = causal verbs intact + `_kg.jsonl` built. Reuses `scripts/lib/eval-common.sh`. Deterministic floor (substring grader) + the harness’s exit-0-on-completion contract. |

**Baselines (verbatim, captured 2026-06-05):**
- `scripts/smoke-all.sh --no-build > /dev/null; echo $?` → `0` (15/15 green)
- `test -f scripts/wiki-to-kg.py; echo $?` → `1` (does not exist)
- `test -f scripts/wiki-lint-causal.sh; echo $?` → `1` (does not exist)
- `test -f scripts/eval-causal.sh; echo $?` → `1` (does not exist)
- `test -f scripts/verify-causal.sh; echo $?` → `1` (does not exist)
- `grep -rn '_kg' .claude/commands/ | wc -l` → `0` (query has no KG traversal yet)
- AGENTS.md schema version → `2`

## §4 Scope

**In scope** (agent may freely create/modify):
- `templates/causal-vocab.txt` — the canonical causal verb set (one per line): `causes`, `caused-by`, `enables`, `prevents`, `contributes-to`. Single source of truth for both the lint and the KG.
- `scripts/wiki-lint-causal.sh` — causal-vocabulary lint (canonical-set + synonym→canonical normalization map).
- `scripts/wiki-to-kg.py` — stdlib KG builder (ALL typed edges; causal is the verb-set subset).
- `scripts/eval-causal.sh` — discrimination eval, reusing `scripts/lib/eval-common.sh`.
- `scripts/verify-causal.sh` — deterministic umbrella (C2 + C3 + guards).
- `tests/canary/causal-fixture/`, `tests/canary/causal-fixture-bad/` — lint + KG fixtures.
- `tests/eval/causal-fixture/`, `tests/eval/causal-questions.md` — eval fixture + questions.
- `raw/causal-smoke-source.md` — a raw source with an explicit causal claim (for C1).
- `.claude/commands/wiki-ingest.md` — add causal-edge authoring guidance (when the source states a cause→effect, encode it with a canonical causal verb).
- `.claude/commands/wiki-query.md` — add a causal-traversal step (if `wiki/_kg.jsonl` exists and the question is causal, follow causal edges forward/backward multi-hop, cite the pages).
- `AGENTS.md` → "Typed relations" — document the canonical causal vocabulary + direction convention (source→target). **Prose/convention only — NO schema-version bump.**
- `scripts/smoke-all.sh` — wire `verify-causal.sh` as a new regression guard (R11).
- `scripts/installer-skeleton-manifest.txt` — ship ONLY the runtime capability (`templates/causal-vocab.txt`, `scripts/wiki-lint-causal.sh`, `scripts/wiki-to-kg.py`); dev-only artifacts (eval, verify umbrella, all causal fixtures, raw smoke source) are NOT manifested (see §6 step 6).
- `docs/`, `README.md` — one pointer each.
- `.scratch/causal-relationships/` — working notes.

**Adjacent-creep boundary rule:** conservative default = **leave it; don't force it**. Do NOT retrofit causal verbs into existing dev-repo `wiki/*.md` pages (causal authoring is forward-looking, applied at ingest). Do NOT change the typed-relations lint's behavior — the causal lint is a *separate, additive* script. Do NOT auto-generate `_kg.jsonl` at ingest (keep it out of the body-hash path).

**Out of scope:** see §8.

## §5 Deliverable artifacts

| Path | Purpose | Notes |
|---|---|---|
| `templates/causal-vocab.txt` | Canonical causal verbs | 5 lines: `causes caused-by enables prevents contributes-to` (one per line). The ONLY place the set is defined. |
| `scripts/wiki-lint-causal.sh` | Causal-vocab lint | Bash + awk, `#!/usr/bin/env bash`, `set -uo pipefail`. Reads `templates/causal-vocab.txt`. Walks `## Related` single-target lines (same parser shape as `wiki-lint-typed-relations.sh`). A verb that is canonical → OK. A verb present in the embedded **synonym→canonical map** (`leads-to→causes`, `results-in→causes`, `due-to→caused-by`, `because-of→caused-by`, `cause→causes`, `prevent→prevents`, `enable→enables`, `enabled-by→caused-by`, `contributes→contributes-to`) but NOT canonical → **flag to stderr** `file:line: non-canonical causal verb '<v>' → use '<canonical>'` and exit 1. Any other open verb (e.g. `founded-by`) → ignored (not causal). Exit 0 iff no flagged lines. Usage `scripts/wiki-lint-causal.sh [<path>…]` (default `wiki/`). |
| `scripts/wiki-to-kg.py` | KG builder | Python 3 **stdlib only** (any stdlib module — `collections`, `typing`, etc. are fine; C3b checks against `sys.stdlib_module_names`, not a fixed allowlist). `rglob('*.md')` under the input dir; for each single-target `## Related` line with a verb, emit one JSONL object `{"source": <file-stem>, "verb": <verb>, "target": <slug>}`. Implicit (`related-to`) and multi-link lines: emit with `verb:"related-to"` (so the KG is general). Deterministic order (sort by source,verb,target). `--causal-only` restricts output to verbs in `templates/causal-vocab.txt`. Read-only on input. ~120 lines. |
| `scripts/eval-causal.sh` | Discrimination eval | **Sources `scripts/lib/eval-common.sh`** and reuses `eval_build_variant`/`eval_strip_related`/`eval_parse_questions`/`eval_run_questions`/`eval_verdict`/`eval_grade_substring`. The `--causal-only` KG sidecar is generated **inline** in this script (`python3 scripts/wiki-to-kg.py --causal-only "$WORK/typed/wiki/" > "$WORK/typed/wiki/_kg.jsonl"`) — **NOT** via `eval_gen_kg_sidecar`, which hardcodes a non-`--causal-only` call and is on the untouchable list. typed variant: causal verbs intact + the inline sidecar; baseline variant: `eval_strip_related … 0` (verbs stripped), no sidecar. Threshold 2, prefix `eval-causal`. Exit 0 on completion. |
| `scripts/verify-causal.sh` | Deterministic umbrella | Runs C2 (lint good/bad/wiki), C3a (exact causal-triple set on good fixture + 0 on bad fixture), C3b (stdlib-only), G1, G2, G3. Exit 0 iff all pass. This is the `/goal` condition's first half. |
| `tests/canary/causal-fixture/*.md` | Lint+KG good fixture | A small **frozen** causal chain, e.g. `drought.md` → `[[yield-drop]] causes`, `yield-drop.md` → `[[price-spike]] causes`, `price-spike.md` → `[[export-ban]] causes`, `export-ban.md` (terminal). Exactly **K causal edges** (freeze K + the exact `(source,verb,target)` tuple set at step 1; with this example K=3). Each page also has ≥2 `## Related` links to satisfy the existing schema invariant. |
| `tests/canary/causal-fixture-bad/page-x.md` | Lint REJECT fixture | ≥3 single-target `## Related` lines using **distinct non-canonical synonyms mapping to ≥2 canonicals**: `- [[drought]] results-in — …` (→causes), `- [[yield-drop]] due-to — …` (→caused-by), `- [[price-spike]] enabled-by — …` (→caused-by). The causal lint MUST flag all three with their correct canonical, and `wiki-to-kg.py --causal-only` MUST emit 0 causal triples for this dir. |
| `tests/eval/causal-fixture/*.md` | Eval fixture | A causal graph rich enough for multi-hop causal questions (can extend the canary chain with branches). Pages carry canonical causal verbs. |
| `tests/eval/causal-questions.md` | Eval questions | ≥5 `### Q<n>` causal questions ("what caused X", "downstream effects of Y"), each with `expects:` (chain tokens) and `baseline-absent: true` (answerable only via causal edges the baseline strips). Same format `eval-common.sh` parses. |
| `raw/causal-smoke-source.md` | C1 source | A short raw source stating an explicit cause→effect ("The drought caused a yield drop, which drove a price spike…"), with frontmatter per the raw spec, so `/wiki-ingest` has causal material to encode. |

### Direction convention (document in AGENTS.md)

A causal verb reads **source-page → target**: on page `drought`, the line `- [[yield-drop]] causes` means *drought causes yield-drop*. Inverse verbs (`caused-by`, `enabled-by`) read target→source for the same edge. The KG records the verb verbatim; traversal interprets direction by verb.

## §6 Iteration loop (per-step cadence)

Steps are sequential. Each ends with a `feat(causal): step N — <what>` commit.

**K=3 definition:** *K counts commits in the current loop session that modify the SAME component file. After 3 such commits without that step's check turning green, STOP and escalate. Per-step; resets next step.*

1. **Author the frozen fixtures + vocab.** `templates/causal-vocab.txt`; `tests/canary/causal-fixture/` (freeze the chain topology and **K**); `tests/canary/causal-fixture-bad/page-x.md`; `tests/eval/causal-fixture/` + `tests/eval/causal-questions.md`; `raw/causal-smoke-source.md`.
   - Verify: files exist; `grep -hoE '\] (causes|caused-by|enables|prevents|contributes-to)( |$)' tests/canary/causal-fixture/*.md | wc -l` == **K**; bad fixture contains ≥3 distinct non-canonical synonyms (`results-in`, `due-to`, `enabled-by`) across ≥2 canonicals.
   - **Frozen rule:** after this commit, fixture filenames + the exact causal `(source,verb,target)` topology + K are immutable. Changes → escalate.
   - K=3.
2. **`scripts/wiki-to-kg.py`.** Verify (no LLM): C3a (exact causal tuple set == frozen topology on the good fixture AND 0 causal triples on the bad fixture) AND C3b (stdlib-only via `sys.stdlib_module_names`) AND G3 (build mutates nothing). Narrow fix: parser/regex/emit. K=3.
3. **`scripts/wiki-lint-causal.sh`.** Verify (no LLM): C2 (good=0, bad≠0, wiki/=0). Narrow fix: awk verb logic + synonym map. K=3.
4. **`scripts/eval-causal.sh`.** Verify (no LLM): `bash -n`, executable, sources `eval-common.sh`, and `--dry`-style smoke — running it with `claude` absent exits at the CLI precondition (non-zero) cleanly; with `claude` present (local) it completes and prints a `delta:` line. Narrow fix: wiring. K=3.
5. **`scripts/verify-causal.sh`** umbrella. Verify (no LLM): exits 0 (C2 + C3a + C3b + G1 + G2 + G3 all green). Narrow fix: harness. K=3.
6. **Wire regression + installer.** Add R11 (`verify-causal.sh`) to `scripts/smoke-all.sh` — this also requires bumping the **four** count strings smoke-all hardcodes: `# Exit 0 iff all 15` (line 9 → 16), `14 deterministic checks` (line 12 → 15), the `R1–R10` section label (line 58 → R1–R11), and `All 15 checks green` (line 165 → 16). **Manifest — ship ONLY the runtime capability, NOT the test scaffolding:** append exactly `templates/causal-vocab.txt`, `scripts/wiki-lint-causal.sh`, `scripts/wiki-to-kg.py` to `installer-skeleton-manifest.txt`. Do **NOT** manifest `eval-causal.sh`, `verify-causal.sh`, any `tests/canary/causal-*`, `tests/eval/causal-*`, or `raw/causal-smoke-source.md` — those are dev-only (a generated wiki must not ship demo causal content or the dev eval). Verify: `scripts/smoke-all.sh --no-build` exits 0 (now 16 deterministic checks) AND `scripts/verify-create-llm-wiki.sh` exits 0 (R2 — its exact-tree match would flag a leaked dev fixture). K=3.
7. **Command + AGENTS.md prose.** Add causal authoring guidance to `wiki-ingest.md`; causal-traversal step to `wiki-query.md`; canonical vocab + direction convention to AGENTS.md "Typed relations". Verify (no LLM): R3 (`scripts/wiki-lint-typed-relations.sh` good/bad unchanged); G1 (schema still 2); G2 (`! grep _kg.jsonl wiki-ingest.md`); `grep -q 'causes' AGENTS.md`. K=3.
8. **Deterministic integration (the condition).** `scripts/verify-causal.sh && scripts/smoke-all.sh --no-build > /dev/null` exits 0.
   - R1/R2/R3 red → STOP, escalate (baseline regression).
   - C2/C3 red → fix the owning script. K=3.
9. **LLM acceptance gate (local, needs `claude`).** Run, in order:
   - C1: `claude -p '/wiki-ingest raw/causal-smoke-source.md'` → produced page has a canonical causal edge (grep).
   - C5: `scripts/eval-causal.sh` → `delta ≥ 2` / `verdict: improvement`.
   - C4: `claude -p '/wiki-query "what ultimately caused …"'` against the typed eval wiki (with `_kg.jsonl`) → all chain tokens present.
   - If C5 shows `null-result`, treat as a *capability* gap (improve the `wiki-query.md` traversal prose or the fixture's discriminability), NOT an oracle weakening — escalate after K=3 prose iterations. **Never** lower the threshold or strip the baseline less to force a pass.
   - Add README/docs pointer last; `grep -q causal docs/* README.md`.

## §7 Stop/escalate conditions

The agent must NOT push through any of these:
- **Gaming the oracle:** weakening C2/C3 predicates; making the canary chain trivial so K is degenerate; lowering the C5 threshold below 2; stripping the baseline *more* (or the typed variant *less*) to manufacture a delta; hand-writing the C1 causal edge into the fixture page instead of having `/wiki-ingest` author it from the raw source; emitting fake KG triples not parsed from the fixture.
- **Schema pressure (G1):** if a check would only pass by bumping AGENTS.md `schema_version` past 2, STOP — causal is a vocab+tooling layer, not a schema change.
- **Prior-umbrella regression (R1/R2/R3):** green-before → red-after on `smoke-all.sh`/`verify-create-llm-wiki.sh`/typed-relations lint ⇒ STOP, escalate.
- **eval-multi-hop interaction:** creating `scripts/wiki-to-kg.py` makes `eval-multi-hop-{sparse,sealed}.sh` start generating `_kg.jsonl` in their typed variant (they key on `[ -f "$KG_GENERATOR" ]`). This is **intended convergence** (one real KG builder), NOT a regression — those evals need `claude` and are out of CI. Do not delete or special-case the generator to keep them sidecar-less; if their *documented* semantics must be preserved, note it and escalate rather than guessing.
- **Ontology pressure:** expanding the canonical causal set beyond the approved 5, or changing the source→target direction convention, is an architectural decision → escalate, don't decide.
- **K=3** on the same component without its check turning green.
- **Infra flakiness:** transient `claude`/`python3`/`mktemp` failures → retry ≤3, then escalate.
- **Frozen-artifact re-edits:** fixtures/K after step 1 → escalate.

## §8 Non-goals (explicit out-of-scope)
- **Causal inference / statistical causality** (do-calculus, confounders, RCT reasoning). This is *asserted* causality from sources, encoded as typed edges — not learned causality.
- **Retrofitting causal verbs into existing dev-repo `wiki/` pages.** Forward-looking only.
- **A controlled vocabulary beyond the approved 5 verbs**, or per-domain causal ontologies.
- **Auto-emitting `wiki/_kg.jsonl` at ingest** or folding it into the body-hash. It's a build/query artifact, materialized on demand.
- **Cycle detection / contradiction reasoning over causal graphs** (e.g. A causes B causes A). Lint validates vocabulary, not graph semantics.
- **A visual causal-graph renderer** beyond what `scripts/visualize/graph.sh` already gives by grouping edges by verb.
- **MCP/slash-command parity** beyond the prose added to `wiki-ingest.md` / `wiki-query.md`.
- **Schema-version bump.**

## §9 Real-data test inventory

**Primary oracle (deterministic):** `scripts/verify-causal.sh` (NEW) — C2 lint good/bad/wiki + C3 KG count/stdlib/read-only + G1/G2. Plus `scripts/smoke-all.sh --no-build` (regression, now incl. R11).

**LLM acceptance (local, needs `claude`):** `scripts/eval-causal.sh` (typed vs causal-stripped baseline, delta ≥ 2); `/wiki-ingest` C1 smoke; `/wiki-query` C4 smoke.

**Fixtures (this iteration):** `tests/canary/causal-fixture/` (+ `-bad/`), `tests/eval/causal-fixture/` + `tests/eval/causal-questions.md`, `raw/causal-smoke-source.md`.

**Existing fixtures preserved as baseline (R1/R2/R3):** everything `smoke-all.sh` and `verify-create-llm-wiki.sh` cover; the typed-relations canary fixtures.

**Before/after:** Before — `wiki-to-kg.py`/`wiki-lint-causal.sh`/`eval-causal.sh`/`verify-causal.sh` and all causal fixtures absent; `/wiki-query` has no causal traversal. After — all present; `verify-causal.sh` exits 0; `eval-causal.sh` shows typed beats baseline; a causal question returns the full chain.

## Critical files

**New:** `templates/causal-vocab.txt` · `scripts/wiki-lint-causal.sh` · `scripts/wiki-to-kg.py` · `scripts/eval-causal.sh` · `scripts/verify-causal.sh` · `tests/canary/causal-fixture/*.md` · `tests/canary/causal-fixture-bad/page-x.md` · `tests/eval/causal-fixture/*.md` · `tests/eval/causal-questions.md` · `raw/causal-smoke-source.md` · `.scratch/causal-relationships/GOAL.md` (this file)

**Modified:** `scripts/smoke-all.sh` (R11) · `scripts/installer-skeleton-manifest.txt` · `.claude/commands/wiki-ingest.md` · `.claude/commands/wiki-query.md` · `AGENTS.md` ("Typed relations" prose only) · `docs/*` + `README.md` (pointers)

**Untouched (regression guards):** existing `wiki/*.md`, `scripts/smoke-*.sh` core, `scripts/create-llm-wiki.sh`, `scripts/verify-create-llm-wiki.sh`, typed-relations lint + its fixtures, `scripts/lib/eval-common.sh` (reused, not modified), schema version (stays 2).

## After approval
Ready for `/goal`, `claude -p`, a worktree agent, or AFK. This skill does not dispatch the loop.
