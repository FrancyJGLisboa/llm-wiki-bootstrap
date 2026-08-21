# Gates: Claim Core

Scope: Deterministic, stdlib-only validation and projection of source-grounded temporal claims.

- [x] G1: Clean claim shards validate and malformed class/provenance/speaker/confidence cases fail.
  CHECK: bash scripts/verify-claim-core.sh
  EXPECT: schema fixtures: PASS
  EVIDENCE: `tests/claims/test_claims.py`; 16 tests pass on 2026-08-21, including profile-aware identity, ISO date/datetime, validity-order, attribution traps, and flat-field why lookup regressions.

- [x] G2: Citation anchors resolve and deterministic claim IDs are checked.
  CHECK: bash scripts/verify-claim-core.sh
  EXPECT: provenance fixtures: PASS
  EVIDENCE: clean, missing, and ambiguous anchors plus canonical-ID mismatch are exercised by `scripts/verify-claim-core.sh`.

- [x] G3: Explicit supersession/history/contradiction semantics project correctly without model calls.
  CHECK: bash scripts/verify-claim-core.sh
  EXPECT: temporal fixtures: PASS
  EVIDENCE: explicit supersession, current-vs-historical contradiction, point-in-time, and inclusive date-only `valid_to` tests pass with stdlib-only `scripts/lib/claims.py`.

- [x] G4: Repeated projection is byte-identical.
  CHECK: bash scripts/verify-claim-core.sh
  EXPECT: idempotence: PASS
  EVIDENCE: repeated `claim-state.py` subprocess output is byte-identical in the test suite.
