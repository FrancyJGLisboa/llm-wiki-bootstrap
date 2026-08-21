---
description: Show the exception-only review queue for one client's decision context.
allowed-tools: Bash, Read
argument-hint: <client-slug> [--json] [--save]
---

Execute `/ctx-client-review` from the compiler root. This is read-only on evidence; `--save` writes the deterministic exception report under `REVIEWS/`.

1. Require `python3 scripts/profile-resolve.py` to print exactly `client-decision`.
2. Run `python3 scripts/client-context.py review $ARGUMENTS`.
3. Return only the deterministic exception queue. Do not request approval for every claim or resolve ambiguity automatically.
