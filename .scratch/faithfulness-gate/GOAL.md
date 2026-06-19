# GOAL: Wire the C3 entailment judge into `/wiki-ingest` as a blocking faithfulness gate (Hook A)

> Hand-off spec for an autonomous coding agent. Self-contained. The agent iterates until
> every check in §3 passes, using §6 as the loop and §7 as the stop rules.

## 1. Context — why this exists

`llm-wiki-bootstrap` mechanically guarantees a wiki is well-formed, navigable, and that
its citations *point at real places* (R8 / `verify-citation-audit.sh` proves the C1+C2
deterministic floor: cited `raw/<file>` exists, `#anchor` resolves). It does **not** check
that the cited evidence actually **supports** the claim — the C3 entailment step. That
piece already exists as a *measurement* tool (`scripts/eval-citation-faithfulness.sh`: a
`claude -p` judge over an 8-citation sample of the whole wiki, reports a rate) but is
wired to **nothing** — it can't block a bad claim from entering the wiki.

This goal turns that latent capability into an **ingest-time blocking gate**: when
`/wiki-ingest` writes a page, every cited claim on that page is judged against its own
`raw/` evidence, and the result gates the commit. Web-promotion (Hook B) is explicitly a
**later, separate** goal — promoted content cites URLs, not `raw/`, so the evidence
resolver can't read it until a promote-via-raw change lands first (user-confirmed:
Hook A first).

Decision (user-confirmed): claim = a sentence terminating in a `(source: raw/X#anchor)`
citation (already what `citation-audit.py` extracts); asymmetric policy — `CONTRADICTED`
blocks everywhere, `UNSUPPORTED` blocks on promote but only flags-inline on ingest. Build
**both** mode policies and test both; wire only `--mode ingest`.

## 2. Definition of done (one sentence)

A new `scripts/wiki-faithfulness-gate.sh` reuses `citation-audit.py` to extract every
cited claim on a target page, judges each via an **injectable** 3-way verdict
(SUPPORTED / UNSUPPORTED / CONTRADICTED), applies the asymmetric block/flag policy by
`--mode`, is proven by a deterministic mocked-verdict oracle wired into `smoke-all.sh` as
**R16**, and is invoked as a step in `.claude/commands/wiki-ingest.md` — with the full
smoke green at the new count and no existing check regressed.

## 3. Success checks — ALL green (the oracle)

| # | Check | How to verify |
|---|---|---|
| C1 | Full smoke green at the new count, no regression *(strongest oracle)* | `bash scripts/smoke-all.sh --no-build` exits 0 and prints `All 21 checks green.` |
| C2 | R16 oracle passes, is wired into smoke, **and can fail** (not vacuous) | `bash scripts/verify-faithfulness-gate.sh` exits 0; `grep -q 'R16' scripts/smoke-all.sh`; **mutation test:** the oracle (or a one-liner reusing it) exits **non-zero** when fed a verdicts file that mislabels the contradicted page as `SUPPORTED` — proving the test can fail |
| C3 | `CONTRADICTED` blocks in BOTH modes, **non-vacuously** (G1) | with the mock verdicts: gate `--mode ingest` and `--mode promote` on the contradicted page both exit non-zero **and** the per-claim report shows **≥1 claim actually judged** (not "0 citations") |
| C4 | `UNSUPPORTED` is asymmetric (G2) | on the unsupported page: `--mode promote` exits non-zero; `--mode ingest` exits 0 **and** the page copy gains a `FAITHFULNESS UNVERIFIED` marker (`grep -c` ≥ 1) |
| C5 | No false positive on a faithful page (G3) | on the all-SUPPORTED page: gate exits 0 in both modes **and** `grep -c 'FAITHFULNESS UNVERIFIED'` on the copy == 0 |
| C6 | Deterministic + zero LLM/network when verdicts injected *(negative guard)* | the oracle runs the gate **twice** with the same `--verdicts` and asserts `diff` exit 0 (byte-identical stdout + marker insertions); a run with `claude` removed from `PATH` but `--verdicts` supplied still exits per policy (never errors on a missing judge). Determinism is asserted for the **injected** path only — the production `claude` path is not claimed deterministic |
| C7 | Reuses the existing extractor; no second citation parser, no new dependency *(negative guard)* | `grep -q 'citation-audit.py' scripts/wiki-faithfulness-gate.sh`; no new non-stdlib import (`grep -rnE 'import (requests\|httpx\|yaml\|bs4)' scripts/` shows nothing new); no file created outside the §Critical-files set |
| C8 | Ingest hook instruction present; existing faithfulness assets untouched *(negative guard)* | `grep -q 'wiki-faithfulness-gate' .claude/commands/wiki-ingest.md`; `git diff --stat` shows `scripts/eval-citation-faithfulness.sh` and `scripts/citation-audit.py` **unmodified**; R8 still green (within C1) |
| C9 | The real (non-injected) judge branch parses *(closes the live-path hole)* | with a fake `claude` on `PATH` printing `VERDICT=SUPPORTED`, the gate run **without** `--verdicts` on the good page exits 0 and its report shows the stubbed verdict was consumed — proves the judge-invocation + parse branch works without a real LLM |

