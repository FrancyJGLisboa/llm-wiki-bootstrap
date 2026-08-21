#!/usr/bin/env python3
"""Deterministic claim validation and temporal projection (stdlib only)."""
from __future__ import annotations

import hashlib
import json
import re
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterable

CLAIM_CLASSES = {"observation", "fact", "assumption", "inference", "derivation", "unknown"}
RELATIONS = {"supersedes", "updates", "confirms", "contradicts", "narrows", "broadens"}
REPLACING = {"supersedes", "updates", "narrows", "broadens"}
ATTRIBUTABLE_TYPES = {"email", "email-export", "transcript", "meeting-transcript", "message", "chat", "interaction"}
SPEECH_ACTS = {"assertion", "question", "hypothetical", "agreement", "qualified-agreement"}
NON_ASSERTIVE_ACTS = {"question", "hypothetical", "agreement", "qualified-agreement"}
EVIDENCE_DOMAINS = {"client", "internal-research", "external-market", "compiler-derived"}
REVIEW_TRIGGERS = {
    "ambiguous-speaker", "contradiction", "low-confidence-entity-resolution",
    "low-confidence-speaker-resolution", "material-inference",
    "possible-supersession", "unsupported-high-impact-claim",
}
ID_RE = re.compile(r"^CLM-[0-9A-F]{12}$")


class ClaimError(ValueError):
    pass


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def speaker_identity(source: Any) -> Any:
    if not isinstance(source, dict) or not source.get("speaker"):
        return None
    return {"name": source.get("speaker"), "role": source.get("speaker_role")}


def identity(claim: dict[str, Any]) -> dict[str, Any]:
    source = claim.get("source") or {}
    return {
        "profile": claim.get("profile"),
        "source.id": source.get("id"),
        "source.path": source.get("path"),
        "source.anchor": source.get("anchor"),
        "speaker": speaker_identity(source),
        "proposition": {
            "subject": claim.get("subject"),
            "predicate": claim.get("predicate"),
            **({"object": claim.get("object")} if "object" in claim else {}),
        },
    }


def claim_id(claim: dict[str, Any]) -> str:
    digest = hashlib.sha256(canonical_json(identity(claim)).encode("utf-8")).hexdigest()[:12].upper()
    return "CLM-" + digest


def _iso_or_unknown(value: Any) -> bool:
    if value in (None, "unknown"):
        return True
    if not isinstance(value, str):
        return False
    try:
        date.fromisoformat(value)
        return bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}", value))
    except ValueError:
        try:
            datetime.fromisoformat(value.replace("Z", "+00:00"))
            return True
        except ValueError:
            return False


def _temporal_key(value: str, *, end_of_day: bool = False) -> datetime:
    """Normalize ISO dates/datetimes for deterministic mixed-granularity ordering."""
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        suffix = "T23:59:59.999999+00:00" if end_of_day else "T00:00:00+00:00"
        return datetime.fromisoformat(value + suffix)
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed.astimezone(timezone.utc)


