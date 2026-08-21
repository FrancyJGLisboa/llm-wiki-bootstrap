#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export CLIENT_PROFILE_ROOT="$ROOT"

python3 - <<'PY'
import json
import os
import re
from datetime import date, datetime
from pathlib import Path

root = Path(os.environ["CLIENT_PROFILE_ROOT"])
profile = root / "profiles/client-decision"

def load(relative):
    path = profile / relative
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"missing profile asset: {relative}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON in {relative}: {exc}") from exc

manifest = load("profile.json")
assert manifest["name"] == "client-decision", manifest
assert manifest["profile_version"] == 1, manifest

assets = [
    "schemas/claim.schema.json",
    "schemas/decision.schema.json",
    "vocabularies/ontology.json",
    "vocabularies/relations.json",
    "vocabularies/predicates.json",
    "vocabularies/evidence-domains.json",
    "vocabularies/speaker-acts.json",
    "vocabularies/review-triggers.json",
    "templates/claim.json",
    "templates/decision.json",
]
assert manifest["artifacts"] == sorted(["COMPILATION.md", *assets]), manifest["artifacts"]
contract = (profile / "COMPILATION.md").read_text(encoding="utf-8")
for asset in assets:
    load(asset)
    assert f"`{asset}`" in contract, f"COMPILATION.md does not reference {asset}"
print("assets: PASS")

required_concepts = {
    "client", "person", "organization", "asset", "geography", "commodity",
    "exposure", "decision", "assumption", "question", "constraint", "objective",
    "risk-factor", "scenario", "market-variable", "interaction",
}
ontology = load("vocabularies/ontology.json")
assert set(ontology["concepts"]) == required_concepts
assert ontology["concepts"] == sorted(ontology["concepts"])
print("ontology: PASS")

relations = load("vocabularies/relations.json")
required_page = {
    "operates-in", "exposed-to", "produces", "consumes", "exports-to", "imports-from",
    "monitors", "assumes", "considering", "depends-on", "affected-by", "affects",
    "constrains", "triggers", "questions",
}
required_temporal = {"supersedes", "updates", "confirms", "contradicts", "narrows", "broadens"}
assert set(relations["page_relations"]) == required_page
assert set(relations["claim_relations"]) == required_temporal
for relation in relations["page_relations"] + relations["claim_relations"]:
    assert re.fullmatch(r"[a-z][a-z0-9-]*", relation)
assert set(load("vocabularies/evidence-domains.json")["values"]) == {
    "client", "internal-research", "external-market", "compiler-derived"
}
assert set(load("vocabularies/speaker-acts.json")["values"]) == {
    "assertion", "question", "hypothetical", "agreement", "qualified-agreement", "disagreement"
}
assert set(load("vocabularies/review-triggers.json")["values"]) == {
    "contradiction", "ambiguous-speaker", "low-confidence-speaker-resolution",
    "low-confidence-entity-resolution", "possible-supersession", "material-inference",
    "unsupported-high-impact-claim",
}
predicates = load("vocabularies/predicates.json")["values"]
assert predicates == sorted(predicates)
assert set(predicates) == {
    "affected-by", "assumes", "considering", "constrains", "depends-on",
    "exposed-to", "monitors", "questions", "responds-to", "triggers",
}
print("vocabularies: PASS")

claim_schema = load("schemas/claim.schema.json")
decision_schema = load("schemas/decision.schema.json")
template = load("templates/decision.json")
claim_template = load("templates/claim.json")
assert claim_schema["additionalProperties"] is False
assert decision_schema["additionalProperties"] is False
assert set(claim_schema["properties"]["classification"]["enum"]) == {
    "observation", "fact", "assumption", "inference", "derivation", "unknown"
}
assert decision_schema["required"] == [
    "decision_id", "subject", "description", "supporting_claim_ids", "current_state", "historical_states"
]
assert set(template) == set(decision_schema["properties"])
assert template["owner"] is None and template["status"] is None
assert claim_schema["properties"]["profile"] == {"const": "client-decision"}
assert claim_template["profile"] == "client-decision"
assert claim_schema["properties"]["predicate"]["enum"] == predicates
print("schemas: PASS")

def validate_claim(document):
    required = set(claim_schema["required"])
    if not required <= set(document):
        return False
    if document.get("profile") != "client-decision":
        return False
    classification = document["classification"]
    if classification not in claim_schema["properties"]["classification"]["enum"]:
        return False
    if document.get("predicate") not in predicates:
        return False
    if classification == "inference" and not isinstance(document.get("confidence"), (int, float)):
        return False
    if classification == "derivation" and "derivation" not in document:
        return False
    if classification == "unknown" and "unknown" not in document:
        return False
    if classification == "unknown" and "object" in document:
        return False
    def valid_temporal(value):
        if value is None or value == "unknown":
            return True
        if not isinstance(value, str):
            return False
        date_shape = re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value)
        datetime_shape = re.fullmatch(
            r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
            r"(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})?",
            value,
        )
        if date_shape is None and datetime_shape is None:
            return False
        try:
            if datetime_shape is not None:
                datetime.fromisoformat(value.replace("Z", "+00:00"))
            else:
                date.fromisoformat(value)
        except ValueError:
            return False
        return True
    if not valid_temporal(document.get("valid_from")) or not valid_temporal(document.get("valid_to")):
        return False
    source = document.get("source", {})
    if not set(claim_schema["properties"]["source"]["required"]) <= set(source):
        return False
    if not valid_temporal(source.get("timestamp")):
        return False
    act = source.get("speaker_act")
    allowed_acts = claim_schema["properties"]["source"]["properties"]["speaker_act"]["enum"]
    if act is not None and act not in allowed_acts:
        return False
    if act in {"question", "hypothetical", "agreement", "qualified-agreement"} and classification not in {"observation", "unknown"}:
        return False
    if "low-confidence-speaker-resolution" in document.get("review_triggers", []):
        confidence = source.get("speaker_confidence")
        if not isinstance(confidence, (int, float)) or isinstance(confidence, bool) or not 0 <= confidence <= 1:
            return False
    return True

fixtures = root / "tests/client-profile"
assert validate_claim(json.loads((fixtures / "valid-claim.json").read_text()))
assert validate_claim(json.loads((fixtures / "valid-date-claim.json").read_text()))
assert not validate_claim(json.loads((fixtures / "invalid-inference-no-confidence.json").read_text()))
assert not validate_claim(json.loads((fixtures / "invalid-speaker-act.json").read_text()))
assert not validate_claim(json.loads((fixtures / "invalid-low-confidence-speaker.json").read_text()))
assert not validate_claim(json.loads((fixtures / "invalid-malformed-date-claim.json").read_text()))
assert not validate_claim(json.loads((fixtures / "invalid-unknown-object.json").read_text()))
assert not validate_claim(json.loads((fixtures / "invalid-nonassertive-fact.json").read_text()))

def valid_temporal(value):
    if value is None or value == "unknown":
        return True
    if not isinstance(value, str):
        return False
    try:
        if re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value):
            date.fromisoformat(value)
            return True
        if re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})?", value):
            datetime.fromisoformat(value.replace("Z", "+00:00"))
            return True
    except ValueError:
        pass
    return False

def validate_decision_temporal(document):
    states = [document.get("current_state", {})] + list(document.get("historical_states", []))
    return all(valid_temporal(state.get(field)) for state in states for field in ("valid_from", "valid_to"))

assert validate_decision_temporal(template)
assert not validate_decision_temporal(json.loads((fixtures / "invalid-decision-date.json").read_text()))
print("fixtures: PASS")
print("client profile: PASS")
PY
