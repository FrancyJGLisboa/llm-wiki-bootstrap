#!/usr/bin/env python3
"""Acceptance tests for profile readiness and explicit behavioral approval."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SCAFFOLD = ROOT / "scripts" / "profile-scaffold.py"
READY = ROOT / "scripts" / "profile-readiness.py"
USE = ROOT / "scripts" / "use-profile.sh"


def run(*args: str, ok: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(list(args), text=True, capture_output=True)
    if ok and result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout)
    if not ok and result.returncode == 0:
        raise AssertionError("command unexpectedly passed")
    return result


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "scripts").mkdir()
        for source in ("profile-check.py", "profile-resolve.py", "profile-readiness.py"):
            (root / "scripts" / source).write_bytes((ROOT / "scripts" / source).read_bytes())
        (root / "scripts" / "use-profile.sh").write_bytes(USE.read_bytes())

        run(
            "python3", str(SCAFFOLD), "--root", str(root), "--name", "project-decision",
            "--title", "Project Decisions", "--purpose", "Track project decisions.",
            "--evidence", "meetings", "--evidence", "decision records",
            "--concept", "decision", "--concept", "owner",
            "--output", "brief", "--output", "delta",
            "--review-trigger", "contradiction", "--review-trigger", "ambiguous owner",
        )
        pending = json.loads(run("python3", str(READY), "--root", str(root), "--profile", "project-decision", "--json", ok=False).stdout)
        assert pending["technical_valid"] is True
        assert pending["behavioral_coverage"] is False
        assert pending["human_approved"] is False
        assert pending["ready"] is False
        run("bash", str(root / "scripts/use-profile.sh"), "project-decision", "--root", str(root), ok=False)

        acceptance_path = root / "profiles/project-decision/acceptance.json"
        acceptance = json.loads(acceptance_path.read_text())
        for case in acceptance["cases"]:
            case["expected_behavior"] = f"Domain owner expects a grounded {case['category']} result."
        acceptance_path.write_text(json.dumps(acceptance, indent=2, sort_keys=True) + "\n")

        approved = json.loads(run(
            "python3", str(READY), "--root", str(root), "--profile", "project-decision",
            "--approve", "Domain Owner", "--approved-at", "2026-08-22", "--write", "--json"
        ).stdout)
        assert approved["ready"] is True
        report = root / "REVIEWS" / "project-decision-readiness.md"
        assert report.is_file() and "READY TO USE" in report.read_text()
        run("bash", str(root / "scripts/use-profile.sh"), "project-decision", "--root", str(root))
        assert json.loads((root / "context-profile.json").read_text())["profile"] == "project-decision"

        acceptance = json.loads(acceptance_path.read_text())
        acceptance["cases"] = [case for case in acceptance["cases"] if case["category"] != "absence"]
        acceptance_path.write_text(json.dumps(acceptance, indent=2) + "\n")
        incomplete = json.loads(run("python3", str(READY), "--root", str(root), "--profile", "project-decision", "--json", ok=False).stdout)
        assert incomplete["behavioral_coverage"] is False
        assert incomplete["ready"] is False

        unsafe = json.loads(run("python3", str(READY), "--root", str(root), "--profile", "../escape", "--json", ok=False).stdout)
        assert unsafe["issues"] == ["unsafe profile name"]
        bad_date = json.loads(run(
            "python3", str(READY), "--root", str(root), "--profile", "project-decision",
            "--approve", "Owner", "--approved-at", "2026-02-31", "--json", ok=False
        ).stdout)
        assert "valid YYYY-MM-DD" in bad_date["issues"][0]

    print("profile readiness: PASS")


if __name__ == "__main__":
    main()
