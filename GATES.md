# Gates: Decision Context Milestone

Scope: A generic context compiler can load the client-decision profile and reproducibly reconstruct Northstar decision state without regressing generic workflows.

- [x] G1: Profile activation is opt-in and generic installs remain functional.
  CHECK: bash scripts/verify-profile-resolution.sh && bash scripts/verify-create-context-compiler.sh
  EXPECT: /profile resolution.*PASS|Passed/
  EVIDENCE: [verifier] cleaning prior tests/installer-output/* … | [verifier] target: tests/installer-output/20260821-111319/freshrepo

- [x] G2: Claim schema, provenance, speaker, temporal state, and UNKNOWN rules are mechanically validated.
  CHECK: bash scripts/verify-claim-core.sh
  EXPECT: idempotence: PASS
  EVIDENCE: Ran 16 tests in 0.387s | OK

- [x] G3: Client brief, delta, why, history, review, and lint workflows pass acceptance fixtures.
  CHECK: bash scripts/verify-client-workflows.sh
  EXPECT: unknown/review: PASS
  EVIDENCE: Ran 5 tests in 1.566s | OK

- [x] G4: The 24-source Northstar benchmark is leakage-resistant and emits measured results for compiled, long-context, and BM25 retrieval arms.
  CHECK: bash scripts/verify-northstar-benchmark.sh
  EXPECT: baseline arms: PASS
  EVIDENCE: Ran 6 tests in 0.580s | OK

- [x] G5: Existing generic behavior, packaging, quality, and all regression guards remain green.
  CHECK: bash scripts/smoke-all.sh --no-build && bash scripts/quality.sh --ci
  EXPECT: quality gate passed
  EVIDENCE: Reminder: run /ctx-lint for markdown health (links, orphans, contradictions). | ✓ quality gate passed
