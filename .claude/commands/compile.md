---
description: Alias for /ctx-compile. Process raw/ → wiki/ via the 7-step pipeline.
allowed-tools: Bash, Read, Write, Edit
argument-hint: [<raw-file>]
---

This is a short-form alias for `/ctx-compile`. Read the canonical procedure in `.claude/commands/ctx-compile.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth for the 7-step pipeline (read, extract, write summary, update existing, flag contradictions, update index, log).
