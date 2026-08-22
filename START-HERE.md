# Your AI context workspace

Work here as if you were collaborating with a research assistant. You do not need to
learn the files behind it or memorize commands.

If the optional **Context Workspace** VS Code extension is installed, use its sidebar
for every action below. Without it, the same workflow works directly through AI chat.

Start the AI chat and say:

> Help me set up this workspace for my work.

The assistant will ask what you are trying to keep current, choose the closest starter,
check the workspace, and give you one small next action.

## Add evidence

Use whichever action is easiest:

- Drag files into `EVIDENCE-INBOX/`.
- Give the assistant a local file or folder path.
- Give the assistant a URL.
- Paste text and give it a title.

Then say:

> Add this evidence and update my context.

That is the only intake concept you need. The workspace identifies what is new,
preserves your originals, records the source, and updates only affected context.

## Ask for work, not files

Try requests such as:

- “Prepare me for the Northstar meeting.”
- “What changed since August 1?”
- “Why do we think availability is now a concern?”
- “What did we believe at the end of June?”
- “Show me only what needs my judgment.”

Useful outputs are saved automatically:

- `BRIEFS/` contains meeting-ready briefs, changes, decisions, and evidence chains.
- `REVIEWS/` contains only contradictions, ambiguity, stale assumptions, and other
  exceptions needing judgment.

When the subject or date is unclear, the assistant asks one question instead of guessing.
When evidence is missing, it says UNKNOWN instead of filling the gap.

## The only folders in your daily work

| Folder | Purpose |
|---|---|
| `EVIDENCE-INBOX/` | Evidence you dropped into the workspace. Your originals are never edited or deleted. |
| `BRIEFS/` | Work-ready outputs you asked for. |
| `REVIEWS/` | Exceptions that genuinely need a human decision. |

Everything else is still local and inspectable, but hidden from the friendly workspace
view. Open [`ADVANCED.md`](ADVANCED.md) only when you want the compiler internals.
