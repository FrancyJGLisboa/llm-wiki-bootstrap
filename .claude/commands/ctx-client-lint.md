---
description: Print transparent decision-context health diagnostics for one client.
allowed-tools: Bash, Read
argument-hint: <client-slug> [--json] [--save]
---

Execute `/ctx-client-lint` from the compiler root. This is read-only on evidence; `--save` writes the deterministic diagnostic report under `REVIEWS/`.

1. Require `python3 scripts/profile-resolve.py` to print exactly `client-decision`.
2. Run `python3 scripts/client-context.py lint $ARGUMENTS`.
3. Return the counts and percentages unchanged. Never invent or summarize them into an aggregate AI score.
