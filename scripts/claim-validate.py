#!/usr/bin/env python3
"""Validate source-scoped claim JSONL shards."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from claims import ClaimError, claim_id, discover, load_claims, validate_claim

_citation_path = Path(__file__).resolve().parent / "citation-audit.py"
_citation_spec = importlib.util.spec_from_file_location("citation_audit", _citation_path)
assert _citation_spec and _citation_spec.loader
_citation_module = importlib.util.module_from_spec(_citation_spec)
_citation_spec.loader.exec_module(_citation_module)
resolve_anchor = _citation_module.resolve_anchor


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("--root", default=".")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--print-id", help="print the deterministic ID for one JSON claim")
    args = parser.parse_args()
    if args.print_id:
        try:
            print(claim_id(json.loads(Path(args.print_id).read_text(encoding="utf-8"))))
            return 0
        except (OSError, json.JSONDecodeError, TypeError) as exc:
            print(f"setup error: {exc}", file=sys.stderr)
            return 2
    try:
        claims = load_claims(discover(Path(args.input)))
    except ClaimError as exc:
        print(f"setup error: {exc}", file=sys.stderr)
        return 2
    errors = []
    seen = set()
    for claim in claims:
        location = claim.pop("_location", "unknown")
        current = validate_claim(claim, Path(args.root).resolve(), resolve_anchor)
        errors.extend(f"{location}: {message}" for message in current)
        cid = claim.get("claim_id")
        if cid in seen:
            errors.append(f"{location}: duplicate claim_id {cid}")
        seen.add(cid)
    known = {c.get("claim_id") for c in claims}
    for claim in claims:
        for relation in claim.get("relations", []):
            if relation.get("target_claim_id") not in known:
                errors.append(f"{claim.get('claim_id')}: relation target is absent: {relation.get('target_claim_id')}")
        for target in (claim.get("derivation") or {}).get("input_claim_ids", []):
            if target not in known:
                errors.append(f"{claim.get('claim_id')}: derivation input is absent: {target}")
    result = {"claims": len(claims), "errors": errors, "valid": not errors}
    if args.json:
        print(json.dumps(result, sort_keys=True))
    elif errors:
        print("claim validation: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
    else:
        print(f"claim validation: PASS ({len(claims)} claims)")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
