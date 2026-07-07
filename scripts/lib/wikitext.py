"""Shared wiki-text primitives — the ONE definition of the wikilink grammar and
the frontmatter parser, so wiki-to-kg / wiki-to-okf / citation-audit / graph-html
don't each carry their own copy.

Stdlib-only. The consumers are standalone scripts (run as `python3 scripts/x.py`,
not a package), so each adds its own `scripts/lib` to sys.path before importing.
`package-wiki.sh` ships `scripts/lib/` alongside `citation-audit.py`, so the
import resolves inside a distributed bundle too (proven by verify-bundle).
"""

import re

# Canonical wikilink grammar: [[<slug>]] where slug is lowercase kebab-case.
# This is THE definition of what counts as a page link — wiki-lint enforces the
# same shape. Anchor/path variants (`[[#x]]`, `[[a/b]]`) are deliberately not
# matched: they are not resolvable page links in this system.
WIKILINK_RE = re.compile(r"\[\[([a-z][a-z0-9-]*)\]\]")


def parse_frontmatter(lines):
    """Parse the leading --- frontmatter block into a flat {key: value} dict.

    `lines` is the file split into lines (no trailing newlines). Returns {} when
    there is no frontmatter — INCLUDING an UNCLOSED leading `---`: treating an
    unclosed block as {} (rather than parsing to the end of file) stops an author
    from opening `---` + `type: navigation` and never closing it to dodge the
    citation-coverage gate. This security property is relied on by
    citation-audit's coverage exemptions — do not relax it.
    """
    if lines[:1] != ["---"]:
        return {}
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
