# LEARNINGS — llm-wiki-bootstrap

Project-scoped lessons. Lead with the rule, then `Why:` and `When to apply:`.

---

## 2026-06-01 — shell scripts are macOS-authored but run in Ubuntu CI: force byte locale, don't trust local green

**Rule:** Any awk/sed that manipulates non-ASCII bytes (em-dash, etc.) must run
under `LC_ALL=C` so it stays byte-oriented. A passing run on macOS's BSD awk
proves nothing about Ubuntu CI, where gawk/mawk in a UTF-8 locale treat the same
bytes as multi-byte codepoints. Also: a `--no-build`/offline CI path can only
verify *committed* artifacts — anything gitignored as a build product (e.g.
`tests/smoke/output/last-answer.md`) must be tracked as a baseline or the check
fails on a fresh checkout.

**Why:** `wiki-lint-typed-relations.sh` built the em-dash via
`sprintf("%c%c%c",226,128,148)` and matched it with `index()`. On BSD awk that
yields the 3 raw bytes (R7 green locally); on Ubuntu CI's UTF-8 awk each `%c`
became a 2-byte char, so `index()` never matched and verbs were miscounted (R7
red). Separately, C4 reads the captured query answer, which was gitignored — CI
had no file to assert on. Both were invisible until the PR's Ubuntu run; local
macOS green was a false signal.

**When to apply:** Before claiming "CI-verified" — actually push and watch the
Ubuntu run, never infer it from a macOS pass. Any new shell check touching
non-ASCII, or any CI assertion on a generated artifact.

---

## 2026-05-30 — body-hash.sh frontmatter validation must allow body `---` rules

**Rule:** When guarding `scripts/body-hash.sh` (and `verify-extract.sh`) against
malformed frontmatter, validate as *line 1 is `---` AND there are ≥ 2 `^---$`
delimiters* — never *exactly 2*. Markdown bodies legitimately contain `---`
horizontal-rule lines, which push the count past 2 on perfectly valid files.

**Why:** The UX stress-test report's suggested fix ("count `^---$`; if ≠ 2,
exit 1") would have rejected any extracted article/PDF containing a thematic
break. The actual bug being fixed was a *missing closing* delimiter (count < 2)
yielding the empty-string SHA (`e3b0c442…`, exit 0) → `/wiki-ingest` stamps a
placeholder hash and idempotence skips the file forever (silent data loss).

**When to apply:** Any change to the hashing/idempotence core. Also: the fix is
a *pre-check guard only* — do NOT alter the hashing `awk` itself, or the
already-committed `ingested_hash` values change and idempotence breaks. A
legitimately-empty body (well-formed frontmatter, no content) should still pass
and honestly hash to `e3b0…`; that is correct, not the bug. Pinned by
`scripts/verify-body-hash.sh` (R6 in `smoke-all.sh`).

---

## 2026-05-30 — adding a confirm-gate to a shared script breaks its automated callers

**Rule:** When you add an interactive `[y/N]` confirmation to a destructive shell
command, grep for every **non-interactive** caller and give them the `--yes`
escape hatch. Headless callers (oracles, `claude -p`, CI) read EOF on the prompt
and abort — which is the right *safety* default but silently fails *automation*.

**Why:** Adding the `prune --apply` confirm gate to `scripts/registry.sh`
(report finding #5) immediately broke `scripts/verify-multi-wiki.sh`'s M2 check,
which calls `prune --apply >/dev/null 2>&1` and now hit EOF → abort → oracle red.
Fixed by passing `prune --apply --yes` in the oracle.

**When to apply:** Any new confirmation/`--force`/`--yes` gate on a script that
other scripts or slash-command prompts invoke. Mirror the existing convention:
`--yes`/`-y`/`--force` skips the prompt; TTY/interactive gets `[y/N]`; headless
without `--yes` aborts unchanged (see `wipe-meta-wiki.sh`).

---

## 2026-05-30 — an LLM-judge eval lies in BOTH directions; validate with planted cases

**Rule:** When building an eval with an LLM judge, prove it on **two planted
fixtures — one faithful, one unfaithful** — before trusting any number. The
judge can be wrong both ways: (a) too lenient if you parse its output badly,
(b) too harsh if you feed it the wrong evidence.

**Why (both bugs hit while building `eval-citation-faithfulness.sh`):**
1. *False FAITHFUL* — the grader echoed the instruction "FAITHFUL or
   UNFAITHFUL?", so `grep ... | head -1` grabbed the echoed word, not the
   verdict. Fix: demand a `VERDICT=` token, parse the LAST one, default-closed.
   Also: never pass multi-line evidence through bash `read` via hand-rolled
   `\n` encoding — bash double-quotes mangle it; base64 the fields instead.
2. *False UNFAITHFUL* — the evidence window for timestamp anchors was 8 lines
   from the heading, but the cited quote sat at line ~58 of a ~10-line section,
   just past the window. The judge correctly said "evidence doesn't support
   the claim" — because the evidence I extracted didn't contain it. Fix:
   extract the whole section (heading → next heading), not a fixed window.

**When to apply:** any judge-based eval. The judge is only as good as the
evidence you feed it and the parsing of its answer. A green that can't catch a
planted failure is theater; a red that flags a planted-faithful case is noise.
Both waste trust. The fixture lives at `tests/eval/faithfulness-fixture/`.
