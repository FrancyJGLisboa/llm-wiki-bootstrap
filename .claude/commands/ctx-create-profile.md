---
description: Interview the user and create a validated specialized compiler profile.
allowed-tools: Bash, Read, Write
argument-hint: [profile-name]
---

Create a profile as an extension of the generic compiler, never as a core rewrite.

## Interview

Ask at most five short questions, one conversational batch:

1. What evidence enters this compiler?
2. Which subjects, entities, or decisions must it represent?
3. Which changes, contradictions, or stale states matter?
4. Which daily outputs would save time?
5. Which statements require human review rather than automatic acceptance?

If the answers are already present in the conversation, do not ask again. Propose a
kebab-case profile name and obtain confirmation before creating files.

## Build contract

1. Read `profiles/client-decision/` as the reference extension, not as a commodity
   ontology to copy blindly.
2. Create only `profiles/<name>/` plus profile-owned tests and commands. Do not add
   domain concepts or branches to `scripts/lib/claims.py` or the generic lifecycle.
3. Write `profile.json` with matching `name`, integer `profile_version`, and an
   exhaustive sorted `artifacts` list. Paths must be relative and remain inside the
   profile directory.
4. Keep the ontology minimal. Separate observation, fact, assumption, inference,
   derivation, and unknown. Preserve speaker and evidence domains when attributable
   sources are in scope.
5. Include positive, negative, absence, temporal, provenance, and no-op fixtures.
6. Run `python3 scripts/profile-check.py --profile <name>` and the profile-owned
   verifier. Fix every failure before offering activation.
7. Show the generated files and explain the specialization in ordinary language.
8. Activate only after user confirmation with `./scripts/use-profile.sh <name>`.

UNKNOWN is a valid output. Never invent fields merely to make a template complete.
