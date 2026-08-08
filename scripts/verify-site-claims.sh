#!/usr/bin/env bash
# scripts/verify-site-claims.sh — the public page states numbers; this checks
# they are still true.
#
# site/index.html was the only artifact in this repo with nothing verifying it,
# and it rotted within hours of being published: it advertised "31 deterministic
# smoke checks" (the suite ran 26 in the CI configuration), "8 binary checks"
# (there are 10) and "21/21" (a superseded run). Every script here has an
# oracle; the page that makes claims to strangers had none.
#
# Structural claims are recomputed from the repo. Run-result claims (scores)
# cannot be — a score is an event, not a property — so those are required to
# carry a date, which turns silent rot into a visibly old number.
#
# Exit: 0 all claims hold, 1 otherwise.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

PAGE="site/index.html"
[ -f "$PAGE" ] || { echo "verify-site-claims: $PAGE missing" >&2; exit 1; }

fails=0
ok()   { echo "  ok: $1"; }
bad()  { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }

# claimed <label-substring> — the <b> value of the stat tile whose <span> matches
claimed() {
  grep -oE "<b>[^<]+</b><span>[^<]*$1[^<]*</span>" "$PAGE" \
    | sed -e 's|<b>||' -e 's|</b>.*||' -e 's/ //g' | head -1
}

# S1 — smoke check count. smoke-all.sh counts its own passes at runtime; the
# static tally of ok "…" call sites equals that count (verified when the literal
# was replaced by a counter). If the two ever diverge, THAT is the bug.
want_smoke=$(grep -c '^[[:space:]]*ok "' scripts/smoke-all.sh)
got_smoke=$(claimed "smoke checks")
if [ "$got_smoke" = "$want_smoke" ]; then
  ok "S1 smoke-check count on the page ($got_smoke) matches scripts/smoke-all.sh"
else
  bad "S1 page claims $got_smoke smoke checks, scripts/smoke-all.sh has $want_smoke"
fi

# S2 — retrieval-eval check count, from the report block the eval actually prints.
want_checks=$(grep -cE '^(R[1-5]|M[1-6]) [a-z]' scripts/eval-retrieval.sh)
got_checks=$(claimed "binary retrieval checks")
if [ "$got_checks" = "$want_checks" ]; then
  ok "S2 binary-check count on the page ($got_checks) matches the eval's report block"
else
  bad "S2 page claims $got_checks binary checks, eval-retrieval.sh reports $want_checks"
fi

# S3 — slash-command count: the five core commands the page calls "the whole
# interface". Output/aux commands (visualize, flashcards, diagram, discover) are
# deliberately not counted; if that framing changes, the page must change too.
want_cmds=0
for c in init extract ingest query lint; do
  [ -f ".claude/commands/wiki-$c.md" ] && want_cmds=$((want_cmds + 1))
done
got_cmds=$(claimed "slash commands")
if [ "$got_cmds" = "$want_cmds" ]; then
  ok "S3 command count on the page ($got_cmds) matches .claude/commands/"
else
  bad "S3 page claims $got_cmds commands, found $want_cmds core command files"
fi

# S4 — every run-result score on the page carries a date. A score is an event;
# undated it reads as a standing property and rots invisibly.
undated=0
while IFS= read -r line; do
  case "$line" in *[0-9]" / "[0-9]*|*[0-9]"/"[0-9]*) ;; *) continue ;; esac
  # Tile spans are structural context, not standalone claims; prose must date.
  case "$line" in *"<span>"*) continue ;; esac
  printf '%s' "$line" | grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}|at 19 pages|at 495 pages|495 pages' \
    || { bad "S4 undated score claim: $(printf '%s' "$line" | sed 's/<[^>]*>//g' | cut -c1-90)"; undated=1; }
done < <(grep -nE '[0-9]+ ?/ ?[0-9]+' "$PAGE" | grep -v 'minmax\|1fr\|/>' | cut -d: -f2-)
[ "$undated" -eq 0 ] && ok "S4 every score claim on the page is dated or scale-qualified"

# S5 — the page must not resurrect a number the repo has moved past. Cheap
# tripwire on the exact figures that were wrong.
#
# `31</b><span>deterministic` was on this list: the page once claimed 31 while
# the suite had 30. R28 (the /ctx-query temporal contract) made 31 the true
# count, so the tripwire started firing on the CORRECT figure. Removed rather
# than bumped — a hardcoded list of wrong numbers has to be retired as the repo
# grows past them, or it outlives the error it was written for and blocks the
# truth. S1/S6 already check this count dynamically against the suite itself.
stale=0
for n in "8 binary" "21 / 21</b>"; do
  grep -qF "$n" "$PAGE" && { bad "S5 superseded claim present: $n"; stale=1; }
done
[ "$stale" -eq 0 ] && ok "S5 no superseded figures resurrected"

# S6 — the README states the same counts to a different audience. Two documents
# quoting one number will drift apart the moment only one is updated; that is
# exactly what happened here (the page was corrected, the README kept the old
# figure in the same commit). Same source of truth, checked in the same place.
if [ -f README.md ]; then
  readme_smoke=$(grep -oE 'smoke-all\.sh` — [0-9]+ deterministic checks' README.md \
                 | grep -oE '[0-9]+' | head -1)
  readme_checks=$(grep -oE 'against [0-9]+ binary checks' README.md | grep -oE '[0-9]+' | head -1)
  if [ "$readme_smoke" = "$want_smoke" ]; then
    ok "S6 README smoke count ($readme_smoke) agrees with the suite and the page"
  else
    bad "S6 README claims $readme_smoke smoke checks, suite has $want_smoke (page says $got_smoke)"
  fi
  if [ "$readme_checks" = "$want_checks" ]; then
    ok "S6 README binary-check count ($readme_checks) agrees with the eval and the page"
  else
    bad "S6 README claims $readme_checks binary checks, eval reports $want_checks"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "verify-site-claims: the published page's claims still hold."
  exit 0
fi
echo "verify-site-claims: $fails claim(s) on site/index.html no longer hold" >&2
exit 1
