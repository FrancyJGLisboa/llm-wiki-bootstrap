#!/usr/bin/env python3
"""scripts/extract/segment-doc.py — deterministic long-source segmenter.

Ports the *idea* of PageIndex into the BYO-agent model: turn a long source
into a hierarchy of sections with positional ranges, so that

  - /wiki-ingest can author a compact summary TREE (one line per node) and
    read the source section-by-section instead of swallowing a flat blob, and
  - /wiki-query can read the tree and fetch only the relevant sections via the
    existing `(source: raw/<file>#<anchor>)` citation-anchor machinery.

This script is the DETERMINISTIC half (no LLM): it only segments and emits
anchors. The agent writes the one-line summaries (ingest) and chooses which
nodes to read (query). Mirrors scripts/vtt-to-md.sh: emits the BODY only to
stdout; the caller (/wiki-extract) prepends frontmatter and the `# <title>`.

Output: markdown where every section is a heading
    #{level} <Title> (lines A-B)        # text / markdown sources
    #{level} <Title> (pages N-M)        # pdf sources
followed by that section's verbatim text. Heading levels preserve hierarchy.

Strategy ladder (smart, with graceful fallback):
  text/markdown : existing heading hierarchy -> else fixed paragraph-window
  pdf           : outline/bookmarks -> heading-by-font-size -> fixed page-window

Determinism: pure function of the input bytes. No clocks, no randomness, no
dict-ordering reliance. Same input -> byte-identical stdout (oracle check C2).

Usage:
  segment-doc.py <file> [--type auto|md|txt|pdf] [--word-budget N]

Exit codes:
  0 — segmented (possibly degraded, e.g. pdf tooling absent: flat + warning)
  2 — usage error / unreadable input
Degraded states are reported on stderr (the caller records extraction_status).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# A leaf section longer than this many words is sub-split at paragraph
# boundaries so no single node is too big to summarize cheaply.
DEFAULT_WORD_BUDGET = 1200

_HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$")


def _warn(msg: str) -> None:
    print(f"segment-doc: {msg}", file=sys.stderr)


def _word_count(text: str) -> int:
    return len(text.split())


def _detect_type(path: Path, declared: str) -> str:
    if declared != "auto":
        return declared
    ext = path.suffix.lower()
    if ext == ".pdf":
        return "pdf"
    if ext in (".md", ".markdown"):
        return "md"
    return "txt"


# ---------------------------------------------------------------------------
# Text / markdown segmentation
# ---------------------------------------------------------------------------

def _split_paragraph_windows(
    body_lines: list[str], start_line: int, level: int, title: str, word_budget: int
) -> list[str]:
    """Sub-split an over-budget leaf section at blank-line (paragraph) breaks.

    Emits synthetic `#{level+1} <title> — part K (lines A-B)` anchors. Returns
    the rendered lines. Deterministic: walks paragraphs in order, greedily
    filling each part up to the word budget.
    """
    # Group into (paragraph_lines, abs_start, abs_end) blocks on blank lines.
    paras: list[tuple[list[str], int, int]] = []
    cur: list[str] = []
    cur_start = start_line
    for offset, ln in enumerate(body_lines):
        abs_no = start_line + offset
        if ln.strip() == "":
            if cur:
                paras.append((cur, cur_start, abs_no - 1))
                cur = []
            cur_start = abs_no + 1
        else:
            if not cur:
                cur_start = abs_no
            cur.append(ln)
    if cur:
        paras.append((cur, cur_start, start_line + len(body_lines) - 1))

    out: list[str] = []
    part: list[str] = []
    part_words = 0
    part_start = start_line
    part_end = start_line
    part_no = 0
    sub_level = "#" * min(level + 1, 6)

    def flush_part() -> None:
        nonlocal part, part_words, part_no
        if not part:
            return
        part_no += 1
        out.append(f"{sub_level} {title} — part {part_no} (lines {part_start}-{part_end})")
        out.append("")
        out.extend(part)
        out.append("")
        part = []
        part_words = 0

    for plines, p_start, p_end in paras:
        if part and part_words + _word_count("\n".join(plines)) > word_budget:
            flush_part()
            part_start = p_start
        if not part:
            part_start = p_start
        part.extend(plines)
        part.append("")
        part_words += _word_count("\n".join(plines))
        part_end = p_end
    flush_part()
    # Drop the trailing blank we always append, for clean idempotent output.
    while out and out[-1] == "":
        out.pop()
    return out


def segment_text(text: str, word_budget: int) -> str:
    """Segment markdown/plain text by heading hierarchy with line ranges."""
    lines = text.splitlines()
    n = len(lines)

    # Find heading boundaries: (line_index, level, title).
    heads: list[tuple[int, int, str]] = []
    for i, ln in enumerate(lines):
        m = _HEADING_RE.match(ln)
        if m:
            heads.append((i, len(m.group(1)), m.group(2).strip()))

    out: list[str] = []

    # Preamble before the first heading becomes its own anchored section so it
    # is never orphaned (content-losslessness: every source line is reachable).
    first = heads[0][0] if heads else n
    if any(lines[i].strip() for i in range(first)):
        out.append(f"## Preamble (lines 1-{first})")
        out.append("")
        out.extend(lines[:first])
        out.append("")

    if not heads:
        # No headings at all: window the whole body by paragraphs.
        windowed = _split_paragraph_windows(lines, 1, 1, Path("section").stem, word_budget)
        out.extend(windowed)
        return "\n".join(out).rstrip() + "\n"

    for idx, (line_i, level, title) in enumerate(heads):
        end_i = heads[idx + 1][0] if idx + 1 < len(heads) else n
        a = line_i + 1            # 1-based heading line
        b = end_i                 # last line of this section (inclusive)
        body = lines[line_i + 1:end_i]
        hashes = "#" * level
        out.append(f"{hashes} {title} (lines {a}-{b})")
        out.append("")
        if _word_count("\n".join(body)) > word_budget:
            out.extend(_split_paragraph_windows(body, a + 1, level, title, word_budget))
        else:
            out.extend(body)
        out.append("")

    return "\n".join(out).rstrip() + "\n"


# ---------------------------------------------------------------------------
# PDF segmentation (outline -> headings -> page-window)
# ---------------------------------------------------------------------------

def segment_pdf(path: Path, word_budget: int) -> str:
    """Segment a PDF into page-ranged sections. Requires pymupdf; degrades."""
    try:
        import fitz  # pymupdf
    except ImportError:
        _warn("pymupdf (fitz) not installed; cannot segment PDF structurally.")
        _warn("install hint: pip install pymupdf  — emitting DEGRADED flat text.")
        return _pdf_flat_fallback(path)

    doc = fitz.open(str(path))
    page_count = doc.page_count
    page_text = [doc.load_page(p).get_text("text") for p in range(page_count)]

    # Strategy 1: PDF outline / bookmarks -> section page ranges.
    toc = doc.get_toc(simple=True)  # [[level, title, page1based], ...]
    sections: list[tuple[int, str, int, int]] = []  # level, title, start0, end0
    if toc:
        for j, (level, title, page1) in enumerate(toc):
            start0 = max(0, page1 - 1)
            end0 = (toc[j + 1][2] - 2) if j + 1 < len(toc) else (page_count - 1)
            end0 = max(start0, end0)
            sections.append((min(level, 6), title.strip() or f"Section {j+1}", start0, end0))
    else:
        # Strategy 3 (fallback): fixed page-window. (Font-size heading detection
        # — strategy 2 — is left as a documented future refinement; the window
        # fallback keeps output deterministic and dependency-light.)
        window = 5
        for start0 in range(0, page_count, window):
            end0 = min(start0 + window - 1, page_count - 1)
            sections.append((1, f"Pages {start0+1}-{end0+1}", start0, end0))

    out: list[str] = []
    for level, title, start0, end0 in sections:
        hashes = "#" * level
        out.append(f"{hashes} {title} (pages {start0+1}-{end0+1})")
        out.append("")
        body = "\n".join(page_text[start0:end0 + 1]).rstrip()
        out.append(body)
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def _pdf_flat_fallback(path: Path) -> str:
    """No pymupdf: shell out to pdftotext if present, else fail closed."""
    import shutil
    import subprocess
    if shutil.which("pdftotext"):
        res = subprocess.run(
            ["pdftotext", str(path), "-"], capture_output=True, text=True
        )
        body = res.stdout.rstrip()
        return f"## Full text (pages 1-?) [DEGRADED: flat, no section tree]\n\n{body}\n"
    _warn("neither pymupdf nor pdftotext available — cannot extract PDF.")
    return "## Full text (unavailable) [DEGRADED: no PDF tooling]\n\n"


# ---------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="segment-doc.py")
    ap.add_argument("file")
    ap.add_argument("--type", choices=["auto", "md", "txt", "pdf"], default="auto")
    ap.add_argument("--word-budget", type=int, default=DEFAULT_WORD_BUDGET)
    args = ap.parse_args(argv)

    path = Path(args.file)
    if not path.is_file():
        _warn(f"not a file: {path}")
        return 2

    kind = _detect_type(path, args.type)
    if kind == "pdf":
        sys.stdout.write(segment_pdf(path, args.word_budget))
    else:
        text = path.read_text(encoding="utf-8", errors="replace")
        sys.stdout.write(segment_text(text, args.word_budget))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
