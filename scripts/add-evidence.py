#!/usr/bin/env python3
"""Safely stage local files, folders, or pasted text in EVIDENCE-INBOX."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import unicodedata


class AddError(ValueError):
    pass


def sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", normalized).strip("-") or "evidence"


def reject_symlinks(folder: Path) -> None:
    if folder.is_symlink():
        raise AddError(f"evidence inbox must be a real directory: {folder}")
    for current, directories, files in os.walk(folder, followlinks=False):
        base = Path(current)
        for name in directories + files:
            candidate = base / name
            if candidate.is_symlink():
                raise AddError(f"symlink not allowed in evidence inbox: {candidate.relative_to(folder)}")


def source_files(source: Path, inbox: Path) -> list[tuple[Path, Path]]:
    if source.is_symlink():
        raise AddError(f"symlink source is not allowed: {source}")
    try:
        resolved = source.resolve(strict=True)
    except FileNotFoundError as exc:
        raise AddError(f"source does not exist: {source}") from exc
    try:
        resolved.relative_to(inbox.resolve(strict=True))
    except ValueError:
        pass
    else:
        raise AddError("EVIDENCE-INBOX is already staged; say 'Compile my evidence' instead")
    if source.is_file():
        return [(source, Path(source.name))]
    if not source.is_dir():
        raise AddError(f"unsupported source: {source}")
    result: list[tuple[Path, Path]] = []
    for current, directories, files in os.walk(source, followlinks=False):
        base = Path(current)
        for name in list(directories):
            candidate = base / name
            if candidate.is_symlink():
                raise AddError(f"symlink source is not allowed: {candidate}")
        for name in files:
            candidate = base / name
            if candidate.is_symlink():
                raise AddError(f"symlink source is not allowed: {candidate}")
            relative = Path(source.name) / candidate.relative_to(source)
            result.append((candidate, relative))
    return sorted(result, key=lambda item: item[1].as_posix())


def collision_target(target: Path, digest: str) -> tuple[Path, bool]:
    if not target.exists():
        return target, False
    if target.is_symlink() or not target.is_file():
        raise AddError(f"unsafe destination collision: {target}")
    if sha256(target) == digest:
        return target, True
    candidate = target.with_name(f"{target.stem}-{digest[:8]}{target.suffix}")
    if candidate.exists():
        if candidate.is_symlink() or not candidate.is_file():
            raise AddError(f"unsafe destination collision: {candidate}")
        if sha256(candidate) == digest:
            return candidate, True
        raise AddError(f"hash collision at destination: {candidate}")
    return candidate, False


def atomic_copy(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".add-evidence-", dir=target.parent)
    os.close(fd)
    try:
        shutil.copyfile(source, temporary)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def stage_file(source: Path, relative: Path, inbox: Path) -> tuple[str, str]:
    digest = sha256(source)
    target, unchanged = collision_target(inbox / relative, digest)
    if not unchanged:
        atomic_copy(source, target)
    return ("unchanged" if unchanged else "staged", target.relative_to(inbox).as_posix())


def execute(root: Path, sources: list[str], text: str | None, title: str | None) -> dict:
    inbox = root / "EVIDENCE-INBOX"
    if not inbox.is_dir():
        raise AddError(f"EVIDENCE-INBOX is missing under {root}")
    reject_symlinks(inbox)
    if text is not None:
        if sources:
            raise AddError("use either local sources or --text, not both")
        if not title or not title.strip():
            raise AddError("--text requires --title")
        payload = text.rstrip("\n") + "\n"
        with tempfile.TemporaryDirectory() as td:
            source = Path(td) / f"{slug(title)}.md"
            source.write_text(payload, encoding="utf-8")
            status, destination = stage_file(source, Path(source.name), inbox)
        result = {"staged": [], "unchanged": []}
        result[status].append(destination)
        return result
    else:
        if title:
            raise AddError("--title is valid only with --text")
        if not sources:
            raise AddError("provide a local file/folder or --text with --title")
        items = []
        for value in sources:
            if re.match(r"^https?://", value, re.IGNORECASE):
                raise AddError("URLs are acquired by /ctx-add through the existing /ctx-extract contract")
            items.extend(source_files(Path(value).expanduser(), inbox))
    result = {"staged": [], "unchanged": []}
    for source, relative in items:
        status, destination = stage_file(source, relative, inbox)
        result[status].append(destination)
    result["staged"].sort()
    result["unchanged"].sort()
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--text")
    parser.add_argument("--title")
    parser.add_argument("sources", nargs="*")
    args = parser.parse_args()
    try:
        result = execute(Path(args.root).resolve(), args.sources, args.text, args.title)
    except AddError as exc:
        if args.json:
            print(json.dumps({"error": str(exc), "staged": [], "unchanged": []}, sort_keys=True))
        else:
            print(f"add-evidence: {exc}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        for name in result["staged"]:
            print(f"added      {name}")
        for name in result["unchanged"]:
            print(f"unchanged  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
