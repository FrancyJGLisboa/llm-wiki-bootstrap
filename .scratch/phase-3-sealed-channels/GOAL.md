# GOAL: phase-3 sealed-channels eval — closing the four leak channels found in phase-2

> Hand-off spec for an autonomous coding agent. Self-contained. The agent iterates
> until every check in §3 passes, using §6 as the loop and §7 as the stop rules.
> Stylistic and structural conventions match `.scratch/phase-2-kg-traversal/GOAL.md`
> — the same M1 / M2 acceptance disjunction, the same anti-game guards, the same
> frozen-after-step-5 question discipline.

## 1. Context — why this exists

Phase-2 ran a sparse-prose, fictional-entity eval (`.scratch/phase-2-kg-traversal/`)
and the gate failed at **baseline 7/7 = 100%**. The M2 log entry identified three
leak channels the LLM used to recover direction without typed verbs:

1. **Connectivity** — stripped `## Related` lines retain `[[slug]]` targets, so
   the undirected graph is intact.
2. **Tag semantics** — frontmatter `tags: [..., ore, refinery, port]` lets the
   LLM apply real-world supply-chain priors to the fictional names.
3. **Question-text-as-teacher** — phase-2's questions named the verbs in the
   prompt (`"Following forward supply edges (feeds, powers, produces, ...)"`),
   re-introducing the very signal the baseline strip removed.

Plus one channel that was anticipated but not yet exploited:

4. **Slug priors** — entity slugs like `mordax` ("vessel"), `velnar` ("port")
   carry no explicit meaning, but combined with the tags they become semantic
   anchors. With tags also stripped, slug priors remain a residual leak path.

This spec exists to design and run **the next experiment that closes all four
channels** — and to do so under a strictly stricter gate. If THIS experiment
also says "the LLM doesn't need typed structure," that is a much stronger
null-result than phase-2's and retires the parallel-KG idea on **this fixture
+ grader class** (not for all time and all architectures — see §1.1 below).
If, instead, the sealed-channels eval finally discriminates (baseline < 30%
of questions), Phase-3b ships the minimal KG sidecar that phase-2 declined.

Hard pre-decision: this work proceeds in two ordered phases, with a **gate** in
between. The agent must STOP at the gate if it fails — do not build KG code on
top of another null-result.