## 4. Scope — in / out + the boundary rule

**In:**
- `scripts/wiki-faithfulness-gate.sh` — the runtime gate (audit → judge → policy → marker).
- `scripts/verify-faithfulness-gate.sh` — the R16 deterministic oracle (mocked verdicts).
- Fixture additions under `tests/eval/faithfulness-fixture/` (an UNSUPPORTED page + a mock
  verdicts file; reuse the existing `page-good.md`, `page-unfaithful.md`, `raw/source-a.md`).
- `scripts/smoke-all.sh` — add the R16 block, bump the count (20 → 21) everywhere it appears.
- `.claude/commands/wiki-ingest.md` — add the gate-invocation step (Hook A).
- Extending the **judge prompt** to a 3-way verdict (`VERDICT=SUPPORTED|UNSUPPORTED|CONTRADICTED`)
  lives inside the new gate script (copy the adversarial, default-closed pattern from
  `eval-citation-faithfulness.sh:88-112`; do **not** edit that file).

**Out:** Hook B / web-promotion; any change to URL-citation conventions; changing
`citation-audit.py` or `eval-citation-faithfulness.sh`; any schema-version bump; an
auto-revise retry *loop* inside the gate (the gate decides; the agent retries per the
prose, bounded by §6).

**Boundary rule:** the gate **reuses** `citation-audit.py --tsv` for all claim/evidence
extraction — it never re-parses citations itself. Evidence resolution is whatever the
audit already returns (heading-slug / timestamp / line-range / whole-file). If a claim's
citation fails the C1/C2 floor (a `BAD` TSV row), the gate **blocks in both modes** (a
broken pointer is never acceptable) — do not try to "fix" resolution here. When unsure
whether something is in scope: leave it; it's Hook B or a later goal.

## 5. Concrete deliverable artifacts

