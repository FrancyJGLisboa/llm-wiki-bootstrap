---
name: installer-fresh-skeleton
status: ready-for-agent
created: 2026-05-26
revised: 2026-05-26 (post-adversarial-pass)
---

# Installer: fresh skeleton without smoke artifacts

> Produce a self-contained installer that generates a fresh `llm-wiki-bootstrap` repo for a new user, stripped of meta-wiki content and smoke artifacts, ready to use without any subsequent `wipe-meta-wiki.sh` step.

## §1 Context

After the previous `/goal` iteration (`plug-and-play-curator-smoke`), the dev repo contains the meta-wiki (~24 pages about the LLM-wiki pattern) AND the smoke artifacts (4 pages about the fictional Phase Coherence Engineering / Quortex protocol, plus the smoke fixture and outputs). A new user cloning today must run `./scripts/wipe-meta-wiki.sh` to start their own wiki. That's one step too many for the mid-technical knowledge-worker persona.

**Why this change is being made.** Closing the persona's first-mile friction.

Today's flow:
```
git clone … my-wiki
cd my-wiki
./scripts/wipe-meta-wiki.sh --yes    # ← friction we're removing
```

Target flow:
```
git clone … tmp
tmp/scripts/create-llm-wiki.sh ~/my-wiki
rm -rf tmp                            # optional cleanup
```

Three commands either way, but the new third command does USEFUL work (generates the fresh repo at a chosen path) rather than destructive cleanup of state the user never wanted.

**Intended outcome.** A single bash entry-point (`scripts/create-llm-wiki.sh`) that produces a fresh-state target dir, verified by a deterministic shell oracle each iteration via a positive-shape + content-tripwire assertion (not a spot-list of forbidden files).

## §2 Definition of done (one sentence)

Running `./scripts/verify-create-llm-wiki.sh` invokes `./scripts/create-llm-wiki.sh` against a fresh `mktemp` target, then asserts the target's tree shape matches the skeleton manifest EXACTLY (no extra files anywhere), that target content contains none of the dev-repo's identifiable strings (`Quortex`, `karpathy`, `Phase Coherence`), that target frontmatter on `wiki/index.md` parses correctly, and that the target's own `preflight.sh` exits 0 — all while the previous iteration's `smoke-all.sh` continues to exit 0 and dev-repo protected content remains intact.

## §3 Success checks (the oracle)

All 8 must be green. The /goal completion condition is:
`./scripts/smoke-all.sh > /dev/null && ./scripts/verify-create-llm-wiki.sh`

### Installer checks (I1–I5)

