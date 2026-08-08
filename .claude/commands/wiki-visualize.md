---
description: "Deprecated alias for /ctx-visualize. Renamed in schema v5; still works."
allowed-tools: Bash, Read, Glob
argument-hint: [graph|mermaid|slides|serve] [target] [--out <path>]
---

`/wiki-visualize` was renamed to `/ctx-visualize` when this project became a context compiler rather than a wiki generator. This alias still works and is not scheduled for removal — old muscle memory and old scripts keep working.

Print exactly this one line first:

    note: /wiki-visualize is now /ctx-visualize

Then read `.claude/commands/ctx-visualize.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth.
