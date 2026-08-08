---
description: "Deprecated alias for /ctx-lint. Renamed in schema v5; still works."
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [--apply]
---

`/wiki-lint` was renamed to `/ctx-lint` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-lint is now /ctx-lint

Then read `.claude/commands/ctx-lint.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
