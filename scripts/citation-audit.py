#!/usr/bin/env python3
"""scripts/citation-audit.py — deterministic citation-faithfulness floor (C1+C2).

Audits every `(source: raw/<file>#<anchor>)` citation in a wiki directory:

  C1  file resolves   — raw/<file> exists
  C2  anchor resolves — <anchor> is locatable in that raw, by anchor type:
                          #heading-slug      → a heading whose GitHub slug matches
                          #M:SS or #M:SS-M:SS → the start timestamp appears in raw
                          #L5 / #L5-L10      → the line range is within the file
                          (no anchor)        → whole-file citation, trivially resolves

It also extracts, for each citation that passes C1+C2, the **claim** (the wiki
sentence the citation is attached to) and the **evidence** (the raw passage the
anchor points at). Those pairs feed the C3 entailment judge in
`eval-citation-faithfulness.sh`; this module does the deterministic half and is
runnable / self-testable with no LLM.

Usage:
  scripts/citation-audit.py <wiki-dir> [--raw <raw-dir>] [--json|--tsv|--coverage]

  Default <raw-dir> is "<wiki-dir>/../raw".

Output:
  default   human report; exit 1 if any C1/C2 fails (the deterministic gate)
  --json    one JSON object per citation on stdout (for the harness); always exit 0
  --coverage  the inverse gate (vision check #5): list claim-bearing pages that
              carry NO resolving citation; exit 1 if any exist. A page is exempt
              when `type: navigation` (structural, points inward) or it declares
              `provenance: none` (an explicit "makes no external claims" knob).
  --tsv     one TSV row per citation for the shell harness (always exit 0):
             tag<TAB>page<TAB>line<TAB>file<TAB>anchor<TAB>c1<TAB>c2<TAB>claim_b64<TAB>evidence_b64
           claim/evidence are base64 (single-line, no tabs/newlines) — decode with
           `openssl base64 -d -A`. tag is OK when c1 ∧ c2, else BAD.

Exit codes:
  0  all citations resolve (or --json)
  1  at least one C1/C2 failure
  2  usage error
"""
import base64
import json
import os
import re
import sys

CITATION_RE = re.compile(r"\(source:\s*raw/([^)#\s]+)(?:#([^)\s]+))?\)")
HEADING_RE = re.compile(r"^#{1,6}\s+(.*?)\s*$")
TIMESTAMP_RE = re.compile(r"^\d{1,2}:\d{2}(?:-\d{1,2}:\d{2})?$")
LINERANGE_RE = re.compile(r"^L(\d+)(?:-L?(\d+))?$")
EVIDENCE_MAX_LINES = 40


def body_start(lines):
    """Index of the first body line: 0, or just past a closed leading --- block.

    An UNCLOSED leading `---` is treated as no frontmatter (body starts at 0) so
    a citation buried in a never-closed YAML-ish block still counts as body.
    """
    if lines[:1] != ["---"]:
        return 0
    try:
        return lines.index("---", 1) + 1
    except ValueError:
        return 0


def slugify(text):
    """GitHub-style heading slug: lowercase, drop punctuation, spaces -> hyphens."""
    text = text.strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)      # drop punctuation (keep word chars, space, hyphen)
    text = re.sub(r"[\s_]+", "-", text)        # whitespace/underscore -> hyphen
    text = re.sub(r"-+", "-", text).strip("-")
    return text


