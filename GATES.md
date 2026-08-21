# Gates: AI workspace experience

Scope: Let non-developer operators bootstrap and use a specialized compiler through one evidence action and an intentionally simplified AI workspace, while preserving advanced contracts underneath.

- [x] G1: Local files, folders, and pasted text can be staged through one safe, deterministic add-evidence boundary.
  CHECK: python3 tests/ai-workspace/test_add_evidence.py
  EXPECT: /^OK$/m
  EVIDENCE: `tests/ai-workspace/test_add_evidence.py` covers recursive staging, pasted text, identical no-op, deterministic collision names, missing inputs, inbox self-copy, and source/destination symlink rejection.

- [x] G2: `/ctx-add` is the sole evidence-entry workflow presented in first-run guidance and routes URL, local, text, and drop-folder inputs to existing verified internals.
  CHECK: bash scripts/verify-ai-workspace.sh
  EXPECT: /single intake: PASS/
  EVIDENCE: `verify-ai-workspace.sh` reports `single intake: PASS`; it inspects first-run copy and all four routing contracts.

- [x] G3: A generated compiler includes a valid friendly VS Code workspace that foregrounds guidance, evidence, briefs, and reviews while leaving advanced files accessible outside that view.
  CHECK: bash scripts/verify-ai-workspace.sh
  EXPECT: /friendly workspace: PASS/
  EVIDENCE: `verify-ai-workspace.sh` parses the workspace JSON and verifies a fresh manifest-driven install contains the workspace, guide, advanced escape hatch, and staging boundary.

- [x] G4: First-run and daily guidance use ordinary work language, automatically save useful views, and clearly distinguish setup, daily work, and exception review.
  CHECK: bash scripts/verify-ai-workspace.sh
  EXPECT: /plain language: PASS/
  EVIDENCE: `START-HERE.md` and `/ctx-start` are contract-checked for natural-language requests, UNKNOWN behavior, saved views, and absence of internal intake commands.

- [x] G5: Installer, guided workspace, profile, packaging, quality, reachability, ratchet, site claims, and full keyless regressions remain green.
  CHECK: bash scripts/ai-workspace-regression.sh
  EXPECT: /ai workspace regression: PASS/
  EVIDENCE: `ai-workspace-regression.sh` passed; its nested smoke run reported all 55 checks green and package roundtrip rejected all four tamper cases.
