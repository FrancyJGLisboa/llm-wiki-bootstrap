#!/usr/bin/env python3
"""Read-only client-decision workflows over compiled claim shards."""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from claims import ClaimError, _temporal_key, discover, load_claims, project  # noqa: E402

_citation_path = Path(__file__).resolve().parent / "citation-audit.py"
_citation_spec = importlib.util.spec_from_file_location("citation_audit", _citation_path)
assert _citation_spec and _citation_spec.loader
_citation_module = importlib.util.module_from_spec(_citation_spec)
_citation_spec.loader.exec_module(_citation_module)
resolve_anchor = _citation_module.resolve_anchor

CHANGE_RELATIONS = {"updates", "narrows", "broadens"}
REPLACING_RELATIONS = CHANGE_RELATIONS | {"supersedes"}
MATERIAL_PREDICATES = {
    "affected-by", "assumes", "considering", "constrains", "depends-on",
    "exposed-to", "monitors", "questions", "triggers",
}


def compiled_root(root: Path) -> Path:
    for name in ("context", "wiki"):
        candidate = root / name
        if candidate.is_dir():
            return candidate
    raise ClaimError(f"compiled context root not found under {root}")


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ClaimError(f"cannot read {path}: {exc}") from exc


def load(root: Path, claim_input: Path | None) -> tuple[list[dict[str, Any]], Path]:
    context = compiled_root(root)
    path = claim_input or context / "claims" / "by-source"
    return load_claims(discover(path)), context


def decisions_for(context: Path, client: str) -> list[dict[str, Any]]:
    folder = context / "decisions" / client
    if not folder.exists():
        return []
    result = []
    for path in sorted(folder.glob("*.json")):
        value = read_json(path)
        if isinstance(value, dict) and value.get("subject") == client:
            value["_path"] = str(path)
            result.append(value)
    return result


def client_claims(all_claims: list[dict[str, Any]], decisions: list[dict[str, Any]], client: str) -> list[dict[str, Any]]:
    ids = {cid for decision in decisions for cid in decision.get("supporting_claim_ids", [])}
    return [claim for claim in all_claims if claim.get("subject") == client or claim.get("claim_id") in ids]


def citation(claim: dict[str, Any]) -> str:
    source = claim.get("source") or {}
    return f"{source.get('path', 'UNKNOWN')}#{source.get('anchor', 'UNKNOWN')}"


def compact_claim(claim: dict[str, Any]) -> dict[str, Any]:
    source = claim.get("source") or {}
    return {
        "claim_id": claim.get("claim_id"),
        "statement": claim.get("statement"),
        "classification": claim.get("classification"),
        "valid_from": claim.get("valid_from"),
        "evidence_domain": claim.get("evidence_domain"),
        "speaker": source.get("speaker"),
        "speaker_role": source.get("speaker_role"),
        "speaker_act": source.get("speaker_act"),
        "source_id": source.get("id"),
        "source_timestamp": source.get("timestamp"),
        "citation": citation(claim),
    }


def decision_view(decision: dict[str, Any], as_of: str | None = None) -> dict[str, Any] | None:
    clean = {key: value for key, value in decision.items() if not key.startswith("_")}
    if not as_of:
        return clean
    try:
        boundary = _temporal_key(as_of, end_of_day=True)
    except (TypeError, ValueError) as exc:
        raise ClaimError("--as-of must be an ISO date or datetime") from exc
    states = list(decision.get("historical_states", [])) + [decision.get("current_state", {})]
    eligible = []
    for state in states:
        start_value = state.get("valid_from")
        end_value = state.get("valid_to")
        start = datetime.min.replace(tzinfo=timezone.utc) if start_value in (None, "unknown") else _temporal_key(start_value)
        end = datetime.max.replace(tzinfo=timezone.utc) if end_value in (None, "unknown") else _temporal_key(end_value, end_of_day=True)
        if start <= boundary <= end:
            eligible.append((start, state))
    if not eligible:
        return None
    selected = sorted(eligible, key=lambda item: item[0])[-1][1]
    clean["current_state"] = selected
    clean["status"] = selected.get("status")
    return clean


def delta_data(claims: list[dict[str, Any]], since: str) -> dict[str, list[dict[str, Any]]]:
    before = project(claims, since)
    after = project(claims)
    before_ids = {claim["claim_id"] for claim in before["current"]}
    after_ids = {claim["claim_id"] for claim in after["current"]}
    by_id = {claim["claim_id"]: claim for claim in claims}
    introduced = after_ids - before_ids
    changed: set[str] = set()
    superseded: set[str] = set()
    for cid in introduced:
        for relation in by_id[cid].get("relations", []):
            if relation["type"] in CHANGE_RELATIONS:
                changed.add(cid)
            elif relation["type"] == "supersedes":
                superseded.add(relation["target_claim_id"])
    unresolved_ids = {claim["claim_id"] for claim in after["unresolved"]}
    unresolved_ids.update(
        claim["claim_id"] for claim in claims
        if claim["claim_id"] in after_ids and "possible-supersession" in claim.get("review_triggers", [])
    )
    new = introduced - changed - unresolved_ids
    unchanged = (before_ids & after_ids) - unresolved_ids
    return {
        "NEW": [compact_claim(by_id[cid]) for cid in sorted(new)],
        "CHANGED": [compact_claim(by_id[cid]) for cid in sorted(changed)],
        "SUPERSEDED": [compact_claim(by_id[cid]) for cid in sorted(superseded) if cid in by_id],
        "UNRESOLVED": [compact_claim(by_id[cid]) for cid in sorted(unresolved_ids) if cid in by_id],
        "UNCHANGED BUT MATERIAL": [compact_claim(by_id[cid]) for cid in sorted(unchanged) if by_id[cid].get("predicate") in MATERIAL_PREDICATES],
    }


