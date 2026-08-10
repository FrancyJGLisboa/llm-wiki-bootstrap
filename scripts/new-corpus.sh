#!/usr/bin/env bash
# scripts/new-corpus.sh — scaffold an adapter for a new source.
#
# Point this compiler at something other than GAIN. It writes the three files a
# new corpus needs and leaves exactly one decision unmade: how to talk to the
# source.
#
# DELIBERATELY DUMB, on the same principle as scripts/new-gate.sh. It does not
# guess the endpoint, the auth, the pagination, or the field names — those are
# decisions, and a scaffolder that guesses at them produces an adapter whose
# author never had to think about what the source actually is. It refuses to
# overwrite anything.
#
# WHAT IT DOES CARRY OVER is the part that is genuinely reusable and took three
# tarpit incidents to learn: the fetch hardening. A hard wall-clock deadline
# around the whole call, Content-Length truncation detection, retry with
# backoff, politeness pacing, atomic writes, and content-hash idempotence all
# ship in the skeleton. Those are properties of talking to any HTTP source, not
# of talking to this one, and an adapter that starts without them will
# rediscover each in production.
#
# WHAT YOU WRITE is `_catalog()` and `_fetch_one()` — list what exists, fetch
# one item — plus the field names in corpus.json.
#
# WHAT PROVES IT IS RIGHT is scripts/gate-adapter-contract.sh. Run it against
# the staged output and it settles, with an exit code, whether the adapter
# produces something this compiler can actually compile: frontmatter complete,
# both time axes genuinely distinct, anchors resolving, everything hashable,
# slugs matching the declaration. That gate is the reason this is a blueprint
# rather than a pattern to imitate — an agent cannot reliably copy an
# architecture from prose, but it can satisfy a contract that exits 0 or 1.
#
# Usage:  scripts/new-corpus.sh <name>          e.g. new-corpus.sh edgar
# Exit:   0 = scaffolded · 1 = refused · 2 = setup error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO" || { echo "new-corpus: cannot cd to $REPO" >&2; exit 2; }

die1() { printf 'new-corpus: %s\n' "$1" >&2; exit 1; }

NAME="${1:-}"
[ -n "$NAME" ] || die1 "usage: new-corpus.sh <name>   (e.g. new-corpus.sh edgar)"
# LC_ALL=C, and POSIX classes rather than a-z. Under a UTF-8 locale the range
# [a-z] collates to aAbBcC..., so `[a-z][a-z0-9-]*` happily matches "Bad Name" —
# which it did, writing `scripts/harvest-Bad Name.py` before this was fixed. The
# repo runs an entire CI job on locale invariance for this class of bug; a range
# in a case pattern is the same trap in a quieter place.
case "$(printf '%s' "$NAME" | LC_ALL=C tr -d '[:lower:][:digit:]-')" in
  "") : ;;
  *) die1 "name must be lowercase kebab-case (got '$NAME'). It keys the corpus declaration, the harvester filename and the slug template — a free-form name silently decouples all three." ;;
esac
case "$NAME" in
  [0-9-]*) die1 "name must start with a letter (got '$NAME')" ;;
esac

HARVEST="scripts/harvest-$NAME.py"
WATCHD="scripts/$NAME-watchd.sh"
CFG="corpus-$NAME.json"

for f in "$HARVEST" "$WATCHD" "$CFG"; do
  [ -e "$f" ] && die1 "$f already exists. Refusing to overwrite — regenerating would discard its endpoint logic and its field mapping. Edit it, or delete it deliberately first."
done

