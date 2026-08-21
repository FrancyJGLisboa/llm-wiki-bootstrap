# Start here

You do not need to understand the repository before using it. Open the AI chat in
VS Code (or another agentic coding tool) and type:

> Help me set up this context compiler.

The agent should follow `/ctx-start`: check the workspace, explain the active
profile in plain language, and give you one next action.

## The three folders you use

| Folder | What you do there |
|---|---|
| `EVIDENCE-INBOX/` | Drop new emails, transcripts, reports, spreadsheets, screenshots, or notes. Your originals are never edited or deleted. |
| `BRIEFS/` | Read generated meeting briefs, decision lists, deltas, and evidence chains. |
| `REVIEWS/` | Read only the exceptions that need judgment: contradictions, ambiguous speakers, possible supersession, and unsupported material claims. |

Everything else is the compiler machinery. You can inspect it, but ordinary daily
use does not require editing it.

## First useful result

1. Activate the included specialization from the VS Code task **Context: Activate client-decision**, or run:

   ```bash
   ./scripts/use-profile.sh client-decision
   ```

2. Drop evidence into `EVIDENCE-INBOX/`.
3. Tell the AI: **Compile my inbox.**
4. Tell the AI: **Prepare a brief for `<client-name>`.**

The agent maps those requests to the stable `/ctx-inbox`, `/ctx-compile`, and
`/client-brief` workflows. You can use the commands directly, but you do not need
to memorize them.

## Daily language that works

| Say this | Workflow used |
|---|---|
| “Compile my inbox.” | `/ctx-inbox`, then `/ctx-compile` |
| “Prepare me for the Northstar meeting.” | `/client-brief northstar-feeds --save` |
| “What changed since August 1?” | `/client-delta northstar-feeds --since 2026-08-01 --save` |
| “Why do we think availability is a concern?” | `/client-why northstar-feeds "availability is a concern" --save` |
| “Show me what needs review.” | `/client-review northstar-feeds --save` |
| “What did we believe on June 30?” | `/client-decisions northstar-feeds --as-of 2026-06-30 --save` |

When the subject is ambiguous, the agent must ask for the exact subject rather
than guessing.

## Create a different specialization

Tell the AI:

> Help me create a context compiler profile for my work.

It follows `/ctx-create-profile`: a short interview about evidence, subjects,
decisions, changes, and useful outputs. The generated profile stays separate from
the generic core and must pass `scripts/profile-check.py` before activation.

## Check the workspace

Use the VS Code task **Context: Check setup**, or run:

```bash
./scripts/preflight.sh
python3 scripts/inbox.py pending
```

The compiler keeps explicit files and Git history underneath this guided surface.
That is deliberate: the friendly workflow does not trade away provenance,
inspectability, or portability.