def brief_data(claims: list[dict[str, Any]], decisions: list[dict[str, Any]]) -> dict[str, Any]:
    state = project(claims)
    current = state["current"]
    assumptions = [compact_claim(c) for c in current if c.get("classification") == "assumption"]
    variables = sorted({str(c.get("object")) for c in current if c.get("predicate") in {"affected-by", "depends-on", "monitors", "exposed-to"} and "object" in c})
    unknowns = [compact_claim(c) for c in current if c.get("classification") == "unknown"]
    questions = [compact_claim(c) for c in current if c.get("predicate") == "questions"]
    relations = [r for r in state["relations"] if r["type"] in REPLACING_RELATIONS]
    by_id = {c["claim_id"]: c for c in claims}
    changes = [compact_claim(by_id[r["source"]]) for r in relations if r["source"] in by_id]
    return {
        "decisions": [{k: v for k, v in d.items() if not k.startswith("_")} for d in decisions],
        "recent_changes": changes,
        "active_assumptions": assumptions,
        "exposures_and_material_variables": variables,
        "open_questions_and_unknowns": questions + unknowns,
        "contradictions": state["contradictions"],
        "evidence": [compact_claim(c) for c in current],
    }


def why_data(claims: list[dict[str, Any]], query: str) -> dict[str, Any]:
    by_id = {c["claim_id"]: c for c in claims}
    selected = by_id.get(query)
    matches: list[dict[str, Any]] = []
    if selected is None:
        needle = query.casefold()
        matches = [c for c in claims if needle in " ".join(str(c.get(k, "")) for k in ("statement", "subject", "predicate", "object")).casefold()]
        if len(matches) != 1:
            return {
                "status": "UNKNOWN",
                "reason": "claim is absent" if not matches else "claim text is ambiguous",
                "matching_claim_ids": sorted(c["claim_id"] for c in matches),
            }
        selected = matches[0]
    if selected.get("classification") == "unknown":
        unknown = selected.get("unknown") or {}
        return {
            "status": "UNKNOWN",
            "question": unknown.get("question") or selected.get("statement"),
            "reason": unknown.get("reason") or "evidence is insufficient",
            "inspected_scope": unknown.get("inspected_scope", []),
            "evidence": compact_claim(selected),
        }
    incoming = []
    for claim in claims:
        for relation in claim.get("relations", []):
            if relation["target_claim_id"] == selected["claim_id"]:
                incoming.append({"claim_id": claim["claim_id"], "type": relation["type"]})
    evidence_chain = [compact_claim(selected)]
    chain_ids = {selected["claim_id"]}
    for cid in (selected.get("derivation") or {}).get("input_claim_ids", []):
        if cid in by_id and cid not in chain_ids:
            evidence_chain.append(compact_claim(by_id[cid]))
            chain_ids.add(cid)
    for relation in selected.get("relations", []):
        cid = relation["target_claim_id"]
        if cid in by_id and cid not in chain_ids:
            evidence_chain.append(compact_claim(by_id[cid]))
            chain_ids.add(cid)
    for relation in incoming:
        cid = relation["claim_id"]
        if cid in by_id and cid not in chain_ids:
            evidence_chain.append(compact_claim(by_id[cid]))
            chain_ids.add(cid)
    state = project(claims)
    current_ids = {claim["claim_id"] for claim in state["current"]}
    historical_ids = {claim["claim_id"] for claim in state["history"]}
    return {
        "status": "SUPPORTED",
        "claim": compact_claim(selected),
        "confidence": selected.get("confidence"),
        "temporal_state": "current" if selected["claim_id"] in current_ids else "historical" if selected["claim_id"] in historical_ids else "unresolved",
        "current_related_claims": [compact_claim(by_id[cid]) for cid in sorted(chain_ids & current_ids)],
        "previous_related_claims": [compact_claim(by_id[cid]) for cid in sorted(chain_ids & historical_ids)],
        "evidence_chain": evidence_chain,
        "incoming_relations": sorted(incoming, key=lambda r: (r["type"], r["claim_id"])),
        "outgoing_relations": selected.get("relations", []),
    }


