#!/usr/bin/env python3
"""Validate the portable asset contract of any context-compiler profile."""

from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import re
import sys


NAME = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")


def validate(root: Path, requested: str) -> dict:
    errors: list[str] = []
    if not NAME.fullmatch(requested):
        return {"profile": requested, "valid": False, "artifact_count": 0, "errors": ["unsafe profile name"]}
    base = root / "profiles" / requested
    if base.is_symlink() or not base.is_dir():
        return {"profile": requested, "valid": False, "artifact_count": 0, "errors": ["profile directory missing or unsafe"]}
    resolved_base = base.resolve()
    manifest_path = base / "profile.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        return {"profile": requested, "valid": False, "artifact_count": 0, "errors": ["profile.json missing"]}
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"profile": requested, "valid": False, "artifact_count": 0, "errors": [f"invalid profile.json: {exc}"]}
    if manifest.get("name") != requested:
        errors.append("manifest name does not match directory")
    version = manifest.get("profile_version")
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        errors.append("profile_version must be an integer >= 1")
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        errors.append("artifacts must be a non-empty list")
        artifacts = []
    if any(not isinstance(item, str) for item in artifacts):
        errors.append("every artifact must be a string path")
        artifacts = [item for item in artifacts if isinstance(item, str)]
    if len(artifacts) != len(set(artifacts)):
        errors.append("artifact paths must be unique")
    checked = 0
    for value in artifacts:
        rel = PurePosixPath(value.replace("\\", "/"))
        if rel.is_absolute() or any(part in {"", ".", ".."} for part in rel.parts) or value == "profile.json":
            errors.append(f"unsafe artifact path: {value}")
            continue
        path = base / Path(*rel.parts)
        try:
            path.resolve(strict=True).relative_to(resolved_base)
        except (FileNotFoundError, ValueError):
            errors.append(f"artifact escapes profile or is missing: {value}")
            continue
        if path.is_symlink() or not path.is_file():
            errors.append(f"artifact missing or unsafe: {value}")
            continue
        checked += 1
        if path.suffix == ".json":
            try:
                json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                errors.append(f"invalid JSON artifact {value}: {exc}")
        elif path.stat().st_size == 0:
            errors.append(f"artifact is empty: {value}")
    return {"profile": requested, "valid": not errors, "artifact_count": checked, "errors": errors}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = validate(Path(args.root).resolve(), args.profile)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    elif result["valid"]:
        print(f"profile {result['profile']}: PASS ({result['artifact_count']} artifacts)")
    else:
        for error in result["errors"]:
            print(f"profile {result['profile']}: {error}", file=sys.stderr)
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
