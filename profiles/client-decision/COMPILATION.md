# Client Decision Compilation Contract

This profile specializes the generic compiler. It does not change generic compilation when inactive.

## Owned contracts

- `schemas/claim.schema.json` — durable claim envelope and epistemic rules.
- `schemas/decision.schema.json` — evidence-referencing decision projection.
- `vocabularies/ontology.json` — minimal client-decision concepts.
- `vocabularies/relations.json` — controlled page and temporal claim relations.
- `vocabularies/predicates.json` — closed claim predicates used by milestone workflows.
- `vocabularies/evidence-domains.json` — separation of client, research, market, and derived evidence.
- `vocabularies/speaker-acts.json` — attributable speech-act distinctions.
- `vocabularies/review-triggers.json` — exception-based human review reasons.
- `templates/claim.json` — profile-labelled claim output shape.
- `templates/decision.json` — deterministic decision output shape.

## Extraction rules

1. Emit `profile: client-decision` on every claim. Copy the exact raw anchor and evidence span. Never cite a summary when the source assertion is available.
2. Preserve speaker identity, role, and speech act. A question, hypothetical, agreement, or qualified agreement is not an assertion and may compile only as `observation` or `unknown`; never turn it into a fact or assumption. Do not convert an analyst statement into a client belief. When speaker resolution is low-confidence, record `source.speaker_confidence` from 0 to 1 and add `low-confidence-speaker-resolution` review.
3. Classify direct source language as `observation`; use `fact` only for a normalized proposition strongly entailed by that evidence. An `assumption` is what the attributed subject uses for reasoning, not objective truth.
4. Label interpretation `inference`, provide numeric confidence, and add `material-inference` review when it affects a decision. Never promote inference to fact to complete a profile.
5. A `derivation` names at least two input claim IDs and a reproducible operation. An absent value becomes `unknown` with the inspected scope and reason and has no `object` field; never fabricate it.

Claim predicates come only from `vocabularies/predicates.json`. Add one only when an evidenced client-decision workflow cannot normalize to an existing predicate; do not emit source wording as a new predicate.

`commodities`, `geographies`, and `assets` on the decision projection are client-decision profile specializations. They are not compiler-core fields and do not constrain the ontology or projection contracts of future, independently designed profiles.

## Temporal and review rules

Claims remain immutable historical evidence. Explicit `supersedes`, `updates`, `narrows`, or `broadens` relations may close a prior same-scope state. `confirms` adds support. `contradicts` preserves both states and queues review. Recency alone never establishes supersession.

Queue review for every trigger in `vocabularies/review-triggers.json`. Ambiguous scope, speaker, entity, or supersession remains unresolved. Decision projections reference claim IDs and omit unevidenced optional fields; JSON `null` in the template means unknown, never “not applicable.”
