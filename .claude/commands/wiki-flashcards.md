---
description: "Deprecated alias for /ctx-flashcards. Renamed in schema v5; still works."
allowed-tools: Bash, Read, Glob
argument-hint: [target-dir] [--out <path>]
---

`/wiki-flashcards` was renamed to `/ctx-flashcards` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-flashcards is now /ctx-flashcards

Then read `.claude/commands/ctx-flashcards.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