- **`scripts/wiki-faithfulness-gate.sh`** (~120 lines, bash). Usage:
  `wiki-faithfulness-gate.sh --mode ingest|promote [--raw <dir>] [--verdicts <file>] <page.md> [<page.md>...]`.
  - **`citation-audit.py` is directory-only** — it `os.walk`s a wiki-dir and rejects a
    non-directory argument (`citation-audit.py:176,222`). So the gate runs
    `python3 scripts/citation-audit.py <target's containing wiki-dir> --tsv` and then
    **filters** the rows where the `page` column equals each target's relpath within that
    dir. Rows: `tag<TAB>page<TAB>line<TAB>file<TAB>anchor<TAB>c1<TAB>c2<TAB>claim_b64<TAB>evidence_b64`
    (decode claim/evidence with `openssl base64 -d -A`, exactly as `eval-citation-faithfulness.sh:78`).
  - For each `OK` row: get a 3-way verdict. **Judge source is injectable** — if
    `--verdicts <file>` is given, look the verdict up there (format below) and make **no**
    `claude` call; otherwise call `claude -p` with the extended 3-way adversarial prompt
    (default-closed: unparseable → `UNSUPPORTED`).
  - `--verdicts` file format (one per line, tab-separated): `<page>:<line><TAB>VERDICT`,
    where `<page>` is the **same relpath** the audit's `page` column emits (not a bare
    basename) — a key mismatch silently judges zero claims, so keep them identical. A
    `page:line` **not found** in the file → `UNSUPPORTED` (default-closed). This injection
    seam is what makes the oracle deterministic and offline.
  - Policy: `CONTRADICTED` → block (exit 3) in both modes. `BAD` row (floor fail) → block
    (exit 3) in both modes. `UNSUPPORTED` → block (exit 3) in `--mode promote`; in
    `--mode ingest` mark the claim and exit 0. `SUPPORTED` → pass.
  - Marker: **appended to the END of the claim's own line** (never inserted as a new line)
    so line numbers — and therefore the `page:line` verdict keys and any re-audit — stay
    stable across multiple flagged claims on one page. Idempotent: skip if the line already
    carries it. Text: `<!-- FAITHFULNESS UNVERIFIED: raw/<file>#<anchor> does not clearly support this claim -->`
  - Exit 0 = all pass / only ingest-flagged; non-zero = blocked. Print a per-claim report.
- **`scripts/verify-faithfulness-gate.sh`** (~120 lines, bash). Copies
  `tests/eval/faithfulness-fixture/` to a `mktemp -d` and runs the gate there (never
  touches the committed fixture — the gate mutates files). Asserts, all offline:
  - **G1/C3** contradicted page blocks in both modes **and** the report shows ≥1 claim judged.
  - **G2/C4** unsupported page: blocks on `promote`, exits 0 on `ingest` + marker appears.
  - **G3/C5** good page: exits 0 both modes, zero markers.
  - **G4/C6** run twice with the same `--verdicts`, `diff` exit 0 (deterministic).
  - **Mutation/C2** a verdicts file that mislabels the contradicted page `SUPPORTED` makes
    the gate **exit 0** there — i.e. the assertion that "contradicted blocks" can actually
    fail, proving the oracle isn't vacuous.
  - **Stub-judge/C9** with a throwaway `claude` shim on `PATH` printing `VERDICT=SUPPORTED`
    (written into the tmp dir, prepended to `PATH`), the gate run **without** `--verdicts`
    on the good page exits 0 and consumed the stub verdict — exercises the real
    invocation+parse branch with no network/LLM.
  Exit 0 iff all hold. The mutation verdicts file and the `claude` shim are generated
  inside the oracle at runtime (not committed).
- **Fixture:** `tests/eval/faithfulness-fixture/wiki/page-unsupported.md` — a page whose
  cited claim resolves (C1+C2 pass) but is only loosely related to its evidence; plus
  `tests/eval/faithfulness-fixture/verdicts.tsv` mapping each fixture claim's `page:line`
  to its intended verdict (good→SUPPORTED, unfaithful→CONTRADICTED, unsupported→UNSUPPORTED).

## 6. The iteration loop the agent must follow

1. **Baseline.** `bash scripts/smoke-all.sh --no-build` → confirm it currently prints
   `All 20 checks green.` (if not, STOP — §7). Record the count. `git rev-parse HEAD`.
2. Build `scripts/wiki-faithfulness-gate.sh` against the **real** existing assets: read
   `scripts/citation-audit.py` (TSV contract) and `scripts/eval-citation-faithfulness.sh`
   (decode + judge pattern) first. → verify: `--verdicts`-driven run on one fixture page
   prints a per-claim report and exits per policy. If wrong → fix only the gate script;
   after 3 attempts → revert + escalate.
3. Add the `page-unsupported.md` fixture + `verdicts.tsv`. → verify: `citation-audit.py`
   floor still flags exactly the pre-existing broken cases (R8 unaffected).
