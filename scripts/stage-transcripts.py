#!/usr/bin/env python3
"""scripts/stage-transcripts.py — stage a YouTube-transcript folder into raw/ with no LLM.

RENAMED from stage-corpus.py on 2026-08-10. The old name claimed a generality
this script never had — it is specific to transcripts, from the `## Source
metadata` section it synthesizes down to the padded/unpadded timestamp headings
it emits. scripts/stage-corpus.py is now the corpus-agnostic stager, driven by a
corpus.json declaration, and the two would have collided under one name with the
specific one winning.

For plain-markdown sources `/ctx-extract` is pure passthrough (AGENTS.md), so
driving an LLM turn per file buys nothing but latency and spend. This does the
same work deterministically, and adds the two things a transcript needs before
it can be cited:

  1. `## Source metadata` — a heading whose section contains the `**Uploaded:**`
     date, so `asserted_at` has a resolving `asserted_at_source` anchor. Without
     valid time an as-of question has nothing to resolve against.
  2. `## (M:SS)` section headings mirroring each inline `**[MM:SS]**` marker.

(2) exists because timestamp-anchor resolution is padding-sensitive:
citation-audit.py matches the anchor as a whole token bounded by
`(?<![\\d:])...(?![\\d:])`, so against a body that writes `[04:41]` the anchor
`#04:41` resolves and `#4:41` does NOT — while the meta-wiki's own convention is
the unpadded `#0:51`. An author following house style would silently break every
citation into a sub-10-minute timestamp. Emitting the heading UNPADDED alongside
the padded inline marker makes both forms resolve, so the measurement reflects
retrieval quality rather than a formatting accident. The heading also gives
citation-audit's HEADING_RE branch a tight, semantically-bounded passage
(heading → next heading) instead of a fixed 8-line window.

Sampling is seeded and stratified by upload year-quarter, so a run is
reproducible from the manifest: same seed + same source dir => same files.

Usage:
  scripts/stage-corpus.py <src-dir> <wiki-root> [--n N | --all] [--seed S]
                          [--reserved-months K] [--manifest FILE] [--dry-run]

Exit: 0 staged (or dry-run), 2 usage/setup error.
"""

import argparse
import hashlib
import os
import random
import re
import sys

FIELD_RE = re.compile(r"^- \*\*(?P<key>[A-Za-z]+):\*\*\s*(?P<val>.*?)\s*$")
TS_LINE_RE = re.compile(r"^\*\*\[(?P<h>\d{1,2}):(?P<m>\d{2})\]\(")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
VIDEO_ID_RE = re.compile(r"\[([A-Za-z0-9_-]{6,})\]\s*$")


def slugify(text):
    text = text.strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    return re.sub(r"-+", "-", text).strip("-")


def parse_transcript(path):
    """Pull the header fields and body out of one yt2md markdown file."""
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")

    title = ""
    fields = {}
    for i, line in enumerate(lines):
        if not title and line.startswith("# "):
            title = line[2:].strip()
        m = FIELD_RE.match(line)
        if m:
            fields[m.group("key")] = m.group("val")
        if line.strip() == "## Transcript":
            return title, fields, lines[i + 1:]
    return title, fields, []


def restage_body(body_lines):
    """Mirror each inline **[MM:SS]** marker with an unpadded `## (M:SS)` heading."""
    out = []
    for line in body_lines:
        m = TS_LINE_RE.match(line)
        if m:
            unpadded = "%d:%s" % (int(m.group("h")), m.group("m"))
            if out and out[-1].strip():
                out.append("")
            out.append("## (%s)" % unpadded)
            out.append("")
        out.append(line)
    return out


