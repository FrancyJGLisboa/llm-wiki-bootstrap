#!/usr/bin/env python3
"""scripts/wiki-to-okf.py — export this wiki as an Open Knowledge Format bundle.

OKF (Google Cloud, https://github.com/GoogleCloudPlatform/knowledge-catalog) is
a deliberately minimal interchange format: a directory of markdown concept files
with YAML frontmatter, one concept per file, whose ONLY hard rule is that every
non-reserved `.md` carries a non-empty `type` field. Our schema is a strict
superset, so export is mechanical — see wiki/okf-vs-llm-wiki-bootstrap.md.

The transform, per page:
  - `[[slug]]`            → `[slug](./slug.md)`  (OKF uses ordinary md paths)
  - frontmatter `updated` → `timestamp`          (OKF's recommended field)
  - `description`         → kept if present, else derived from `## Definition /
                            TL;DR`, else the title (OKF `description` is a
                            single-sentence summary; never empty)
  - `type`, `title`, `tags`, `source`, `provenance` → passed through verbatim
    (`source`/`provenance` are unknown-but-tolerated OKF keys — kept as extra
    provenance signal; OKF readers ignore keys they don't recognize)
  - `index.md` and root `log.md` map to OKF's two reserved filenames.

Guarantees (asserted by `--check` and by scripts/verify-wiki-to-okf.sh):
  (a) every exported non-reserved `.md` has parseable frontmatter with a
      non-empty `type`;
  (b) zero unconverted wikilinks remain — where "wikilink" is the system's
      canonical grammar `[[<a-z><a-z0-9->*]]` (same as wiki-lint / wiki-to-kg).
      Non-canonical `[[...]]` in prose or code (anchor refs like `[[#wiki-init]]`,
      the forbidden-syntax example `[[folder/page]]`) are intentionally left
      verbatim — they are not page links, and rewriting them would corrupt docs;
  (c) DETERMINISTIC — no timestamps or host paths in output, sorted iteration,
      so a rerun on unchanged input is byte-identical;
  (d) READ-ONLY on the source — writes only under <out>, never wiki/ or raw/.

  ponytail: `[[...]]` rewrite is global (all occurrences, code spans included),
  so an illustrative wikilink like `[[kebab-case-page-name]]` in a doc page
  becomes a link to a nonexistent file. OKF tolerates broken links, so this is
  spec-legal; it's the price of guarantee (b) being a one-line regex instead of
  a context-aware parser. Upgrade to code-span-aware rewriting only if real
  bundles trip over it.

Usage:
  scripts/wiki-to-okf.py [<wiki-root>] [--out <dir>] [--check]

  <wiki-root>  defaults to the parent of scripts/ (this repo)
  --out        output bundle dir (default: <wiki-root>/dist/okf)
  --check      after export, verify guarantees (a) and (b); exit 1 on failure

Exit codes:
  0  bundle written (and, with --check, guarantees held)
  1  a guarantee failed under --check
  2  setup error (not a wiki root, output dir would overlap the source)
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

# Reserved OKF filenames (exempt from the non-empty-`type` conformance rule).
RESERVED = {"index.md", "log.md"}
# Derived artifacts that are not OKF concepts — skipped (regenerable, non-portable).
SKIP_NAMES = {"knowledge-graph.json"}

# Canonical wikilink grammar — mirrors _LINK_RE in wiki-to-kg.py and the slug
# form wiki-lint enforces. Anchor/path variants (`[[#x]]`, `[[a/b]]`) are not
# page links and are deliberately not matched.
_WIKILINK_RE = re.compile(r"\[\[([a-z][a-z0-9-]*)\]\]")
_MD_LINK_RE = re.compile(r"\[([^\]]+)\]\((?:\./)?[^)]*\)")
_CITATION_RE = re.compile(r"\(source:[^)]*\)")
_TLDR_RE = re.compile(r"^##\s+Definition\s*/\s*TL;DR\s*$", re.IGNORECASE)


def split_frontmatter(text: str) -> tuple[list[str], str]:
    """Return (frontmatter_lines, body). Empty frontmatter list if none."""
    if not text.startswith("---\n"):
        return [], text
    end = text.find("\n---\n", 4)
    if end == -1:
        return [], text
    fm = text[4:end].splitlines()
    body = text[end + 5 :]
    return fm, body


def parse_frontmatter(lines: list[str]) -> list[tuple[str, str]]:
    """Parse simple `key: value` frontmatter into ordered (key, value) pairs.

    Wiki pages use only single-line scalar/inline-list values (no block scalars),
    so a line-wise split is sufficient and keeps us stdlib-only.
    """
    pairs: list[tuple[str, str]] = []
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        pairs.append((key.strip(), value.strip()))
    return pairs


def rewrite_links(body: str) -> str:
    """`[[slug]]` → `[slug](./slug.md)` for every occurrence (guarantee b)."""
    return _WIKILINK_RE.sub(lambda m: f"[{m.group(1)}](./{m.group(1)}.md)", body)


def derive_description(body: str) -> str:
    """One-line summary from the `## Definition / TL;DR` section, or ''.

    Runs on the link-rewritten body; strips markdown links, citations, and
    emphasis down to plain prose and collapses to a single line.
    """
    lines = body.splitlines()
    start = next((i for i, l in enumerate(lines) if _TLDR_RE.match(l)), None)
    if start is None:
        return ""
    chunk: list[str] = []
    for l in lines[start + 1 :]:
        if l.startswith("## "):
            break
        chunk.append(l)
    text = " ".join(chunk)
    text = _MD_LINK_RE.sub(lambda m: m.group(1), text)  # [text](url) -> text
    text = _CITATION_RE.sub("", text)  # drop (source: ...) receipts
    text = text.replace("**", "").replace("*", "").replace("`", "")
    text = " ".join(text.split()).strip()
    # First sentence, capped, so the description stays a single summary line.
    if len(text) > 240:
        cut = text.rfind(". ", 0, 240)
        text = text[: cut + 1] if cut > 60 else text[:240].rstrip() + "…"
    return text


def emit_frontmatter(pairs: list[tuple[str, str]], description: str) -> str:
    """Build the OKF frontmatter block from parsed source pairs.

    Field order is fixed for determinism. `type` first (the one required key),
    then title/description/timestamp/tags, then passthrough extras.
    """
    src = dict(pairs)
    out: list[tuple[str, str]] = []
    out.append(("type", src.get("type", "").strip() or "concept"))
    if "title" in src:
        out.append(("title", src["title"]))
    desc = src.get("description", "").strip() or description
    if desc:
        out.append(("description", desc if _is_quoted(desc) else _quote(desc)))
    if "updated" in src:
        out.append(("timestamp", src["updated"]))
    for key in ("tags", "source", "provenance"):
        if key in src:
            out.append((key, src[key]))
    lines = ["---"] + [f"{k}: {v}" for k, v in out] + ["---"]
    return "\n".join(lines) + "\n"


def _is_quoted(s: str) -> bool:
    return len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'"


def _quote(s: str) -> str:
    """Quote a description only if YAML would otherwise mis-parse it."""
    if s and (s[0] in "\"'[]{}#&*!|>%@`" or ": " in s or s.endswith(":")):
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return s


def transform_page(text: str) -> str:
    fm_lines, body = split_frontmatter(text)
    body = rewrite_links(body)
    pairs = parse_frontmatter(fm_lines)
    description = derive_description(body)
    if not pairs:
        # No frontmatter (shouldn't happen for wiki concepts) — still emit a
        # minimal conformant header so the bundle stays valid.
        return f"---\ntype: concept\n---\n{body}"
    return emit_frontmatter(pairs, description) + body


def export(wiki_root: Path, out: Path) -> list[Path]:
    """Write the OKF bundle; return the list of written .md paths."""
    wiki_dir = wiki_root / "wiki"
    if out.exists():
        shutil.rmtree(out)
    written: list[Path] = []
    for src in sorted(wiki_dir.rglob("*.md")):
        if src.name in SKIP_NAMES:
            continue
        rel = src.relative_to(wiki_dir)
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(transform_page(src.read_text()), encoding="utf-8")
        written.append(dst)
    # Reserved log.md lives at the repo root and has no frontmatter (exempt from
    # the type rule) — but it still carries `[[links]]`, so it gets the same link
    # rewrite as every other file to satisfy guarantee (b).
    root_log = wiki_root / "log.md"
    if root_log.exists():
        out.mkdir(parents=True, exist_ok=True)
        (out / "log.md").write_text(rewrite_links(root_log.read_text()), encoding="utf-8")
        written.append(out / "log.md")
    return written


def check_bundle(out: Path) -> list[str]:
    """Verify guarantees (a) and (b) over the written bundle. Return failures."""
    failures: list[str] = []
    for md in sorted(out.rglob("*.md")):
        text = md.read_text()
        if "[[" in text and _WIKILINK_RE.search(text):
            failures.append(f"(b) unconverted wikilink in {md.name}")
        if md.name in RESERVED:
            continue
        fm, _ = split_frontmatter(text)
        if not fm:
            failures.append(f"(a) no frontmatter in {md.name}")
            continue
        src = dict(parse_frontmatter(fm))
        if not src.get("type", "").strip():
            failures.append(f"(a) empty/missing type in {md.name}")
    return failures


def main() -> int:
    ap = argparse.ArgumentParser(description="Export the wiki as an OKF bundle.")
    ap.add_argument("wiki_root", nargs="?", default=None)
    ap.add_argument("--out", default=None)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = Path(args.wiki_root).resolve() if args.wiki_root else Path(__file__).resolve().parent.parent
    if not (root / "wiki").is_dir() or not (root / "AGENTS.md").is_file():
        print(f"error: {root} is not a wiki root (needs wiki/ and AGENTS.md)", file=sys.stderr)
        return 2
    out = Path(args.out).resolve() if args.out else root / "dist" / "okf"
    # Guarantee (d): never write into the source trees.
    for guarded in (root / "wiki", root / "raw"):
        if guarded == out or guarded in out.parents:
            print(f"error: --out {out} would overlap the read-only source {guarded}", file=sys.stderr)
            return 2

    written = export(root, out)
    md_count = sum(1 for p in written if p.suffix == ".md")
    print(f"OKF bundle: {out}  ({md_count} concept files + reserved index.md/log.md)")

    if args.check:
        failures = check_bundle(out)
        if failures:
            for f in failures:
                print(f"  ✗ {f}", file=sys.stderr)
            print(f"✗ {len(failures)} guarantee failure(s)", file=sys.stderr)
            return 1
        print("✓ guarantees (a) non-empty type + (b) zero unconverted wikilinks hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
