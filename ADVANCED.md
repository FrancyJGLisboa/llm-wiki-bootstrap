# Advanced controls

The friendly workspace hides compiler machinery from the Explorer; it does not remove
or lock it. To inspect everything, open the repository folder normally instead of
`AI-WORKSPACE.code-workspace`, or change `files.exclude` in workspace settings.

## Stable internal workflows

- `/ctx-extract` acquires a URL, local file, or pasted text into normalized `raw/`.
- `/ctx-inbox` processes files already staged under `EVIDENCE-INBOX/`.
- `/ctx-compile` compiles normalized sources.
- `/ctx-lint` checks generic context health.
- `/ctx-create-profile` creates another specialization through a guided interview.

Ordinary use should start with `/ctx-add`, which routes to those contracts and compiles
by default.

## Inspectability

The hidden surfaces remain ordinary local files: `raw/` evidence, `context/` compiled
state, `profiles/` specialization contracts, `scripts/` deterministic tools, and Git
history. The simplified view changes presentation, not provenance or ownership.
