#!/usr/bin/env python3
"""Deterministic boundary between EVIDENCE-INBOX and immutable raw evidence.

This script never extracts or rewrites evidence. It inventories pending files and
records which normalized raw source an agent created through /ctx-extract.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import sys
import tempfile


STATE_VERSION = 1
IGNORED_NAMES = {".gitkeep", ".DS_Store", "README.md"}


class InboxError(ValueError):
    pass


def safe_relative(value: str, label: str) -> PurePosixPath:
    normalized = value.replace("\\", "/")
    path = PurePosixPath(normalized)
    if not normalized or path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        raise InboxError(f"unsafe {label}: {value!r}")
    return path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def load_state(path: Path) -> dict:
    if not path.exists():
        return {"version": STATE_VERSION, "entries": {}}
    if path.is_symlink():
        raise InboxError(f"state file must not be a symlink: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise InboxError(f"invalid inbox state: {exc}") from exc
    if data.get("version") != STATE_VERSION or not isinstance(data.get("entries"), dict):
        raise InboxError("invalid inbox state contract")
    return data


def write_state(path: Path, state: dict) -> None:
    if path.parent.exists() and path.parent.is_symlink():
        raise InboxError(f"state directory must not be a symlink: {path.parent}")
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(state, indent=2, sort_keys=True) + "\n"
    fd, temporary = tempfile.mkstemp(prefix=".inbox-state-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(payload)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def inbox_files(inbox: Path) -> list[tuple[str, Path]]:
    if not inbox.is_dir() or inbox.is_symlink():
        raise InboxError(f"EVIDENCE-INBOX directory missing or unsafe: {inbox}")
    found: list[tuple[str, Path]] = []
    for current, directories, files in os.walk(inbox, followlinks=False):
        current_path = Path(current)
        for name in list(directories):
            candidate = current_path / name
            if candidate.is_symlink():
                raise InboxError(f"symlink not allowed in EVIDENCE-INBOX: {candidate.relative_to(inbox)}")
            if name.startswith("."):
                directories.remove(name)
        for name in files:
            candidate = current_path / name
            relative = candidate.relative_to(inbox).as_posix()
            if candidate.is_symlink():
                raise InboxError(f"symlink not allowed in EVIDENCE-INBOX: {relative}")
            if name in IGNORED_NAMES or name.startswith("."):
                continue
            if not candidate.is_file():
                raise InboxError(f"unsupported EVIDENCE-INBOX entry: {relative}")
            found.append((relative, candidate))
    return sorted(found)


def pending_data(root: Path) -> dict:
    state = load_state(root / "context" / "inbox-state.json")
    pending = []
    for relative, path in inbox_files(root / "EVIDENCE-INBOX"):
        sha256 = digest(path)
        entry = state["entries"].get(relative)
        reason = "new"
        if entry:
            raw_path = root / entry.get("raw", "")
            if entry.get("sha256") != sha256:
                reason = "changed"
            elif not raw_path.is_file() or raw_path.is_symlink():
                reason = "raw-missing"
            else:
                continue
        pending.append({"path": relative, "sha256": sha256, "size": path.stat().st_size, "reason": reason})
    return {"version": STATE_VERSION, "pending": pending}


def record(root: Path, inbox_value: str, raw_value: str) -> dict:
    inbox_rel = safe_relative(inbox_value, "EVIDENCE-INBOX path")
    raw_rel = safe_relative(raw_value, "raw path")
    if not raw_rel.parts or raw_rel.parts[0] != "raw":
        raise InboxError("recorded source must live under raw/")
    inbox_root = root / "EVIDENCE-INBOX"
    raw_root = root / "raw"
    if inbox_root.is_symlink() or raw_root.is_symlink() or not raw_root.is_dir():
        raise InboxError("EVIDENCE-INBOX/ and raw/ must be real directories, not symlinks")
    inbox_path = inbox_root / Path(*inbox_rel.parts)
    raw_path = root / Path(*raw_rel.parts)
    try:
        inbox_path.resolve(strict=True).relative_to(inbox_root.resolve(strict=True))
        raw_path.resolve(strict=True).relative_to(raw_root.resolve(strict=True))
    except (FileNotFoundError, ValueError) as exc:
        raise InboxError("recorded paths must resolve inside EVIDENCE-INBOX/ and raw/") from exc
    if inbox_path.is_symlink() or not inbox_path.is_file():
        raise InboxError(f"EVIDENCE-INBOX source does not exist or is unsafe: {inbox_value}")
    if raw_path.is_symlink() or not raw_path.is_file():
        raise InboxError(f"normalized raw source does not exist or is unsafe: {raw_value}")
    state_path = root / "context" / "inbox-state.json"
    state = load_state(state_path)
    state["entries"][inbox_rel.as_posix()] = {
        "raw": raw_rel.as_posix(),
        "sha256": digest(inbox_path),
        "size": inbox_path.stat().st_size,
    }
    state["entries"] = dict(sorted(state["entries"].items()))
    write_state(state_path, state)
    return {"recorded": inbox_rel.as_posix(), "raw": raw_rel.as_posix()}


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--root", default=".", help="context compiler root")
    commands = result.add_subparsers(dest="command", required=True)
    pending = commands.add_parser("pending", help="list new or changed EVIDENCE-INBOX evidence")
    pending.add_argument("--json", action="store_true")
    recorded = commands.add_parser("record", help="record a successful /ctx-extract result")
    recorded.add_argument("path", help="path relative to EVIDENCE-INBOX/")
    recorded.add_argument("--raw", required=True, help="normalized source path under raw/")
    recorded.add_argument("--json", action="store_true")
    return result


def main() -> int:
    args = parser().parse_args()
    root = Path(args.root).resolve()
    try:
        if args.command == "pending":
            result = pending_data(root)
            if args.json:
                print(json.dumps(result, indent=2, sort_keys=True))
            elif result["pending"]:
                for item in result["pending"]:
                    print(f"{item['reason']:11} {item['path']}")
            else:
                print("EVIDENCE-INBOX is up to date.")
        else:
            result = record(root, args.path, args.raw)
            if args.json:
                print(json.dumps(result, indent=2, sort_keys=True))
            else:
                print(f"recorded {result['recorded']} -> {result['raw']}")
    except InboxError as exc:
        print(f"inbox: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
