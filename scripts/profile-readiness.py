#!/usr/bin/env python3
"""Report whether a self-service profile is technically and behaviorally ready."""

from __future__ import annotations

import argparse
from datetime import date
import json
from pathlib import Path
import subprocess
import sys
import re


REQUIRED_CASES = {"positive", "provenance", "temporal", "contradiction", "absence", "no-op"}
REQUIRED_CLASSES = {"observation", "fact", "assumption", "inference", "derivation", "unknown"}
NAME = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")


def atomic_json(path: Path, value: object) -> None:
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def assess(root: Path, profile: str, approve: str | None, approved_at: str | None) -> dict:
    if not NAME.fullmatch(profile):
        return {
            "profile": profile, "technical_valid": False, "behavioral_coverage": False,
            "human_approved": False, "ready": False, "approval": {},
            "issues": ["unsafe profile name"],
        }
    if approve is not None and not approve.strip():
        return {
            "profile": profile, "technical_valid": False, "behavioral_coverage": False,
            "human_approved": False, "ready": False, "approval": {},
            "issues": ["approver name cannot be empty"],
        }
    if approved_at is not None:
        try:
            date.fromisoformat(approved_at)
        except ValueError:
            return {
                "profile": profile, "technical_valid": False, "behavioral_coverage": False,
                "human_approved": False, "ready": False, "approval": {},
                "issues": ["approved-at must be a valid YYYY-MM-DD date"],
            }
    base = root / "profiles" / profile
    check = subprocess.run(
        [sys.executable, str(root / "scripts/profile-check.py"), "--root", str(root), "--profile", profile, "--json"],
        text=True, capture_output=True,
    )
    try:
        validation = json.loads(check.stdout)
    except json.JSONDecodeError:
        validation = {"valid": False, "errors": [check.stderr.strip() or "profile validator did not return JSON"]}
    technical = check.returncode == 0 and validation.get("valid") is True
    issues = list(validation.get("errors", []))

    acceptance_path = base / "acceptance.json"
    acceptance = {}
    try:
        acceptance = json.loads(acceptance_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        issues.append(f"acceptance.json unavailable: {exc}")
    categories = {case.get("category") for case in acceptance.get("cases", []) if isinstance(case, dict)}
    missing_cases = sorted(REQUIRED_CASES - categories)
    if missing_cases:
        issues.append(f"missing acceptance categories: {', '.join(missing_cases)}")
    classes = set()
    try:
        classes = set(json.loads((base / "vocabularies/claim-classes.json").read_text())["values"])
    except (OSError, KeyError, TypeError, json.JSONDecodeError):
        issues.append("claim-class vocabulary is missing or malformed")
    missing_classes = sorted(REQUIRED_CLASSES - classes)
    if missing_classes:
        issues.append(f"missing evidence classes: {', '.join(missing_classes)}")
    cases_complete = True
    for case in acceptance.get("cases", []):
        if not isinstance(case, dict):
            cases_complete = False
            continue
        case_id = str(case.get("id", "")).strip()
        question = str(case.get("question", "")).strip()
        expected = str(case.get("expected_behavior", "")).strip()
        files = case.get("evidence_files", [])
        if not case_id or not question or not expected or expected.lower().startswith("pending") or not isinstance(files, list) or not files:
            cases_complete = False
        for value in files if isinstance(files, list) else []:
            candidate = (base / str(value)).resolve()
            try:
                candidate.relative_to(base.resolve())
            except ValueError:
                cases_complete = False
                continue
            if not candidate.is_file():
                cases_complete = False
    if not cases_complete:
        issues.append("acceptance examples still contain placeholders or missing evidence")
    behavioral = not missing_cases and not missing_classes and cases_complete and acceptance.get("gold_answers_are_compilation_inputs") is False
    if acceptance and acceptance.get("gold_answers_are_compilation_inputs") is not False:
        issues.append("gold answers must be explicitly excluded from compilation inputs")

    if approve:
        if not technical or not behavioral:
            issues.append("cannot approve until technical validation and behavioral coverage pass")
        else:
            acceptance["human_approval"] = {
                "status": "approved", "approved_by": approve.strip(), "approved_at": approved_at or str(date.today())
            }
            atomic_json(acceptance_path, acceptance)
    approval = acceptance.get("human_approval", {}) if isinstance(acceptance, dict) else {}
    approval_date_valid = False
    try:
        date.fromisoformat(str(approval.get("approved_at", "")))
        approval_date_valid = True
    except ValueError:
        pass
    human_approved = (
        approval.get("status") == "approved"
        and isinstance(approval.get("approved_by"), str)
        and bool(approval["approved_by"].strip())
        and approval_date_valid
    )
    if not human_approved:
        issues.append("behavioral examples still need explicit human approval")
    ready = technical and behavioral and human_approved
    return {
        "profile": profile,
        "technical_valid": technical,
        "behavioral_coverage": behavioral,
        "human_approved": human_approved,
        "ready": ready,
        "approval": approval,
        "issues": sorted(set(issues)),
    }


def report(result: dict) -> str:
    mark = lambda value: "PASS" if value else "NEEDS ATTENTION"
    lines = [
        f"# {result['profile']} specialization readiness", "",
        f"## {'READY TO USE' if result['ready'] else 'NOT READY'}", "",
        f"- Technical package: {mark(result['technical_valid'])}",
        f"- Behavioral coverage: {mark(result['behavioral_coverage'])}",
        f"- Domain-owner approval: {mark(result['human_approved'])}", "",
        "## What needs attention", "",
    ]
    lines.extend(f"- {issue}" for issue in result["issues"] or ["Nothing. Add the first evidence."])
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--approve", metavar="NAME")
    parser.add_argument("--approved-at")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    result = assess(root, args.profile, args.approve, args.approved_at)
    if args.write:
        destination = root / "REVIEWS" / f"{args.profile}-readiness.md"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(report(result), encoding="utf-8")
        result["report"] = str(destination)
    print(json.dumps(result, indent=2, sort_keys=True) if args.json else report(result), end="" if args.json else "")
    if args.json:
        print()
    return 0 if result["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
