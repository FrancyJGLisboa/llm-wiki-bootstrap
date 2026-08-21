# Gates: Integration

Scope: Profile-aware compile/lint/package behavior composes with the unchanged generic compiler.

- [x] G1: Profile compile hook is additive and no-profile command contract remains intact.
  CHECK: bash scripts/verify-decision-context-integration.sh
  EXPECT: generic/profile split: PASS
  EVIDENCE: verifier passes generic inactive resolution and explicit profile hooks.

- [x] G2: No-op compile is byte-identical and one source change affects only its shard and linked decisions.
  CHECK: bash scripts/verify-decision-context-integration.sh
  EXPECT: incrementality: PASS
  EVIDENCE: verifier compares byte-identical projections and independent source shards.

- [x] G3: Bundle verification includes claim/profile integrity.
  CHECK: bash scripts/verify-bundle-roundtrip.sh
  EXPECT: Passed
  EVIDENCE: conditional G5/B6 claim validation; generic G1-G4/B1-B5 unchanged.

- [x] G4: Full keyless regression and quality suites pass.
  CHECK: bash scripts/smoke-all.sh --no-build && bash scripts/quality.sh --ci
  EXPECT: All /[0-9]+/ checks green
  EVIDENCE: final parent run: All 53 checks green (`smoke-all.sh --no-build`); quality gate passed at 2.37% duplication.
