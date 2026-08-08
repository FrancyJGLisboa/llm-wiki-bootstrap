---
description: "Deprecated alias for /ctx-discover. Renamed in schema v5; still works."
allowed-tools: Bash, Read
argument-hint: (no args)
---

`/wiki-discover` was renamed to `/ctx-discover` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-discover is now /ctx-discover

Then read `.claude/commands/ctx-discover.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
