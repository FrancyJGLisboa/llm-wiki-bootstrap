#!/usr/bin/env bash
# scripts/gate-adapter-contract.sh — gate ADAPTER-CONTRACT.
#
# RULE: a corpus adapter must produce staged sources the compiler can actually
# compile. Five properties, each independently checkable, none of them opinions.
#
# WHY THIS GATE EXISTS. Pointing a context compiler at a new source means writing
# a fetch client and a corpus.json. Everything downstream — /ctx-compile, the
# citation floor, the valid-time audit, the packager — assumes the staged output
# holds certain properties, and every one of those assumptions is currently
# checked far away from where it would be broken. An adapter that writes a
# plausible-looking file with a subtly wrong date field does not fail here; it
# fails hundreds of compiled pages later, as answers resolved against the wrong
# time axis. By then the corpus is the evidence and the bug is invisible.
#
# THIS IS THE POINT OF THE WHOLE EXERCISE. An architecture is not transferable
# because it is documented; an agent cannot reliably copy a pattern from prose.
# It is transferable when there is a contract that exits 0 or 1. This is that
# contract: an agent building a compiler for a new source writes the adapter,
# runs this, and KNOWS whether it is right.
#
# THE FIVE PROPERTIES, and what each one prevents:
#
#   A1  Required raw frontmatter present on every staged file.
#       Without it /ctx-compile cannot commit an ingest, and the failure surfaces
#       as a silently skipped source rather than an error.
#
#   A2  Both time axes present, and asserted_at != fetched_at as a MAPPING —
#       not necessarily per file (a report harvested the day it published
#       legitimately has both equal), but the adapter must not have wired both
#       to the same source field. Checked across the corpus: if no file anywhere
#       differs, the mapping is collapsed and every point-in-time answer will
#       resolve against acquisition time. This is the single most expensive
#       adapter bug and the least visible.
#
#   A3  asserted_at_source resolves, and the date appears in the passage it
#       resolves to. Delegated to scripts/asserted-at-audit.py so this gate and
#       the valid-time lint cannot disagree about what resolution means.
#
#   A4  body-hash.sh succeeds on every staged file. It is the build-cache key;
#       a file it cannot hash is a file that re-ingests forever or never.
#
#   A5  Slugs match the declared template. The slug is the citation target; an
#       adapter that drifts from its own declaration breaks every anchor.
#
# DELIBERATELY NOT CHECKED HERE: that re-staging is a no-op. It matters — an
# adapter that rewrites unchanged files makes every sync look like a corpus
# change, and on this repo one silently flattened frontmatter it could not
# round-trip, emptying ingested_pages on 261 committed sources. But proving it
# requires RUNNING the stager, and a gate that mutates the tree it is judging is
# a gate that can cause the failure it reports. It belongs in the adapter's own
# verify script, where a side effect is the point. Naming the omission here so
# a green run is not mistaken for a stronger claim than it makes.
#
# FAILURE MODES — the honest ones:
#   1. It proves the output is COMPILABLE, not that it is TRUE. An adapter that
#      faithfully stages the wrong document passes every check here.
#   2. A2 is a corpus-level check. An adapter that maps the axes correctly but
#      mangles one file's date still passes, because one file cannot distinguish
#      a collapsed mapping from a same-day publication.
#   3. It says nothing about the fetch layer — deadlines, retries, pacing,
#      atomicity. Those are properties of a running harvester, not of its output,
#      and this gate only ever reads what landed on disk.
#
# SCOPE: a corpus.json + the raw/ directory its stager produced.
#
# EXIT: 0 = contract satisfied · 1 = a property is violated
#       · 2 = the gate itself failed (no config, no raw/, no python3).
#
# MODES:
#   (default)      check this repository
#   --repo <dir>   check the tree at <dir> — fixture mode
#   --count        print "<violations>TAB<suppressions>" and exit 0
#
# RUNTIME: bash 3.2+ + python3. No LLM, no network, no key.
# WIRED AT: gates/baseline.tsv.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate-lib.sh
. "$SCRIPT_DIR/lib/gate-lib.sh" || { printf 'gate-adapter-contract: cannot source lib/gate-lib.sh\n' >&2; exit 2; }
gate_init "gate-adapter-contract" "ADAPTER-CONTRACT"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  ROOT="${2:-}"; [ -n "$ROOT" ] || gate_die "--repo needs a directory"; shift 2 ;;
    --count) GATE_COUNT_MODE=1; shift ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || gate_die "not a directory: $ROOT"
cd "$ROOT" || gate_die "cannot cd to $ROOT"

gate_need python3

CFG="corpus.json"

# An absent declaration is not a violation: a compiler may legitimately have no
# harvest adapter at all, feeding raw/ by hand through /ctx-extract. This gate
# checks adapters, so with no adapter there is nothing to check — the same
# reasoning scripts/ctx-lint-rules.sh applies to an absent rules/ directory.
#
# The distinction that matters is DECLARED-AND-BROKEN versus NOT-DECLARED. Only
# the first is a failure, and conflating them made a freshly generated compiler
# fail its own installer check for the crime of not yet having a corpus.
if [ ! -r "$CFG" ]; then
  gate_verdict "clean — no $CFG; this package declares no harvest adapter."
fi
[ -d raw ] || gate_die "no raw/ — there is nothing staged to check, which is not the same as the contract holding"

n_files="$(find raw -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
[ "$n_files" -gt 0 ] || gate_die "raw/ holds no .md sources — a clean verdict here would be vacuous"

# One python pass over the corpus: A1, A2 and A5.
REPORT="$(python3 - "$CFG" <<'PY' 2>/dev/null
import json, os, re, sys

