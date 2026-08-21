---
description: Show current or point-in-time decision projections for one client.
allowed-tools: Bash, Read
argument-hint: <client-slug> [--as-of YYYY-MM-DD] [--json] [--save]
---

Execute `/ctx-client-decisions` from the compiler root. This is read-only on evidence; `--save` writes the deterministic view under `BRIEFS/`.

1. Require `python3 scripts/profile-resolve.py` to print exactly `client-decision`.
2. Run `python3 scripts/client-context.py decisions $ARGUMENTS`.
3. Return the deterministic projection unchanged. Missing fields are unknown; never complete them from model judgment or web search.
