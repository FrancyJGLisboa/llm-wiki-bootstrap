---
description: List currently active, evidence-grounded assumptions for one client.
allowed-tools: Bash, Read
argument-hint: <client-slug> [--json]
---

Execute `/ctx-client-assumptions` from the compiler root. This is read-only.

1. Require `python3 scripts/profile-resolve.py` to print exactly `client-decision`.
2. Run `python3 scripts/client-context.py assumptions $ARGUMENTS`.
3. Return the output unchanged. Never turn a question, hypothetical, agreement, or qualified agreement into an assumption.
