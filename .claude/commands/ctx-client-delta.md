---
description: Report semantic changes in a client's decision context since a date.
allowed-tools: Bash, Read
argument-hint: <client-slug> --since YYYY-MM-DD [--json] [--save]
---

Execute `/ctx-client-delta` from the compiler root. This is read-only on evidence; `--save` writes the deterministic view under `BRIEFS/`.

1. Run `python3 scripts/profile-resolve.py` and stop unless its exact output is `client-decision`.
2. Run `python3 scripts/client-context.py delta $ARGUMENTS`.
3. Return all five deterministic categories unchanged: `NEW`, `CHANGED`, `SUPERSEDED`, `UNRESOLVED`, `UNCHANGED BUT MATERIAL`.

Do not derive a delta from textual differences, search the web, promote claims, or edit compiled evidence.
