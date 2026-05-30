---
description: Alias for /wiki-query. Answer a question from the wiki; web-search + promote on gaps. Optionally diagram the answer with --visual.
allowed-tools: Bash, Read, Write, Edit, WebSearch, WebFetch, Glob, Grep
argument-hint: <question> [--no-promote] [--visual [html|pdf|png]] [--archetype <name>]
---

This is a short-form alias for `/wiki-query`. Read the canonical procedure in `.claude/commands/wiki-query.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth for the query + (optional) auto-promote flow.
