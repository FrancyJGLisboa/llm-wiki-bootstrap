#!/usr/bin/env python3
"""Verify that a Context Workspace VSIX contains the intended offline product."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import zipfile


def fail(message: str) -> None:
    raise SystemExit(f"VSIX verification failed: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify-vsix.py <package.vsix>")
    archive = Path(sys.argv[1])
    if not archive.is_file():
        fail(f"missing archive: {archive}")
    with zipfile.ZipFile(archive) as package:
        names = set(package.namelist())
        required = {
            "extension/package.json",
            "extension/extension.js",
            "extension/src/core.js",
            "extension/resources/compiler-template/START-HERE.md",
            "extension/resources/compiler-template/scripts/add-evidence.py",
            "extension/resources/compiler-template/profiles/client-decision/profile.json",
            "extension/resources/compiler-template/.vscode/extensions.json",
        }
        missing = sorted(required - names)
        if missing:
            fail(f"missing required files: {', '.join(missing)}")
        forbidden = [name for name in names if "/.git/" in name or "/node_modules/" in name or name.endswith("GATES.md")]
        if forbidden:
            fail(f"development files leaked: {forbidden[:3]}")
        manifest = json.loads(package.read("extension/package.json"))
        if manifest.get("publisher") != "context-compiler" or manifest.get("version") != "0.1.0":
            fail("unexpected extension identity")
        if "telemetry" in json.dumps(manifest).lower():
            fail("manifest declares telemetry")
        recommendations = json.loads(package.read("extension/resources/compiler-template/.vscode/extensions.json"))["recommendations"]
        if "context-compiler.context-workspace" not in recommendations:
            fail("fresh compiler does not recommend the extension")
    print("VSIX contents: PASS")


if __name__ == "__main__":
    main()
