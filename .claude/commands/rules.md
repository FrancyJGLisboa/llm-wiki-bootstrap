---
description: Alias for /ctx-rules. Inventory and triage rules; classify deterministic / heuristic / unverifiable. Writes no code.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [--scan-repo | --scan-context] [--class deterministic|heuristic|unverifiable]
---

This is a short-form alias for `/ctx-rules`. Read the canonical procedure in `.claude/commands/ctx-rules.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth for the inventory (§2) and triage (§3) steps, including the rule that this command writes no code.
