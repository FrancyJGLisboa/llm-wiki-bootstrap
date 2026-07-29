#!/usr/bin/env python3
"""scripts/cite-span.py — resolve one `raw/<file>#<anchor>` citation to the
passage it points at, and report how many lines that passage spans.

The retrieval eval (scripts/eval-retrieval.sh) grades two things about every
citation an answer produces: does the cited passage actually CONTAIN the fact
(not just resolve), and is the passage tight enough to count as a locus rather
than a gesture at the document. Both need the resolved span, so this reuses
`citation-audit.py`'s anchor grammar by import — the same reason `body-hash.sh`
is the one hasher. A second, drifting copy of the anchor rules would make the
eval measure something the audit doesn't enforce.

Usage:
  cite-span.py <raw-dir> '<file>[#<anchor>]'

Stdout: the resolved passage. Stderr: `span: <N> lines`.
Exit: 0 resolved, 1 unresolved (bad anchor / missing file), 2 usage error.

Note: passages are capped at citation-audit's EVIDENCE_MAX_LINES (40). A
whole-file citation therefore yields the first 40 body lines — which is why a
deep needle cannot be smuggled in by citing the whole file.
"""
import importlib.util
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "citation_audit", os.path.join(_HERE, "citation-audit.py"))
_ca = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ca)


def main(argv):
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[-6], file=sys.stderr)
        return 2
    raw_dir, target = argv[1], argv[2]

    target = target.strip()
    if target.startswith("raw/"):
        target = target[len("raw/"):]
    name, _, anchor = target.partition("#")
    anchor = anchor or None

    path = os.path.join(raw_dir, name)
    if not os.path.isfile(path):
        print(f"unresolved: no such raw file: {name}", file=sys.stderr)
        return 1

    resolved, evidence = _ca.resolve_anchor(anchor, _ca.raw_lines(path))
    if not resolved:
        print(f"unresolved: anchor #{anchor} does not resolve in {name}",
              file=sys.stderr)
        return 1

    span = len(evidence.splitlines()) if evidence else 0
    print(f"span: {span} lines", file=sys.stderr)
    sys.stdout.write(evidence)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
