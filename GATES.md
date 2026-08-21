# Gates: Guided context-compiler workspace

Scope: Make generated compilers approachable from VS Code through a guided workspace, inbox workflow, natural-language routing, and profile-creation contract without weakening the generic core.

- [x] G1: A fresh installed compiler opens with START-HERE, EVIDENCE-INBOX, BRIEFS, REVIEWS, and valid VS Code recommendations/tasks.
  CHECK: bash scripts/verify-guided-workspace.sh
  EXPECT: /guided workspace: PASS/
  EVIDENCE: daily routing: PASS | guided workspace: PASS

- [x] G2: Inbox import is deterministic, incremental, non-destructive, collision-safe, and rejects symlinks/path escapes.
  CHECK: python3 tests/guided-workspace/test_inbox_import.py
  EXPECT: /^OK$/m
  EVIDENCE: OK

- [x] G3: Profile creation has a guided command and a generic deterministic profile-package validator; client-decision passes it and unsafe manifests fail.
  CHECK: python3 tests/guided-workspace/test_profile_check.py
  EXPECT: /^OK$/m
  EVIDENCE: OK

- [x] G4: Natural-language daily operations map to stable compiler commands and generated outputs have explicit BRIEFS/REVIEWS ownership rules.
  CHECK: bash scripts/verify-guided-workspace.sh
  EXPECT: /daily routing: PASS/
  EVIDENCE: daily routing: PASS | guided workspace: PASS

- [x] G5: Installer, profile, decision-context, site-claim, quality, and full keyless regression suites remain green.
  CHECK: bash scripts/guided-workspace-regression.sh
  EXPECT: /guided workspace regression: PASS/
  EVIDENCE: Ran 6 tests in 0.631s | OK
