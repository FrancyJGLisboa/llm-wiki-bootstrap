---
description: Alias for /wiki-learn. Distill an interaction into durable facts, gate them, and ingest into the wiki.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [<transcript-file>] [--dry-run] [--scope-dir <path>]
---

This is a short-form alias for `/wiki-learn`. Read the canonical procedure in `.claude/commands/wiki-learn.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth for the distill → notability-gate → capture → ingest loop (gate criteria, factual/preference tagging, privacy guard, latest-wins-with-trail contradiction policy).
