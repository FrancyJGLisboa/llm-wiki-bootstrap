# Gates: Client Workflows

Scope: Evidence-grounded human and JSON workflows over compiled claim/decision state.

- [x] G1: Brief reports current decisions, assumptions, changes, exposures, contradictions, unknowns, and evidence.
  CHECK: bash scripts/verify-client-workflows.sh
  EXPECT: brief: PASS
  EVIDENCE: `test_brief_is_evidence_grounded_and_does_not_promote_qualified_agreement` passes; every compact claim includes its deterministic ID and `raw/path#anchor` citation.

- [x] G2: Delta classifies NEW/CHANGED/SUPERSEDED/UNRESOLVED/UNCHANGED-BUT-MATERIAL semantically.
  CHECK: bash scripts/verify-client-workflows.sh
  EXPECT: delta: PASS
  EVIDENCE: `test_delta_uses_explicit_temporal_relations` passes using claim projection plus explicit temporal relations, not text diffs.

- [x] G3: Why and as-of history preserve evidence order, speaker attribution, and prior/current state.
  CHECK: bash scripts/verify-client-workflows.sh
  EXPECT: why/history: PASS
  EVIDENCE: `test_as_of_and_why_unknown` and `test_as_of_handles_mixed_date_and_datetime_states` pass for attributed evidence, explicit UNKNOWN claims, linked prior/current claims, and timezone-aware mixed date/datetime projections.

- [x] G4: Unsupported questions return UNKNOWN and exception review is queue-based.
  CHECK: bash scripts/verify-client-workflows.sh
  EXPECT: unknown/review: PASS
  EVIDENCE: `test_as_of_and_why_unknown` and `test_review_and_lint_are_transparent` pass; review contains controlled triggers and contradictions only, while citation resolution fails a present source whose anchor is absent.
