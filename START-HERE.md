# Your AI context workspace

Work here as if you were collaborating with a research assistant. You do not need to
learn the files behind it or memorize commands.

If the optional **Context Workspace** VS Code extension is installed, use its sidebar
for every action below. Without it, the same workflow works directly through AI chat.

## 1. See it work first, with nothing of your own

A complete synthetic corpus ships with this workspace. Run:

```bash
./scripts/stage-northstar.sh .
```

Then open the AI chat and ask:

```text
Update my context, then prepare a brief for Northstar Feeds.
```

Then, to see the rest of the surface:

```text
What changed since June 1?
Why is BRL/USD 5.70 the current assumption?
What did we believe on June 30?
Show me only what needs review.
```

Northstar Feeds is fictional; every person, number, and event in it is invented. Use it
to see what a brief, a change report, and an evidence chain actually look like.

## 2. Set it up for your own work

Say to the AI:

> Help me set up this workspace for my work.

The assistant will ask what you are trying to keep current, choose the closest starter,
check the workspace, and give you one small next action.

## 3. Add evidence

Use whichever action is easiest:

- Choose files or folders with **Add Evidence**.
- Drop files or folders on the Context Workspace sidebar.
- Give the assistant a local file or folder path.
- Paste text, or paste one or many URLs.
- Drag files into `EVIDENCE-INBOX/`.

Then say:

> Add this evidence and update my context.

That is the only intake concept you need. Any regular file is preserved before
extraction. Common formats are compiled directly; an unfamiliar binary is retained and
reported as needing attention rather than discarded or falsely marked complete. The
workspace reports added, unchanged, degraded, and failed items separately.

After successful validation, the compiler creates a scoped local checkpoint. You do not
run Git during daily use, and the compiler never pushes automatically.

## Teach the workspace another kind of work

If the included specialization does not fit, choose **Create Specialization** and describe
the work in ordinary language. The assistant asks only for missing domain meaning, builds
and tests the technical package, then shows examples such as a supported conclusion,
supersession, contradiction, and UNKNOWN response.

You approve those observable examples—not schemas or code. Activation is blocked until
technical validation, behavioral coverage, and explicit domain-owner approval all pass.
After activation, the next action is **Add Evidence**.

## Ask for work, not files

Try requests such as:

- “Prepare me for the Northstar meeting.”
- “What changed since <your date>?”
- “Why do we think availability is now a concern?”
- “What did we believe on <your date>?”
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
