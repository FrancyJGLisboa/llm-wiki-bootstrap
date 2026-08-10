#!/usr/bin/env python3
"""scripts/stage-corpus.py — stage a harvested archive into raw/, with no LLM.

CORPUS-AGNOSTIC. Everything this needs to know about a particular source lives
in corpus.json; this file contains only the logic, which is the same for every
document corpus. It replaces the GAIN-specific stage-gain.py, and the reason it
could is worth recording: an audit of that file found every corpus-specific line
was a field NAME or a format STRING. Not one was corpus-specific LOGIC. So the
names moved to configuration and the logic stayed here.

The practical consequence is the point of the exercise: pointing a context
compiler at a new source costs a fetch client and a corpus.json, not a second
copy of this file that will drift from the first.

For plain-markdown sources `/ctx-extract` is pure passthrough (AGENTS.md), so
driving an LLM turn per file buys nothing but latency and spend. At 2,413 sources
that is the difference between a deterministic minute and days of metered
inference before the real ingest starts.

WHAT IT ADDS over a plain copy:

  1. The compiler's raw frontmatter spec, mapped from the source's own. The
     mapping that matters is the TIME AXES — `time.valid` -> asserted_at (what
     the document speaks for) and `time.transaction` -> fetched_at (when it was
     pulled). Conflating them is exactly what wiki-lint-asserted-at.sh catches,
     and it is silent when it goes wrong: every point-in-time question resolves
     against the acquisition date and answers confidently.

  2. A metadata section, so `asserted_at_source` has a short stable anchor that
     resolves. Its first row carries the valid-time date, because the audit
     resolves the anchor and then requires the date to be IN that passage.

  3. Section trees for long sources, via the deterministic segmenter.

IDEMPOTENCE is what makes this the steady-state sync tool. Re-running is a no-op
on everything already staged, and it NEVER touches a source the compiler has
already ingested — see stage_one(). That rule was learned the hard way: an
earlier version re-rendered committed files and, because its flat frontmatter
reader cannot represent a block-style YAML list, silently emptied
`ingested_pages` on 261 of them.

READ-ONLY on the archive. The harvester owns those files and
scripts/gate-archive-immutable.sh keeps them append-only.

Usage:
  scripts/stage-corpus.py <archive-dir> <raw-dir> [--config corpus.json]
                          [--dry-run] [--limit N] [--no-segment] [--quiet]

Exit: 0 = staged (or nothing to do) · 1 = one or more files failed · 2 = usage.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "lib"))
from wikitext import parse_frontmatter  # noqa: E402

SEGMENTER = os.path.join(_HERE, "extract", "segment-doc.py")

# The three ingest-commitment fields /ctx-compile owns. Never invented here.
COMMITMENT_KEYS = ("ingested_hash", "ingested_at", "ingested_pages")

ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
HEADING_RE = re.compile(r"^#{1,6}\s+")


def die(msg: str, code: int = 2):
    print(f"stage-corpus: {msg}", file=sys.stderr)
    raise SystemExit(code)


def load_config(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as fh:
            cfg = json.load(fh)
    except OSError as e:
        die(f"cannot read {path}: {e}")
    except json.JSONDecodeError as e:
        die(f"{path} is not valid JSON: {e}")

    # Fail loudly on an incomplete declaration. A stager that quietly defaults a
    # missing time axis would produce a corpus whose dates are all wrong and all
    # plausible — the failure this whole layer exists to prevent.
    for key in ("name", "source_type", "id_field", "slug", "time"):
        if not cfg.get(key):
            die(f"{path}: missing required key '{key}'")
    if "valid" not in cfg["time"] or "transaction" not in cfg["time"]:
        die(f"{path}: time needs both 'valid' and 'transaction' "
            f"(use null for valid if the corpus genuinely has no document date)")
    return cfg


def slugify(text: str) -> str:
    """GitHub-style heading slug — the same rule citation-audit.py applies.

    Must agree with it exactly: this produces the anchor, that resolves it.
    """
    text = text.strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    return re.sub(r"-+", "-", text).strip("-")


def unquote(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v


def yaml_quote(v: str) -> str:
    """Double-quote a scalar, escaping what would break the block.

    Titles carry colons, which would otherwise parse as a nested mapping and
    silently truncate the value.
    """
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


def body_of(text: str) -> str:
    lines = text.splitlines()
    if lines[:1] != ["---"]:
        return text
    try:
        close = lines.index("---", 1)
    except ValueError:
        return text
    return "\n".join(lines[close + 1:]).lstrip("\n")


def segment(path: str) -> tuple[str | None, int]:
    """Deterministic section tree; degrades to (None, 0) rather than raising."""
    try:
        out = subprocess.run([sys.executable, SEGMENTER, path],
                             capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return None, 0
    if out.returncode != 0 or not out.stdout.strip():
        return None, 0
    return out.stdout, sum(1 for ln in out.stdout.splitlines()
                           if HEADING_RE.match(ln))


def resolve(field: str, fm: dict, cfg: dict, capture: str) -> str:
    """Resolve a metadata-row field reference: @-computed, or a source key."""
    if field == "@valid":
        return fm.get(cfg["time"]["valid"] or "", "")
    if field == "@transaction":
        return fm.get(cfg["time"]["transaction"], "")
    if field == "@author_capture":
        return capture
    return fm.get(field, "")


def build_metadata_section(fm: dict, cfg: dict, capture: str) -> str:
    sec = cfg.get("metadata_section") or {}
    heading = sec.get("heading", "Source metadata")
    rows = [f"## {heading}", ""]
    for row in sec.get("rows", []):
        val = resolve(row["field"], fm, cfg, capture)
        if val:
            rows.append(f"**{row['label']}:** {val}")
    rows.append("")
    return "\n".join(rows)


def render(fm: dict, cfg: dict, capture: str, body: str,
           segmented: bool, segments: int, commitments: dict) -> str:
    valid_key = cfg["time"]["valid"]
    title = fm.get(cfg.get("title_field", "title")) or fm.get(cfg["id_field"], cfg["name"])
    method = "passthrough+segment-doc" if segmented else "passthrough"

    author_cfg = cfg.get("author") or {}
    if capture and author_cfg.get("template"):
        author = author_cfg["template"].replace("{capture}", capture).strip()
    else:
        author = author_cfg.get("fallback", "")

    out = [
        "---",
        f"source_url: {fm.get(cfg.get('url_field', 'source_url'), 'n/a')}",
        f"source_type: {cfg['source_type']}",
        f"source_title: {yaml_quote(title)}",
        f"source_author: {yaml_quote(author)}",
        # Transaction time: when this was acquired.
        f"fetched_at: {fm['@fetched_at']}",
    ]
    # Valid time: what the document speaks for. `unknown` is a first-class
    # answer — a corpus with no document date must say so, not fabricate one.
    if valid_key and fm.get(valid_key):
        anchor = slugify((cfg.get("metadata_section") or {}).get("heading", "Source metadata"))
        out.append(f"asserted_at: {fm[valid_key]}")
        out.append(f'asserted_at_source: "#{anchor}"')
    else:
        out.append("asserted_at: unknown")
        out.append(f'asserted_at_note: "{cfg["name"]} sources carry no document '
                   f'date; only the acquisition time is known"')
    out += [
        f"ingested_hash: {commitments.get('ingested_hash', '\"\"')}",
        f"ingested_at: {commitments.get('ingested_at', 'never')}",
        f"ingested_pages: {commitments.get('ingested_pages', '[]')}",
        f"extraction_method: {method}",
    ]
    for k in cfg.get("passthrough", []):
        if fm.get(k):
            out.append(f"{k}: {yaml_quote(fm[k])}")
    if segmented:
        out.append("segmented: true")
        out.append(f"segments: {segments}")
    out.append("---")

    return "\n".join(out) + "\n\n" + body.rstrip("\n") + "\n"


def is_committed(path: str) -> bool:
    """True once /ctx-compile has ingested this staged source."""
    if not os.path.exists(path):
        return False
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            fm = parse_frontmatter(fh.read().splitlines())
    except OSError:
        return False
    return bool(unquote(fm.get("ingested_hash", "")).strip())


def read_commitments(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            fm = parse_frontmatter(fh.read().splitlines())
    except OSError:
        return {}
    return {k: fm[k] for k in COMMITMENT_KEYS if k in fm}


def stage_one(src: str, raw_dir: str, cfg: dict, allow_segment: bool):
    try:
        with open(src, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError as e:
        return "failed", f"unreadable: {e}"

    fm = {k: unquote(v) for k, v in parse_frontmatter(text.splitlines()).items()}
    if fm.get("source") and fm["source"] != cfg["name"]:
        return "skipped", f"not a {cfg['name']} source"

    ident = fm.get(cfg["id_field"], "")
    if not ident:
        return "failed", f"no {cfg['id_field']}"

    valid_key = cfg["time"]["valid"]
    valid = fm.get(valid_key, "") if valid_key else ""
    if valid_key and not ISO_DATE_RE.match(valid):
        return "failed", f"{valid_key} {valid!r} is not YYYY-MM-DD"

    trans = fm.get(cfg["time"]["transaction"], "")
    # fetched_at is a DATE in the raw spec; the source may carry a timestamp.
    fm["@fetched_at"] = (trans.split("T", 1)[0] if trans else valid) or "unknown"

    slug = (cfg["slug"]
            .replace("{valid}", valid)
            .replace("{id}", re.sub(r"[^a-z0-9]+", "-", ident.lower()).strip("-")))
    target = os.path.join(raw_dir, slug + ".md")

    # HANDS OFF A COMMITTED SOURCE. Once /ctx-compile has ingested a file its
    # frontmatter belongs to the compiler, including whatever shape it chose.
    # Re-rendering can only do harm: at best a no-op, at worst it flattens a
    # value this module's flat frontmatter reader cannot represent — which is
    # how 261 files lost their ingested_pages.
    if is_committed(target):
        return "skipped", "already ingested"

    original_body = body_of(text)
    capture = ""
    pat = (cfg.get("author") or {}).get("from_body")
    if pat:
        m = re.search(pat, original_body, re.MULTILINE)
        if m:
            capture = m.group(1).strip()

    segmented, segments = False, 0
    body = original_body
    threshold = cfg.get("segment_word_threshold", 6000)
    if allow_segment and threshold and len(original_body.split()) >= threshold:
        seg, n = segment(src)
        if seg is not None:
            body, segmented, segments = seg, True, n

    meta = build_metadata_section(fm, cfg, capture)
    title_line = f"# {fm.get(cfg.get('title_field', 'title'), ident)}"
    # Drop the source's own leading H1: it is replaced by title_line, and two
    # H1s give the file two heading slugs competing for the same anchor.
    body_lines = body.lstrip("\n").splitlines()
    if body_lines and body_lines[0].startswith("# "):
        body_lines = body_lines[1:]
    body = "\n".join(body_lines).lstrip("\n")

    rendered = render(fm, cfg, capture, f"{title_line}\n\n{meta}\n{body}",
                      segmented, segments, read_commitments(target))

    existed = os.path.exists(target)
    if existed:
        try:
            with open(target, encoding="utf-8", errors="replace") as fh:
                if fh.read() == rendered:
                    return "skipped", "unchanged"
        except OSError:
            pass

    try:
        with open(target, "w", encoding="utf-8") as fh:
            fh.write(rendered)
    except OSError as e:
        return "failed", f"write failed: {e}"
    return ("updated" if existed else "staged"), os.path.basename(target)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="stage-corpus.py")
    ap.add_argument("archive", help="harvested archive directory (read-only)")
    ap.add_argument("raw", help="destination raw/ directory")
    ap.add_argument("--config", default="corpus.json")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--no-segment", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args(argv[1:])

    cfg = load_config(a.config)
    if not os.path.isdir(a.archive):
        die(f"not a directory: {a.archive}")
    if not a.dry_run and not os.path.isdir(a.raw):
        die(f"not a directory: {a.raw}")
    if not os.path.exists(SEGMENTER) and not a.no_segment:
        die(f"missing segmenter: {SEGMENTER}")

    sources = []
    for dirpath, _d, filenames in os.walk(a.archive):
        sources += [os.path.join(dirpath, f) for f in filenames if f.endswith(".md")]
    # Newest first: an interrupted backlog leaves the most relevant end done.
    sources.sort(reverse=True)
    if a.limit:
        sources = sources[:a.limit]
    if not sources:
        print(f"stage-corpus: no .md sources under {a.archive}")
        return 0

    tally = {"staged": 0, "updated": 0, "skipped": 0, "failed": 0}
    failures = []
    for src in sources:
        if a.dry_run:
            tally["staged"] += 1
            continue
        status, detail = stage_one(src, a.raw, cfg, not a.no_segment)
        tally[status] += 1
        if status == "failed":
            failures.append(f"{os.path.basename(src)}: {detail}")
        elif not a.quiet and status in ("staged", "updated"):
            print(f"  {status}: {detail}")

    verb = "would stage" if a.dry_run else "staged"
    print(f"stage-corpus[{cfg['name']}]: {verb} {tally['staged']}, "
          f"updated {tally['updated']}, skipped {tally['skipped']}, "
          f"failed {tally['failed']} (of {len(sources)} source files)")
    for f in failures[:20]:
        print(f"  FAILED {f}", file=sys.stderr)
    return 1 if tally["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
