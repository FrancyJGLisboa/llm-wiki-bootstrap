#!/usr/bin/env python3
"""scripts/corpus-health.py — the A3/A4 measurements, deterministic and no LLM.

Reports the numbers the assessment's synthesis and faithfulness checks need, in
one re-runnable block, so a published figure can be recomputed rather than
taken on trust:

  compression   wiki body words as a share of ingested raw words. A wiki that
                merely transcribes its sources is not a wiki.
  claim density cited claims per claim-bearing page. This is the anti-hedge
                floor: a wiki with no figures, dates or names is trivially
                faithful because nothing in it can be contradicted, so a
                faithfulness RATE alone can be satisfied by saying nothing.
  orphans       pages with no inbound [[link]]. In a vectorless system the link
                graph IS the recall mechanism, so an orphan is unreachable
                except by exact-name grep.
  thin pages    content pages with <2 outbound ## Related links.
  max degree /  the star-topology guard. "Every page has >=2 links" is trivially
  diameter      satisfied by one hub linking everything, which encodes no
                structure; a hub of degree ~N with diameter 2 is that failure,
                visible on its face.

Usage:
  scripts/corpus-health.py <wiki-root> [--json]
    <wiki-root> holds wiki/ and raw/.

Exit: 0 always (the deliverable is the measurement), 2 on setup error.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from collections import defaultdict, deque

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
from wikitext import WIKILINK_RE, parse_frontmatter  # noqa: E402

CITATION_RE = re.compile(r"\(source:\s*raw/([^)#\s]+)(?:#([^)\s]+))?\)")
EXEMPT_TYPES = {"navigation", "journal"}


def body_of(lines):
    if lines[:1] != ["---"]:
        return lines
    try:
        return lines[lines.index("---", 1) + 1:]
    except ValueError:
        return lines


def related_links(lines):
    """Links under ## Related only — the traversal surface."""
    out, inside = [], False
    for line in lines:
        if re.match(r"^##\s+Related\s*$", line):
            inside = True
            continue
        if inside and line.startswith("#"):
            break
        if inside:
            out.extend(WIKILINK_RE.findall(line))
    return out


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("wiki_root")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    wiki_dir = os.path.join(args.wiki_root, "wiki")
    raw_dir = os.path.join(args.wiki_root, "raw")
    if not os.path.isdir(wiki_dir) or not os.path.isdir(raw_dir):
        print("error: %s must contain wiki/ and raw/" % args.wiki_root, file=sys.stderr)
        return 2

    # ── raw side: only sources actually ingested count toward compression ──
    raw_words = 0
    raw_total = raw_ingested = 0
    for name in sorted(os.listdir(raw_dir)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(raw_dir, name)
        lines = open(path, encoding="utf-8").read().split("\n")
        fm = parse_frontmatter(lines)
        raw_total += 1
        if (fm.get("ingested_hash") or "").strip('"'):
            raw_ingested += 1
            raw_words += len(" ".join(body_of(lines)).split())

    # ── wiki side ──
    wiki_words = 0
    pages, content_pages = [], []
    cites_per_page = {}
    outbound, inbound = {}, defaultdict(set)
    thin = []

    for root, _dirs, files in os.walk(wiki_dir):
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            slug = os.path.splitext(os.path.relpath(path, wiki_dir))[0]
            lines = open(path, encoding="utf-8").read().split("\n")
            fm = parse_frontmatter(lines)
            body = body_of(lines)
            wiki_words += len(" ".join(body).split())
            pages.append(slug)

            ptype = (fm.get("type") or "").strip()
            exempt = ptype in EXEMPT_TYPES or (fm.get("provenance") or "").strip() == "none"

            links = related_links(body)
            outbound[slug] = set(links)
            for tgt in links:
                inbound[tgt].add(slug)
            # Links anywhere in the body still make a page reachable.
            for tgt in WIKILINK_RE.findall("\n".join(body)):
                inbound[tgt].add(slug)

            if not exempt:
                content_pages.append(slug)
                cites_per_page[slug] = len(CITATION_RE.findall("\n".join(body)))
                if len(set(links)) < 2:
                    thin.append(slug)

    orphans = sorted(p for p in content_pages if not (inbound.get(p) - {p}))

    # ── verbatim overlap: the direct transcription test ──
    # Size ratio alone is a weak proxy. The shipped meta-wiki sits at ~372% of
    # its raw words because it legitimately EXPANDS six tiny sources with
    # synthesis, so a flat size threshold would score good work as failure and
    # copying-but-shorter as success. Shingle overlap measures the actual
    # failure: how much of the wiki is lifted verbatim from the transcripts.
    def shingles(text, n=12):
        words = re.sub(r"[^a-z0-9 ]", " ", text.lower()).split()
        return {" ".join(words[i:i + n]) for i in range(max(0, len(words) - n + 1))}

    raw_shingles = set()
    for name in sorted(os.listdir(raw_dir)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(raw_dir, name)
        lines = open(path, encoding="utf-8").read().split("\n")
        if (parse_frontmatter(lines).get("ingested_hash") or "").strip('"'):
            raw_shingles |= shingles(" ".join(body_of(lines)))

    lifted = considered = 0
    worst = []
    for root, _dirs, files in os.walk(wiki_dir):
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            lines = open(path, encoding="utf-8").read().split("\n")
            body = "\n".join(body_of(lines))
            body = CITATION_RE.sub(" ", body)
            sh = shingles(body)
            if not sh:
                continue
            hit = len(sh & raw_shingles)
            lifted += hit
            considered += len(sh)
            if raw_shingles:
                worst.append((round(100.0 * hit / len(sh), 1),
                              os.path.splitext(os.path.relpath(path, wiki_dir))[0]))
    verbatim_pct = round(100.0 * lifted / considered, 1) if considered else None
    worst.sort(reverse=True)

    # ── graph shape ──
    adj = defaultdict(set)
    for src, tgts in outbound.items():
        for tgt in tgts:
            adj[src].add(tgt)
            adj[tgt].add(src)
    degrees = {p: len(adj.get(p, ())) for p in pages}
    max_deg_page = max(degrees, key=lambda p: degrees[p]) if degrees else None
    max_deg = degrees.get(max_deg_page, 0)

    def eccentricity(start):
        seen = {start}
        q = deque([(start, 0)])
        far = 0
        while q:
            node, d = q.popleft()
            far = max(far, d)
            for nxt in sorted(adj.get(node, ())):
                if nxt not in seen:
                    seen.add(nxt)
                    q.append((nxt, d + 1))
        return far

    diameter = max((eccentricity(p) for p in pages), default=0)

    n_content = len(content_pages) or 1
    cited_pages = sum(1 for v in cites_per_page.values() if v > 0)
    total_cites = sum(cites_per_page.values())

    out = {
        "raw_sources_total": raw_total,
        "raw_sources_ingested": raw_ingested,
        "raw_words_ingested": raw_words,
        "wiki_pages": len(pages),
        "wiki_content_pages": len(content_pages),
        "wiki_words": wiki_words,
        "compression_pct": round(100.0 * wiki_words / raw_words, 1) if raw_words else None,
        "verbatim_overlap_pct": verbatim_pct,
        "most_verbatim_pages": worst[:5],
        "total_citations": total_cites,
        "claim_density": round(total_cites / n_content, 2),
        "pages_with_no_citation": len(content_pages) - cited_pages,
        "orphans": len(orphans),
        "orphan_pct": round(100.0 * len(orphans) / n_content, 1),
        "orphan_pages": orphans[:20],
        "thin_pages_lt2_related": len(thin),
        "thin_page_list": sorted(thin)[:20],
        "max_degree": max_deg,
        "max_degree_page": max_deg_page,
        "max_degree_share_pct": round(100.0 * max_deg / max(1, len(pages) - 1), 1),
        "graph_diameter": diameter,
    }

    if args.json:
        print(json.dumps(out, indent=2, sort_keys=True))
        return 0

    print("# corpus health — %s" % args.wiki_root)
    print()
    print("raw sources:        %d ingested of %d staged" % (raw_ingested, raw_total))
    print("raw words ingested: %d" % raw_words)
    print("wiki pages:         %d (%d claim-bearing)" % (len(pages), len(content_pages)))
    print("wiki words:         %d" % wiki_words)
    print("size ratio:         %s%% of ingested raw words   (directional only)"
          % out["compression_pct"])
    print("verbatim overlap:   %s%% of wiki 12-grams appear in raw   (A4 transcription test)"
          % out["verbatim_overlap_pct"])
    if worst:
        print("  most verbatim:    %s" % ", ".join("%s %s%%" % (p, v) for v, p in worst[:3]))
    print()
    print("citations:          %d total, %.2f per claim-bearing page   (A3 density floor)"
          % (total_cites, out["claim_density"]))
    print("uncited pages:      %d   (A3 coverage: target 0)" % out["pages_with_no_citation"])
    print()
    print("orphans:            %d (%.1f%%)   (A4 target <=5%%)" % (len(orphans), out["orphan_pct"]))
    print("thin (<2 related):  %d   (A4 target 0)" % len(thin))
    print("max degree:         %d on '%s' = %.1f%% of all pages   (star-topology guard)"
          % (max_deg, max_deg_page, out["max_degree_share_pct"]))
    print("graph diameter:     %d   (a hub-and-spoke wiki reads 2)" % diameter)
    if orphans:
        print()
        print("orphan pages: %s" % ", ".join(orphans[:20]))
    if thin:
        print("thin pages:   %s" % ", ".join(sorted(thin)[:20]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
