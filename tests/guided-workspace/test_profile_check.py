#!/usr/bin/env python3
"""Acceptance tests for generic profile-package validation."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile


REPO = Path(__file__).resolve().parents[2]
CLI = REPO / "scripts" / "profile-check.py"


def run(root: Path, name: str, ok: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["python3", str(CLI), "--root", str(root), "--profile", name, "--json"],
        text=True,
        capture_output=True,
    )
    if ok and result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout)
    if not ok and result.returncode == 0:
        raise AssertionError("invalid profile unexpectedly passed")
    return result


def write_profile(root: Path, manifest: dict, artifacts: dict[str, object]) -> None:
    base = root / "profiles" / manifest["name"]
    base.mkdir(parents=True)
    for rel, value in artifacts.items():
        path = base / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(value, str):
            path.write_text(value)
        else:
            path.write_text(json.dumps(value))
    (base / "profile.json").write_text(json.dumps(manifest))


def main() -> None:
    result = json.loads(run(REPO, "client-decision").stdout)
    assert result["valid"] is True
    assert result["artifact_count"] >= 10

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        manifest = {
            "name": "project-decision",
            "profile_version": 1,
            "artifacts": ["COMPILATION.md", "schemas/decision.schema.json"],
        }
        write_profile(
            root,
            manifest,
            {"COMPILATION.md": "# Project decision\n", "schemas/decision.schema.json": {"type": "object"}},
        )
        assert json.loads(run(root, "project-decision").stdout)["artifact_count"] == 2

        (root / "profiles" / "project-decision" / "undeclared.md").write_text("not in manifest")
        run(root, "project-decision", ok=False)
        (root / "profiles" / "project-decision" / "undeclared.md").unlink()

        (root / "profiles" / "project-decision" / "schemas" / "decision.schema.json").unlink()
        run(root, "project-decision", ok=False)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        write_profile(
            root,
            {"name": "unsafe", "profile_version": 1, "artifacts": ["../secret.json"]},
            {"COMPILATION.md": "unused"},
        )
        run(root, "unsafe", ok=False)

    if hasattr(os, "symlink"):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            base = root / "profiles" / "linked-profile"
            base.mkdir(parents=True)
            outside = root / "outside.json"
            outside.write_text('{"type":"object"}')
            os.symlink(outside, base / "linked.json")
            (base / "profile.json").write_text(json.dumps({
                "name": "linked-profile", "profile_version": 1, "artifacts": ["linked.json"]
            }))
            run(root, "linked-profile", ok=False)

    print("OK")


if __name__ == "__main__":
    main()
