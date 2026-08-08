#!/usr/bin/env bash
# scripts/package-quality.sh — the Context Package Quality scorecard.
#
# The definition this project answers to claims a context package is one that
# LLMs "can navigate, retrieve from, and reason over". An earlier draft said
# "reliably use" and that was wrong: a compiler controls the artifact, not the
# model reading it. Three verbs replaced the adjective because each is a
# property of the artifact — and a property nobody measures is a slogan.
#
# This is the TIER 1 half of that measurement: everything computable from the
# package itself with NO LLM, NO network, and NO spend. It is the floor, not
# the ceiling. A perfect score here proves the package is SOUND — nothing in it
# is unverifiable, unattributed, or unreachable. It does NOT prove the package
# is USEFUL; that is tier 2 (scripts/eval-retrieval.sh and the eval-* family),
# which drives a real model, costs money, and produces dated EVENTS rather than
# recomputable properties. The two must not be printed as one number.
#
# WHY AGGREGATE AT ALL: every measure below already existed, each behind its own
# script with its own output shape. Scattered, they answered "did this specific
# check pass?" and nobody could answer "how good is this package?" without
# running eight things and reading eight formats. A number nobody can obtain in
# one command is a number nobody obtains.
#
# NOTHING IS RECOMPUTED HERE. Each row delegates to the tool that already owns
# that measurement — same reason body-hash.sh is the one hasher. A second
# implementation of "count the citations" would drift from citation-audit.py
# and the scorecard would then measure something the gates do not enforce.
#
# EXIT CONTRACT — report by default, gate on request:
#   (default)  0 always. This is an instrument, not a gate; a repo with known
#              provenance debt must still be able to read its own numbers.
#   --strict   1 if any measure FAILS. Use once the debt is paid, to keep it paid.
#   2          the scorecard itself broke (a delegate is missing/unrunnable).
#
# MODES:
#   (default)     human-readable table
#   --json        machine-readable object, for binding a doc claim or trending
#   --repo <dir>  score the package at <dir> instead of this repository
#
# RUNTIME: bash + python3 (for the delegates). No LLM, no network, no key.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die2() { printf 'package-quality: %s\n' "$1" >&2; exit 2; }

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STRICT=0
JSON=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --json)   JSON=1; shift ;;
    --repo)   ROOT="${2:-}"; [ -n "$ROOT" ] || die2 "--repo needs a directory"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) die2 "unknown argument: $1" ;;
  esac
done

[ -d "$ROOT" ] || die2 "not a directory: $ROOT"
ROOT="$(cd "$ROOT" && pwd)"
[ -d "$ROOT/wiki" ] || die2 "$ROOT has no wiki/ — not a context package"
[ -d "$ROOT/raw" ]  || die2 "$ROOT has no raw/ — not a context package"

for d in citation-audit.py corpus-health.py wiki-lint-commitment.sh \
         wiki-lint-hash-drift.sh asserted-at-audit.py; do
  [ -r "$SCRIPT_DIR/$d" ] || die2 "missing delegate: scripts/$d"
done

cd "$ROOT" || die2 "cannot cd to $ROOT"

if [ -t 1 ] && [ "$JSON" -eq 0 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=; GREEN=; YELLOW=; DIM=; RESET=
fi

fails=0
warns=0
ROWS=()   # name<TAB>verdict<TAB>value<TAB>detail

row() { ROWS+=("$1	$2	$3	$4"); case "$2" in FAIL) fails=$((fails+1));; WARN) warns=$((warns+1));; esac; }

# ---------------------------------------------------------------- provenance

# C1+C2: every (source: ...) resolves to a real raw anchor.
audit_out="$(python3 "$SCRIPT_DIR/citation-audit.py" wiki 2>&1)"; audit_rc=$?
cite_total="$(printf '%s' "$audit_out" | grep -oE '[0-9]+ raw citation' | grep -oE '^[0-9]+' | head -1)"
cite_ok="$(printf '%s' "$audit_out"    | grep -oE '[0-9]+ resolve'      | grep -oE '^[0-9]+' | head -1)"
: "${cite_total:=0}"; : "${cite_ok:=0}"
if [ "$audit_rc" -eq 0 ] && [ "$cite_total" -gt 0 ]; then
  row "citation resolution" PASS "$cite_ok/$cite_total" "every citation lands on a real raw anchor"
elif [ "$cite_total" -eq 0 ]; then
  row "citation resolution" WARN "0/0" "no citations in this package yet"
