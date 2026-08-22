# Advanced controls

The friendly workspace hides compiler machinery from the Explorer; it does not remove
or lock it. To inspect everything, open the repository folder normally instead of
`AI-WORKSPACE.code-workspace`, or change `files.exclude` in workspace settings.

## Stable internal workflows

- `/ctx-extract` acquires a URL, local file, or pasted text into normalized `raw/`.
- `/ctx-inbox` processes files already staged under `EVIDENCE-INBOX/`.
- `/ctx-compile` compiles normalized sources.
- `/ctx-lint` checks generic context health.
- `/ctx-create-profile` scaffolds, customizes, previews, validates, approves, activates,
  and checkpoints another specialization through a guided interview.

Self-service profile tools are deterministic controls behind that conversation:

- `scripts/profile-scaffold.py` safely creates a non-overwriting profile package.
- `scripts/profile-check.py` validates its exhaustive portable-asset manifest.
- `scripts/profile-readiness.py` separates technical validity, behavioral coverage, and
  explicit domain-owner approval. `use-profile.sh` refuses an unready self-service profile.

Ordinary use should start with `/ctx-add`, which routes to those contracts and compiles
by default.

## Inspectability

The hidden surfaces remain ordinary local files: `raw/` evidence, `context/` compiled
state, `profiles/` specialization contracts, `scripts/` deterministic tools, and Git
history. The simplified view changes presentation, not provenance or ownership.
