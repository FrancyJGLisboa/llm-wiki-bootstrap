#!/usr/bin/env python3
"""scripts/wiki-to-kg.py — materialize the wiki's typed `## Related` edges as a
JSONL knowledge graph.

Each single-target `## Related` line `- [[target]] <verb> [<attr>] — prose`
becomes one triple {"source": <file-stem>, "verb": <verb>, "target": <slug>}.
A line with no verb, or with more than one [[link]], emits verb "related-to"
— matching scripts/wiki-lint-typed-relations.sh / AGENTS.md "Typed relations"
semantics. Causal edges are the subset whose verb is in templates/causal-vocab.txt;
--causal-only restricts output to those.

Stdlib only. Read-only on the input. Deterministic order (sorted, deduped).

Usage:
  scripts/wiki-to-kg.py <wiki-dir> [--causal-only] [--vocab <path>]
"""
import argparse
import json
import re
import sys
from pathlib import Path

LINK_RE = re.compile(r"\[\[([a-z][a-z0-9-]*)\]\]")
RELATED_HEADER_RE = re.compile(r"^## Related\s*$")
SECTION_RE = re.compile(r"^## ")
BULLET_RE = re.compile(r"^\s*-\s+\[\[")
VERB_RE = re.compile(r"^[a-z][a-z0-9-]*$")
EM_DASH = "—"


def load_vocab(path):
    return {
        ln.strip()
        for ln in Path(path).read_text(encoding="utf-8").splitlines()
        if ln.strip()
    }


def extract_verb(line):
    """Verb token after the first ]] (before the em-dash / --), or None.

    Mirrors the cut logic in scripts/wiki-lint-typed-relations.sh.
    """
    idx = line.find("]]")
    if idx == -1:
        return None
    after = line[idx + 2:].lstrip()
    em = after.find(EM_DASH)
    dh = after.find("--")
    cut = -1
    if em != -1 and (dh == -1 or em < dh):
        cut = em
    elif dh != -1:
        cut = dh
    if cut != -1:
        after = after[:cut]
    after = after.strip()
    if not after:
        return None
    verb = after.split()[0]
    return verb if VERB_RE.match(verb) else None


def edges_from_file(path):
    source = path.stem
    in_related = False
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if RELATED_HEADER_RE.match(line):
            in_related = True
            continue
        if SECTION_RE.match(line):  # any other ## heading closes the section
            in_related = False
            continue
        if not in_related or not BULLET_RE.match(line):
            continue
        targets = LINK_RE.findall(line)
        if not targets:
            continue
        if len(targets) >= 2:
            # multi-link line: every target is implicit related-to (no verb)
            out.extend((source, "related-to", t) for t in targets if t != source)
            continue
        target = targets[0]
        if target == source:
            continue
        out.append((source, extract_verb(line) or "related-to", target))
    return out


def main():
    ap = argparse.ArgumentParser(
        description="Materialize wiki typed-relation edges as JSONL."
    )
    ap.add_argument("wiki_dir")
    ap.add_argument("--causal-only", action="store_true",
                    help="emit only edges whose verb is in the causal vocab")
    ap.add_argument("--vocab", default=None,
                    help="path to causal-vocab.txt (default: ../templates/causal-vocab.txt)")
    args = ap.parse_args()

    root = Path(args.wiki_dir)
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 2

    vocab = None
    if args.causal_only:
        vocab_path = args.vocab or (
            Path(__file__).resolve().parent.parent / "templates" / "causal-vocab.txt"
        )
        try:
            vocab = load_vocab(vocab_path)
        except OSError as e:
            print(f"error: cannot read causal vocab: {e}", file=sys.stderr)
            return 2

    edges = []
    for md in root.rglob("*.md"):
        edges.extend(edges_from_file(md))

    if vocab is not None:
        edges = [e for e in edges if e[1] in vocab]

    for s, v, t in sorted(set(edges)):
        print(json.dumps({"source": s, "verb": v, "target": t}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
