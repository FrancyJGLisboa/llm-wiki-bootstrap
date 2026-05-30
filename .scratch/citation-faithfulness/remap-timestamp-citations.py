#!/usr/bin/env python3
"""One-time faithfulness repair: remap fabricated timestamp/anchor citations in
wiki/ to anchors that actually resolve in the raw.

Root cause (found by scripts/eval-citation-faithfulness.sh): the wiki cites
second-level timestamp ranges like `#2:01-2:31` that appear nowhere in the raw
transcript — which only carries section-level timestamps at its headings
(`## ... (0:51)`, `(2:32)`, ...). The ingest invented precision the source
doesn't have.

Faithful fix (mechanical): map each cited timestamp to the REAL section timestamp
it falls within (largest section ts <= cited start). The section heading exists
verbatim in the raw, so the citation becomes resolvable and honestly points at
the source region. Entailment (does that section actually support the claim) is
then validated separately by the C3 judge — this script does not assert it.

Also remaps the slide sidecar's bad `#step-06/#step-07` to the real section that
holds the numbered steps.

Run from repo root:  python3 .scratch/citation-faithfulness/remap-timestamp-citations.py [--apply]
Without --apply: dry-run (prints the rewrites). With --apply: edits wiki/ in place.
"""
import os
import re
import sys

TRANSCRIPT = "karpathy-llm-wiki-video-transcript.md"
SLIDE = "karpathy-video-slide-ingest-pipeline.png.md"
SLIDE_STEPS_ANCHOR = "body-verbatim-numbered-0107"  # the section holding steps 01-07

TS_RE = re.compile(r"^(\d{1,2}):(\d{2})")


def secs(ts):
    m = TS_RE.match(ts)
    return int(m.group(1)) * 60 + int(m.group(2))


def section_timestamps(raw_path):
    """Valid anchors = the (M:SS) markers in the transcript's headings."""
    out = []
    with open(raw_path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("#"):
                for m in re.finditer(r"\((\d{1,2}:\d{2})\)", line):
                    out.append(m.group(1))
    # de-dup, keep ascending by time
    uniq = sorted(set(out), key=secs)
    return uniq


def containing_section(start_ts, sections):
    s = secs(start_ts)
    chosen = sections[0]
    for ts in sections:
        if secs(ts) <= s:
            chosen = ts
        else:
            break
    return chosen


def main(argv):
    apply = "--apply" in argv
    repo = os.getcwd()
    sections = section_timestamps(os.path.join(repo, "raw", TRANSCRIPT))
    print(f"valid section timestamps: {', '.join(sections)}\n")

    # citation with an anchor on either raw file
    cite_re = re.compile(
        r"\(source: raw/(" + re.escape(TRANSCRIPT) + r"|" + re.escape(SLIDE) + r")#([^)\s]+)\)"
    )
    total_changes = 0
    for root, _d, files in os.walk(os.path.join(repo, "wiki")):
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
            changes = []

            def repl(m):
                rawfile, anchor = m.group(1), m.group(2)
                new_anchor = anchor
                if rawfile == TRANSCRIPT and TS_RE.match(anchor):
                    start = anchor.split("-", 1)[0]
                    new_anchor = containing_section(start, sections)
                elif rawfile == SLIDE and anchor.lower().startswith("step-"):
                    new_anchor = SLIDE_STEPS_ANCHOR
                if new_anchor != anchor:
                    changes.append((anchor, new_anchor))
                    return f"(source: raw/{rawfile}#{new_anchor})"
                return m.group(0)

            new_text = cite_re.sub(repl, text)
            if changes:
                total_changes += len(changes)
                print(f"{name}: {len(changes)} rewrite(s)")
                for old, new in changes:
                    print(f"    #{old}  ->  #{new}")
                if apply:
                    with open(path, "w", encoding="utf-8") as fh:
                        fh.write(new_text)

    print(f"\n{'APPLIED' if apply else 'DRY-RUN'}: {total_changes} citation anchor(s)"
          f"{' rewritten' if apply else ' would change'}.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