def review_data(claims: list[dict[str, Any]]) -> dict[str, Any]:
    state = project(claims)
    by_id = {c["claim_id"]: c for c in claims}
    items = []
    for claim in claims:
        for trigger in claim.get("review_triggers", []):
            items.append({"claim": compact_claim(claim), "reason": trigger})
    seen = {(item["claim"]["claim_id"], item["reason"]) for item in items}
    for pair in state["contradictions"]:
        for cid in pair["claims"]:
            if (cid, "contradiction") not in seen:
                items.append({"claim": compact_claim(by_id[cid]), "reason": "contradiction"})
    return {"count": len(items), "items": sorted(items, key=lambda item: (item["reason"], item["claim"]["claim_id"]))}


def lint_data(root: Path, claims: list[dict[str, Any]], decisions: list[dict[str, Any]]) -> dict[str, Any]:
    total = len(claims)
    resolving = 0
    for claim in claims:
        source = claim.get("source") or {}
        source_path = Path(str(source.get("path", "")))
        if source_path.is_absolute() or ".." in source_path.parts or not source_path.parts or source_path.parts[0] != "raw":
            continue
        path = root / source_path
        if not path.is_file() or not source.get("anchor"):
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        resolved, _ = resolve_anchor(source["anchor"], lines)
        resolving += int(resolved)
    with_time = sum(1 for c in claims if c.get("valid_from") not in (None, "unknown"))
    unsupported = sum("unsupported-high-impact-claim" in c.get("review_triggers", []) for c in claims)
    current = project(claims)["current"]
    cutoff = date.today() - timedelta(days=90)
    fresh = 0
    dated = 0
    for claim in current:
        value = claim.get("valid_from")
        if isinstance(value, str) and value != "unknown":
            try:
                parsed = datetime.fromisoformat(value.replace("Z", "+00:00")).date()
            except ValueError:
                continue
            dated += 1
            fresh += parsed >= cutoff
    contradictions = len(project(claims)["contradictions"])
    stale_assumptions = sum(1 for c in current if c.get("classification") == "assumption" and c.get("valid_from") not in (None, "unknown") and datetime.fromisoformat(c["valid_from"].replace("Z", "+00:00")).date() < cutoff)
    return {
        "citation_resolution": {"count": resolving, "total": total, "percentage": round(100 * resolving / total, 1) if total else 100.0},
        "claims_with_valid_time": {"count": with_time, "total": total, "percentage": round(100 * with_time / total, 1) if total else 100.0},
        "current_claims_under_90_days": {"count": fresh, "total": dated, "percentage": round(100 * fresh / dated, 1) if dated else 100.0},
        "unresolved_contradictions": contradictions,
        "stale_assumptions": stale_assumptions,
        "unsupported_claims": unsupported,
        "unknown_decision_owners": sum(d.get("owner") in (None, "unknown", "") for d in decisions),
        "review_items": review_data(claims)["count"],
    }


def human(title: str, value: Any) -> None:
    print(title)
    if isinstance(value, dict):
        for key, item in value.items():
            print(f"\n{key.replace('_', ' ').upper()}")
            if isinstance(item, list):
                if not item:
                    print("- none")
                for entry in item:
                    if isinstance(entry, dict) and "claim_id" in entry:
                        print(f"- {entry.get('statement')} [{entry['claim_id']}] ({entry.get('citation')})")
                    else:
                        print("- " + json.dumps(entry, ensure_ascii=False, sort_keys=True))
            else:
                print(json.dumps(item, ensure_ascii=False, sort_keys=True))


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", type=Path, default=Path.cwd())
    p.add_argument("--claims", type=Path)
    sub = p.add_subparsers(dest="command", required=True)
    for name in ("brief", "assumptions", "review", "lint"):
        command = sub.add_parser(name); command.add_argument("client"); command.add_argument("--json", action="store_true")
    decisions = sub.add_parser("decisions"); decisions.add_argument("client"); decisions.add_argument("--as-of"); decisions.add_argument("--json", action="store_true")
    delta = sub.add_parser("delta"); delta.add_argument("client"); delta.add_argument("--since", required=True); delta.add_argument("--json", action="store_true")
    why = sub.add_parser("why"); why.add_argument("client"); why.add_argument("query"); why.add_argument("--json", action="store_true")
    return p


def main() -> int:
    args = parser().parse_args()
    try:
        all_claims, context = load(args.root.resolve(), args.claims)
        decisions = decisions_for(context, args.client)
        claims = client_claims(all_claims, decisions, args.client)
        if args.command == "brief": result = brief_data(claims, decisions)
        elif args.command == "delta": result = delta_data(claims, args.since)
        elif args.command == "decisions": result = {"client": args.client, "as_of": args.as_of or "latest", "decisions": [view for d in decisions if (view := decision_view(d, args.as_of)) is not None]}
        elif args.command == "assumptions": result = {"client": args.client, "assumptions": [compact_claim(c) for c in project(claims)["current"] if c.get("classification") == "assumption"]}
        elif args.command == "why": result = why_data(claims, args.query)
        elif args.command == "review": result = review_data(claims)
        else: result = lint_data(args.root.resolve(), claims, decisions)
    except (ClaimError, ValueError) as exc:
        print(f"setup error: {exc}", file=sys.stderr); return 2
    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        human(f"CLIENT {args.client} — {args.command.upper()}", result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
