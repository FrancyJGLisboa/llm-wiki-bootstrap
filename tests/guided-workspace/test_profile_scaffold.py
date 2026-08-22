#!/usr/bin/env python3
"""Acceptance tests for the deterministic self-service profile scaffold."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / "scripts" / "profile-scaffold.py"


def command(root: Path, name: str = "project-decision") -> list[str]:
    return [
        "python3", str(CLI), "--root", str(root), "--name", name,
        "--title", "Project Decisions",
        "--purpose", "Reconstruct evolving project decisions and their evidence.",
        "--evidence", "meeting transcripts", "--evidence", "architecture notes",
        "--concept", "decision", "--concept", "alternative", "--concept", "constraint",
        "--output", "decision brief", "--output", "change delta",
        "--review-trigger", "ambiguous owner", "--review-trigger", "possible supersession",
        "--json",
    ]


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        result = subprocess.run(command(root), text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        summary = json.loads(result.stdout)
        assert summary["profile"] == "project-decision"
        assert summary["created"] is True
        base = root / "profiles" / "project-decision"
        manifest = json.loads((base / "profile.json").read_text())
        assert manifest["self_service"]["purpose"].startswith("Reconstruct")
        assert manifest["artifacts"] == sorted(manifest["artifacts"])
        assert all((base / item).is_file() for item in manifest["artifacts"])
        acceptance = json.loads((base / "acceptance.json").read_text())
        assert {case["category"] for case in acceptance["cases"]} == {
            "positive", "provenance", "temporal", "contradiction", "absence", "no-op"
        }
        assert acceptance["human_approval"]["status"] == "pending"

        repeat = subprocess.run(command(root), text=True, capture_output=True)
        assert repeat.returncode != 0
        assert "already exists" in repeat.stderr

        unsafe = subprocess.run(command(root, "../escape"), text=True, capture_output=True)
        assert unsafe.returncode != 0
        assert not (root / "escape").exists()

    print("profile scaffold: PASS")


if __name__ == "__main__":
    main()
