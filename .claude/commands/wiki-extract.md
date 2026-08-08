---
description: "Deprecated alias for /ctx-extract. Renamed in schema v5; still works."
allowed-tools: Bash, Read, Write, WebFetch
argument-hint: <url-or-filepath> [<url-or-filepath> ...]  |  --text [--title "<title>"] [--source-type <value>] <pasted text>
---

`/wiki-extract` was renamed to `/ctx-extract` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-extract is now /ctx-extract

Then read `.claude/commands/ctx-extract.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
