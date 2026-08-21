---
description: Guide a non-developer through the next useful context-compiler action.
allowed-tools: Bash, Read
argument-hint: [goal in plain language]
---

Guide the user from the compiler root. Do not modify evidence or choose a domain
without confirmation.

1. Read `START-HERE.md`.
2. Run `./scripts/preflight.sh` and summarize only actionable failures.
3. Resolve the profile conditionally: if `scripts/profile-resolve.py` exists, run it;
   otherwise report `generic`. Explain the result in one sentence.
4. If `scripts/inbox.py` exists, run `python3 scripts/inbox.py pending --json` and
   report the number and names of pending files.
5. If `$ARGUMENTS` names a goal, map it using the natural-language table in
   `START-HERE.md`. If the subject, client, or date is required and ambiguous, ask
   one question instead of guessing.
6. End with exactly one next action that takes under two minutes.

Do not expose schemas, ontology terminology, Git internals, or optional tools unless
the user asks. Never claim an EVIDENCE-INBOX file was compiled unless its raw mapping was
recorded successfully.