else
  row "citation resolution" FAIL "$cite_ok/$cite_total" "$((cite_total - cite_ok)) citation(s) do not resolve"
fi

# Coverage: no claim-bearing page is unsourced.
if python3 "$SCRIPT_DIR/citation-audit.py" wiki --coverage >/dev/null 2>&1; then
  row "citation coverage" PASS "0 gaps" "every claim-bearing page carries a resolving citation"
else
  gaps="$(python3 "$SCRIPT_DIR/citation-audit.py" wiki --coverage 2>&1 | grep -cE '^\s*wiki/' || true)"
  row "citation coverage" FAIL "${gaps:-?} gap(s)" "claim-bearing page(s) with no resolving citation"
fi

# Ingest commitment: a cited source with no derived ingested_hash makes every
# citation into its body unverifiable AND disables drift detection for it.
commit_out="$(bash "$SCRIPT_DIR/wiki-lint-commitment.sh" 2>&1)"; commit_rc=$?
commit_num="$(printf '%s' "$commit_out" | grep -oE '[0-9]+ of [0-9]+ cited source' | head -1)"
if [ "$commit_rc" -eq 0 ]; then
  row "ingest commitment" PASS "all cited sources" "every cited source carries a derived ingested_hash"
else
  row "ingest commitment" FAIL "${commit_num:-see detail}" "lack a commitment — their citations cannot be verified"
fi

# Hash drift: a cited body that changed after the ingest that cited it.
drift_out="$(bash "$SCRIPT_DIR/wiki-lint-hash-drift.sh" 2>&1)"; drift_rc=$?
if [ "$drift_rc" -eq 0 ]; then
  row "hash drift" PASS "0 drifted" "no cited body changed since the ingest that cited it"
else
  drift_n="$(printf '%s' "$drift_out" | grep -cE '^raw/' || true)"
  row "hash drift" FAIL "${drift_n:-?} drifted" "cited source(s) changed after being cited"
fi

# Valid time: without asserted_at an as-of question has nothing to resolve against.
va_out="$(python3 "$SCRIPT_DIR/asserted-at-audit.py" raw 2>&1)"; va_rc=$?
va_num="$(printf '%s' "$va_out" | grep -oE '[0-9]+ source\(s\) violate' | grep -oE '^[0-9]+' | head -1)"
if [ "$va_rc" -eq 0 ]; then
  row "valid time" PASS "0 violations" "every source records its own date, or an explicit unknown"
else
  row "valid time" FAIL "${va_num:-?} violation(s)" "source(s) with no asserted_at — as-of queries cannot resolve"
fi

# --------------------------------------------------------------- navigability

# corpus-health.py --json is the machine-readable contract; the human table is
# not. Parsing the prose would mean re-deriving field boundaries that the JSON
# already names — and it goes wrong quietly: "thin (<2 related): 0" carries a 2
# inside its own label, so a first-number grab reports the THRESHOLD as the
# count. Read the JSON.
health_json="$(python3 "$SCRIPT_DIR/corpus-health.py" . --json 2>&1)" \
  || die2 "corpus-health.py --json failed"

# One python call emits `key=value` lines; the shell reads named fields only.
hv_all="$(printf '%s' "$health_json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    sys.stderr.write("corpus-health JSON unreadable: %s\n" % e); sys.exit(2)
for k in ("claim_density", "orphan_pct", "thin_pages_lt2_related",
          "max_degree_share_pct", "graph_diameter", "verbatim_overlap_pct"):
    v = d.get(k)
    print("%s=%s" % (k, "" if v is None else v))
')" || die2 "could not read corpus-health fields"

hv() { printf '%s' "$hv_all" | sed -nE "s/^$1=(.*)$/\1/p" | head -1; }

density="$(hv claim_density)"
if [ -n "$density" ]; then
  # A3 density floor: a page with a single citation is thinly sourced.
  if awk "BEGIN{exit !($density >= 1.0)}"; then
    row "citation density" PASS "$density /page" "citations per claim-bearing page (A3 floor)"
  else
    row "citation density" WARN "$density /page" "below the A3 density floor of 1.0"
  fi
fi

orph="$(hv orphan_pct)"
if [ -n "$orph" ]; then
  if awk "BEGIN{exit !($orph <= 5.0)}"; then
    row "orphan rate" PASS "${orph}%" "unreachable pages (A4 target <= 5%)"
  else
    row "orphan rate" FAIL "${orph}%" "exceeds the A4 target of 5% — pages nothing links to"
  fi
