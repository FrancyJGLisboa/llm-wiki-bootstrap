# LEARNINGS — llm-wiki-bootstrap

Project-scoped lessons. Lead with the rule, then `Why:` and `When to apply:`.

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
