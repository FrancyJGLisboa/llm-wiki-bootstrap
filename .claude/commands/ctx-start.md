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
4. If no specialization is active, offer only these choices: track client decisions
   (the one shipped specialization, `client-decision`), keep general research without a
   specialization (the generic compiler — say plainly that it captures claims and
   sources but has no domain vocabulary), or teach the workspace another kind of work
   (`/ctx-create-profile`). Confirm the choice before activation or creation.
5. Run `python3 scripts/inbox.py pending --json`. If evidence is waiting, offer to add
   and compile it through `/ctx-add`; do not present `/ctx-inbox` as another choice.
6. If no evidence is waiting AND the compiled context is empty, offer the shipped demo
   before anything else: `./scripts/stage-northstar.sh .` stages a synthetic corpus, so
   the user can see a real brief, delta and evidence chain without supplying anything.
   Say it is fictional. Offer it; never stage it without confirmation.
7. Map `$ARGUMENTS` to one intake or output workflow. Append `--save` to useful client
   views so results appear under `BRIEFS/` or `REVIEWS/`.
8. If the subject, client, or date is required and ambiguous, ask one question instead
   of guessing.
9. End with exactly one next action that takes under two minutes.

Do not expose commands, schemas, ontology terminology, Git internals, or optional tools
unless the user asks. Never claim evidence was compiled unless its raw mapping was
recorded successfully.