4. Build `scripts/verify-faithfulness-gate.sh` (copy-to-tmp; mocked verdicts; runtime
   mutation-verdicts + `claude` shim). → verify: it exits 0 and asserts C2(mutation), C3,
   C4, C5, C6, C9. If red → fix the oracle or the gate, never the fixture's intent; after
   3 → revert + escalate.
5. Wire R16 into `scripts/smoke-all.sh`: add the guard block after R15, and bump every
   `20`→`21` / `R1–R15`→`R1–R16` in the header comment, section label, and summary line.
   → verify: C1 (`All 21 checks green.`). One commit for the gate+oracle+fixture, one for
   the smoke wiring, so the oracle is auditable.
6. Add the Hook A step to `.claude/commands/wiki-ingest.md` (after pages are written,
   before the log entry): run `scripts/wiki-faithfulness-gate.sh --mode ingest <changed
   pages>`; on a block, the agent fixes the claim (rewrite to match evidence or drop the
   citation) and re-runs **once**, then commits; `UNSUPPORTED` markers are left in place
   for `/wiki-lint` to surface. → verify: C8.
7. **Final gate.** C1–C8 all green. Commit. Stop.

## 7. Stop / escalate conditions (do NOT push through these)

- Baseline smoke is **not** green (≠ `All 20 checks green.`) before you start → stop, report.
- A smoke check goes red for a reason unrelated to the gate (e.g. R10 synthesis, R7
  installer) → stop, report the check + diagnostics. Don't "fix" an unrelated guard.
- `citation-audit.py`'s TSV contract isn't what this spec describes (columns differ) → stop,
  report — the spec is built on it; don't silently re-parse citations a second way.
- You're tempted to bump the schema version or change a citation/marker convention older
  clients depend on → out of scope; stop and ask (it also breaks R4).
- A revert doesn't restore `All 20 checks green.` → stop, report.
- When in doubt → stop and report. Don't guess.

## 8. Non-goals (explicitly out of scope)

Hook B / web-promotion gating; extracting promoted URLs into `raw/`; changing the
`(source: <url>)` convention; editing `scripts/citation-audit.py` or
`scripts/eval-citation-faithfulness.sh`; a schema-version bump (must keep
`**Schema version:** 4` so R4 stays green); an in-gate auto-revise loop or LLM
self-correction; sampling logic (the gate judges **all** cited claims on the target, not a
sample); "improving" adjacent scripts, formatting, or the existing fixtures' good/broken
pages; adding tests beyond the oracle + fixture named here.

## 9. Real-data test inventory

- **Primary oracle:** `tests/eval/faithfulness-fixture/` — planted pages
  (good=SUPPORTED, unfaithful=CONTRADICTED, unsupported=UNSUPPORTED, broken-file/anchor
  floor cases) + `verdicts.tsv`; driven offline by `scripts/verify-faithfulness-gate.sh`
  (R16) with mocked verdicts. Covered by C2–C6.
- **Live smoke (informational, like `eval-causal.sh` — never a gate):**
  `scripts/wiki-faithfulness-gate.sh --mode ingest wiki/<a-real-page>.md` with `claude` on
  PATH over the actual meta-wiki — exercises the real C3 judge end-to-end; report the
  per-claim verdicts. Not part of the deterministic floor.
- **Before/after:** run the gate (`--verdicts`) on `page-good.md` → exit 0, no marker;
  on `page-unfaithful.md` → exit 3 (blocked). Confirms the policy wiring on real fixture text.

## Critical files

- New: `scripts/wiki-faithfulness-gate.sh`, `scripts/verify-faithfulness-gate.sh`,
  `tests/eval/faithfulness-fixture/wiki/page-unsupported.md`,
  `tests/eval/faithfulness-fixture/verdicts.tsv`
- Modified: `scripts/smoke-all.sh` (R16 block + count 20→21),
  `.claude/commands/wiki-ingest.md` (Hook A step)
- Read-only (reused, must NOT change): `scripts/citation-audit.py`,
  `scripts/eval-citation-faithfulness.sh`, the existing fixture pages
