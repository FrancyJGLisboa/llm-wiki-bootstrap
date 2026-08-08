---
description: Alias for /ctx-gate. Turn a deterministic rule into a proven, wired gate.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: <RULE-ID> [--dry-run]
---

This is a short-form alias for `/ctx-gate`. Read the canonical procedure in `.claude/commands/ctx-gate.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth, including the refusals (non-deterministic rule, LLM-based detection) and the mutation proof that cannot be skipped.