def _timestamp_or_unknown(value: Any) -> bool:
    if value in (None, "unknown"):
        return True
    if not isinstance(value, str):
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def _resolve_raw(root: Path, source_path: str) -> Path:
    candidate = Path(source_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ClaimError("source.path must be a repository-relative raw/ path")
    if not candidate.parts or candidate.parts[0] != "raw":
        raise ClaimError("source.path must begin with raw/")
    return root / candidate


def validate_claim(claim: Any, root: Path, resolve_anchor=None) -> list[str]:
    errors: list[str] = []
    if not isinstance(claim, dict):
        return ["claim must be a JSON object"]
    cid = claim.get("claim_id", "<missing>")
    prefix = f"{cid}: "
    required = ("profile", "claim_id", "classification", "statement", "subject", "predicate", "evidence_domain", "source")
    for field in required:
        if claim.get(field) in (None, ""):
            errors.append(prefix + f"missing {field}")
    if claim.get("classification") not in CLAIM_CLASSES:
        errors.append(prefix + f"classification must be one of {sorted(CLAIM_CLASSES)}")
    if claim.get("evidence_domain") not in EVIDENCE_DOMAINS:
        errors.append(prefix + f"evidence_domain must be one of {sorted(EVIDENCE_DOMAINS)}")
    for field in ("statement", "subject", "predicate"):
        if not isinstance(claim.get(field), str) or not claim[field].strip():
            errors.append(prefix + f"{field} must be a nonempty string")
    if claim.get("classification") == "unknown" and "object" in claim:
        errors.append(prefix + "unknown claim must not contain object")
    source = claim.get("source")
    if not isinstance(source, dict):
        errors.append(prefix + "source must be an object")
        source = {}
    for field in ("id", "type", "path", "anchor", "timestamp", "evidence_span"):
        if source.get(field) in (None, "") and field != "timestamp":
            errors.append(prefix + f"source.{field} is required")
    if not _timestamp_or_unknown(source.get("timestamp")):
        errors.append(prefix + "source.timestamp must be an ISO timestamp, null, or unknown")
    for field in ("valid_from", "valid_to"):
        if not _iso_or_unknown(claim.get(field)):
            errors.append(prefix + f"{field} must be ISO YYYY-MM-DD, null, or unknown")
    valid_from = claim.get("valid_from")
    valid_to = claim.get("valid_to")
    if valid_from not in (None, "unknown") and valid_to not in (None, "unknown"):
        if _iso_or_unknown(valid_from) and _iso_or_unknown(valid_to):
            if _temporal_key(valid_from) > _temporal_key(valid_to, end_of_day=True):
                errors.append(prefix + "valid_from must not be after valid_to")
    if claim.get("classification") == "inference":
        confidence = claim.get("confidence")
        if isinstance(confidence, bool) or not isinstance(confidence, (int, float)) or not 0 <= confidence <= 1:
            errors.append(prefix + "inference requires numeric confidence in [0,1]")
    if claim.get("classification") == "derivation":
        derivation = claim.get("derivation")
        if not isinstance(derivation, dict) or not isinstance(derivation.get("input_claim_ids"), list) or len(derivation.get("input_claim_ids", [])) < 2 or not derivation.get("operation"):
            errors.append(prefix + "derivation requires at least two input_claim_ids and operation")
        elif any(not ID_RE.fullmatch(str(value)) for value in derivation["input_claim_ids"]):
            errors.append(prefix + "derivation input_claim_ids must be CLM identifiers")
    if claim.get("classification") == "unknown":
        unknown = claim.get("unknown")
        if not isinstance(unknown, dict) or not isinstance(unknown.get("inspected_scope"), list) or not unknown.get("inspected_scope") or not unknown.get("reason") or not unknown.get("question"):
            errors.append(prefix + "unknown requires inspected_scope and reason")
    if source.get("type") in ATTRIBUTABLE_TYPES or source.get("attributable") is True:
        if not source.get("speaker"):
            errors.append(prefix + "attributable source requires source.speaker")
        else:
            if not source.get("speaker_role"):
                errors.append(prefix + "attributable source requires source.speaker_role")
            if source.get("speaker_act") not in SPEECH_ACTS | {"disagreement"}:
                errors.append(prefix + f"source.speaker_act must be one of {sorted(SPEECH_ACTS | {'disagreement'})}")
            elif source.get("speaker_act") in NON_ASSERTIVE_ACTS and claim.get("classification") not in {"observation", "unknown"}:
                errors.append(prefix + f"{source['speaker_act']} speech may only classify as observation or unknown")
            confidence = source.get("speaker_confidence")
            if isinstance(confidence, bool) or not isinstance(confidence, (int, float)) or not 0 <= confidence <= 1:
                errors.append(prefix + "source.speaker_confidence must be numeric in [0,1]")
    relations = claim.get("relations", [])
    if not isinstance(relations, list):
        errors.append(prefix + "relations must be a list")
    else:
        for i, relation in enumerate(relations):
            if not isinstance(relation, dict) or relation.get("type") not in RELATIONS or not ID_RE.fullmatch(str(relation.get("target_claim_id", ""))):
                errors.append(prefix + f"relations[{i}] requires a supported type and CLM target")
    triggers = claim.get("review_triggers", [])
    if not isinstance(triggers, list) or len(triggers) != len(set(triggers)) or any(item not in REVIEW_TRIGGERS for item in triggers):
        errors.append(prefix + "review_triggers must be a unique list from the controlled vocabulary")
    expected = claim_id(claim)
    if claim.get("claim_id") != expected:
        errors.append(prefix + f"claim_id mismatch; expected {expected}")
    if source.get("path") and source.get("anchor"):
        try:
            raw_path = _resolve_raw(root, source["path"])
            if not raw_path.is_file():
                errors.append(prefix + f"source file does not resolve: {source['path']}")
            elif resolve_anchor:
                lines = raw_path.read_text(encoding="utf-8", errors="replace").splitlines()
                ok, _ = resolve_anchor(source["anchor"], lines)
                if not ok:
                    errors.append(prefix + f"source anchor does not resolve: #{source['anchor']}")
        except ClaimError as exc:
            errors.append(prefix + str(exc))
    return errors


def load_claims(paths: Iterable[Path]) -> list[dict[str, Any]]:
    claims: list[dict[str, Any]] = []
    for path in paths:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError as exc:
            raise ClaimError(f"cannot read {path}: {exc}") from exc
        for number, line in enumerate(lines, 1):
            if not line.strip():
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ClaimError(f"{path}:{number}: invalid JSON: {exc.msg}") from exc
            if not isinstance(value, dict):
                raise ClaimError(f"{path}:{number}: claim must be an object")
            value["_location"] = f"{path}:{number}"
            claims.append(value)
    return claims


def discover(path: Path) -> list[Path]:
    if not path.exists():
        raise ClaimError(f"claim input does not exist: {path}")
    return sorted(path.rglob("*.jsonl")) if path.is_dir() else [path]


def public(claim: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in claim.items() if not k.startswith("_")}


def project(claims: list[dict[str, Any]], as_of: str | None = None) -> dict[str, Any]:
    if as_of and (as_of == "unknown" or not _iso_or_unknown(as_of)):
        raise ClaimError("--as-of must be an ISO date or datetime")
    boundary = _temporal_key(as_of, end_of_day=True) if as_of else None
    eligible = [
        c for c in claims
        if boundary is None or c.get("valid_from") in (None, "unknown")
        or _temporal_key(c["valid_from"]) <= boundary
    ]
    by_id = {c["claim_id"]: c for c in eligible}
    # valid_to is an explicit close, just like an explicit replacing relation.
    # Claims remain in `history`; they are never deleted from the projection.
    replaced: set[str] = {
        c["claim_id"] for c in eligible
        if c.get("valid_to") not in (None, "unknown")
        and (boundary is None or _temporal_key(c["valid_to"], end_of_day=True) < boundary)
    }
    confirmations: dict[str, list[str]] = {}
    contradictions: set[tuple[str, str]] = set()
    relations: list[dict[str, str]] = []
    for claim in eligible:
        for relation in claim.get("relations", []):
            target = relation["target_claim_id"]
            if target not in by_id:
                continue
            kind = relation["type"]
            relations.append({"source": claim["claim_id"], "type": kind, "target": target})
            if kind in REPLACING:
                replaced.add(target)
            elif kind == "confirms":
                confirmations.setdefault(target, []).append(claim["claim_id"])
            elif kind == "contradicts":
                contradictions.add(tuple(sorted((claim["claim_id"], target))))
    current_ids = sorted(set(by_id) - replaced)
    current_set = set(current_ids)
    unresolved_ids = sorted({item for pair in contradictions for item in pair if item in current_set})
    return {
        "as_of": as_of or "latest",
        "current": [public(by_id[cid]) for cid in current_ids],
        "history": [public(by_id[cid]) for cid in sorted(replaced)],
        "unresolved": [public(by_id[cid]) for cid in unresolved_ids],
        "contradictions": [{"claims": list(pair)} for pair in sorted(contradictions)],
        "confirmations": {key: sorted(value) for key, value in sorted(confirmations.items())},
        "relations": sorted(relations, key=lambda x: (x["source"], x["type"], x["target"])),
    }
