---
name: plug-and-play-curator-smoke
status: ready-for-agent
created: 2026-05-26
revised: 2026-05-26 (post-adversarial-pass)
---

# Plug-and-play curator smoke

> Convert the "naive curator + AI librarian" framing from a north-star statement in the docs into a demonstrated, repeatable end-to-end smoke test the persona can re-run on their own machine.

## §1 Context

After absorbing three viewer-agnostic enhancements from the inspiring `tonbistudio/llm-wiki` (schema v2: journal exception, Flashcards convention, optional MCP read surface), a product gap analysis surfaced an honest gap: the README itself says **"Runtime behaviour is untested. Your first real invocation of any slash command is the smoke test."** The 7-step `/wiki-ingest` pipeline is **specified in three places but demonstrated nowhere** — `wiki/open-questions.md` calls this out as the most important open question.

For the mid-technical knowledge-worker persona (research analyst, journalist, librarian, indie consultant — comfortable with terminal commands, won't write code), today's experience scores ~2-3/10 on plug-and-play because the very thing the product promises (LLM librarian compounding knowledge over time) has never been observed end-to-end.

This goal closes that gap by producing a runnable, idempotent, two-phase smoke test that **demonstrates the system actually works** — and structures it so the persona can rerun it whenever they want to know if their setup is still healthy.

Out of scope deliberately (deferred to follow-ons): the installer, MCP registration helper, native slash-command parity for Cursor/Copilot/Cline, GUI/desktop/hosted version, AGENTS.md schema rework.

## §2 Definition of done (one sentence)

Running `./scripts/smoke-all.sh` from a clean checkout drives `claude -p` to ingest a known fictitious-fact fixture and query it back, asserts the answer recalls the fact AND cites the raw source AND that ingest produced wiki content containing the same anchor (no hand-authoring possible), and confirms no existing verifier or schema invariant regressed — all in a single shell-runnable, exit-code-driven check.

## §3 Success checks (the oracle)

All 9 must be green. The /goal loop evaluates `./scripts/smoke-all.sh` (which composes them) each iteration. **C5 is the anti-gaming guard** — without it, C2/C3/C4 are all hand-authorable.

| # | Check | How to verify (shell predicate) |
|---|---|---|
| C1 | Fixture exists with the fictitious anchors | `grep -q 'Quortex protocol' tests/smoke/smoke-source.md && grep -q 'Dr. Alma Voss' tests/smoke/smoke-source.md && grep -q '47 phase rotations' tests/smoke/smoke-source.md` |
| C2 | **Ingest produced a NEW wiki page containing the anchor** (anti-gaming) | `comm -13 <(sort tests/smoke/output/baseline-wiki.txt) <(ls wiki/*.md 2>/dev/null \| sort) \| xargs grep -lF 'Quortex' 2>/dev/null \| grep -q .` |
| C3 | Log entry cites the smoke raw source | `grep -F 'raw/smoke-source.md' log.md > /dev/null` |
| C4 | Query recall + citation (tightened anchor) | `grep -F '47 phase rotations' tests/smoke/output/last-answer.md && grep -F 'raw/smoke-source.md' tests/smoke/output/last-answer.md` |
| C5 | **`raw/smoke-source.md` carries a non-empty `ingested_hash`** (proves `/wiki-ingest` actually executed; closes the "fake the outputs" gaming path) | `grep -qE '^ingested_hash: sha256:[0-9a-f]{16,}' raw/smoke-source.md` |
| R1 | Baseline preflight stays green | `./scripts/preflight.sh > /dev/null` |
| R2 | Baseline anki verifier stays green | `./scripts/verify-wiki-to-anki.sh > /dev/null` |
| R3 | No Obsidian-specific markdown (negative guard) | `grep -rE -f scripts/r3-obsidian-patterns.txt wiki/ tests/canary/ templates/ docs/ 2>/dev/null \| grep -q .; [ $? -ne 0 ]` (note: `tests/smoke/` excluded by design; fixture purity enforced by §7 stop condition) |
| R4 | Schema + core-script purity stay stable (negative guard) | `grep -q '\*\*Schema version:\*\* 2' AGENTS.md && grep -qE '^- .type. — .concept.*entity.*summary.*analysis.*navigation.*journal' AGENTS.md && for f in scripts/body-hash.sh scripts/preflight.sh scripts/verify-extract.sh scripts/verify-wiki-to-anki.sh scripts/wiki-to-anki.sh; do head -1 "$f" \| grep -q '#!/usr/bin/env bash' \|\| exit 1; done` |

**Baseline counts (verbatim, captured 2026-05-26):**
- `scripts/preflight.sh > /dev/null`: exit 0 (green)
- `scripts/verify-wiki-to-anki.sh > /dev/null`: exit 0 (green)
- `scripts/verify-extract.sh canary-smoke-test`: precondition-dependent (not part of baseline)
- AGENTS.md schema version: 2
- `type` enum: `concept, entity, summary, analysis, navigation, journal`
- `wiki/*.md` count: 24

## §4 Scope

**In scope** (the agent may freely modify):
- `tests/smoke/` (new directory) — fixture + expected query + outputs
- `scripts/smoke-build.sh`, `scripts/smoke-check.sh`, `scripts/smoke-all.sh` (all new)
- `scripts/r3-obsidian-patterns.txt` (new — patterns file for R3, avoids backtick quoting hazards)
- `.scratch/plug-and-play-curator-smoke/` — working notes, scratch files
- `.gitignore` — adding entries for `tests/smoke/output/`
- `README.md` — adding ONE pointer section to `scripts/smoke-all.sh`

**Adjacent-creep boundary rule:** if a fix appears to need an edit outside the in-scope set, the conservative default is **leave it; don't force it** — escalate per §7. The one narrow exception is `.claude/commands/wiki-ingest.md` and `.claude/commands/wiki-query.md`: prompt-tuning these IS the legitimate path to making C2/C3/C4 pass, but each prompt body has its own K=3 cap (see §6).

**Out of scope** (see §8 for full non-goals).

## §5 Deliverable artifacts

The agent must produce these files; each is the deliverable for one step in §6.

| Path | Purpose | Notes |
|---|---|---|
| `tests/smoke/smoke-source.md` | The fictitious fixture | Contains the fact "The Quortex protocol uses 47 phase rotations" AND the entity "Dr. Alma Voss". Must be self-contained, ≤200 lines, pure CommonMark (no Obsidian-flavored markdown — see §7 stop condition). |
| `tests/smoke/expected-query.md` | The exact prompt the smoke runs through `/wiki-query` | One-line question: "How many phase rotations does the Quortex protocol use, and who founded phase coherence engineering?" |
| `tests/smoke/.gitignore` | Hides `output/` | Single line: `output/` |
| `tests/smoke/output/baseline-wiki.txt` | Manifest of `wiki/*.md` BEFORE first smoke run | Generated by `smoke-build.sh` ONLY when `raw/smoke-source.md` does NOT exist (clean state). If it exists already AND `wiki/` contains pages not in the baseline (potential pollution), `smoke-build.sh` MUST refuse to run and print the reset instructions (see §6 "Reset procedure"). |
| `tests/smoke/output/last-answer.md` | Captured `/wiki-query` output | Overwritten each rerun. |
| `tests/smoke/output/build.log` | Stderr/stdout of the build phase | For debugging. Not asserted (the check that ingest ran is C5, not log content). |
| `scripts/r3-obsidian-patterns.txt` | grep -E pattern file for R3 | Each line a regex. Initial content (literal, ASCII only — no fancy quoting):<br>`^> \[!`<br>`(^\|[^\\])%%[^%]`<br>`^[\` ]+dataview`<br>(The third line matches the start of a fenced code block whose info string begins with `dataview`. Patterns file approach eliminates shell-quoting hazards from embedding literal backticks in `smoke-all.sh`.) |
| `scripts/smoke-build.sh` | LLM-driven, idempotent | See "Build-phase algorithm" below. |
| `scripts/smoke-check.sh` | Pure POSIX shell | Asserts C1, C2, C3, C4, C5 from §3. Sub-second. No LLM calls. |
| `scripts/smoke-all.sh` | Umbrella | Sequence: `smoke-build.sh && smoke-check.sh && preflight.sh > /dev/null && verify-wiki-to-anki.sh > /dev/null && <R3 grep guard, using scripts/r3-obsidian-patterns.txt via -f> && <R4 schema-script guard>`. Single source of truth for /goal's completion condition. |
| `README.md` | Add one section | "Verify your install: `./scripts/smoke-all.sh`" — a 4-line addition; nothing else changes. |

All new scripts must start with `#!/usr/bin/env bash` and `set -euo pipefail`. All must be `chmod +x`.

### Build-phase algorithm (`scripts/smoke-build.sh`)

```text
1. Compute fixture hash:  FIXTURE_HASH=$(./scripts/body-hash.sh tests/smoke/smoke-source.md)
2. If raw/smoke-source.md exists:
     READ its ingested_hash field
     If $FIXTURE_HASH == $ingested_hash:
       Skip the LLM work (idempotent — already ingested this exact fixture)
       Verify last-answer.md still exists and is non-empty; if not, redrive only the query
       Exit 0
     If $FIXTURE_HASH != $ingested_hash:
       Refuse to run — print "Source delta detected. Run reset: rm raw/smoke-source.md tests/smoke/output/*. Then re-run." and exit 1
3. Else (raw/smoke-source.md does NOT exist — clean state):
     Capture baseline: ls wiki/*.md | sort > tests/smoke/output/baseline-wiki.txt
     Copy fixture to raw/ with proper frontmatter (script writes this itself; agent does not run /wiki-extract)
     Drive: claude -p '/wiki-ingest raw/smoke-source.md' >> tests/smoke/output/build.log 2>&1
     Drive: claude -p "/wiki-query \"$(cat tests/smoke/expected-query.md)\"" > tests/smoke/output/last-answer.md 2>> tests/smoke/output/build.log
     Exit 0 only if both claude invocations exited 0
```

**Exact `claude` CLI invocation:** the local install is at `/Users/francylisboacharuto/.local/bin/claude` v2.1.150. Use `claude -p '<prompt>'` (printer / non-interactive mode). The `-p`/`--print` flag is documented in `claude --help`. The prompt string IS the slash command exactly as a user would type it (e.g., `'/wiki-ingest raw/smoke-source.md'`). The prompt body those slash commands resolve to lives in `.claude/commands/wiki-ingest.md` and `.claude/commands/wiki-query.md` — modify those files (within K=3) if C2/C3/C4 misbehave.

## §6 Iteration loop (per-step cadence)

Steps are sequential. Each has its own check and its own narrow-fix rule. **Commit after each step's check passes.** Commit message format: `feat(smoke): step N — <what>`.

**K=3 definition:** *K counts git commits in the current loop session that modify the same prompt body file (`.claude/commands/wiki-ingest.md` or `.claude/commands/wiki-query.md`). After 3 such commits without C2/C3/C4 turning green, STOP and escalate per §7. K resets only when the agent moves to a different prompt body file.*

### Reset procedure (when in doubt)

If `tests/smoke/output/baseline-wiki.txt` exists AND `wiki/` contains pages absent from the baseline (suggests prior partial run polluted the state), the build script refuses and prints:

```
RESET REQUIRED. Run:
  rm -f raw/smoke-source.md tests/smoke/output/baseline-wiki.txt tests/smoke/output/last-answer.md tests/smoke/output/build.log
  # Then manually inspect wiki/ for smoke-derived pages and delete them
  # (any page that grep -lF 'Quortex' matches and isn't tracked in HEAD~1)
  git checkout HEAD -- wiki/   # nuclear option: restore wiki/ to last commit
  ./scripts/smoke-all.sh         # re-run from scratch
```

The agent MUST run the reset procedure (not invent its own) before retrying.

### Steps

1. **Author the fixture.** Write `tests/smoke/smoke-source.md`. Once this step's commit lands, the fixture is **frozen** — see §7 "fixture re-edit" stop condition.
   - Verify: `grep -q 'Quortex protocol' tests/smoke/smoke-source.md && grep -q 'Dr. Alma Voss' tests/smoke/smoke-source.md && grep -q '47 phase rotations' tests/smoke/smoke-source.md`
   - If red, fix only the fixture content; never change the fictitious anchors (the assertions depend on them).
   - K=3 attempts then escalate.

2. **Author the expected query.** Write `tests/smoke/expected-query.md`.
   - Verify: file exists, non-empty, contains both "phase rotations" and "founded".
   - Narrow fix: query phrasing only. Never alter the fictitious anchors.
   - K=3 then escalate.

3. **Author `scripts/r3-obsidian-patterns.txt`.** Plain text, one regex per line. See deliverable spec.
   - Verify: `grep -E -f scripts/r3-obsidian-patterns.txt scripts/r3-obsidian-patterns.txt` returns nothing (patterns file itself is pattern-free); `wc -l < scripts/r3-obsidian-patterns.txt` is ≥3.
   - Narrow fix: regex content only.
   - K=3 then escalate.

4. **Author `scripts/smoke-build.sh`.** LLM-driven, idempotent, capture-baseline-on-clean-only. Follow the algorithm in §5.
   - Verify (without LLM): `bash -n scripts/smoke-build.sh`; `chmod +x` set; first 2 lines are shebang + `set -euo pipefail`; running it with `raw/smoke-source.md` already present and matching hash exits 0 without invoking claude (test by mocking with a stub `claude` on PATH, or simply assert the idempotence branch's text exists in the script).
   - Narrow fix: shell logic, idempotence guard, path resolution, `claude -p` invocation.
   - K=3 then escalate.

5. **Author `scripts/smoke-check.sh`.** Pure shell asserts C1–C5 from §3.
   - Verify (without LLM): `bash -n scripts/smoke-check.sh`; runs against a hand-constructed `tests/smoke/output/` skeleton with known-good + known-bad fakes; exits 0 only on all-good, exit 1 on any single check broken.
   - Narrow fix: assertion logic only. Never weaken an assertion to make a known-bad fake pass.
   - K=3 then escalate.

6. **Author `scripts/smoke-all.sh`.** Umbrella wrapper.
   - Verify (without LLM): `bash -n scripts/smoke-all.sh`; exits non-zero when any sub-check is artificially broken; exits 0 when all green.
   - Narrow fix: composition order, error propagation.
   - K=3 then escalate.

7. **First real smoke run.** Execute `./scripts/smoke-all.sh` end-to-end with `claude -p`. Reset (per "Reset procedure" above) before this step if any partial state exists.
   - Verify: exit 0 (all 9 checks green).
   - **Narrow fix rules** for the most likely failure modes (in priority order):
     - **C5 red (ingested_hash empty/absent)** — `/wiki-ingest` didn't update the raw frontmatter. Fix `.claude/commands/wiki-ingest.md` step-7 "compute hash + write back" guidance. K=3 then escalate.
     - **C2 red (no new wiki page containing 'Quortex')** — fix `.claude/commands/wiki-ingest.md` step-4 "update existing pages" + step-3 "write summary page" guidance to ensure Quortex-bearing content lands. K=3 then escalate. NEVER weaken C2 to drop the Quortex requirement.
     - **C3 red (no log entry)** — fix `.claude/commands/wiki-ingest.md` step-7 "append log.md" guidance. K=3 then escalate.
     - **C4 red (no fact recall or no citation)** — fix `.claude/commands/wiki-query.md` citation-format guidance. K=3 then escalate. NEVER weaken C4.
     - **R1/R2 red** — STOP, escalate immediately. Baseline regression.
     - **R3/R4 red** — STOP, escalate immediately. Architectural drift.
   - On total exit 0, append a one-line note to `wiki/open-questions.md` resolving "do the 7 steps actually happen?" with a link to this GOAL.md and the date.

8. **Add the README pointer.** Single-line section "Verify your install: `./scripts/smoke-all.sh`".
   - Verify: `grep -q 'smoke-all.sh' README.md`.

## §7 Stop/escalate conditions

The agent must NOT push through any of these — halt and surface to a human.

- **Gaming the oracle:** modifying `tests/smoke/smoke-source.md`'s fictitious anchors (Quortex, Dr. Alma Voss, 47 phase rotations) after step 1's commit; modifying `tests/smoke/expected-query.md` after step 2's commit; modifying `scripts/r3-obsidian-patterns.txt` after step 3's commit; weakening any §3 predicate; deleting a regression guard; turning a shell-runnable check into a prose "looks good" check; hand-writing `wiki/*.md` content to satisfy C2 without `/wiki-ingest` actually running (C5 will catch this, but the *intent* is also a stop condition); manually editing `tests/smoke/output/last-answer.md` outside `claude -p`.
- **Fixture re-edit after step 1:** if at any point in steps 2–8 the agent considers editing `tests/smoke/smoke-source.md`, STOP and escalate. The fixture is frozen after step 1's commit. The only legitimate reason to re-edit it is a clear bug found by a human review.
- **Prompt-tuning wall:** K=3 commits to the same prompt-body file (`.claude/commands/wiki-ingest.md` or `.claude/commands/wiki-query.md`) in the current session without C2/C3/C4/C5 turning green. The prompt may need a human design judgment.
- **Infrastructure non-code failures:** `claude -p` returning model-unavailable, rate-limit, or auth errors — retry with exponential backoff up to 3 times, then escalate. Do not work around by editing the model name, skipping LLM steps, or replacing `claude -p` with another tool.
- **Pre-existing baseline red:** `scripts/preflight.sh` or `scripts/verify-wiki-to-anki.sh` failing BEFORE the agent has made any change. Restore baseline first; if can't, escalate.
- **Architectural pressure:** making C1–C5 pass would require changing the `type` enum, the schema version, removing a regression guard, adding a runtime dependency to a core script, modifying AGENTS.md beyond the smoke's own additions, or violating §8.
- **Revert doesn't restore green:** after reverting a step's commit, the regression guards are still red. Indicates a deeper baseline problem; escalate.
- **Partial-state pollution detected:** `tests/smoke/output/baseline-wiki.txt` exists AND `wiki/` contains pages not in the baseline AND ingested_hash mismatches the fixture hash. Run the Reset procedure (do not improvise). If reset still leaves state inconsistent, escalate.

## §8 Non-goals (explicit out-of-scope)

- Installer or package registry publishing (`npx create-llm-wiki`, PyPI/npm publish). Deferred.
- Native slash-command parity for Cursor, Copilot, Cline, Codex, or Gemini. Existing natural-language shims remain the documented multi-tool path.
- GUI, desktop wrapper, or hosted version.
- Rewriting AGENTS.md beyond what the smoke literally requires (no schema bump 2→3, no enum changes, no field renames). Minor wording clarifications are fine.
- MCP-side smoke testing — the MCP server already shipped is a separate read surface; verifying it has its own (future) goal.
- First-source guide as a separate doc — the smoke fixture + `scripts/smoke-build.sh` script comments serve as the walkthrough.
- Multi-tool oracle (driving Cursor or Copilot headlessly). Oracle uses `claude -p` only.
- Anki/journal end-to-end smoke (already shape-verified by `scripts/verify-wiki-to-anki.sh`).
- Auto-promotion behavior of `/wiki-query` — this iteration runs `/wiki-query` against a wiki that already contains the relevant content (from the ingest of the same source), so promotion is not exercised.

## §9 Real-data test inventory

**Primary oracle (this iteration):**
- `tests/smoke/smoke-source.md` (NEW) — purpose-built fictitious fixture.
- `scripts/smoke-all.sh` (NEW) — umbrella verifier. Drives C1–C5 + R1–R4.

**Live smoke command:** `./scripts/smoke-all.sh`. First run is slow (~30–60s, fetches `claude -p` output). Subsequent runs are sub-second (idempotent build skip + shell-only checks).

**Existing fixtures/verifiers preserved as baseline:**
- `tests/canary/canary-smoke-test.md` + `scripts/verify-extract.sh canary-smoke-test` — shape verification of `/wiki-extract` (precondition-dependent; not part of the regression guard set).
- `tests/canary/canary-csv.csv` — CSV-path fixture for `/wiki-extract`.
- `tests/canary/canary-flashcards.md` + `scripts/verify-wiki-to-anki.sh` — shape verification of the Anki exporter (part of regression guard set R2).
- `scripts/preflight.sh` — environment check (part of regression guard set R1).

**Before/after observable on a real run:**
- Before: `wiki/` contains the meta-wiki only (24 pages); `log.md` has no `smoke-source.md` references; `tests/smoke/output/` is absent or empty; `raw/smoke-source.md` is absent.
- After: `wiki/` contains the meta-wiki + ≥1 new page derived from `raw/smoke-source.md` containing the literal "Quortex"; `log.md` has at least one entry citing `raw/smoke-source.md`; `tests/smoke/output/last-answer.md` is non-empty and contains both `47 phase rotations` and `raw/smoke-source.md`; `raw/smoke-source.md` has `ingested_hash: sha256:...`.

## Critical files

**New:**
- `tests/smoke/smoke-source.md`
- `tests/smoke/expected-query.md`
- `tests/smoke/.gitignore`
- `scripts/r3-obsidian-patterns.txt`
- `scripts/smoke-build.sh`
- `scripts/smoke-check.sh`
- `scripts/smoke-all.sh`
- `.scratch/plug-and-play-curator-smoke/GOAL.md` (this file)

**Modified:**
- `README.md` (one new section: "Verify your install" — pointer line to `scripts/smoke-all.sh`)
- `wiki/open-questions.md` (one-line resolution note for "do the 7 steps actually happen?", appended only after smoke is green)
- `log.md` (touched as a side effect by `/wiki-ingest raw/smoke-source.md`; not directly authored by the agent)
- `.gitignore` (one new line: `tests/smoke/output/`)

**Untouched (negative guards):**
- `AGENTS.md` schema version stays 2; `type` enum stays {concept, entity, summary, analysis, navigation, journal}.
- `scripts/body-hash.sh`, `scripts/preflight.sh`, `scripts/verify-extract.sh`, `scripts/verify-wiki-to-anki.sh`, `scripts/wiki-to-anki.sh` stay pure bash (`#!/usr/bin/env bash`).
