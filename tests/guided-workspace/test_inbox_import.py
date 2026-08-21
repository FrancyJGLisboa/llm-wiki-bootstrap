#!/usr/bin/env python3
"""Acceptance tests for the deterministic evidence-inbox state boundary."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile


REPO = Path(__file__).resolve().parents[2]
CLI = REPO / "scripts" / "inbox.py"


def run(root: Path, *args: str, ok: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["python3", str(CLI), "--root", str(root), *args],
        text=True,
        capture_output=True,
    )
    if ok and result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout)
    if not ok and result.returncode == 0:
        raise AssertionError(f"command unexpectedly passed: {args}")
    return result


def main() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        for name in ("EVIDENCE-INBOX", "raw", "context"):
            (root / name).mkdir()
        evidence = root / "EVIDENCE-INBOX" / "Client Email.md"
        evidence.write_text("The trigger is another $20 decline.\n")

        pending = json.loads(run(root, "pending", "--json").stdout)
        assert [item["path"] for item in pending["pending"]] == ["Client Email.md"]
        original = evidence.read_bytes()

        raw = root / "raw" / "client-email.md"
        raw.write_text("---\nsource_type: email\n---\nThe trigger is another $20 decline.\n")
        run(root, "record", "Client Email.md", "--raw", "raw/client-email.md")
        assert evidence.read_bytes() == original, "evidence inbox must never be rewritten"
        assert json.loads(run(root, "pending", "--json").stdout)["pending"] == []

        evidence.write_text("The trigger is another $25 decline.\n")
        changed = json.loads(run(root, "pending", "--json").stdout)
        assert changed["pending"][0]["reason"] == "changed"

        second = root / "EVIDENCE-INBOX" / "nested" / "Call.txt"
        second.parent.mkdir()
        second.write_text("Speaker: qualified agreement\n")
        paths = [x["path"] for x in json.loads(run(root, "pending", "--json").stdout)["pending"]]
        assert paths == ["Client Email.md", "nested/Call.txt"], paths

        run(root, "record", "../escape.md", "--raw", "raw/client-email.md", ok=False)
        run(root, "record", "nested/Call.txt", "--raw", "../outside.md", ok=False)

        escaped_raw = root / "escaped-raw"
        escaped_raw.mkdir()
        (escaped_raw / "evidence.md").write_text("outside")
        if hasattr(os, "symlink"):
            os.symlink(escaped_raw, root / "raw" / "linked")
            run(root, "record", "nested/Call.txt", "--raw", "raw/linked/evidence.md", ok=False)

        if hasattr(os, "symlink"):
            outside = root / "outside.txt"
            outside.write_text("secret")
            os.symlink(outside, root / "EVIDENCE-INBOX" / "linked.txt")
            run(root, "pending", "--json", ok=False)

        state = json.loads((root / "context" / "inbox-state.json").read_text())
        assert state["version"] == 1
        assert list(state["entries"]) == ["Client Email.md"]

    print("OK")


if __name__ == "__main__":
    main()
