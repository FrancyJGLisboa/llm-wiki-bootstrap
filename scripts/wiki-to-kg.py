#!/usr/bin/env python3
"""scripts/wiki-to-kg.py — materialize the typed-relation knowledge graph.

Reads a wiki directory and emits one JSONL edge per typed `## Related` link:

    {"source": "<page-slug>", "verb": "<verb>", "target": "<target-slug>"}

This is the shared substrate for connection discovery (graph traversal at
query time) and causal discovery (the causal subgraph). It is DETERMINISTIC,
STDLIB-ONLY, and READ-ONLY: it parses wiki pages and writes JSONL to stdout —
it never mutates `wiki/` and never auto-runs at ingest (the sidecar is a
build/query-time artifact, kept out of the content-hash path).

Parse rule mirrors scripts/wiki-lint-typed-relations.sh (AGENTS.md → "Typed
relations"):
  - Edges are read ONLY inside a `## Related` section.
  - `- [[target]] <verb> [<attr>] — <prose>` → verb is the token after `]]`,
    before the em-dash (—) or `--`; must match [a-z][a-z0-9-]*.
  - A line with no verb token, or a malformed verb, is implicit `related-to`.
  - A line with ≥2 `[[…]]` tokens is `related-to` for every target.
  - source = the page's filename stem.

Usage:
  wiki-to-kg.py <wiki-dir> [--causal-only] [--vocab templates/causal-vocab.txt]

--causal-only keeps only edges whose verb is in the causal vocabulary
(default templates/causal-vocab.txt, relative to the repo root if present).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

_LINK_RE = re.compile(r"\[\[([a-z][a-z0-9-]*)\]\]")
_VERB_RE = re.compile(r"^[a-z][a-z0-9-]*$")
_EM_DASH = "—"


def _verb_from_single(line: str) -> str:
    """Return the verb for a single-target Related line, or 'related-to'."""
    after = line.split("]]", 1)[1] if "]]" in line else ""
    # Cut at the earliest of em-dash or '--' (the prose separator).
    cuts = [i for i in (after.find(_EM_DASH), after.find("--")) if i != -1]
    if cuts:
        after = after[: min(cuts)]
    after = after.strip()
    if not after:
        return "related-to"
    verb = after.split()[0]
    return verb if _VERB_RE.match(verb) else "related-to"


def edges_in_page(text: str, source: str):
    """Yield (source, verb, target) for every Related link in one page."""
    in_related = False
    for line in text.splitlines():
        if re.match(r"^## Related\s*$", line):
            in_related = True
            continue
        if line.startswith("## ") and not re.match(r"^## Related\s*$", line):
            in_related = False
        if not in_related:
            continue
        if not re.match(r"^\s*-\s+\[\[", line):
            continue
        targets = _LINK_RE.findall(line)
        if not targets:
            continue
        if len(targets) >= 2:
            for t in targets:
                yield (source, "related-to", t)
        else:
            yield (source, _verb_from_single(line), targets[0])


def load_vocab(path: Path | None) -> set[str]:
    if path and path.is_file():
        return {
            ln.strip()
            for ln in path.read_text(encoding="utf-8").splitlines()
            if ln.strip() and not ln.startswith("#")
        }
    return set()


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="wiki-to-kg.py")
    ap.add_argument("wiki_dir")
    ap.add_argument("--causal-only", action="store_true")
    ap.add_argument("--vocab", default=None)
    args = ap.parse_args(argv)

    root = Path(args.wiki_dir)
    if not root.is_dir():
        print(f"wiki-to-kg: not a directory: {root}", file=sys.stderr)
        return 2

    vocab_path = Path(args.vocab) if args.vocab else _default_vocab(root)
    vocab = load_vocab(vocab_path)
    if args.causal_only and not vocab:
        print("wiki-to-kg: --causal-only needs a vocab file", file=sys.stderr)
        return 2

    out = sys.stdout
    for md in sorted(root.rglob("*.md")):
        source = md.stem
        text = md.read_text(encoding="utf-8", errors="replace")
        for src, verb, target in edges_in_page(text, source):
            if args.causal_only and verb not in vocab:
                continue
            out.write(json.dumps({"source": src, "verb": verb, "target": target}) + "\n")
    return 0


def _default_vocab(wiki_dir: Path) -> Path | None:
    """Best-effort: find templates/causal-vocab.txt near the repo root."""
    for base in (Path.cwd(), wiki_dir, *wiki_dir.parents):
        cand = base / "templates" / "causal-vocab.txt"
        if cand.is_file():
            return cand
    return None


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
