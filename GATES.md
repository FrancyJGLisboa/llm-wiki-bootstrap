# Gates: Local VS Code context workspace extension

Scope: Ship a usable, locally installable VS Code extension that operates existing specialized context compilers through a friendly interface while preserving filesystem ownership, provenance, deterministic validation, and enterprise controls.

- [x] G1: The extension has a versioned product specification with explicit user journeys, non-goals, trust boundaries, telemetry policy, permissions, and failure behavior.
  CHECK: bash scripts/verify-vscode-extension.sh
  EXPECT: /specification: PASS/
  EVIDENCE: `docs/VSCODE-EXTENSION-SPEC.md`; `verify-vscode-extension.sh` reported `specification: PASS`.

- [x] G2: A user can create or open a compiler workspace and reach a useful first action without entering a terminal command.
  CHECK: node --test tests/vscode-extension/*.test.js
  EXPECT: /fail 0/
  EVIDENCE: Walkthrough, activity view, named-folder scaffold, open-existing flow, and template-copy contracts; Node test suite passed 8/8.

- [x] G3: Files, folders, pasted text, URLs, and EVIDENCE-INBOX are exposed through one Add Evidence experience backed by existing safe compiler boundaries.
  CHECK: node --test tests/vscode-extension/*.test.js
  EXPECT: /fail 0/
  EVIDENCE: One Add Evidence chooser routes four modes; local/text tests pass, text uses stdin, URL acquisition requires modal consent.

- [x] G4: Briefs, deltas, why chains, historical state, and review exceptions are accessible through plain-language actions; generated files open in VS Code and citations resolve to local evidence.
  CHECK: bash scripts/verify-vscode-extension.sh
  EXPECT: /daily workflows: PASS/
  EVIDENCE: Seven outcome actions plus exact raw citation resolver and anchor navigation; verifier reported `daily workflows: PASS`.

- [x] G5: The extension is local-first, has no telemetry, does not embed credentials or call an independent model API, validates process inputs, and asks before network evidence acquisition.
  CHECK: bash scripts/verify-vscode-extension.sh
  EXPECT: /security boundary: PASS/
  EVIDENCE: Static security boundary passed; subprocesses use `shell: false`; workspace trust required; npm audit found 0 vulnerabilities.

- [x] G6: A reproducible VSIX and enterprise deployment guide are produced, the generated compiler recommends the extension without requiring it, and the complete generic/decision-context regression suite remains green.
  CHECK: bash scripts/vscode-extension-regression.sh
  EXPECT: /VS Code extension regression: PASS/
  EVIDENCE: Two builds produced SHA-256 `d123acb0958355407b607e3dbd5d6b789598c6d5db127ab982869de9416ea602`; isolated VS Code install passed; all 56 regressions passed.
