# Gates: Self-service specialization builder

Scope: A domain expert using VS Code Agent Mode can describe a new specialization, review observable examples, activate it, and add evidence without editing schemas, running Git, or using a terminal.

- [x] G1: One deterministic command safely scaffolds a complete profile package from plain-language inputs and refuses overwrite/path traversal.
  CHECK: python3 tests/guided-workspace/test_profile_scaffold.py
  EXPECT: /profile scaffold: PASS/
  EVIDENCE: `test_profile_scaffold.py` printed `profile scaffold: PASS`, including overwrite and traversal negatives.

- [x] G2: Readiness reports distinguish technical validity, behavioral coverage, and explicit human approval; incomplete profiles cannot appear ready.
  CHECK: python3 tests/guided-workspace/test_profile_readiness.py
  EXPECT: /profile readiness: PASS/
  EVIDENCE: `test_profile_readiness.py` printed `profile readiness: PASS`, including incomplete, unsafe-name, and invalid-date negatives.

- [x] G3: `/ctx-create-profile` conducts the interview, scaffolds, customizes, tests, previews examples, obtains behavioral approval, activates, checkpoints, and ends at Add Evidence.
  CHECK: bash scripts/verify-self-service-profile.sh
  EXPECT: /conversational contract: PASS/
  EVIDENCE: Static contract audit printed `conversational contract: PASS`.

- [x] G4: Context Workspace exposes Create Specialization and Check Specialization Readiness as outcome-oriented AI-chat actions with no schema or Git prompts.
  CHECK: bash scripts/verify-self-service-profile.sh
  EXPECT: /VS Code journey: PASS/
  EVIDENCE: Extension command parity and prompt audit printed `VS Code journey: PASS`; VSIX install passed.

- [x] G5: Fresh scaffolds include all self-service tools and README/START-HERE/GitHub Pages consistently explain the journey and its honest human-approval boundary.
  CHECK: bash scripts/verify-self-service-profile.sh
  EXPECT: /distribution and guidance: PASS/
  EVIDENCE: Fresh installer and six-surface documentation assertions printed `distribution and guidance: PASS`.

- [x] G6: A temporary compiler can scaffold, approve, activate, and verify a new specialization end to end; the full generic/profile/extension suite remains green.
  CHECK: bash scripts/vscode-extension-regression.sh
  EXPECT: /VS Code extension regression: PASS/
  EVIDENCE: Fresh compiler e2e passed through first evidence; npm audit found 0 vulnerabilities; reproducible VSIX SHA-256 `5e15762a644f09827dc27148cbdc6646a3ffbe0dcc0c5c038266c0fa24b186fa`; all 58 checks green.