# ── corpus declaration ───────────────────────────────────────────────────────
cat > "$CFG" <<EOF
{
  "_comment": [
    "corpus-$NAME.json — what this compiler's $NAME sources ARE.",
    "",
    "Everything corpus-specific about staging lives here rather than in code,",
    "so scripts/stage-corpus.py stays generic. Fill in the field names your",
    "source actually uses; the keys below are the contract, the values are yours.",
    "",
    "Prove it with: scripts/gate-adapter-contract.sh"
  ],

  "name": "$NAME",
  "description": "TODO: one line — what these documents are",

  "source_type": "document",
  "markers": ["source_type", "TODO_unique_id_field"],

  "id_field": "TODO_unique_id_field",
  "slug": "$NAME-{valid}-{id}",

  "title_field": "title",
  "url_field": "source_url",

  "time": {
    "valid": "TODO_document_date_field",
    "transaction": "TODO_fetch_time_field"
  },
  "_time": [
    "THE MAPPING THAT MATTERS, and the one worth checking twice.",
    "valid       -> asserted_at : the date the DOCUMENT claims for its content",
    "transaction -> fetched_at  : when YOU pulled it",
    "Wire both to the same field and every point-in-time question resolves",
    "against acquisition time — answering 'what was true in 2020' with what you",
    "downloaded last week, confidently, with a citation that resolves.",
    "gate-adapter-contract.sh check A2 exists to catch exactly that.",
    "If the corpus genuinely has no document date, set valid to null: the stager",
    "writes asserted_at: unknown with a note rather than inventing one."
  ],

  "author": {
    "template": "TODO {capture}",
    "fallback": "TODO",
    "from_body": null
  },

  "metadata_section": {
    "heading": "Source metadata",
    "rows": [
      { "label": "Released", "field": "@valid" },
      { "label": "Identifier", "field": "TODO_unique_id_field" }
    ]
  },
  "_metadata_section": [
    "Synthesized into every staged file so asserted_at_source has a short stable",
    "anchor. The FIRST ROW MUST CARRY THE VALID-TIME DATE: the audit resolves",
    "#<slugified heading> and then requires the date to appear in that passage."
  ],

  "passthrough": [],
  "segment_word_threshold": 6000,
  "poll_interval_s": 2700,
  "harvest_script": "$HARVEST"
}
EOF

# ── harvester skeleton ───────────────────────────────────────────────────────
# The fetch hardening is copied from the working harvester rather than
# re-derived. Everything above _catalog() is done; everything in it is yours.
python3 - "$NAME" "$HARVEST" "$REPO/templates/corpus/transport.py.tmpl" <<'PY'
import re, sys
name, out, ref = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(ref, encoding="utf-8").read()

# The transport template is already source-agnostic; use it whole.
transport = src[src.index("class HarvestError"):]

