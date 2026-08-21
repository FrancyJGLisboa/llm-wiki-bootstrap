#!/usr/bin/env python3
"""Resolve an optional context-compiler profile without activating one implicitly."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


PROFILE_NAME = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")


class SetupError(ValueError):
    """A profile configuration error (CLI exit 2)."""


def read_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SetupError(f"{label} not found: {path}") from exc
    except (OSError, UnicodeError) as exc:
        raise SetupError(f"cannot read {label} {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SetupError(
            f"invalid JSON in {label} {path}: line {exc.lineno}, column {exc.colno}: {exc.msg}"
        ) from exc
    if not isinstance(value, dict):
        raise SetupError(f"{label} must contain a JSON object: {path}")
    return value


def validate_name(value: Any, label: str) -> str:
    if not isinstance(value, str) or not PROFILE_NAME.fullmatch(value):
        raise SetupError(
            f"{label} must be lowercase kebab-case (for example, client-decision)"
        )
    return value


def resolve(root: Path, override: str | None) -> dict[str, Any]:
    root = root.resolve()
    if not root.is_dir():
        raise SetupError(f"context-compiler root is not a directory: {root}")
    config_path = root / "context-profile.json"
    configured: str | None = None
    configured_version: int | None = None
    if config_path.exists():
        config = read_object(config_path, "profile config")
        if "profile" not in config:
            raise SetupError(f"profile config is missing required key 'profile': {config_path}")
        configured = validate_name(config["profile"], "configured profile")
        if "profile_version" in config:
            configured_version = config["profile_version"]
            if (
                isinstance(configured_version, bool)
                or not isinstance(configured_version, int)
                or configured_version < 1
            ):
                raise SetupError(
                    f"profile config 'profile_version' must be an integer >= 1: {config_path}"
                )

    if override is None and configured is None:
        return {
            "active": False,
            "profile": "generic",
            "profile_version": None,
            "root": str(root),
            "config": None,
            "manifest": None,
            "source": "default",
        }

    # `generic` is the built-in no-profile mode. Allow it as an explicit,
    # non-persistent override so callers can inspect generic behavior in a
    # profile-configured repository without hiding or editing the config.
    if override == "generic":
        return {
            "active": False,
            "profile": "generic",
            "profile_version": None,
            "root": str(root),
            "config": str(config_path) if configured is not None else None,
            "manifest": None,
            "source": "override",
        }

    name = validate_name(override if override is not None else configured, "profile")
    manifest_path = root / "profiles" / name / "profile.json"
    manifest = read_object(manifest_path, f"profile '{name}' manifest")
    manifest_name = validate_name(manifest.get("name"), "manifest 'name'")
    if manifest_name != name:
        raise SetupError(
            f"profile manifest name mismatch: selected '{name}', manifest declares '{manifest_name}'"
        )
    version = manifest.get("profile_version")
    if isinstance(version, bool) or not isinstance(version, int) or version < 1:
        raise SetupError(
            f"profile '{name}' manifest 'profile_version' must be an integer >= 1: {manifest_path}"
        )
    if override is None and configured_version is not None and configured_version != version:
        raise SetupError(
            f"profile version mismatch: config requests {configured_version}, "
            f"but profile '{name}' provides {version}"
        )

    return {
        "active": True,
        "profile": name,
        "profile_version": version,
        "root": str(root),
        "config": str(config_path) if configured is not None else None,
        "manifest": str(manifest_path),
        "source": "override" if override is not None else "config",
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Resolve the active context-compiler profile")
    parser.add_argument("--root", default=".", help="context-compiler root (default: current directory)")
    parser.add_argument("--profile", help="resolve this profile without changing context-profile.json")
    parser.add_argument("--json", action="store_true", help="print the complete resolution as JSON")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        result = resolve(Path(args.root), args.profile)
    except SetupError as exc:
        print(f"profile setup error: {exc}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    else:
        print(result["profile"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