- **Phase 3a (the experiment).** Build a hand-crafted **sealed-channel fixture**
  that closes leak channels 1–4. The baseline harness strips **verbs, attrs,
  AND `tags:` frontmatter lines** (a stricter strip than phase-2's verbs-only).
  Questions are **verb-neutral** (do NOT name any verb in the prompt) and have
  **numeric answers ≥ 4 digits long** (so the substring-grader can't false-pass
  on incidental short-number coincidences in baseline prose — see §5). Answers
  are computed by **summing or otherwise composing `attr` integers across
  hops** — attrs get stripped from baseline, so baseline cannot reach the
  answer except by hallucinating a multi-digit number. Slugs are random
  pseudonyms with no English-word substring of length ≥ 4. If baseline still
  passes ≥ 30% of the questions on this sealed-channels fixture, phase-3b is
  **abandoned** on this fixture/grader class (M2: null-result, no parallel KG
  infrastructure on this design, recorded in log.md).

- **Phase 3b (the build).** Only if Phase 3a's gate holds: ship the same
  minimum-viable KG layer phase-2 declined — `scripts/wiki-to-kg.py` writes
  `wiki/_kg.jsonl` from typed `## Related` lines (subject / verb / attr /
  object plus parsed `attr_num`), `/wiki-ingest` regenerates the sidecar,
  `/wiki-query` reads it for multi-hop questions. Re-run the sealed-channels
  eval; require typed ≥ baseline + 3 (one tighter than phase-2's + 2, because
  the sealed gate's absolute baseline is lower — so the absolute delta needs
  to be larger to be meaningful).

Anti-failure-mode: this spec is structured so that a "build it anyway" agent
gets a red C9 / C14 / C15 and has to stop. The C-gates are in §3, not just in
§6's iteration loop.

### 1.1 Scope of the null-result claim

If C9 fails (M2), the conclusion recorded in `log.md` is narrowly worded:
"the typed-relations + JSONL-sidecar design does not measurably help on this
fixture/grader class." It is NOT "the LLM never needs typed structure." A
later experiment that changes the grader, the prompt framework, or the
verb/attr schema can revisit the question. The M2 entry must include the
channel-closure inventory (§3 C15) so the next person sees what was actually
sealed.

## 2. Definition of done (one sentence)

Either (a) phase-3a's sealed-channels eval shows baseline-stripped wiki fails
≥ 70% of the multi-hop questions AND phase-3b's KG sidecar + `/wiki-query`
traversal lifts typed runs by ≥ 3 over baseline on that same fixture, with no
regression on the existing Brazilian-ag fixture and the phase-2 sparse harness
remaining intact (verified by bash-syntax check, not a full LLM-call rerun —
see C2); OR (b) phase-3a's eval shows baseline still passes ≥ 30%, the gate
fails, and the null-result is logged in `log.md` with phase-3b explicitly
abandoned and the channel-closure inventory recorded.

Both outcomes are valid "done" states — the deliverable is the **conclusion**,
not the code.

## 3. Success checks — ALL green (the oracle)

The oracle has **two acceptance modes**: build-and-improve (M1) or
gate-failed-and-logged (M2). The full oracle is `M1 OR M2`. C14 (artifact-absence
under M2) and C15 (channel-closure proof) make the modes mutually exclusive and
prevent both directions of gaming.

**Boundary discipline (read carefully).** The gate is strict less-than: M1
requires `baseline*100 < 30*N` (strictly under 30%); M2 requires `baseline*100
>= 30*N` (at-or-above 30%). The two are exhaustive and disjoint for any
integer X, N — no ambiguous boundary case.

| # | Check | How to verify |
|---|---|---|
| C1 | **PRIMARY REGRESSION ORACLE (rich-prose)**: existing pipeline + Brazilian-ag eval don't regress | `./scripts/smoke-all.sh` exits 0 AND `./scripts/eval-multi-hop.sh > /tmp/eval-rich.md && grep -qE '^verdict: (null-result\|improvement)' /tmp/eval-rich.md` |
| C2 | **SECONDARY REGRESSION CHEAP-CHECK (sparse harness intact)**: phase-2 sparse-eval script is still syntactically valid and unmodified by phase-3 work | `bash -n scripts/eval-multi-hop-sparse.sh` exits 0 AND `git diff HEAD scripts/eval-multi-hop-sparse.sh` produces no output (phase-3 work does not touch the phase-2 harness). **Note**: a full rerun of the phase-2 eval is NOT required here — that would cost ~14 extra LLM calls per iteration. The syntactic + unchanged check is the regression guard. |
| C3 | Sealed fixture exists, ≥ 6 pages, each ≤ 80 words of body prose | `find tests/eval/sealed-fixture -name '*.md' -type f \| wc -l` ≥ 6 AND the same awk body-word counter from phase-2 (with the threshold lowered to 80) exits 0 |
| C4 | Sealed fixture uses **pseudonym slugs** with no English-word substring of length ≥ 4 from the stoplist | Extract every `[[slug]]` from fixture files, then for each slug, `grep -iF -f tests/eval/sealed-fixture-stoplist.txt <<< "$slug"` must return zero matches. The stoplist file enumerates ~30 short common English words (`port`, `ore`, `ship`, `mine`, `power`, `feed`, `load`, etc.) plus a guard against the phase-2 slugs (`zerlon`, `quirpal`, `bryntex`, `mordax`, `velnar`, `thalox`, `glivex`) so a lazy agent can't reuse them. Slugs themselves match `[a-z]{5,7}`. |
| C5 | Sealed fixture has **no semantic tags**: every `tags:` field is exactly `tags: [sealed-fixture, node]` (the canonical sealed form) | `awk '/^tags:/' tests/eval/sealed-fixture/*.md \| sort -u \| wc -l` ≤ 1 AND the single line (if present) is exactly `tags: [sealed-fixture, node]`. |
| C6 | Sealed fixture has ≥ 3 distinct verbs across ≥ 10 typed Related lines, AND every typed Related line carries a numeric `attr` | reuse phase-2's verb/line awk with thresholds raised to `t>=10 && n>=3`; ADDITIONALLY, every single-target Related line must match (in awk): `^[[:space:]]*-[[:space:]]+\[\[[a-z][a-z0-9-]*\]\][[:space:]]+[a-z][a-z0-9-]*[[:space:]]+[0-9]+[[:space:]]+(—\|--)` (target, verb, integer attr, em-dash). |
| C7 | Sealed multi-hop questions: ≥ 10 questions, all hops 2 or 3, all baseline-absent, expects-tokens are 4+-digit integers, AND question text is verb-neutral | (a) `grep -c '^### Q[0-9]\+' tests/eval/sealed-multi-hop-questions.md` ≥ 10; (b) `grep -c '^hops:[[:space:]]*[23]' …` ≥ 10; (c) `grep -c '^baseline-absent:[[:space:]]*true' …` ≥ 10; (d) every expects-token matches `^[0-9]{4,}$` (≥ 4 digits — the lower bound makes incidental substring coincidence in baseline prose statistically rare); (e) **for each verb V in the fixture, `grep -iF "$V" tests/eval/sealed-multi-hop-questions.md` returns zero matches** (closes leak channel 3 — using plain `-iF` substring, not `-w`, because kebab verbs like `ships-via` would otherwise let `ships` slip through); (f) every expects-token is absent from the fixture per `grep -F` over `tests/eval/sealed-fixture/*.md` (closes the trivial leak where the LLM finds the number in prose). |
| C8 | **The sealed strip-harness strips verbs, attrs, AND tags from the baseline** (closes leak channels 1 + 2 mechanically) | `./scripts/eval-multi-hop-sealed.sh --dry-run-baseline > /tmp/baseline-dump.txt` exits 0 AND (a) `grep -cE '^tags:' /tmp/baseline-dump.txt` is 0 (tags-line stripped); AND (b) for the awk inside the dry-run output, no Related line carries a multi-digit numeric token: `awk '/^[[:space:]]*-[[:space:]]+\[\[/{if (match($0, /[0-9]{4,}/)) {print FILENAME":"NR; exit 1}} END{exit 0}' /tmp/baseline-dump.txt` exits 0; AND (c) for the awk inside the dry-run output, no Related line carries a typed verb (every `]]` is immediately followed by whitespace + em-dash or `--`, optionally with the literal word `attr-stripped` as a sentinel): the harness writes a deterministic post-strip shape and the dry-run check confirms it. |
| C9 | **THE GATE — baseline-stripped sealed fixture must FAIL** the new eval | `./scripts/eval-multi-hop-sealed.sh > /tmp/eval-sealed.md` exits 0 AND `awk -F'[: /]+' '/^baseline:/{b=$2; n=$3; exit !(b*100 < 30*n)}' /tmp/eval-sealed.md` exits 0 (i.e. `baseline*100 < 30*N`). If the awk exits non-zero (baseline at or above 30%), the experiment failed to discriminate and phase-3b is forbidden — see §6 step 6 and §7 stop conditions. **Frozen-by-design**: question set committed at §6 step 4 and not modified after step 6. |
| C10 | **M1 only — KG sidecar generator** writes `wiki/_kg.jsonl` with ≥ 10 triples on the sealed fixture, each carrying numeric `attr` parsed into `attr_num` | `./scripts/wiki-to-kg.py tests/eval/sealed-fixture/ > /tmp/_kg.jsonl && grep -c '"subject"' /tmp/_kg.jsonl` ≥ 10 AND `head -1 /tmp/_kg.jsonl \| python3 -c 'import sys,json; t=json.loads(sys.stdin.read()); assert {"subject","verb","object","attr","attr_num"} <= set(t); assert isinstance(t["attr_num"], int)'` exits 0 |
| C11 | **M1 only — `/wiki-query` reads the sidecar** for multi-hop with numeric composition | `grep -c '_kg\.jsonl' .claude/commands/wiki-query.md` ≥ 1 AND `grep -iE 'attr_num\|sum.*attr\|compose.*attr' .claude/commands/wiki-query.md` ≥ 1 (the multi-hop instruction explicitly says to compose `attr_num` values across triples when the question is numeric) |
| C12 | **M1 only — sealed-fixture eval improves**: typed ≥ baseline + 3 | `awk -F': ' '/^baseline:/{b=$2; sub("/.*","",b)} /^typed:/{t=$2; sub("/.*","",t)} END{exit !(t-b >= 3)}' /tmp/eval-sealed.md` exits 0. **Pre-requisite**: the sealed eval script must generate `wiki/_kg.jsonl` in the *typed* work dir (only) before invoking `claude -p`. The harness must also strip attrs in baseline so the typed run is the only one that retains numeric signal. |
| C13 | Verdict logged in `log.md` with a phase-3 entry | `grep -q 'phase-3 sealed-channels' log.md` AND `grep -A 6 'phase-3 sealed-channels' log.md \| grep -qE 'phase-3b-shipped\|phase-3b-abandoned-on-gate'` |
| C14 | **M2 only — anti-game absence guards** | M2 acceptance ALSO requires: `! test -f scripts/wiki-to-kg.py` AND `! test -f wiki/_kg.jsonl` AND `! grep -q '_kg\.jsonl' .claude/commands/wiki-query.md` AND `! grep -q '_kg\.jsonl' .claude/commands/wiki-ingest.md`. **Strict-absence rule for wiki-to-kg.py**: even though a previous Phase-3 attempt might have created the script, under M2 it must be deleted — leaving it in place would cause `eval-multi-hop-sealed.sh` to silently treat the *typed* variant as "typed + KG" and contaminate C9. The only honest M2 state is: no generator, no sidecar, no spec references. |
| C15 | **M2 only — channel-closure proof**: each of the four leak channels is mechanically demonstrated closed | (1) tags closure: C5 green (closes channel 2); (2) prompt closure: C7(e) green (closes channel 3); (3) slug closure: C4 green (closes channel 4); (4) attr+verb closure: C8 green (closes channel 1's verbs + the additional attr-stripping the sealed strip introduces). All four must be green for M2. |

**Acceptance**:

- **M1 (build mode)**: C1 + C2 + C3 + C4 + C5 + C6 + C7 + C8 + C9 + C10 + C11 + C12 + C13 all green.
- **M2 (gate-failed mode)**: C1 + C2 + C3 + C4 + C5 + C6 + C7 + C8 + C13 + C14 + C15 all green, AND C9 SPECIFICALLY FAILED (`baseline*100 >= 30*N`). C12 must be unmet (no KG-driven improvement measured).

The oracle script in §9 evaluates `M1 OR M2`. The two modes are mutually exclusive
by C14: under M1 `scripts/wiki-to-kg.py` and `wiki/_kg.jsonl` exist; under M2 they
must not.

Negative-guard rows: C1 + C2 (no regression on prior phases), C9-gate (no KG
without proven signal), C14 (no smuggled-in KG artifacts under M2), C15 (no
smuggled-in leak channels into the experiment).

## 4. Scope — in / out + the boundary rule

**IN scope (Phase 3a, always):**

- Hand-crafted sealed-channel fixture at `tests/eval/sealed-fixture/` — ≥ 6 .md
  pages, each ≤ 80 words of body prose outside the `## Related` section. Body
  prose is **near-identical across pages** (an explicit template; only the
  title and one or two neutral pronoun-style swaps differ). The intent is to
  make body prose carry **zero signal**.
- `tests/eval/sealed-fixture-stoplist.txt` — list of ~30 short English words
  (`port`, `ore`, `ship`, `mine`, `feed`, `load`, `road`, `boat`, `power`,
  `train`, `cargo`, etc.) plus phase-2's slugs. Used to mechanically gate slug
  choice via C4.
- `tests/eval/sealed-multi-hop-questions.md` — **≥ 10 questions** (raised from
  phase-2's 5–7 because the gate is stricter and N must support the threshold
  arithmetic without single-coincidence noise dominating), each tagged `hops:
  2` or `hops: 3`, `expects: <4+-digit integer>`, `baseline-absent: true`.
  Question prose is **verb-neutral**: it talks about "the typed `## Related`
  numbers" or "the chain", never about `feeds`/`powers`/etc.
- `scripts/eval-multi-hop-sealed.sh` — variant of `eval-multi-hop.sh`. Its
  baseline-strip removes **`^tags:` lines, verbs, AND attrs** from single-target
  Related lines. It supports `--dry-run-baseline` to emit the post-strip
  baseline wiki to stdout for C8 inspection. Like phase-2's sparse harness, it
  conditionally generates `wiki/_kg.jsonl` in the typed work dir only when
  `scripts/wiki-to-kg.py` exists, and never in baseline.
- **Numeric grader patch in the harness**: the per-token PASS/FAIL grader in
  the sealed harness must NOT reuse phase-2's `grep -q -F -i` for numeric
  expects. For numeric tokens (`^[0-9]+$`), grading must use the word-boundary
  pattern `grep -qE "(^|[^0-9])${token}([^0-9]|\$)"` — substring match would
  false-pass on common short-number coincidences in baseline prose. This is a
  bug carried over from phase-2 that phase-3 cannot inherit.

**IN scope (Phase 3b, *only if* C9's gate holds):**

- `scripts/wiki-to-kg.py` — stdlib Python, walks wiki dir, emits one JSON
  object per typed Related line with `{subject, verb, object, attr, attr_num,
  source_page, source_line}`. `attr_num` is the parsed integer or `null`.
- `.claude/commands/wiki-ingest.md` — append a step: "If any wiki page contains
  typed `## Related` lines, run `python3 scripts/wiki-to-kg.py wiki/ > wiki/_kg.jsonl`."
- `.claude/commands/wiki-query.md` — add a step: "If `wiki/_kg.jsonl` exists
  AND the question is numeric AND it references a chain or path, read the
  sidecar, find the matching chain, and **sum / compose `attr_num` values**
  across the matching hops to produce the numeric answer. Cite each triple."

**OUT of scope:**

- Any database, triplestore, RDF, SPARQL, embedding store, vector index.
- Auto-generating verbs or attrs at ingest time.
- Schema-version bump.
- New slash commands.
- Cross-source contradiction detection over the KG.
- Visualization changes for `attr_num` (a fine phase-4 idea; not here).
- Touching Phase-1's rich-prose fixture or Phase-2's sparse fixture (both are
  regression oracles, leave them alone).
- A controlled-vocabulary registry of verbs.

**Boundary rule:** when a design call comes up that could touch the OUT list,
take the conservative path — leave it; don't force it. The experiment is the
deliverable.

## 5. Concrete deliverable artifacts

Always produced (Phase 3a):

| Path | ~Size | What it must do |
|---|---|---|
| `tests/eval/sealed-fixture/*.md` | 6–8 files, each ≤ 80 prose words | Pseudonym-slug pages, near-identical body template, single canonical `tags` line (`tags: [sealed-fixture, node]`), `## Related` block with ≥ 3 verbs and ≥ 10 typed lines, every typed line carries an integer `attr`. Pages connected so the typed graph contains at least one numeric-summation chain ≥ 3 hops long used by a question. Attrs chosen so that summation along the question chain yields a ≥ 4-digit answer absent from the file. |
| `tests/eval/sealed-fixture-stoplist.txt` | ≤ 40 lines | One short word per line: common-English nouns + phase-2 slugs. Read by C4's mechanical check. |
| `tests/eval/sealed-multi-hop-questions.md` | ≤ 110 lines | 10–12 multi-hop questions; expects are 4+-digit integers; question prose is verb-neutral. |
| `scripts/eval-multi-hop-sealed.sh` | ≤ 150 lines | Reuses phase-2's harness shape. Critical extensions: (a) baseline-strip also removes `^tags:` lines AND attrs in typed Related lines (the attr is the second whitespace-delimited token after `]]`); (b) numeric-grader uses word-boundary regex (`grep -qE "(^\|[^0-9])${token}([^0-9]\|\$)"`) for any expects-token matching `^[0-9]+$` — substring grader would false-pass; (c) supports `--dry-run-baseline` to dump the post-strip baseline wiki; (d) typed-side runs `python3 scripts/wiki-to-kg.py <typed-dir>/wiki/ > <typed-dir>/wiki/_kg.jsonl` only when the generator file exists; baseline-side never does. |

Conditionally produced (Phase 3b, only if C9's gate holds):

| Path | ~Size | What it must do |
|---|---|---|
| `scripts/wiki-to-kg.py` | ≤ 200 lines Python (stdlib) | Walks `<input_dir>` recursively for `*.md`. For each `## Related` section, parse single-target typed lines into `(subject, verb, object, attr, attr_num, source_page, source_line)` triples. Multi-link and untyped lines emit `verb: related-to, attr: null, attr_num: null`. Output one JSON object per line on stdout. CLI: `wiki-to-kg.py <input_dir> [--out <path>]`. |
| `.claude/commands/wiki-ingest.md` (modify) | +6 lines | Append step 8 (KG sidecar regeneration); idempotent on empty graphs. |
| `.claude/commands/wiki-query.md` (modify) | +10 lines | Add the multi-hop-with-numeric-composition step. Cite triples; cite the summation. |
| `scripts/installer-skeleton-manifest.txt` (modify) | +1 line | Add `scripts/wiki-to-kg.py` so fresh installs ship it. Sealed fixture stays dev-only. |

`log.md` entry — always produced, with verdict tag.

## 6. The iteration loop the agent must follow

**Budget note.** Each gate iteration runs: smoke (~9 checks) + the sealed eval
(N×2 ≈ 20–24 `claude -p` calls if N=10). Rich/sparse evals run ONCE at step 1
to set the C1+C2 baseline and are NOT re-run per iteration. Reflexive retries
of the gate are the largest cost driver — if the gate is red, follow §7's
stop rules, don't burn the budget re-running.

Each step ends with one of the C-checks. If a check is red after 3 fix
attempts limited to that step's narrow scope, revert and escalate (§7).
Commit one logical step per commit.

1. **Baseline.** `./scripts/smoke-all.sh` exit 0; `./scripts/eval-multi-hop.sh
   > /tmp/eval-rich.md` exit 0 with verdict in `{null-result, improvement}`;
   `bash -n scripts/eval-multi-hop-sparse.sh` exits 0 AND `git diff HEAD
   scripts/eval-multi-hop-sparse.sh` is empty. Record C1 + C2 evidence. **If
   any is red, STOP** — don't fix prior phases as part of this work.
2. **Stoplist file** → write `tests/eval/sealed-fixture-stoplist.txt`. Verify
   it has at least 30 entries; verify phase-2 slugs are present.
3. **Sealed fixture pages** → verify C3 + C4 + C5 + C6. Tight loop: write 1
   page first, run all four greps, then scale. If C4 (stoplist) red, rename
   slug; if C5 (tags) red, rewrite the tags line; if C6 (attr presence) red,
   add the integer attr token; if C3 (≤ 80 words) red, trim prose.
4. **Sealed questions** → verify C7. Every Q is hops 2/3, baseline-absent,
   numeric ≥ 4 digits, verb-neutral.
5. **Sealed eval harness** → write `scripts/eval-multi-hop-sealed.sh` with
   tags+verbs+attrs strip AND the word-boundary numeric grader. Verify C8 via
   `--dry-run-baseline`. Verify the grader change with a unit-style probe:
   produce a synthetic baseline answer containing `"page 12 of the report"`
   and grade against `expects: 12`; the grader must return FAIL (substring
   would pass).
6. **THE GATE** → run the sealed eval. Verify C9: `baseline*100 < 30*N`. If
   C9 red, **STOP — log M2 (gate failed) and exit**. Phase-3 has then
   retired the parallel-KG idea on this fixture/grader class; the log entry
   must spell out the channel-closure inventory. **Do NOT proceed to step 7.**
7. **(M1 only) KG generator** → write `scripts/wiki-to-kg.py` with `attr_num`.
   Verify C10.
8. **(M1 only) Ingest hook** → modify `wiki-ingest.md`.
9. **(M1 only) Query hook** → modify `wiki-query.md` with the
   numeric-composition step. Verify C11.
10. **(M1 only) Re-run sealed eval** → verify C12 (typed - baseline ≥ 3).
11. **Log the verdict** → C13. Either `phase-3b-shipped (baseline X/N, typed
    Y/N, delta D, channels-closed: connectivity+tags+verbs+slugs+attrs)` or
    `phase-3b-abandoned-on-gate (baseline X/N >= 30%, all four channels
    closed, KG infrastructure retired on this fixture/grader class)`.
12. **(M1 only) Installer manifest** → add `scripts/wiki-to-kg.py`; re-run
    `verify-create-llm-wiki.sh`. Sealed fixture stays dev-only.
13. **Final gate.** Verify the full M1 or M2 set per §3.

## 7. Stop / escalate conditions (do NOT push through these)

- **Baseline already red.** Any of smoke-all, the rich eval, or the sparse
  bash-syntax check is non-zero on the starting commit → stop, report.
- **THE C9 GATE FAILS (`baseline*100 >= 30*N`).** STOP, do NOT build any KG
  code. Log the M2 verdict with the channel-closure inventory.
- **Question gerrymandering temptation.** If iteration on the question set
  makes C9 pass when it didn't before, STOP and escalate. Questions are
  committed at step 4 and frozen by step 6.
- **Stoplist game.** If the stoplist gets shortened to accommodate a slug,
  STOP — that's defeating C4. The stoplist is part of the design.
- **Tag-leak creep.** If you add a non-sealed tag line to make a page parse
  better in some viewer, STOP — that defeats C5.
- **Prose creep.** If body prose grows past 80 words, STOP — that defeats C3.
- **Attr leak in baseline.** If a numeric attr survives the strip into
  baseline (visible in the `--dry-run-baseline` dump), STOP — C8 is the
  central anti-cheating guard. Fix the strip, don't fix the dump.
- **Grader regression.** If the numeric grader is replaced with substring
  match to get the gate to pass, STOP — that's the canonical instance of
  blocker-1 sabotage.
- **External dependency drift.** Any urge to reach for a graph DB, RDF, or new
  pip package → STOP.
- **KG-not-multi-hop pathway.** If `/wiki-query` is tempted to read
  `_kg.jsonl` on every query (not just multi-hop numeric ones), STOP.
- **A revert doesn't restore green.** If reverting the last step doesn't put
  prior smokes back to 0 → stop. Don't keep pulling threads.
- When in doubt → stop and report.

## 8. Non-goals (explicitly out of scope)

- Any external database, triplestore, RDF, SPARQL, GraphQL, embedding store,
  vector index.
- A controlled-vocabulary registry of verbs.
- Auto-extraction of typed verbs at ingest time.
- Schema-version bump.
- New slash commands.
- Bidirectional / implicit-inverse edge synthesis.
- Cross-source contradiction detection over the KG.
- Updating Phase-1's rich-prose fixture or Phase-2's sparse fixture.
- A sidecar viewer for `_kg.jsonl`.

## 9. Real-data test inventory

- **Primary regression oracles**: `./scripts/smoke-all.sh` (the 9-check smoke
  on the Quortex fixture) and `./scripts/eval-multi-hop.sh` (the rich-prose
  Brazilian-ag eval). Both must remain green / non-worse (C1).
- **Cheap secondary regression**: `bash -n scripts/eval-multi-hop-sparse.sh`
  plus a `git diff HEAD` emptiness check on that script. The phase-2 harness
  is not re-run per iteration — re-running it costs ~14 LLM calls and the
  goal is only to prove this work doesn't touch it (C2).
- **New fixture for the experiment**: `tests/eval/sealed-fixture/` +
  `tests/eval/sealed-multi-hop-questions.md` +
  `tests/eval/sealed-fixture-stoplist.txt`. The sealed eval is the only
  place where C9–C12 are decided.
- **One-shot oracle**: run `./scripts/eval-multi-hop-sealed.sh >
  /tmp/eval-sealed.md` first to decide M1 vs M2; then run the full §3 sweep.

## Critical files

- **New (always):**
  - `tests/eval/sealed-fixture/page-*.md` (6–8 files with pseudonym slugs)
  - `tests/eval/sealed-fixture-stoplist.txt`
  - `tests/eval/sealed-multi-hop-questions.md`
  - `scripts/eval-multi-hop-sealed.sh`
- **New (only on M1):**
  - `scripts/wiki-to-kg.py` (with `attr_num` parsing)
- **Modified (only on M1):**
  - `.claude/commands/wiki-ingest.md` (+ KG sidecar regeneration step)
  - `.claude/commands/wiki-query.md` (+ multi-hop-numeric-composition step)
  - `scripts/installer-skeleton-manifest.txt` (+ `scripts/wiki-to-kg.py`)
- **Modified (always — the verdict entry):**
  - `log.md`

---

## `/goal` completion-condition string

The oracle is a disjunction (M1 OR M2). Self-evaluable by the agent each turn
from files and exit codes alone.

```
paste into /goal

EITHER (M1 — KG built and improves):

  `./scripts/smoke-all.sh` exits 0
  AND `./scripts/eval-multi-hop.sh > /tmp/eval-rich.md && grep -qE '^verdict: (null-result|improvement)' /tmp/eval-rich.md`
  AND `bash -n scripts/eval-multi-hop-sparse.sh` exits 0
  AND `git diff HEAD scripts/eval-multi-hop-sparse.sh` is empty
  AND `find tests/eval/sealed-fixture -name '*.md' -type f | wc -l` is ≥ 6
  AND C3 body-word counter exits 0 (every page ≤ 80 body words)
  AND C4 slug-stoplist check returns zero matches
  AND C5 `awk` confirms every tags: line is the literal `tags: [sealed-fixture, node]` (or absent)
  AND C6 awk verb/attr counter exits 0 (≥ 3 verbs, ≥ 10 typed lines, every typed line carries an integer attr)
  AND C7(a)–(f) all green (≥ 10 Qs, all hops 2|3, all baseline-absent, expects ≥ 4 digits, verb-neutral, expects-tokens absent from fixture)
  AND C8 dry-run-baseline confirms tags + verbs + attrs all stripped
  AND `./scripts/eval-multi-hop-sealed.sh > /tmp/eval-sealed.md` exits 0 AND `baseline*100 < 30*N`
  AND `./scripts/wiki-to-kg.py tests/eval/sealed-fixture/ | grep -c '"subject"'` ≥ 10 AND first triple has `attr_num` integer
  AND `grep -q '_kg\.jsonl' .claude/commands/wiki-query.md` AND query.md mentions `attr_num` / sum / compose
  AND awk on /tmp/eval-sealed.md shows typed - baseline ≥ 3
  AND `grep -q 'phase-3 sealed-channels' log.md` AND `grep -A 6` finds `phase-3b-shipped`

OR (M2 — gate failed, honest narrow retirement):

  `./scripts/smoke-all.sh` exits 0
  AND `./scripts/eval-multi-hop.sh > /tmp/eval-rich.md && grep -qE '^verdict: (null-result|improvement)' /tmp/eval-rich.md`
  AND `bash -n scripts/eval-multi-hop-sparse.sh` exits 0
  AND `git diff HEAD scripts/eval-multi-hop-sparse.sh` is empty
  AND C3, C4, C5, C6, C7 (a–f), C8 all green (same as M1)
  AND `./scripts/eval-multi-hop-sealed.sh > /tmp/eval-sealed.md` exits 0 AND `baseline*100 >= 30*N` (gate FAILED)
  AND `grep -q 'phase-3 sealed-channels' log.md` AND `grep -A 6` finds `phase-3b-abandoned-on-gate`
  AND `! test -f scripts/wiki-to-kg.py`
  AND `! test -f wiki/_kg.jsonl`
  AND `! grep -q '_kg\.jsonl' .claude/commands/wiki-query.md`
  AND `! grep -q '_kg\.jsonl' .claude/commands/wiki-ingest.md`
  AND C15 channel-closure proof (4 mechanical checks) green
```

M1 ⊻ M2: the two modes are mutually exclusive by C14's absence checks. Any
state where C9's gate failed AND `wiki/_kg.jsonl` exists is rejected by both
modes.

---

## Adversarial-pass results (recorded — 2026-05-27)

`advisor` attacked the first draft. Three blockers + several smaller issues;
all applied. Highlights:

- **Numeric grader was broken.** The first draft reused phase-2's `grep -q
  -F -i` substring grader for numeric expects. With short expects (`12`,
  `5`), baseline answers containing `"12% of"` or `"page 5"` would false-pass
  and silently kill the experiment. Fixed by (a) requiring expects ≥ 4 digits
  (C7(d)) and (b) requiring the harness to use the word-boundary regex
  `grep -qE "(^|[^0-9])${token}([^0-9]|\$)"` for numeric tokens (§5, step 5
  also adds a unit-style probe to verify the grader change).
- **N too small for a 30% gate.** The first draft had ≥ 6 questions. With
  N=6 and threshold ≤ 30%, M1 needed baseline ≤ 1 — one coincidence ruined
  it. Phase-2's advisor flagged the same risk with ≥ 7 at a looser gate;
  phase-3 is worse. Raised to ≥ 10.
- **Boundary inconsistency at exactly 30%.** First draft had M1 require ≤
  30% and M2 require > 40%, plus a "≥ 30%" in §2. Edge cases would have been
  accepted by neither mode. Pinned to strict-less-than for M1
  (`baseline*100 < 30*N`) and at-or-above for M2 (`baseline*100 >= 30*N`).
- **wiki-to-kg.py contamination on retry.** First draft allowed
  retained-but-inert `wiki-to-kg.py` under M2; but the harness would still
  pick it up and contaminate the next gate run. Tightened C14 to strict-
  absence.
- **`grep -w` would mis-handle kebab verbs.** Switched C7(e) to `grep -iF`.
- **C8 attr-strip check was vibe-only.** Inlined a concrete awk that fails
  if any multi-digit token survives in a baseline Related line.
- **"Definitively retired" was too broad.** Softened to "retired on this
  fixture/grader class" per §1.1.
- **Cost transparency missing.** Added a §6 budget note so the agent doesn't
  burn through `claude -p` calls on reflexive retries of the gate.
</content>
