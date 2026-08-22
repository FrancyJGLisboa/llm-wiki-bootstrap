#!/usr/bin/env python3
"""Rewrite a VSIX with stable ordering, timestamps, compression, and metadata."""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import zipfile


FIXED_TIME = (2026, 1, 1, 0, 0, 0)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: normalize-vsix.py <package.vsix>")
    archive = Path(sys.argv[1]).resolve()
    with zipfile.ZipFile(archive, "r") as source:
        entries = [(item, source.read(item.filename)) for item in source.infolist()]
    with tempfile.NamedTemporaryFile(dir=archive.parent, suffix=".vsix", delete=False) as handle:
        temporary = Path(handle.name)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as target:
            for original, content in sorted(entries, key=lambda value: value[0].filename):
                stable = zipfile.ZipInfo(original.filename, FIXED_TIME)
                stable.compress_type = zipfile.ZIP_DEFLATED
                stable.create_system = 3
                stable.external_attr = original.external_attr
                stable.flag_bits = original.flag_bits
                target.writestr(stable, content, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
        temporary.replace(archive)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