def raw_lines(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read().splitlines()


def resolve_anchor(anchor, lines):
    """Return (resolved: bool, evidence: str). evidence is '' when unresolved."""
    if anchor is None:
        # Whole-file citation: evidence is the body (after frontmatter), capped.
        body = lines
        if lines[:1] == ["---"]:
            try:
                close = lines.index("---", 1)
                body = lines[close + 1:]
            except ValueError:
                body = lines
        return True, "\n".join(body[:EVIDENCE_MAX_LINES]).strip()

    # Timestamp anchor (#M:SS or #M:SS-M:SS): start token must appear in the raw,
    # as a whole token — not a substring (#1:23 must not match '11:235', #2:00 must
    # not match '12:000'). Bound it with negative lookarounds for digit/colon.
    if TIMESTAMP_RE.match(anchor):
        start = anchor.split("-", 1)[0]
        start_re = re.compile(r"(?<![\d:])" + re.escape(start) + r"(?![\d:])")
        for i, line in enumerate(lines):
            if start_re.search(line):
                # If the timestamp lives in a section heading (the transcript's
                # convention), the passage is the WHOLE section (heading to next
                # heading) — not a fixed window, which can clip the cited claim.
                if HEADING_RE.match(line):
                    evidence = [line]
                    for nxt in lines[i + 1:]:
                        if HEADING_RE.match(nxt):
                            break
                        evidence.append(nxt)
                        if len(evidence) >= EVIDENCE_MAX_LINES:
                            break
                    return True, "\n".join(evidence).strip()
                return True, "\n".join(lines[i: i + 8]).strip()
        return False, ""

    # Line-range anchor (#L5 / #L5-L10): range within bounds and pointing at body,
    # not the leading --- frontmatter (a range entirely inside frontmatter cites
    # metadata, not content).
    m = LINERANGE_RE.match(anchor)
    if m:
        lo = int(m.group(1))
        hi = int(m.group(2)) if m.group(2) else lo
        if 1 <= lo <= hi <= len(lines) and hi > body_start(lines):
            return True, "\n".join(lines[lo - 1: hi]).strip()
        return False, ""

    # Heading-slug anchor: a heading slugifies to the anchor. If MORE THAN ONE
    # heading collides on the same slug (e.g. 'Results' and 'Results!!!'), the
    # anchor is ambiguous — fail C2 rather than silently feed the judge the first
    # match's passage.
    matches = [i for i, line in enumerate(lines)
               if (hm := HEADING_RE.match(line)) and slugify(hm.group(1)) == anchor]
    if len(matches) == 1:
        i = matches[0]
        evidence = [lines[i]]
        for nxt in lines[i + 1:]:
            if HEADING_RE.match(nxt):
                break
            evidence.append(nxt)
            if len(evidence) >= EVIDENCE_MAX_LINES:
                break
        return True, "\n".join(evidence).strip()
    return False, ""


FORMATTING_ONLY_RE = re.compile(r"^[\s>|*+\-`#.\d]*$")


def _clean_claim(text: str) -> str:
    """Strip the citation marker + markdown noise from a candidate claim line."""
    text = CITATION_RE.sub("", text)
    text = text.replace("``", "")            # empty inline-code artifacts
    text = text.strip()
    text = re.sub(r"^>+\s*", "", text)        # blockquote markers
    text = re.sub(r"^[-*+]\s+", "", text)     # unordered bullet
    text = re.sub(r"^\d+[.)]\s+", "", text)   # ordered list marker
    return re.sub(r"\s+", " ", text).strip(" .|")


def _alpha_len(s: str) -> int:
    return len(re.sub(r"[^A-Za-z]", "", s))


def extract_claim(lines: list[str], idx: int, match_start: int) -> str:
    """Best-effort prose claim a citation is attached to.

    Handles the layouts the wiki actually uses, so the C3 judge sees the real
    claim, not markdown scaffolding:
      - inline prose: citation at the end of a sentence on lines[idx].
      - table row:    ``| n | name | <prose> (source:...) |`` — use the cell that
                      holds the citation, not the whole pipe-delimited row.
      - own-line cite: a ``> (source:...)`` line under a blockquote — the claim
                       is the nearest preceding prose line.
    """
    line = lines[idx]
    if "|" in line:  # table row: isolate the cell containing the citation
        pos = 0
        for cell in line.split("|"):
            if pos <= match_start <= pos + len(cell) + 1:
                cell_claim = _clean_claim(cell)
                if _alpha_len(cell_claim) >= 12:
                    return cell_claim
                break
            pos += len(cell) + 1
    cleaned = _clean_claim(line)
    if _alpha_len(cleaned) >= 12:
        return cleaned
    # Formatting-only line (e.g. a blockquote citation on its own line): the
    # claim lives on the nearest preceding prose line.
    for j in range(idx - 1, max(-1, idx - 5), -1):
        if FORMATTING_ONLY_RE.match(lines[j]):
            continue
        prev = _clean_claim(lines[j])
        if _alpha_len(prev) >= 12:
            return prev
    return cleaned or line.strip()


def page_frontmatter(lines):
    """Parse the leading --- frontmatter block into a flat {key: value} dict."""
    if lines[:1] != ["---"]:
        return {}
    # No closing fence → not a real frontmatter block. Treat as {} (non-exempt)
    # so an author can't open `---` + `type: navigation` and never close it to
    # exempt a page from coverage.
    try:
        close = lines.index("---", 1)
    except ValueError:
        return {}
    fm = {}
    for line in lines[1:close]:
        m = re.match(r"([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            fm[m.group(1)] = m.group(2).strip()
    return fm


# A page need not cite raw when it makes no external claims: structural pages
# (indexes, dashboards, timelines) point inward, journal entries are user-owned
# free-form (per AGENTS.md), and any page may opt out explicitly with
# `provenance: none`. Everything else must carry provenance.
EXEMPT_TYPES = {"navigation", "journal"}


def page_is_exempt(fm):
    return fm.get("type") in EXEMPT_TYPES or fm.get("provenance") == "none"


def coverage(wiki_dir, raw_dir, records):
    """Vision check #5: pages that make claims but carry no resolving citation.

    Reuses `records` (every citation + its c1/c2 verdict) to find pages with at
    least one resolving citation; any non-exempt page NOT in that set is a gap.
    """
    # ponytail: a page is "covered" only if it carries at least one ANCHORED
    # resolving citation. An anchorless whole-file cite `(source: raw/x.md)`
    # resolves unconditionally (C1∧C2), so counting it would let a bare cite
    # exempt a page of fabrications — the anchor is what ties a claim to a
    # locatable passage. Anchorless cites stay resolving in the C1/C2 report
    # (they ARE valid file references); they just don't earn coverage on their own.
    # Ceiling: a page whose only honest source genuinely has no anchorable
    # structure (e.g. a one-line slide) must set `provenance: none` or cite with
    # a line range — coverage won't accept the bare file cite.
    ok_pages = {r["page"] for r in records if r["c1"] and r["c2"] and r["anchor"]}
    gaps = []
    for root, _dirs, files in os.walk(wiki_dir):
        for name in sorted(files):
            if not name.endswith(".md") or os.path.relpath(os.path.join(root, name), wiki_dir) in ok_pages:
                continue
            page = os.path.relpath(os.path.join(root, name), wiki_dir)
            if not page_is_exempt(page_frontmatter(raw_lines(os.path.join(root, name)))):
                gaps.append(page)
    return sorted(gaps)


def audit(wiki_dir, raw_dir):
    records = []
    for root, _dirs, files in os.walk(wiki_dir):
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            page = os.path.relpath(os.path.join(root, name), wiki_dir)
            lines = raw_lines(os.path.join(root, name))
            # Only body lines yield citation records — a `(source: ...)` placed
            # inside the leading --- frontmatter must NOT satisfy coverage while
            # the body stays uncited.
            start = body_start(lines)
            for idx, line in enumerate(lines):
                if idx < start:
                    continue
                for m in CITATION_RE.finditer(line):
                    rawfile, anchor = m.group(1), m.group(2)
                    # Skip documentation-of-the-syntax, not a real citation:
                    # placeholder files/anchors like raw/<file>#<anchor> or raw/...
                    if ("<" in rawfile or rawfile == "..." or rawfile.startswith("...")
                            or (anchor and ("<" in anchor or anchor == "..."))):
                        continue
                    rawpath = os.path.join(raw_dir, rawfile)
                    c1 = os.path.isfile(rawpath)
                    c2, evidence = (False, "")
                    if c1:
                        c2, evidence = resolve_anchor(anchor, raw_lines(rawpath))
                    records.append({
                        "page": page,
                        "line": idx + 1,
                        "file": rawfile,
                        "anchor": anchor,
                        "c1": c1,
                        "c2": c2,
                        "claim": extract_claim(lines, idx, m.start()),
                        "evidence": evidence,
                    })
    return records


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    raw_dir = None
    as_json = "--json" in argv
    if "--raw" in argv:
        i = argv.index("--raw")
        raw_dir = argv[i + 1]
        args = [a for a in args if a != raw_dir]
    if len(args) != 1:
        sys.stderr.write("usage: citation-audit.py <wiki-dir> [--raw <raw-dir>] [--json]\n")
        return 2
    wiki_dir = args[0]
    if raw_dir is None:
        raw_dir = os.path.join(os.path.dirname(os.path.abspath(wiki_dir.rstrip("/"))), "raw")
    if not os.path.isdir(wiki_dir):
        sys.stderr.write(f"error: not a directory: {wiki_dir}\n")
        return 2

    records = audit(wiki_dir, raw_dir)

    if "--coverage" in argv:
        gaps = coverage(wiki_dir, raw_dir, records)
        print(f"citation-coverage — {wiki_dir}")
        if not gaps:
            print("  every claim-bearing page carries a resolving citation")
            return 0
        print(f"  {len(gaps)} page(s) make claims with no resolving citation:")
        for p in gaps:
            print(f"  ✗ {p} — cite a raw source, or set 'provenance: none' if it makes no external claims")
        return 1

    if as_json:
        for r in records:
            sys.stdout.write(json.dumps(r) + "\n")
        return 0

    if "--tsv" in argv:
        def b64(s):
            return base64.b64encode(s.encode("utf-8")).decode("ascii")
        for r in records:
            tag = "OK" if (r["c1"] and r["c2"]) else "BAD"
            sys.stdout.write("\t".join([
                tag, r["page"], str(r["line"]), r["file"], r["anchor"] or "",
                "1" if r["c1"] else "0", "1" if r["c2"] else "0",
                b64(r["claim"]), b64(r["evidence"]),
            ]) + "\n")
        return 0

    failures = [r for r in records if not (r["c1"] and r["c2"])]
    total = len(records)
    print(f"citation-audit — {wiki_dir} (raw: {raw_dir})")
    print(f"  {total} raw citation(s); {total - len(failures)} resolve, {len(failures)} broken")
    for r in failures:
        why = "file missing" if not r["c1"] else "anchor unresolved"
        anchor = f"#{r['anchor']}" if r["anchor"] else "(no anchor)"
        print(f"  ✗ {r['page']}:{r['line']} -> raw/{r['file']}{anchor} ({why})")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
