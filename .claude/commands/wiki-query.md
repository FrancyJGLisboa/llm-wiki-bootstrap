---
description: "Deprecated alias for /ctx-query. Renamed in schema v5; still works."
allowed-tools: Bash, Read, Write, Edit, WebSearch, WebFetch, Glob, Grep
argument-hint: <question> [--no-promote] [--visual [html|pdf|png]] [--archetype <name>]
---

`/wiki-query` was renamed to `/ctx-query` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-query is now /ctx-query

Then read `.claude/commands/ctx-query.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
