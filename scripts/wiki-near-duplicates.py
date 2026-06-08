#!/usr/bin/env python3
"""scripts/wiki-near-duplicates.py — surface near-duplicate wiki pages.

Defends the self-updating brain's *novelty* gate downstream. `/wiki-learn`'s gate
checks novelty by grepping existing pages, so two sessions that state the same
fact in different words both pass — and nothing dedups equivalent facts (body-hash
only dedups identical raw bodies). Over many sessions the brain bloats with
semantic duplicates. This surfaces them for review during a `/wiki-lint` pass,
the same way contradictions are surfaced — it never auto-merges.

Two signals (stdlib only, no embeddings — deliberately simple and explainable;
the threshold is a heuristic, tune with --threshold):
  1. Lexical: Jaccard overlap of content-word sets >= --threshold.
  2. Structural: two pages whose `[[link]]` set (>=2 links) AND number set are
     identical — a strong "same claim, reworded" signal even at lower lexical overlap.

Usage:
  scripts/wiki-near-duplicates.py <wiki-dir> [--threshold 0.5] [--min-words 15]

Output: one line per flagged pair (sorted by score desc). Exit 0 always — this is
advisory (surface, do not block).
"""
import argparse
import re
import sys
from itertools import combinations
from pathlib import Path

LINK_RE = re.compile(r"\[\[([a-z][a-z0-9-]*)\]\]")
NUM_RE = re.compile(r"\d+(?:\.\d+)?")
WORD_RE = re.compile(r"[a-z0-9]+")
STOPWORDS = {
    "the", "a", "an", "is", "are", "was", "were", "be", "been", "being", "of",
    "to", "in", "on", "at", "by", "for", "with", "and", "or", "but", "if", "as",
    "that", "this", "these", "those", "it", "its", "from", "into", "than", "then",
    "so", "such", "not", "no", "can", "will", "would", "which", "who", "what",
    "when", "where", "how", "page", "related", "definition", "body", "tldr",
}


def body_of(text):
    """Strip YAML frontmatter (leading --- … ---) and the Related/Open-questions
    scaffolding, leaving the substantive prose + links."""
    lines = text.splitlines()
    if lines[:1] == ["---"]:
        try:
            close = lines.index("---", 1)
            lines = lines[close + 1:]
        except ValueError:
            pass
    return "\n".join(lines)


def words(text):
    return [w for w in WORD_RE.findall(text.lower()) if w not in STOPWORDS and len(w) > 1]


def jaccard(a, b):
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def main():
    ap = argparse.ArgumentParser(description="Surface near-duplicate wiki pages.")
    ap.add_argument("wiki_dir")
    ap.add_argument("--threshold", type=float, default=0.5,
                    help="lexical Jaccard threshold to flag a pair (default 0.5)")
    ap.add_argument("--min-words", type=int, default=15,
                    help="skip pages with fewer content words (default 15)")
    args = ap.parse_args()

    root = Path(args.wiki_dir)
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 2

    pages = {}
    for md in sorted(root.rglob("*.md")):
        if md.name == "index.md":   # navigation hub — links everything by design
            continue
        text = md.read_text(encoding="utf-8", errors="replace")
        body = body_of(text)
        wset = set(words(body))
        if len(wset) < args.min_words:
            continue
        rel = str(md.relative_to(root))
        pages[rel] = {
            "words": wset,
            "links": set(LINK_RE.findall(text)),
            "nums": set(NUM_RE.findall(body)),
        }

    findings = []
    for (pa, a), (pb, b) in combinations(pages.items(), 2):
        score = jaccard(a["words"], b["words"])
        structural = (
            len(a["links"]) >= 2 and a["links"] == b["links"] and a["nums"] == b["nums"]
        )
        if score >= args.threshold or structural:
            why = []
            if score >= args.threshold:
                why.append(f"lexical {score:.2f}")
            if structural:
                why.append("identical links+numbers")
            findings.append((score, pa, pb, ", ".join(why)))

    findings.sort(key=lambda f: -f[0])
    for score, pa, pb, why in findings:
        print(f"near-duplicate: {pa} <-> {pb} ({why})")
    if not findings:
        print(f"near-duplicate: none above threshold {args.threshold} in {root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
