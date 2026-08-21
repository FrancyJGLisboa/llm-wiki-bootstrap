---
description: Build a concise, evidence-grounded current decision brief for one client.
allowed-tools: Bash, Read
argument-hint: <client-slug> [--json] [--save]
---

Execute `/ctx-client-brief` from the compiler root. This is read-only on evidence; `--save` writes the deterministic view under `BRIEFS/`.

1. Run `python3 scripts/profile-resolve.py` and stop with a setup error unless its exact output is `client-decision`.
2. Run `python3 scripts/client-context.py brief $ARGUMENTS`.
3. Return the output unchanged. Do not search the web, promote claims, infer missing fields, or edit `raw/` or `context/`.

The client identifier must be its exact slug. Material statements include claim IDs and resolving `raw/path#anchor` citations; absent evidence remains UNKNOWN.