open(out, "w", encoding="utf-8").write(f'''#!/usr/bin/env python3
"""scripts/harvest-{name}.py — acquire {name} documents into archive/{name}/.

SCAFFOLDED by scripts/new-corpus.sh. Two functions are yours; everything else is
already correct.

WHAT YOU WRITE:
  _catalog()    -> list of records describing what exists at the source
  _fetch_one(r) -> (body_text, method) for one record

WHAT IS ALREADY DONE, and should not be rewritten: the transport below. A hard
wall-clock deadline around the WHOLE call (not just the read loop — DNS ignores
urlopen's timeout, and a source that stalls before the first byte is invisible to
an in-loop check), Content-Length truncation detection (a premature close reads
as clean EOF), retry with backoff, politeness pacing between fetches, atomic
writes, and content-hash idempotence. Every one of those is scar tissue from a
real incident against a real government API. An adapter that starts without them
relearns all of them in production.

PROVE IT with scripts/gate-adapter-contract.sh once something is staged. It
settles with an exit code whether this adapter produces output the compiler can
actually compile.

Usage:
  scripts/harvest-{name}.py [--root archive] [--limit N] [--dry-run] [--quiet]
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import os
import re
import signal
import ssl
import sys
import threading
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# TODO: the source's base URL.
BASE = "https://example.invalid"

PACING_S = 0.4          # between fetches; unthrottled downloading gets you blocked
CATALOG_MAX_AGE_S = 20 * 3600

try:
    import certifi
    _SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except Exception:  # noqa: BLE001
    _SSL_CTX = ssl.create_default_context()


{transport}
def _catalog(root: Path, log) -> list:
    """TODO: return a list of records describing every available document.

    Each record must carry enough to build the frontmatter corpus-{name}.json
    declares — at minimum an id, a document date, and whatever locates the
    document for _fetch_one().

    Cache the listing on disk if it is expensive; see CATALOG_MAX_AGE_S. Route
    every request through _fetch() so it inherits the deadline and truncation
    handling — a second fetch path is a second set of bugs.
    """
    raise NotImplementedError("write _catalog() — see corpus-{name}.json")


def _fetch_one(rec: dict) -> tuple[str, str]:
    """TODO: return (body_text, extraction_method) for one record.

    Use _fetch(url) for the bytes. If the document is a PDF or similar, follow
    the repo rule for optional dependencies: try each handler in turn and fall
    back rather than failing, recording WHICH handler ran as the method.
    """
    raise NotImplementedError("write _fetch_one() — see corpus-{name}.json")


def _yaml(front: dict) -> str:
    return "\\n".join(["---", *[f"{{k}}: {{v}}" for k, v in front.items()], "---"])


def _write(root: Path, valid_date: str, slug: str, front_extra: dict,
           body: str) -> str:
    """Atomic, idempotent write. 'written' | 'skipped' | 'changed'.

    Idempotent on a content hash: an unchanged body keeps its ORIGINAL
    retrieved_at, because that timestamp is the real capture time and rewriting
    it turns every run into a fake re-acquisition. A CHANGED body is reported,
    never silently overwritten — captured evidence is not editable.
    """
    out_dir = root / "{name}" / str(valid_date)[:4]
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{{slug}}.md"
    sha = hashlib.sha256(body.encode("utf-8")).hexdigest()

    if path.exists():
        existing = path.read_text(encoding="utf-8", errors="replace")
        return "skipped" if f"data_sha256: {{sha}}" in existing else "changed"

    front = {{
        "source": "{name}",
        "release_date": valid_date,
        "retrieved_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "data_sha256": sha,
        **front_extra,
    }}
    tmp = path.with_suffix(".md.tmp")
    tmp.write_text(_yaml(front) + "\\n\\n" + body + "\\n", encoding="utf-8")
    os.replace(tmp, path)   # atomic: a kill never leaves a partial document
    return "written"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="harvest-{name}.py")
    ap.add_argument("--root", default="archive")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args(argv[1:])
    log = (lambda *_: None) if a.quiet else (lambda m: print(m, flush=True))
    root = Path(a.root)

    written = skipped = failed = 0
    changed: list[str] = []
    for rec in _catalog(root, log):
        # TODO: derive slug + valid_date from rec, per corpus-{name}.json.
        raise NotImplementedError("wire the harvest loop to _catalog()/_fetch_one()")

    log(f"harvest-{name}: written {{written}}, skipped {{skipped}}, failed {{failed}}")
    for slug in changed:
        print(f"harvest-{name}: CHANGED UPSTREAM (not overwritten): {{slug}}", file=sys.stderr)
    return 1 if (failed or changed) else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
''')
print(f"  wrote {out}")
PY

# ── daemon ───────────────────────────────────────────────────────────────────
# A missing template must be an error, not an empty file. Porting this scaffold
# between repos, the daemon step silently sed'd from a source that did not exist
# there and wrote a 0-byte "daemon" that reported success.
WATCHD_TMPL="$REPO/templates/corpus/watchd.sh.tmpl"
[ -r "$WATCHD_TMPL" ] || die1 "missing $WATCHD_TMPL — cannot scaffold the daemon"
UNAME_UC="$(printf '%s' "$NAME" | LC_ALL=C tr 'a-z-' 'A-Z_')"
sed -e "s/__NAME__/$NAME/g" -e "s/__UNAME__/$UNAME_UC/g" "$WATCHD_TMPL" > "$WATCHD"
[ -s "$WATCHD" ] || die1 "scaffolded daemon came out empty — refusing to leave a stub that looks like a working file"
chmod +x "$WATCHD" "$HARVEST"

cat <<EOF

new-corpus: scaffolded
  $CFG        the declaration — fill in every TODO_ field name
  $HARVEST    transport done; write _catalog() and _fetch_one()
  $WATCHD     poll -> harvest -> stage -> commit -> compile (interlocked)

Not done yet. The harvester raises NotImplementedError by design — a scaffolder
that guessed your endpoint would produce an adapter nobody had to think about.

Next, in order:
  1. fill in the TODO_ field names in $CFG, especially time.valid vs
     time.transaction — wiring both to the same field is the expensive mistake
  2. write _catalog() and _fetch_one() in $HARVEST
  3. python3 $HARVEST --root archive --limit 3
  4. python3 scripts/stage-corpus.py archive/$NAME raw/ --config $CFG
  5. scripts/gate-adapter-contract.sh        <- this is what tells you it is right
  6. register it: a row in gates/baseline.tsv, fixtures in scripts/gate-fixtures.tsv
EOF
