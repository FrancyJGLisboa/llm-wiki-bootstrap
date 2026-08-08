---
description: "Deprecated alias for /ctx-compile. Renamed in schema v5; still works."
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [<raw-file>]
---

`/wiki-ingest` was renamed to `/ctx-compile` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-ingest is now /ctx-compile

Then read `.claude/commands/ctx-compile.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
