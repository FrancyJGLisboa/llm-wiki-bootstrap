#!/usr/bin/env python3
"""scripts/asserted-at-audit.py — enforce the raw/ valid-time contract.

Driven by scripts/wiki-lint-asserted-at.sh, which documents the contract and the
reasoning. This is the mechanism: read each ingested raw file's frontmatter and
decide whether its `asserted_at` claim is honest.

Reuses the ONE definition of each thing it needs rather than reimplementing:
`wikitext.parse_frontmatter` for frontmatter, and `citation-audit.py`'s
`resolve_anchor` for the anchor grammar — a second copy of either would let the
lint accept anchors the citation audit rejects, or vice versa.

Stdlib only. Exit 0 clean, 1 violations found.
"""

from __future__ import annotations

import importlib.util
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "lib"))
from wikitext import parse_frontmatter  # noqa: E402

_spec = importlib.util.spec_from_file_location(
    "citation_audit", os.path.join(_HERE, "citation-audit.py")
)
_ca = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ca)

ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# A date is "present in the passage" if it appears either ISO (2026-03-31) or in
# the common prose forms a real document uses for the same day. Deliberately
# narrow: the point is to prove the author read the date off the page, not to
# accept any string that vaguely resembles it.
MONTHS = [
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
]


def date_forms(iso: str) -> list[str]:
    """Every spelling of `iso` the anchor's passage is allowed to use."""
    year, month, day = iso.split("-")
    mon = MONTHS[int(month) - 1]
    d = str(int(day))
    return [
        iso,
        f"{mon} {d}, {year}",
        f"{mon} {d} {year}",
        f"{d} {mon} {year}",
        f"{month}/{day}/{year}",
        f"{day}/{month}/{year}",
    ]


def is_sidecar_of(name: str, names: set[str]) -> bool:
    """True when `name` is the `.md` sidecar of another raw file in the set.

    Binaries and CSVs live as `<slug>.<ext>` plus `<slug>.<ext>.md`, and only the
    sidecar carries frontmatter. Auditing the binary itself would report a
    violation nobody can fix.
    """
    return name.endswith(".md") and name[: -len(".md")] in names


def audit(raw_dir: str, audit_all: bool = False) -> list[str]:
    problems: list[str] = []
    names = {
        e for e in os.listdir(raw_dir) if os.path.isfile(os.path.join(raw_dir, e))
    }
    for name in sorted(names):
        path = os.path.join(raw_dir, name)
        # The binary half of a sidecar pair has no frontmatter by design.
        if not name.endswith(".md") and f"{name}.md" in names:
            continue
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().split("\n")
        except OSError as exc:
            problems.append(f"{name}: unreadable ({exc})")
            continue

        fm = parse_frontmatter([ln.rstrip("\r") for ln in lines])
        if not fm:
            continue  # no frontmatter at all is a different lint's business
        if not audit_all and not fm.get("ingested_hash", "").strip().strip('"'):
            continue  # never ingested — /wiki-extract's job, not ours

        value = fm.get("asserted_at", "").strip().strip('"')
        if not value:
            problems.append(
                f"{name}: no asserted_at — the document's own date is unrecorded, "
                f"so an as-of query has nothing to resolve against "
                f"(use a date + asserted_at_source, or `unknown` + asserted_at_note)"
            )
            continue

        if value == "unknown":
            if not fm.get("asserted_at_note", "").strip().strip('"'):
                problems.append(
                    f"{name}: asserted_at is `unknown` with no asserted_at_note — "
                    f"say why no date could be established"
                )
            continue

        if not ISO_DATE.match(value):
            problems.append(
                f"{name}: asserted_at `{value}` is neither YYYY-MM-DD nor `unknown`"
            )
            continue

        fetched = fm.get("fetched_at", "").strip().strip('"')
        anchor = fm.get("asserted_at_source", "").strip().strip('"').lstrip("#")
        if not anchor:
            problems.append(
                f"{name}: asserted_at {value} has no asserted_at_source anchor — "
                f"an untraceable date is a guess with a colon after it"
            )
            continue

        resolved, evidence = _ca.resolve_anchor(anchor, _ca.raw_lines(path))
        if not resolved:
            problems.append(
                f"{name}: asserted_at_source #{anchor} does not resolve in this file"
            )
            continue

        # resolve_anchor returns the passage as a single string, not a line list;
        # joining a str yields one newline per character and never matches.
        if not isinstance(evidence, str):
            evidence = "\n".join(evidence)
        haystack = evidence.lower()
        if not any(form in haystack for form in date_forms(value)):
            extra = ""
            if value == fetched:
                extra = (
                    " — and it equals fetched_at, which is the signature of "
                    "stamping the fetch date as the document date"
                )
            problems.append(
                f"{name}: asserted_at {value} does not appear in the passage "
                f"#{anchor} resolves to{extra}"
            )
    return problems


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("-")]
    audit_all = "--all" in argv[1:]
    if len(args) != 1:
        print("usage: asserted-at-audit.py <raw-dir> [--all]", file=sys.stderr)
        return 2
    problems = audit(args[0], audit_all=audit_all)
    for p in problems:
        print(p, file=sys.stderr)
    if problems:
        print(
            f"\n{len(problems)} source(s) violate the valid-time contract. "
            f"Fix by recording the document's own date with an anchor into the "
            f"passage that states it, or `unknown` with a reason.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
