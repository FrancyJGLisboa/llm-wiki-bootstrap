#!/usr/bin/env python3
"""scripts/commit-source.py — write the three ingest commitment fields into a raw source.

AGENTS.md hard rule 1: never write to raw/ except `ingested_hash`, `ingested_at`
and `ingested_pages`, as the last step of /wiki-ingest. This does exactly that
and nothing else — every other byte of the file, frontmatter and body alike, is
preserved verbatim. verify-corpus-eval.sh proves that by byte-comparing
everything outside the three fields.

Why it exists: in headless sharded mode (`claude -p "/wiki-ingest raw/<f>"`) the
agent can end its turn while the faithfulness gate is still running — observed
verbatim, "Waiting on the gate — I'll pick up Steps 6-8 automatically when it
completes." There is no later turn in -p mode, so Step 7 never runs: pages are
written, the index is updated, and `ingested_hash` stays "". The shell exit
status is 0, so nothing but a committed=N/M check notices. Idempotence is broken
(a re-run reprocesses everything) and every citation into that body becomes
unverifiable under the repo's own drift contract.

The hash MUST come from scripts/body-hash.sh — AGENTS.md forbids recomputing it
inline, because divergent newline handling between implementations silently
breaks idempotence.

Usage:
  scripts/commit-source.py <raw-file> --hash <sha256> [--at "YYYY-MM-DD HH:MM"]
                           [--pages wiki/a.md,wiki/b.md]
  scripts/commit-source.py <raw-file> --check      # is it committed? exit 0/1

Exit: 0 written (or committed, under --check), 1 not committed (--check),
      2 usage/parse error.
"""

import argparse
import os
import re
import sys

TRIPLE = ("ingested_hash", "ingested_at", "ingested_pages")


def split_frontmatter(lines):
    """(head, fm, body) with fm the inner frontmatter lines. Raises on absence."""
    if lines[:1] != ["---"]:
        raise ValueError("no leading frontmatter")
    try:
        end = lines.index("---", 1)
    except ValueError:
        raise ValueError("unclosed frontmatter")
    return lines[:1], lines[1:end], lines[end:]


def drop_field(fm, key):
    """Remove `key:` and any indented continuation lines (e.g. a YAML list)."""
    out, skipping = [], False
    for line in fm:
        if re.match(r"^%s\s*:" % re.escape(key), line):
            skipping = True
            continue
        if skipping and (line.startswith((" ", "\t", "-")) and line.strip()):
            continue
        skipping = False
        out.append(line)
    return out


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("raw_file")
    ap.add_argument("--hash")
    ap.add_argument("--at")
    ap.add_argument("--pages", default="")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.raw_file):
        print("error: no such file: %s" % args.raw_file, file=sys.stderr)
        return 2

    with open(args.raw_file, encoding="utf-8") as fh:
        text = fh.read()
    lines = text.split("\n")

    try:
        head, fm, tail = split_frontmatter(lines)
    except ValueError as exc:
        print("error: %s: %s" % (args.raw_file, exc), file=sys.stderr)
        return 2

    if args.check:
        for line in fm:
            m = re.match(r'^ingested_hash\s*:\s*"?([0-9a-f]*)"?\s*$', line)
            if m and m.group(1):
                return 0
        return 1

    if not args.hash:
        print("error: --hash is required (use scripts/body-hash.sh)", file=sys.stderr)
        return 2
    if not re.fullmatch(r"[0-9a-f]{64}", args.hash):
        print("error: --hash is not a sha256 hex digest", file=sys.stderr)
        return 2

    for key in TRIPLE:
        fm = drop_field(fm, key)

    fm.append('ingested_hash: "%s"' % args.hash)
    fm.append("ingested_at: %s" % (args.at or "unknown"))
    pages = [p.strip() for p in args.pages.split(",") if p.strip()]
    if pages:
        fm.append("ingested_pages:")
        fm.extend("  - %s" % p for p in pages)
    else:
        fm.append("ingested_pages: []")

    with open(args.raw_file, "w", encoding="utf-8") as fh:
        fh.write("\n".join(head + fm + tail))
    return 0


if __name__ == "__main__":
    sys.exit(main())