def yaml_quote(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def build_source(title, fields, body_lines, fetched_at):
    uploaded = fields.get("Uploaded", "")
    url = fields.get("Video", "").strip("<>")
    channel = fields.get("Channel", "")
    channel_name = channel.split("](")[0].lstrip("[") if "](" in channel else channel

    if DATE_RE.match(uploaded):
        asserted = "asserted_at: %s\nasserted_at_source: #source-metadata" % uploaded
    else:
        asserted = (
            "asserted_at: unknown\n"
            "asserted_at_note: source carries no parseable Uploaded date"
        )

    head = [
        "---",
        "source_url: %s" % (url or "n/a"),
        "source_type: video-transcript",
        "source_title: %s" % yaml_quote(title),
        "source_author: %s" % yaml_quote(channel_name),
        "fetched_at: %s" % fetched_at,
        asserted,
        'ingested_hash: ""',
        "ingested_at: never",
        "extraction_method: passthrough",
        "---",
        "",
        "# %s" % title,
        "",
        "## Source metadata",
        "",
    ]
    for key in ("Video", "Channel", "Uploaded", "Duration", "Captions"):
        if key in fields:
            head.append("- **%s:** %s" % (key, fields[key]))
    head += ["", "## Transcript", ""]
    return "\n".join(head + restage_body(body_lines)).rstrip("\n") + "\n"


def stable_name(path, title, uploaded):
    m = VIDEO_ID_RE.search(os.path.splitext(os.path.basename(path))[0])
    vid = m.group(1) if m else hashlib.sha256(path.encode()).hexdigest()[:11]
    stem = slugify(title)[:60].strip("-") or "untitled"
    date = uploaded if DATE_RE.match(uploaded) else "0000-00-00"
    return "%s-%s-%s.md" % (date, stem, vid.lower())


def quarter(uploaded):
    if not DATE_RE.match(uploaded):
        return "unknown"
    year, month = uploaded[:4], int(uploaded[5:7])
    return "%s-Q%d" % (year, (month - 1) // 3 + 1)


def collect(src_dir):
    """Every transcript in src_dir, sorted deterministically."""
    found = []
    for entry in sorted(os.listdir(src_dir)):
        if not entry.endswith(".md"):
            continue
        path = os.path.join(src_dir, entry)
        if not os.path.isfile(path):
            continue
        title, fields, body = parse_transcript(path)
        if not body:
            continue
        found.append(
            {
                "path": path,
                "title": title,
                "fields": fields,
                "body": body,
                "uploaded": fields.get("Uploaded", ""),
                "quarter": quarter(fields.get("Uploaded", "")),
            }
        )
    found.sort(key=lambda s: (s["uploaded"], s["path"]))
    return found


def stratified_sample(sources, n, seed):
    """Round-robin across year-quarters so the full time span is covered."""
    if n >= len(sources):
        return list(sources)
    buckets = {}
    for src in sources:
        buckets.setdefault(src["quarter"], []).append(src)

    rng = random.Random(seed)
    for key in buckets:
        rng.shuffle(buckets[key])

    picked, keys = [], sorted(buckets)
    while len(picked) < n:
        progressed = False
        for key in keys:
            if buckets[key] and len(picked) < n:
                picked.append(buckets[key].pop())
                progressed = True
        if not progressed:
            break
    picked.sort(key=lambda s: (s["uploaded"], s["path"]))
    return picked


def pick_reserved(picked, frac, seed):
    """A seeded fraction of the SAMPLE held back for the sealed holdout set.

    Reserving whole upload-months reads better but does not survive a sparse
    stratified sample: at n=50 over ~24 quarters, three whole months caught 2
    files — too thin to author a holdout from. Reserving a fraction of the
    sampled files keeps the slice disjoint from the gold set (which is all the
    holdout needs) and scales with n instead of against it.
    """
    if frac <= 0 or not picked:
        return set()
    k = max(1, int(round(len(picked) * frac)))
    return set(random.Random(seed + 1).sample([s["path"] for s in picked], min(k, len(picked))))


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("src_dir")
    ap.add_argument("wiki_root")
    ap.add_argument("--n", type=int, default=150)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--seed", type=int, default=20260730)
    ap.add_argument("--reserved-frac", type=float, default=0.2)
    ap.add_argument("--manifest")
    ap.add_argument("--fetched-at", default="2026-07-30")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not os.path.isdir(args.src_dir):
        print("error: no such directory: %s" % args.src_dir, file=sys.stderr)
        return 2

    sources = collect(args.src_dir)
    if not sources:
        print("error: no transcripts found in %s" % args.src_dir, file=sys.stderr)
        return 2

    picked = sources if args.all else stratified_sample(sources, args.n, args.seed)
    reserved = pick_reserved(picked, args.reserved_frac, args.seed)

    raw_dir = os.path.join(args.wiki_root, "raw")
    if not args.dry_run:
        os.makedirs(raw_dir, exist_ok=True)

    rows = []
    for src in picked:
        name = stable_name(src["path"], src["title"], src["uploaded"])
        text = build_source(src["title"], src["fields"], src["body"], args.fetched_at)
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if not args.dry_run:
            with open(os.path.join(raw_dir, name), "w", encoding="utf-8") as fh:
                fh.write(text)
        rows.append(
            (
                name,
                src["uploaded"],
                src["quarter"],
                "reserved" if src["path"] in reserved else "main",
                digest,
                os.path.basename(src["path"]),
            )
        )

    header = "# staged: %d of %d source(s)  seed=%d  reserved-frac=%s\n" % (
        len(rows),
        len(sources),
        args.seed,
        args.reserved_frac,
    )
    body = "".join("\t".join(r) + "\n" for r in rows)
    if args.manifest and not args.dry_run:
        os.makedirs(os.path.dirname(os.path.abspath(args.manifest)), exist_ok=True)
        with open(args.manifest, "w", encoding="utf-8") as fh:
            fh.write("# name\tuploaded\tquarter\tslice\tsha256\tsrc_basename\n")
            fh.write(header)
            fh.write(body)

    sys.stdout.write(header)
    n_reserved = sum(1 for r in rows if r[3] == "reserved")
    print("quarters covered: %d" % len({r[2] for r in rows}))
    print("reserved slice:   %d file(s) sealed for the holdout" % n_reserved)
    print("manifest sha256:  %s" % hashlib.sha256((header + body).encode()).hexdigest())
    return 0


if __name__ == "__main__":
    sys.exit(main())
