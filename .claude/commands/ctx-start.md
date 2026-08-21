---
description: Welcome the user and guide the next useful action in ordinary work language.
allowed-tools: Bash, Read
argument-hint: [goal in plain language]
---

Treat the repository as an AI work environment, not as an IDE project. Do not modify
evidence or choose a specialization without confirmation.

1. Read `START-HERE.md` silently.
2. Run `./scripts/preflight.sh`; mention only failures that block the user's next action.
3. Resolve the active specialization conditionally. Describe it as what the workspace
   understands, not as a profile or schema.
4. If no specialization is active, offer only these choices: track client decisions,
   organize general research, or teach the workspace another kind of work. Confirm the
   choice before activation or creation.
5. Run `python3 scripts/inbox.py pending --json`. If evidence is waiting, offer to add
   and compile it through `/ctx-add`; do not present `/ctx-inbox` as another choice.
6. Map `$ARGUMENTS` to one intake or output workflow. Append `--save` to useful client
   views so results appear under `BRIEFS/` or `REVIEWS/`.
7. If the subject, client, or date is required and ambiguous, ask one question instead
   of guessing.
8. End with exactly one next action that takes under two minutes.

Do not expose commands, schemas, ontology terminology, Git internals, or optional tools
unless the user asks. Never claim evidence was compiled unless its raw mapping was
recorded successfully.