REQUIRED = ("source_url", "source_type", "fetched_at", "extraction_method",
            "ingested_hash", "asserted_at")

cfg = json.load(open(sys.argv[1]))
slug_tpl = cfg.get("slug", "")
id_field = cfg.get("id_field", "")

def fm(path):
    out, seen = {}, False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for i, line in enumerate(fh):
            line = line.rstrip("\n")
            if i == 0:
                if line != "---":
                    return {}
                seen = True
                continue
            if line == "---":
                break
            if ":" in line and not line.startswith((" ", "\t", "-")):
                k, v = line.split(":", 1)
                out[k.strip()] = v.strip().strip('"')
    return out if seen else {}

missing, differ, slugbad, total = [], 0, [], 0
for name in sorted(os.listdir("raw")):
    if not name.endswith(".md"):
        continue
    path = os.path.join("raw", name)
    f = fm(path)
    if not f:
        missing.append(f"{name}: no frontmatter")
        continue
    total += 1
    for k in REQUIRED:
        if k not in f:
            missing.append(f"{name}: missing {k}")
    a, t = f.get("asserted_at", ""), f.get("fetched_at", "")
    if a and t and a != t and a != "unknown":
        differ += 1
    # A5: slug must match the declared template.
    if slug_tpl and id_field and f.get(id_field):
        ident = re.sub(r"[^a-z0-9]+", "-", f[id_field].lower()).strip("-")
        want = slug_tpl.replace("{valid}", a).replace("{id}", ident) + ".md"
        if want != name:
            slugbad.append(f"{name}: declared slug would be {want}")

print(json.dumps({"total": total, "missing": missing[:20],
                  "n_missing": len(missing), "differ": differ,
                  "slugbad": slugbad[:10], "n_slugbad": len(slugbad)}))
PY
)" || gate_die "the frontmatter pass failed — check that $CFG is valid JSON"
[ -n "$REPORT" ] || gate_die "the frontmatter pass produced nothing"

jget() { printf '%s' "$REPORT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('$1',''))"; }

# ── A1 — required frontmatter ────────────────────────────────────────────────
if [ "$(jget n_missing)" != "0" ]; then
  printf '%s' "$REPORT" | python3 -c "
import json,sys
for m in json.load(sys.stdin)['missing']: print('  '+m)" >&2
  gate_violation "raw/:1" \
"$(jget n_missing) staged file(s) lack required raw frontmatter (see above).
       /ctx-compile cannot record an ingest commitment without these, and the
       failure surfaces as a silently skipped source rather than an error."
fi

# ── A2 — the two time axes are not the same field ────────────────────────────
if [ "$(jget differ)" = "0" ]; then
  gate_violation "$CFG:1" \
"no staged file anywhere has asserted_at different from fetched_at, which means
       time.valid and time.transaction are wired to the same source field. Every
       point-in-time answer will then resolve against ACQUISITION time: ask what
       was true in 2020 and get what was fetched last week, confidently and with
       a resolving citation. This is the most expensive adapter bug and the least
       visible one — fix the mapping in $CFG."
fi

# ── A5 — slugs match the declaration ─────────────────────────────────────────
if [ "$(jget n_slugbad)" != "0" ]; then
  gate_violation "raw/:1" \
"$(jget n_slugbad) staged file(s) do not match the slug template declared in
       $CFG. The slug is the citation target, so an adapter that drifts from its
       own declaration breaks every anchor pointing at it."
fi

# ── A3 — valid time resolves (delegated, so the two cannot disagree) ─────────
# Helpers resolve from SCRIPT_DIR, never from the tree under test. A fixture is
# a scrap of output, not an installation; looking for scripts/ inside one makes
# every fixture run exit 2 as a setup error instead of exercising the check.
# Third time this exact mistake has appeared today — citation-audit.py, then
# corpus.json, now these.
if [ -x "$SCRIPT_DIR/wiki-lint-asserted-at.sh" ]; then
  # No `cd "$ROOT"` here: we are already inside it, and ROOT is often a RELATIVE
  # path, so cd-ing again resolves against the new working directory and lands
  # somewhere that does not exist. That silently ran the lint in the wrong tree
  # and failed the clean fixture. Fourth appearance of this same shape today.
  "$SCRIPT_DIR/wiki-lint-asserted-at.sh" raw --all >/dev/null 2>&1 || gate_violation "raw/:1" \
"the valid-time contract fails. asserted_at must resolve to a passage that
       actually contains the date. Run: ./scripts/wiki-lint-asserted-at.sh raw --all"
else
  gate_die "$SCRIPT_DIR/wiki-lint-asserted-at.sh missing — A3 cannot run, and skipping it would report a contract satisfied on five of six properties as fully satisfied"
fi

# ── A4 — every staged file hashes ────────────────────────────────────────────
if [ -x "$SCRIPT_DIR/body-hash.sh" ]; then
  bad=0
  for f in raw/*.md; do
    "$SCRIPT_DIR/body-hash.sh" "$f" >/dev/null 2>&1 || bad=$((bad + 1))
  done
  [ "$bad" = 0 ] || gate_violation "raw/:1" \
"$bad staged file(s) fail scripts/body-hash.sh. It is the build-cache key: a
       file it cannot hash either re-ingests on every run or never ingests again,
       and both look like the pipeline working."
else
  gate_die "$SCRIPT_DIR/body-hash.sh missing — A4 cannot run"
fi

gate_verdict "contract satisfied — $(jget total) staged source(s); frontmatter complete, time axes distinct, anchors resolve, all hashable, slugs match $CFG."
