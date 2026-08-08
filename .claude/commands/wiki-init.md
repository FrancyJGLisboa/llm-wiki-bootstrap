---
description: "Deprecated alias for /ctx-init. Renamed in schema v5; still works."
allowed-tools: Bash, Read, Write, Glob
argument-hint: (no arguments)
---

`/wiki-init` was renamed to `/ctx-init` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-init is now /ctx-init

Then read `.claude/commands/ctx-init.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
