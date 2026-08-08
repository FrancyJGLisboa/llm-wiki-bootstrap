---
description: "Deprecated alias for /ctx-diagram. Renamed in schema v5; still works."
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "<what you want to show, and for whom>" [--pdf|--png]
---

`/wiki-diagram` was renamed to `/ctx-diagram` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-diagram is now /ctx-diagram

Then read `.claude/commands/ctx-diagram.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
