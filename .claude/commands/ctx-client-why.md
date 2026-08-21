---
description: Inspect the exact evidence chain behind a client claim.
allowed-tools: Bash, Read
argument-hint: <client-slug> "<claim-id-or-unique-text>" [--json]
---

Execute `/ctx-client-why` from the compiler root. This is read-only.

1. Require `python3 scripts/profile-resolve.py` to print exactly `client-decision`.
2. Run `python3 scripts/client-context.py why $ARGUMENTS`.
3. Return the evidence chain unchanged. Ambiguous or absent text must remain explicit `UNKNOWN`; do not choose a match, search the web, or promote a claim.