fi

thin="$(hv thin_pages_lt2_related)"
if [ -n "$thin" ]; then
  if [ "$thin" -eq 0 ]; then
    row "link connectivity" PASS "0 thin" "every content page has >= 2 outbound links (A4 target 0)"
  else
    row "link connectivity" FAIL "$thin thin" "page(s) with < 2 outbound links — nearly orphaned"
  fi
fi

hub="$(hv max_degree_share_pct)"
if [ -n "$hub" ]; then
  # Star topology: one node touching most of the graph means traversal
  # degenerates to "go through the hub", which is a list wearing a graph's hat.
  if awk "BEGIN{exit !($hub <= 50.0)}"; then
    row "hub concentration" PASS "${hub}%" "no single page dominates the graph (star-topology guard)"
  else
    row "hub concentration" WARN "${hub}%" "one page touches most others — traversal is degenerating to a star"
  fi
fi

diam="$(hv graph_diameter)"
if [ -n "$diam" ]; then
  if [ "$diam" -ge 3 ]; then
    row "graph depth" PASS "diameter $diam" "multi-hop traversal has somewhere to go (hub-and-spoke reads 2)"
  else
    row "graph depth" WARN "diameter $diam" "hub-and-spoke — little for multi-hop retrieval to traverse"
  fi
fi

verb="$(hv verbatim_overlap_pct)"
if [ -n "$verb" ]; then
  # A4 transcription test: high verbatim overlap means the build transcribed
  # rather than synthesized — the output is a copy, not compiled context.
  if awk "BEGIN{exit !($verb <= 20.0)}"; then
    row "synthesis (not copying)" PASS "${verb}% verbatim" "wiki 12-grams appearing verbatim in raw (A4 transcription test)"
  else
    row "synthesis (not copying)" WARN "${verb}% verbatim" "high overlap — the build may be transcribing rather than synthesizing"
  fi
fi

# ------------------------------------------------------------------- output

if [ "$JSON" -eq 1 ]; then
  printf '{\n  "package": "%s",\n  "tier": "structural",\n  "measures": [\n' "$(basename "$ROOT")"
  n=${#ROWS[@]}; i=0
  for r in "${ROWS[@]}"; do
    i=$((i+1))
    IFS=$'\t' read -r name verdict value detail <<<"$r"
    printf '    {"measure": "%s", "verdict": "%s", "value": "%s", "detail": "%s"}' \
      "$name" "$verdict" "$value" "$detail"
    [ "$i" -lt "$n" ] && printf ',\n' || printf '\n'
  done
  printf '  ],\n  "failed": %d,\n  "warned": %d,\n  "total": %d\n}\n' "$fails" "$warns" "${#ROWS[@]}"
else
  printf '\n%sContext Package Quality — %s%s\n' "$DIM" "$(basename "$ROOT")" "$RESET"
  printf '%stier 1: structural. no LLM, no network, recomputed on demand.%s\n\n' "$DIM" "$RESET"
  for r in "${ROWS[@]}"; do
    IFS=$'\t' read -r name verdict value detail <<<"$r"
    case "$verdict" in
      PASS) mark="${GREEN}✓${RESET}" ;;
      WARN) mark="${YELLOW}!${RESET}" ;;
      *)    mark="${RED}✗${RESET}" ;;
    esac
    printf '  %s %-24s %-18s %s%s%s\n' "$mark" "$name" "$value" "$DIM" "$detail" "$RESET"
  done
  printf '\n'
  if [ "$fails" -eq 0 ] && [ "$warns" -eq 0 ]; then
    printf '  %s%d/%d structural measures pass.%s\n' "$GREEN" "${#ROWS[@]}" "${#ROWS[@]}" "$RESET"
  else
    printf '  %d of %d pass · %s%d fail%s · %s%d warn%s\n' \
      "$(( ${#ROWS[@]} - fails - warns ))" "${#ROWS[@]}" \
      "$RED" "$fails" "$RESET" "$YELLOW" "$warns" "$RESET"
  fi
  printf '\n  %sThis is the floor: it proves the package is SOUND, not that it is USEFUL.\n' "$DIM"
  printf '  Usefulness is tier 2 — scripts/eval-retrieval.sh and the eval-* family,\n'
  printf '  which drive a real model, cost spend, and produce DATED events.%s\n\n' "$RESET"
fi

[ "$STRICT" -eq 1 ] && [ "$fails" -gt 0 ] && exit 1
exit 0