| # | Check | How to verify (shell predicate) |
|---|---|---|
| I1 | Installer-script shape | `head -1 scripts/create-llm-wiki.sh \| grep -q '^#!/usr/bin/env bash' && [ -x scripts/create-llm-wiki.sh ]` |
| I2 | Installer succeeds against a fresh temp target | `TGT="$(mktemp -d)/freshrepo" && ./scripts/create-llm-wiki.sh "$TGT" && [ -d "$TGT" ]` |
| I3 | **Target has EVERY file in the skeleton manifest** (iterates the full list) | For each path `$P` in `scripts/installer-skeleton-manifest.txt`: `[ -e "$TGT/$P" ]`. The manifest is the single source of truth; both the installer and the verifier consume it. |
| I4 | **Target tree shape is exactly the skeleton — nothing extra anywhere** (anti-gaming, replaces the prior negative spot-list) | Three sub-predicates, ALL must hold:<br>(a) `find "$TGT" -type f -not -path '*/.git/*' \| sort` equals `( cd "$TGT" && cat ../installer-skeleton-manifest.txt \| sort )` (or equivalent: target's tracked-file list IS the manifest, byte-identical sort output);<br>(b) Content tripwire: `! grep -r -l -E 'Quortex\|karpathy\|Phase Coherence' "$TGT" 2>/dev/null` — none of the dev-repo identifier strings appear anywhere in the target;<br>(c) `wiki/index.md` frontmatter parses: `awk '/^---$/{n++} n==1 && /^type:/{t=1} n==1 && /^source:/{s=1} n==1 && /^updated:/{u=1} END{exit !(t&&s&&u)}' "$TGT/wiki/index.md"` exits 0. |
| I5 | Target is internally consistent (preflight runs) | `(cd "$TGT" && ./scripts/preflight.sh > /dev/null)` exits 0. |

### Regression guards (R1–R3)

| # | Check | How to verify |
|---|---|---|
| R1 | Existing smoke stays green | `./scripts/smoke-all.sh > /dev/null` exits 0 (umbrella for prior 9 checks). |
| R2 | Dev-repo protected files present | `[ -f raw/smoke-source.md ] && [ -f raw/karpathy-llm-wiki-video-transcript.md ] && [ -f wiki/quortex-protocol.md ] && [ -f wiki/four-principles.md ] && [ -f wiki/index.md ] && [ -f scripts/smoke-all.sh ]` |
| R3 | Core scripts stay pure bash | For every `scripts/*.sh`: `head -1` matches `^#!/usr/bin/env bash`. |

**Baseline counts (verbatim, captured 2026-05-26 — corrected post-adversarial-pass):**
- `./scripts/smoke-all.sh > /dev/null; echo $?` → 0
- `ls wiki/*.md | wc -l` → **27** (was incorrectly stated as 28 in the prior draft)
- `ls raw/ | wc -l` → 4 (karpathy transcript + slide PNG + slide .md sidecar + smoke-source)
- `ls scripts/*.sh | wc -l` → 10
- `ls .claude/commands/wiki-*.md | wc -l` → 5

## §4 Scope

**In scope** (the agent may freely modify or create):
- `scripts/create-llm-wiki.sh` — the installer (NEW)
- `scripts/verify-create-llm-wiki.sh` — the oracle (NEW)
- `scripts/installer-skeleton-manifest.txt` — single source of truth for which files ship in the fresh skeleton (NEW)
- `README-FRESH.md` — fresh-skeleton README template (NEW, copied to README.md in target)
- `wiki/index-FRESH.md` — fresh-skeleton wiki index stub (NEW, copied to wiki/index.md in target)
- `tests/installer-output/.gitignore` — ignore verifier temp dirs (NEW)
- `.scratch/installer-fresh-skeleton/` — working notes
- `README.md` — one new section pointing at `scripts/create-llm-wiki.sh` for new users

**Adjacent-creep boundary rule:** the conservative default is **leave it; don't force it**. The installer COPIES files from the dev repo to the target; it must not rewrite or strip files in the dev repo itself.

**Out of scope** (see §8 for full non-goals).

## §5 Deliverable artifacts

| Path | Purpose | Notes |
|---|---|---|
| `scripts/installer-skeleton-manifest.txt` | **Single source of truth** — one path per line, lists exactly what ships in the fresh skeleton | Read by BOTH the installer (to know what to copy) AND the verifier (to assert exact shape). Adding or removing a file from the fresh skeleton = one line change in this file. |
| `scripts/create-llm-wiki.sh` | The installer | One positional arg `<target-dir>`. Pure bash 3.2+. Refuses if target exists and is non-empty. Reads the manifest, for each entry: `mkdir -p "$TGT/$(dirname "$P")"` then `cp "$SRC/$P" "$TGT/$P"`. Replaces `wiki/index.md` ← `wiki/index-FRESH.md` and `README.md` ← `README-FRESH.md` during copy. Resets `target/log.md` to header-only. Initializes `target/.git/` via `git init -q`. No initial commit. Exit 0 on success. |
| `scripts/verify-create-llm-wiki.sh` | The oracle | Cleans any prior `tests/installer-output/*` from previous red runs. Creates a fresh temp target. Runs the installer. Asserts I3 + I4 (a/b/c) + I5. Deletes the temp target on green; leaves it on red for inspection with a printed path. |
| `README-FRESH.md` | Template README for fresh installs | Replaces the meta-wiki-aware README content with text appropriate for "you just installed an empty LLM-wiki bootstrap." Includes the typical-session example. ~30–50 lines. Pure CommonMark. Must not mention `Quortex`, `karpathy`, or `Phase Coherence` (content tripwire). |
| `wiki/index-FRESH.md` | Template index stub for fresh wiki | One-paragraph stub: "Your wiki is empty. Add a source with `/wiki-extract`, then `/wiki-ingest`." Frontmatter: required fields `type: navigation`, `source: analysis`, `updated: <today>`, plus `title:` and `tags: []`. Schema v2-compatible. Must not contain `Quortex`/`karpathy`/`Phase Coherence`. |
| `tests/installer-output/.gitignore` | Hide verifier output | Content: `*` then `!.gitignore` (track only this file). |
| `README.md` (modified) | Add new-user pointer | Single new section "Start your own wiki: `./scripts/create-llm-wiki.sh ~/my-wiki`" — 5-line addition. |

### Manifest content (`scripts/installer-skeleton-manifest.txt`)

```
AGENTS.md
CLAUDE.md
GEMINI.md
LICENSE
.gitignore
.clinerules
.cursor/rules/llm-wiki.mdc
.github/copilot-instructions.md
.claude/commands/wiki-init.md
.claude/commands/wiki-extract.md
.claude/commands/wiki-ingest.md
.claude/commands/wiki-query.md
.claude/commands/wiki-lint.md
scripts/body-hash.sh
scripts/preflight.sh
scripts/verify-extract.sh
scripts/verify-wiki-to-anki.sh
scripts/wiki-to-anki.sh
scripts/wipe-meta-wiki.sh
scripts/mcp-server.sh
templates/journal-entry.md
docs/QUICKSTART.md
docs/EXPLAIN.md
docs/MCP.md
tests/canary/canary-smoke-test.md
tests/canary/canary-csv.csv
tests/canary/canary-flashcards.md
wiki/journal/.gitkeep
wiki/index.md
README.md
log.md
```

Notes:
- The last three (`wiki/index.md`, `README.md`, `log.md`) are *target paths*; the installer sources them from `wiki/index-FRESH.md`, `README-FRESH.md`, and a hard-coded 3-line stub respectively. The manifest lists them by their TARGET path so I3/I4(a) work uniformly.
- The manifest is intentionally a flat list — no comments, no sections. Trailing newline. Greppable.

### Installer algorithm

```text
1. Parse positional arg → TARGET. If absent → print usage + exit 2.
2. If TARGET exists AND non-empty → print "refusing to clobber" + exit 1.
3. mkdir -p TARGET
4. SRC=$(cd "$(dirname "$0")/.." && pwd)   # dev-repo root
5. For each path P in scripts/installer-skeleton-manifest.txt:
     If P == wiki/index.md   → source = $SRC/wiki/index-FRESH.md
     ElIf P == README.md     → source = $SRC/README-FRESH.md
     ElIf P == log.md        → source = (synthesized 3-line stub)
     Else                    → source = $SRC/$P
     mkdir -p "$TARGET/$(dirname "$P")"
     copy source → "$TARGET/$P"   (preserves executability for .sh)
6. ( cd "$TARGET" && git init -q )
7. Print success message: target path + cd hint + next steps
8. Exit 0
```

Notes:
- Bash 3.2 has no `cp --parents`. The `mkdir -p` before each `cp` is mandatory and load-bearing.
- The wipe-meta-wiki.sh script is intentionally included; a fresh install has nothing to wipe, but a user adding meta-content later might want it. Not a defect.

## §6 Iteration loop (per-step cadence)

Steps are sequential. Each step ends with `feat(installer): step N — <what>` commit.

**K=3 definition:** *K counts git commits in the current loop session that modify the SAME component file (`scripts/create-llm-wiki.sh`, `scripts/verify-create-llm-wiki.sh`, `scripts/installer-skeleton-manifest.txt`, `README-FRESH.md`, or `wiki/index-FRESH.md`) without that step's check turning green. After 3 such commits, STOP and escalate. K is per-step — fixing a step-3 failure does not reset step-4's counter. K is NOT incremented by the global completion condition's exit code; it is incremented only by the step's own narrow-fix check.*

### Steps

1. **Author `scripts/installer-skeleton-manifest.txt`** (single source of truth FIRST — drives every other step).
   - Verify: `wc -l < scripts/installer-skeleton-manifest.txt` ≥ 25 AND every listed path EITHER exists in the dev repo OR is one of the three target-only paths (`wiki/index.md`, `README.md`, `log.md`):
     ```
     missing=0; while IFS= read -r p; do
       case "$p" in wiki/index.md|README.md|log.md) continue ;; esac
       [ -e "$p" ] || { echo "manifest entry missing in dev repo: $p"; missing=1; }
     done < scripts/installer-skeleton-manifest.txt
     [ $missing -eq 0 ]
     ```
   - Narrow fix: manifest content.
   - K=3 then escalate.

2. **Author `README-FRESH.md`.** Pure CommonMark, fresh-user oriented.
   - Verify: `[ -f README-FRESH.md ] && grep -q 'wiki-extract' README-FRESH.md && grep -q 'wiki-ingest' README-FRESH.md && grep -q 'wiki-query' README-FRESH.md && ! grep -qE 'Quortex|karpathy|Phase Coherence' README-FRESH.md`
   - Narrow fix: README-FRESH.md content. Frozen after this step's commit.
   - K=3 then escalate.

3. **Author `wiki/index-FRESH.md`.** Stub with schema-v2 frontmatter.
   - Verify: frontmatter parses (the same awk predicate used in I4(c)) AND `! grep -qE 'Quortex|karpathy|Phase Coherence' wiki/index-FRESH.md`
   - Narrow fix: frontmatter + stub content. Frozen after this step's commit.
   - K=3 then escalate.

4. **Author `scripts/create-llm-wiki.sh`.** Implement §5 algorithm + manifest consumption.
   - Verify: `bash -n scripts/create-llm-wiki.sh && [ -x scripts/create-llm-wiki.sh ] && head -1 scripts/create-llm-wiki.sh | grep -q '^#!/usr/bin/env bash'`. Also: invoking with no args exits non-zero; invoking with an existing non-empty dir exits non-zero.
   - Narrow fix: installer logic OR manifest copy-path resolution OR `mkdir -p` placement. (Step 6's adversarial-pass concern noted: narrow-fix here covers ALL of installer file's content, not just the manifest-derived list.)
   - K=3 then escalate.

5. **Author `tests/installer-output/.gitignore`** (single line: `*` then `!.gitignore`).
   - Verify: file matches expected content.

6. **Author `scripts/verify-create-llm-wiki.sh`.** Implement the oracle per §3 I3 + I4 + I5.
   - Verify (without installer running yet — bash-level only): `bash -n scripts/verify-create-llm-wiki.sh && [ -x scripts/verify-create-llm-wiki.sh ]`.
   - Then: invoke against a stub installer (e.g., temporarily replace installer with `#!/usr/bin/env bash\nexit 1` — verifier must surface this red without false-greening).
   - Narrow fix: assertion logic.
   - K=3 then escalate.

7. **First real installer + verifier run.** Execute `./scripts/verify-create-llm-wiki.sh`.
   - Verify: exit 0 (all 5 installer asserts green).
   - **Narrow fix rules** (in priority order):
     - **I4(a) red — tree shape mismatch:** target has files not in the manifest OR is missing files in the manifest. Fix installer's copy logic OR the manifest, whichever is wrong. K=3 on the *installer file as a whole* (not per-manifest-entry).
     - **I4(b) red — content tripwire (`Quortex`/`karpathy`/`Phase Coherence` found in target):** the installer leaked dev-repo content. Almost always means a manifest entry resolved to the wrong source (e.g., dev `README.md` not `README-FRESH.md`). Fix path resolution. K=3.
     - **I4(c) red — wiki/index.md frontmatter malformed:** Re-edit `wiki/index-FRESH.md`. **BUT** §7 freezes it after step 3's commit — this triggers stop+escalate unless the malformation is from installer-side corruption (e.g., bad sed).
     - **I3 red — manifest entry missing in target:** parent-dir not created, or path resolution wrong. Fix installer.
     - **I5 red — preflight fails in target:** installer copied scripts without preserving `chmod +x`, or omitted a hard requirement. Fix installer.
     - **R1/R2/R3 red:** STOP and escalate immediately. Baseline regression.

8. **README pointer.** Add the "Start your own wiki" section to dev `README.md`.
   - Verify: `grep -q 'create-llm-wiki.sh' README.md`

## §7 Stop/escalate conditions

The agent must NOT push through any of these.

- **Gaming the oracle:** weakening any I-check predicate; deleting any R-check; padding `README-FRESH.md` or `wiki/index-FRESH.md` with grep-bait strings; making `scripts/installer-skeleton-manifest.txt` an empty/trivial list; having the installer `cp -R` the dev repo wholesale and then `rm` only the I4-named items (would now fail I4(a) tree-shape *and* I4(b) tripwire, but the *intent* is still a stop condition); making the verifier `cd` to the dev repo to satisfy its asserts.
- **Existing smoke regression:** if `./scripts/smoke-all.sh` was green before the agent started and goes red after a change, STOP, escalate.
- **Dev-repo content damage:** any edit that deletes/modifies `raw/smoke-source.md`, `raw/karpathy-llm-wiki-video-transcript.md`, `wiki/quortex-protocol.md`, `wiki/four-principles.md`, `wiki/index.md` (dev version), or `scripts/smoke-all.sh` → STOP. The installer should act ONLY on the temp target.
- **K=3 attempts on the same component file** without the corresponding check turning green.
- **Architectural pressure:** if making a check pass would require AGENTS.md schema bump (2→3), changing the type enum, adding a runtime dependency to a core script (R3), or violating §8.
- **Infrastructure non-code failures:** transient `mktemp`/`cp`/`git init` failures — retry with exponential backoff up to 3 times, then escalate.
- **Frozen-artifact re-edits:** after step 2's commit, `README-FRESH.md` is frozen. After step 3's commit, `wiki/index-FRESH.md` is frozen. If a later step requires changes to either, STOP and escalate.
- **Verifier-temp accumulation:** if `tests/installer-output/` grows beyond 3 unrelated subdirectories without intermediate green runs, STOP — likely indicates the verifier isn't cleaning up on green OR the loop is churning. Run `rm -rf tests/installer-output/*` and re-evaluate.

## §8 Non-goals (explicit out-of-scope)

- No npm/PyPI/GitHub-release publishing. Installer is invoked from a clone of the dev repo only.
- No Windows / PowerShell parity. macOS + Linux only; Bash 3.2+. Windows users via WSL.
- No sandboxed smoke in the fresh skeleton. Strip-all stands.
- No interactive prompts. One positional arg, runs to completion.
- No installer self-tests beyond `bash -n` + the verifier. The verifier IS the test harness.
- No multi-tool oracle. Verifier is pure shell.
- No enhancement of `wipe-meta-wiki.sh`. Stays as-is; the installer is the alternative path.
- No `cp --parents` (GNU-only). Use explicit `mkdir -p` before each copy.

## §9 Real-data test inventory

**Primary oracle (this iteration):**
- `scripts/verify-create-llm-wiki.sh` (NEW) — runs installer into temp target, asserts I3 + I4 (a/b/c) + I5.

**Live smoke command:** `./scripts/verify-create-llm-wiki.sh`. ~1–2 seconds (no LLM). Plus `./scripts/smoke-all.sh > /dev/null` as the regression umbrella.

**Existing fixtures preserved as baseline (R1):**
- All artifacts from the previous /goal iteration (smoke fixture, smoke output baseline, the 4 derived wiki pages, raw/smoke-source.md with populated ingested_hash).

**Before/after observable on a real run:**
- Before: `scripts/create-llm-wiki.sh`, `scripts/verify-create-llm-wiki.sh`, and `scripts/installer-skeleton-manifest.txt` do not exist.
- After: all three exist; running the verifier against the dev repo creates a temp target, asserts shape + tripwire + frontmatter + preflight, cleans up on green.

## Critical files

**New:**
- `scripts/create-llm-wiki.sh`
- `scripts/verify-create-llm-wiki.sh`
- `scripts/installer-skeleton-manifest.txt`
- `README-FRESH.md`
- `wiki/index-FRESH.md`
- `tests/installer-output/.gitignore`
- `.scratch/installer-fresh-skeleton/GOAL.md` (this file)

**Modified:**
- `README.md` (one new section: "Start your own wiki")

**Untouched (negative guards):**
- All dev-repo `raw/*`, `wiki/*.md`, `scripts/smoke-*.sh`, `tests/smoke/`, `tests/canary/`, `AGENTS.md`, `.claude/commands/wiki-*.md`.
- Schema version stays 2; `type` enum unchanged.

## Changes from prior draft (post-adversarial-pass)

1. **I4 reformulated** from a negative spot-list (gameable by wholesale `cp -R` then `rm` of 7 named files) into a positive-shape + content-tripwire + frontmatter-parse triple. The new I4(a) requires the target's tree shape to exactly equal the manifest; I4(b) ensures no dev-repo identifier strings leak; I4(c) validates index.md frontmatter against schema v2.
2. **I3 broadened** from a 5-of-27 spot-check to iterating EVERY manifest entry. The manifest itself becomes the single source of truth (a new deliverable).
3. **Algorithm fixed:** explicit `mkdir -p "$TARGET/$(dirname "$P")"` before each `cp` (Bash 3.2 has no `cp --parents`).
4. **Baseline count corrected:** `ls wiki/*.md | wc -l` is 27, not 28.
5. **Step 6 narrow-fix rules broadened** to cover installer-logic fixes, not just manifest fixes.
6. **K-counting clarified:** K is per-step's narrow-fix check, not the global completion condition's exit code.
7. **Verifier auto-cleanup added** to avoid `tests/installer-output/` accumulation across red runs.
