---
description: Create, preview, approve, and activate a specialization through conversation.
allowed-tools: Bash, Read, Write, Edit
argument-hint: [plain-language goal or profile-name]
---

Treat this as a guided product setup, not a coding lesson. The user supplies domain
meaning and judges examples. You own schemas, vocabularies, fixtures, tests, validation,
activation, and checkpointing. Never ask the user to edit a file, use Git, or run a command.

## 1. Understand the work

Use `$ARGUMENTS` and the conversation first. Ask only for missing information, in one
batch of at most five short questions:

1. What recurring decision or current state should this workspace reconstruct?
2. What evidence will people add in normal work?
3. Which subjects, concepts, and changes matter?
4. Which two or three outputs would save time?
5. Which ambiguity or error must require human judgment?

Summarize the answers in ordinary language and propose a safe kebab-case name. Obtain
name confirmation before writing. Do not ask ontology or schema questions.

## 2. Scaffold safely

Run `scripts/profile-scaffold.py` with the confirmed name, title, purpose, and repeated
plain-language `--evidence`, `--concept`, `--output`, and `--review-trigger` values. Never
create the directory manually and never overwrite an existing profile. If the name
exists, offer to inspect it or choose a new name.

## 3. Turn examples into the domain contract

Read `profiles/client-decision/` only as an extension-pattern reference. Work exclusively
inside `profiles/<name>/` and profile-owned tests or commands. Do not add domain branches
to the compiler core.

Create or refine clearly labelled synthetic evidence that covers realistic domain
language, irrelevant information, ambiguity, and speaker attribution when applicable.
Replace every placeholder in `acceptance.json` with an observable expected behavior for:

- positive/current-state reconstruction;
- exact provenance;
- temporal supersession;
- contradiction review;
- refusal/UNKNOWN on absence;
- unchanged-input no-op.

Gold expectations must remain separate from compilation inputs. Keep the ontology minimal.
Preserve observation, fact, assumption, inference, derivation, and unknown. Require source
anchors for material claims, preserve historical states, and make model judgment heuristic.
Add profile-owned acceptance tests when domain-specific deterministic behavior exists.

If files are added or removed, update `profile.json.artifacts` to the exact sorted list of
portable files. Do not include `profile.json` itself.

## 4. Validate and preview behavior

Run:

```text
python3 scripts/profile-check.py --profile <name>
python3 scripts/profile-readiness.py --profile <name> --write
```

The second command is expected to remain not-ready until human approval. Fix technical or
behavioral failures. Then show the user a compact preview in ordinary work language:

- one supported current-state result with its evidence;
- one meaningful change or supersession;
- one contradiction routed to review;
- one unsupported question answered UNKNOWN;
- the intended brief or other primary output.

Ask: **“Do these examples match how your team should reason about this work?”** Apply
corrections and re-run checks. Approval is about observable behavior, never implementation.

## 5. Approve, activate, and start cultivating

Only after an explicit yes, record the approver name supplied by the user (ask once if
unknown), then run:

```text
python3 scripts/profile-readiness.py --profile <name> --approve "<approver>" --write
./scripts/use-profile.sh <name>
./scripts/checkpoint-context.sh --message "profile: activate <name>"
```

Show the saved readiness report. Explain what the workspace now understands, the evidence
it accepts, the outputs it produces, and what enters human review. End with exactly one
next action: **Add your first evidence.**

UNKNOWN is a valid output. Never activate an incomplete, untested, or unapproved
self-service profile. Never imply that the AI discovered the correct domain semantics;
the user's example approval is the authority.
