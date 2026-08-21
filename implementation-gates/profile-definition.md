# Gates: Client Decision Profile Definition

Scope: Minimal controlled ontology, evidence domains, relations, claim rules, and decision template.

- [x] G1: Profile manifest and every referenced schema/vocabulary/template resolves.
  CHECK: python3 scripts/profile-resolve.py --root . --json --profile client-decision
  EXPECT: client-decision
  EVIDENCE: `profile-resolve.py` selects profile version 1; `verify-client-profile.sh` prints `assets: PASS` after parsing every JSON asset and confirming each is referenced by `COMPILATION.md`.

- [x] G2: Ontology contains the required milestone concepts without future-profile implementations.
  CHECK: bash scripts/verify-client-profile.sh
  EXPECT: ontology: PASS
  EVIDENCE: The verifier prints `ontology: PASS` after exact-set and sorted-order checks; the compilation contract explicitly keeps client-specific decision fields out of compiler core and future profile contracts.

- [x] G3: Controlled relations, speaker acts, evidence domains, and review triggers validate.
  CHECK: bash scripts/verify-client-profile.sh
  EXPECT: vocabularies: PASS
  EVIDENCE: The verifier prints `vocabularies: PASS`, `schemas: PASS`, and `fixtures: PASS`; claim predicates exactly match the controlled milestone vocabulary. Claim and decision-state fixtures accept calendar dates, full ISO datetimes, `unknown`, and null while rejecting malformed dates; claim fixtures also reject unknown claims with an object, non-assertive speech compiled as fact, inference without confidence, unknown speaker acts, and low-confidence speaker review without numeric speaker confidence.
