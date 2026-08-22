#!/usr/bin/env python3
"""Acceptance tests for the single local/text evidence staging boundary."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile


REPO = Path(__file__).resolve().parents[2]
CLI = REPO / "scripts" / "add-evidence.py"


def run(root: Path, *args: str, ok: bool = True) -> dict:
    result = subprocess.run(
        ["python3", str(CLI), "--root", str(root), "--json", *args],
        text=True,
        capture_output=True,
    )
    if ok and result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout)
    if not ok and result.returncode == 0:
        raise AssertionError(f"command unexpectedly passed: {args}")
    return json.loads(result.stdout) if result.stdout.strip() else {}


def run_stdin(root: Path, value: str, *args: str) -> dict:
    result = subprocess.run(
        ["python3", str(CLI), "--root", str(root), "--json", *args],
        text=True,
        input=value,
        capture_output=True,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout)
    return json.loads(result.stdout)


def main() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "workspace"
        inbox = root / "EVIDENCE-INBOX"
        inbox.mkdir(parents=True)
        sources = Path(td) / "sources"
        sources.mkdir()

        report = sources / "Client Report.PDF"
        report.write_bytes(b"synthetic-pdf-v1")
        before = report.read_bytes()
        first = run(root, str(report))
        assert first["staged"] == ["Client Report.PDF"]
        assert (inbox / "Client Report.PDF").read_bytes() == before
        assert report.read_bytes() == before

        repeated = run(root, str(report))
        assert repeated["staged"] == []
        assert repeated["unchanged"] == ["Client Report.PDF"]

        report.write_bytes(b"synthetic-pdf-v2")
        changed = run(root, str(report))
        assert len(changed["staged"]) == 1
        assert changed["staged"][0].startswith("Client Report-")
        assert changed["staged"][0].endswith(".PDF")

        folder = sources / "Meeting Pack"
        (folder / "nested").mkdir(parents=True)
        (folder / "agenda.md").write_text("Agenda\n")
        (folder / "nested" / "notes.txt").write_text("Notes\n")
        directory = run(root, str(folder))
        assert directory["staged"] == [
            "Meeting Pack/agenda.md",
            "Meeting Pack/nested/notes.txt",
        ]

        text = run(root, "--text", "Price concern moved to availability.", "--title", "August Call Notes")
        assert text["staged"] == ["august-call-notes.md"]
        assert (inbox / "august-call-notes.md").read_text() == "Price concern moved to availability.\n"
        assert run(root, "--text", "Price concern moved to availability.", "--title", "August Call Notes")["unchanged"] == ["august-call-notes.md"]
        stdin_text = run_stdin(root, "Sensitive meeting note", "--text-stdin", "--title", "Secure Note")
        assert stdin_text["staged"] == ["secure-note.md"]

        run(root, str(sources / "missing.docx"), ok=False)
        run(root, "--text", "missing title", ok=False)
        run(root, str(inbox), ok=False)

        if hasattr(os, "symlink"):
            outside = sources / "outside.txt"
            outside.write_text("outside")
            os.symlink(outside, sources / "linked.txt")
            run(root, str(sources / "linked.txt"), ok=False)
            os.symlink(outside, inbox / "unsafe.txt")
            run(root, str(outside), ok=False)

    print("OK")


if __name__ == "__main__":
    main()
