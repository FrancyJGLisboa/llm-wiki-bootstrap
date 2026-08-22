# Context Workspace for VS Code — product specification

## Product decision

The extension is a local operator for a context compiler, not a second compiler and
not a hosted service. The filesystem package remains the durable product. Every
extension action delegates to versioned repository contracts, so the same compiler
continues to work from AI chat, the terminal, CI, or another editor.

## Primary user

A domain expert with VS Code and GitHub Copilot Enterprise who is comfortable with
files and AI chat but should not need compiler commands, schemas, or Git for daily
operation.

## Required journeys

1. **Create:** choose a destination and specialization, scaffold a compiler, open its
   friendly workspace, and receive one concrete next action.
2. **Specialize:** describe another kind of work in ordinary language, answer at most five
   domain questions, inspect behavioral examples, and explicitly approve before activation.
3. **Add evidence:** choose files or folders directly, drop them on the sidebar, paste
   titled text, paste one or many URLs, or process the inbox through one experience.
4. **Prepare:** choose a client and produce a saved meeting brief.
5. **Understand change:** choose a client and temporal boundary and produce a saved delta.
6. **Inspect trust:** ask why, open the evidence chain, and jump to cited local evidence.
7. **Review:** show only contradictions, ambiguous attribution, possible supersession,
   stale assumptions, unsupported claims, and unknown owners.

## Usability contract

- The welcome view always offers a useful action; it never opens on an empty dashboard.
- Commands are named for work outcomes: Add Evidence, Prepare Brief, Show Changes,
  Explain Why, Review Exceptions, and Check Health.
- The extension detects the active profile and available outputs instead of asking users
  to understand schemas.
- Every action shows progress, success, degraded results, or a specific recovery action.
- Every regular local file is preserved before extraction. Universal intake must never
  be described as universal extraction; unsupported content remains inspectable and is
  reported as needing attention.
- Successful validated mutations create a scoped local checkpoint without including
  unrelated staged work. The extension and compiler never push automatically.
- Destructive operations are absent from the initial extension.
- Advanced controls remain available through `ADVANCED.md` and the command palette.
- Specialization readiness exposes technical validity, behavioral coverage, and human
  approval separately. An agent cannot approve its own domain examples.

## Architecture and trust boundary

```text
VS Code views and commands
        |
        | validated arguments; explicit consent for URLs
        v
local compiler adapter
        |
        | existing scripts and profile workflows
        v
EVIDENCE-INBOX -> raw -> context -> BRIEFS / REVIEWS
```

The extension may read workspace status and generated outputs. It may write only through
the existing staging, profile, compiler, and output contracts. It must not edit `raw/`
or `context/` directly. It invokes child processes without a shell, with a fixed command
and argument array, and reports non-zero exits without recording false completion.

## Copilot boundary

Version 0.1 contributes workspace instructions and entry points that work naturally with
GitHub Copilot Chat. It does not call a model API, store tokens, select a model, or depend
on a second subscription. A future chat participant may use VS Code's model selected by
the user, but deterministic validation must remain outside model judgment.

## Privacy and enterprise controls

- Telemetry: none.
- Credentials: none stored or requested.
- Network: only the existing URL acquisition workflow, after explicit confirmation.
- Evidence: remains in the selected local workspace.
- Logs: process summaries omit evidence bodies and are shown only in a local output channel.
- Distribution: reproducible VSIX for managed installation; Marketplace publication is
  optional and outside this milestone.
- Updates: enterprise IT controls VSIX deployment. The extension never self-updates.

## Failure behavior

- Missing compiler: offer Create Compiler or Open Compiler.
- Missing dependency: show the exact preflight failure and open setup guidance.
- Cancelled selection or confirmation: no mutation and no error notification.
- Partial evidence failure: preserve staged originals, show per-item status, and do not
  claim compilation completed.
- Unsupported profile workflow: explain which action is unavailable and retain generic
  query/lint functionality.
- Malformed or hostile input: reject before process execution.

## Non-goals

- Reimplementing extraction, compilation, temporal resolution, or validation in TypeScript.
- Background monitoring, connectors, authentication, billing, telemetry, or a cloud backend.
- Automatic access to the entire laptop.
- Silent URL fetching or automatic upload of evidence.
- Requiring the extension to operate a compiler from another supported AI environment.

## Acceptance evidence

The milestone requires contract tests for routing and validation, a static security audit,
a packaged VSIX whose contents are inspected, a fresh-compiler installation check, and the
repository's full keyless regression suite.
