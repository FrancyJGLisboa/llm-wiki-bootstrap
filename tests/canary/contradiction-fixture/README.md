# contradiction-fixture

Two mirror-flagged wiki pages that exercise the `/ctx-compile` → `/ctx-lint`
**contradiction round-trip** (report finding #25 — the path was specified but
never demonstrated).

- `/ctx-compile` step 5 *produces* the flag: a blockquote line containing the
  literal token `CONTRADICTION FLAGGED` plus a `[[other-page]]` back-reference.
- `/ctx-lint` check #3 *consumes* it: `grep -rn 'CONTRADICTION FLAGGED' wiki/`.

Each page flags the other, so the contradiction is visible from both sides.

Verify the consumer side matches the producer format (target the page files so
this README's own mentions of the token don't inflate the count):

```sh
grep -rln 'CONTRADICTION FLAGGED' tests/canary/contradiction-fixture/*-roaster.md   # → 2 files
```
