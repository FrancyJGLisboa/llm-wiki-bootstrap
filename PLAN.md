# Decision Context Milestone — Execution Plan

## Frozen contract

- Profile activation is opt-in through `context-profile.json`; absence preserves generic behavior.
- Profile manifests live at `profiles/<name>/profile.json`; profile schema version starts at 1.
- Generic claims live at `context/claims/by-source/<source-id>.jsonl`; stable IDs are `CLM-` plus 12 uppercase SHA-256 hex characters over canonical identity fields.
- Claim classes are `observation`, `fact`, `assumption`, `inference`, `derivation`, and `unknown`.
- Claim relations are `supersedes`, `updates`, `confirms`, `contradicts`, `narrows`, and `broadens`; deterministic code validates and projects explicit relations but never invents them.
- Decision projections live at `context/decisions/<client>/<decision-id>.json` with a Markdown companion.
- Canonical commands are `/ctx-client-{brief,delta,decisions,assumptions,why,review,lint}` with `/client-*` aliases and `--json` machine output.
- The Northstar milestone corpus contains exactly 24 synthetic sources; gold data is excluded from compilation workspaces.
- Every new deterministic gate must fail a violating fixture and pass a clean fixture. Existing generic behavior and all current smoke guards remain green.

## Ownership and waves

| Leaf | Wave | Ownership | Dependencies |
|---|---:|---|---|
| profile-spine | 0 | profile resolver/selector, Codex smoke fix, installer/package manifest integration, its tests | none |
| claim-core | 1 | claim validation/state/delta/why scripts and fixtures | profile-spine |
| profile-definition | 1 | `profiles/client-decision/` schemas, vocabularies, templates | profile-spine |
| northstar-benchmark | 1 | `benchmarks/northstar/`, staging/eval scripts, leakage tests | profile-spine |
| client-workflows | 2 | client command files, workflow engine, workflow tests | claim-core + profile-definition |
| integration | 3 | compile/lint hook integration, smoke wiring, docs, final regression fixes | all leaves |

No two agents may edit the same file in the same wave. A leaf that needs a frozen interface changed must stop and report it.

## Status log

- 2026-08-21: plan and acceptance ledgers created; existing keyless baseline was 47/47 green before implementation.

