#!/usr/bin/env python3
"""Safely scaffold a self-service context-compiler profile from plain-language inputs."""

from __future__ import annotations

import argparse
from datetime import date
import json
from pathlib import Path
import re
import shutil
import tempfile


NAME = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
CLAIM_CLASSES = ["observation", "fact", "assumption", "inference", "derivation", "unknown"]
CASE_CATEGORIES = ["positive", "provenance", "temporal", "contradiction", "absence", "no-op"]


def clean_many(values: list[str], label: str, minimum: int = 2) -> list[str]:
    cleaned = sorted({value.strip() for value in values if value.strip()}, key=str.casefold)
    if len(cleaned) < minimum:
        raise ValueError(f"provide at least {minimum} distinct {label}")
    if any(len(value) > 120 or "\n" in value for value in cleaned):
        raise ValueError(f"each {label} must be one line and at most 120 characters")
    return cleaned


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build(args: argparse.Namespace) -> dict:
    if not NAME.fullmatch(args.name):
        raise ValueError("profile name must be safe kebab-case")
    title = args.title.strip()
    purpose = args.purpose.strip()
    if not title or not purpose or "\n" in title or len(title) > 100 or len(purpose) > 500:
        raise ValueError("title and purpose are required; title must be one short line")
    evidence = clean_many(args.evidence, "evidence types")
    concepts = clean_many(args.concept, "concepts")
    outputs = clean_many(args.output, "outputs")
    review = clean_many(args.review_trigger, "review triggers")

    root = Path(args.root).resolve()
    profiles = root / "profiles"
    profiles.mkdir(parents=True, exist_ok=True)
    destination = profiles / args.name
    if destination.exists() or destination.is_symlink():
        raise FileExistsError(f"profile already exists: {args.name}")

    temp = Path(tempfile.mkdtemp(prefix=f".{args.name}.", dir=profiles))
    try:
        (temp / "schemas").mkdir()
        (temp / "vocabularies").mkdir()
        (temp / "templates").mkdir()
        (temp / "fixtures").mkdir()

        compilation = f"""# {title} compilation contract

## Purpose

{purpose}

## Evidence discipline

- Preserve every material statement's exact source identifier and evidence anchor.
- Preserve speaker and role for attributable evidence; do not turn agreement or a hypothetical into an assertion.
- Classify claims as observation, fact, assumption, inference, derivation, or unknown.
- Label inference visibly with confidence. UNKNOWN is a correct result when evidence is insufficient.
- Keep subject evidence, internal analysis, external evidence, and compiler derivations distinct.

## Temporal discipline

Keep historical and current states. Represent updates, supersession, confirmation, and contradiction explicitly; never average incompatible claims into one summary.

## Domain customization

The concepts, relations, extraction rules, and output templates below are a safe starting point. Customize them from the user's examples without adding domain branches to the generic compiler core.

## Human review

Route material inference, ambiguity, possible supersession, contradictions, and unsupported claims to exception-based review. Never require approval of every claim.
"""
        (temp / "COMPILATION.md").write_text(compilation, encoding="utf-8")
        (temp / "README.md").write_text(
            f"# {title}\n\n{purpose}\n\nThis profile was generated through the self-service profile builder. Review observable acceptance examples before activation.\n",
            encoding="utf-8",
        )
        write_json(temp / "schemas/context.schema.json", {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": f"{title} context",
            "type": "object",
            "required": ["subject", "claims", "unknowns"],
            "properties": {
                "subject": {"type": "string", "minLength": 1},
                "claims": {"type": "array", "items": {"type": "object"}},
                "unknowns": {"type": "array", "items": {"type": "string"}},
            },
            "additionalProperties": True,
        })
        write_json(temp / "vocabularies/claim-classes.json", {"values": CLAIM_CLASSES})
        write_json(temp / "vocabularies/ontology.json", {"concepts": concepts})
        write_json(temp / "vocabularies/relations.json", {
            "values": ["related-to", "updates", "supersedes", "confirms", "contradicts"]
        })
        write_json(temp / "vocabularies/review-triggers.json", {"values": review})
        (temp / "templates/brief.md").write_text(
            "# {{ subject }} brief\n\n## Current state\n\n## What changed\n\n## Active assumptions\n\n## Unknowns\n\n## Evidence\n",
            encoding="utf-8",
        )
        (temp / "templates/review.md").write_text(
            "# {{ subject }} review exceptions\n\n## Contradictions\n\n## Ambiguity\n\n## Possible supersession\n\n## Unsupported material claims\n",
            encoding="utf-8",
        )
        (temp / "fixtures/example-evidence.md").write_text(
            f"---\nsynthetic: true\nprofile: {args.name}\n---\n\n# Synthetic acceptance evidence\n\nReplace this clearly labelled synthetic fixture with realistic examples during the guided preview. Gold expectations remain in `acceptance.json`, separate from compilation inputs.\n",
            encoding="utf-8",
        )
        cases = []
        prompts = {
            "positive": "Can the compiler reconstruct one supported current state?",
            "provenance": "Does every material conclusion resolve to exact evidence?",
            "temporal": "Does a later state preserve and supersede the earlier state?",
            "contradiction": "Does incompatible evidence enter review instead of being averaged?",
            "absence": "Does an unsupported question return UNKNOWN?",
            "no-op": "Does unchanged evidence leave compiled state unchanged?",
        }
        for category in CASE_CATEGORIES:
            cases.append({
                "id": f"{category}-01",
                "category": category,
                "question": prompts[category],
                "expected_behavior": "pending domain-specific example; must be reviewed before approval",
                "evidence_files": ["fixtures/example-evidence.md"],
            })
        write_json(temp / "acceptance.json", {
            "gold_answers_are_compilation_inputs": False,
            "cases": cases,
            "human_approval": {"status": "pending", "approved_by": None, "approved_at": None},
        })

        artifacts = sorted(str(path.relative_to(temp).as_posix()) for path in temp.rglob("*") if path.is_file())
        write_json(temp / "profile.json", {
            "name": args.name,
            "profile_version": 1,
            "artifacts": artifacts,
            "self_service": {
                "title": title,
                "purpose": purpose,
                "evidence_types": evidence,
                "core_concepts": concepts,
                "outputs": outputs,
                "review_triggers": review,
                "created": str(date.today()),
            },
        })
        temp.rename(destination)
    except Exception:
        shutil.rmtree(temp, ignore_errors=True)
        raise
    return {"profile": args.name, "created": True, "path": str(destination), "artifact_count": len(artifacts)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--name", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--purpose", required=True)
    parser.add_argument("--evidence", action="append", default=[], required=True)
    parser.add_argument("--concept", action="append", default=[], required=True)
    parser.add_argument("--output", action="append", default=[], required=True)
    parser.add_argument("--review-trigger", action="append", default=[], required=True)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        result = build(args)
    except (ValueError, FileExistsError, OSError) as exc:
        parser.exit(1, f"profile scaffold error: {exc}\n")
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"profile scaffold: created {result['profile']} ({result['artifact_count']} artifacts)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
