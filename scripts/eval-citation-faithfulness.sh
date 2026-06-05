#!/usr/bin/env bash
# scripts/eval-citation-faithfulness.sh — measure how faithful the wiki's claims
# are to their cited raw sources. Produces a NUMBER, not prose.
#
# The system promises every non-trivial claim traces to raw via
# `(source: raw/<file>#<anchor>)`. This decomposes into per-citation checks:
#
#   C1  file resolves    — raw/<file> exists                       [deterministic]
#   C2  anchor resolves   — <anchor> is locatable in that raw        [deterministic]
#   C3  entailment        — the cited passage SUPPORTS the claim      [LLM judge]
#
#   faithfulness rate = (citations passing C1 ∧ C2 ∧ C3) / (total raw citations)
#
# C1+C2 are the deterministic floor (scripts/citation-audit.py) — free, CI-able,
# catches fabricated/broken citations. C3 is the real signal: a separate
# `claude -p` grader, adversarially prompted (default UNFAITHFUL), run over a
# sample of the citations that clear the floor.
#
# Philosophy (mirrors eval-multi-hop.sh): the deliverable is the measurement.
# Exit 0 if the harness COMPLETED. Non-zero only on setup failure, or when
# --min-rate is given and the measured rate falls below it.
#
# Usage:
#   scripts/eval-citation-faithfulness.sh [<wiki-dir>] [--raw <dir>]
#                                         [--sample N | --all] [--no-judge]
#                                         [--min-rate <0..1>]
#
# Defaults: <wiki-dir>=wiki, raw=<wiki-dir>/../raw, --sample 8.
#
# Exit codes:
#   0  harness completed (rate reported; >= --min-rate if given)
#   1  measured faithfulness rate below --min-rate
#   2  setup error (missing python3 / audit / wiki dir)
#   3  no LLM judge available and judging was required (no --no-judge)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/citation-audit.py"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=; GREEN=; YELLOW=; DIM=; RESET=
fi

wiki_dir="wiki"
raw_dir=""
sample=8
judge=1
min_rate=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --raw) raw_dir="$2"; shift 2 ;;
    --sample) sample="$2"; shift 2 ;;
    --all) sample=0; shift ;;
    --no-judge) judge=0; shift ;;
    --min-rate) min_rate="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -*) echo "error: unknown flag $1" >&2; exit 2 ;;
    *) wiki_dir="$1"; shift ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "error: python3 required" >&2; exit 2; }
[ -f "$AUDIT" ] || { echo "error: citation-audit.py not found at $AUDIT" >&2; exit 2; }
[ -d "$wiki_dir" ] || { echo "error: not a directory: $wiki_dir" >&2; exit 2; }

command -v openssl >/dev/null 2>&1 || { echo "error: openssl required (base64 decode)" >&2; exit 2; }

audit_args=("$wiki_dir" --tsv)
[ -n "$raw_dir" ] && audit_args+=(--raw "$raw_dir")

# Deterministic floor (C1+C2) as base64-TSV rows (claim/evidence are b64 so they
# carry newlines/tabs through `read` safely — see citation-audit.py --tsv).
cites_tsv="$(python3 "$AUDIT" "${audit_args[@]}")" || { echo "error: audit failed" >&2; exit 2; }

decode() { printf '%s' "$1" | openssl base64 -d -A; }

total=$(printf '%s\n' "$cites_tsv" | grep -c . || true)
if [ "$total" -eq 0 ]; then
  echo "citation-faithfulness — $wiki_dir"
  echo "  no raw citations found. (Nothing to measure — interpretive pages cite no raw.)"
  exit 0
fi

# The grader: strict, adversarial, default UNFAITHFUL.
judge_one() {  # $1=claim $2=evidence  -> prints FAITHFUL | UNFAITHFUL
  local claim="$1" evidence="$2" out verdict
  # Demand a parseable token on the FINAL line. The model tends to echo the
  # option words while reasoning, so we parse `VERDICT=...` (not bare FAITHFUL)
  # and take the LAST match — the verdict, not the echoed instruction.
  local prompt="You are a strict citation auditor. Decide whether the EVIDENCE supports the CLAIM.
Reason in one sentence, then on the FINAL line output exactly one of these tokens, nothing else on that line:
VERDICT=FAITHFUL
VERDICT=UNFAITHFUL
Rule: choose VERDICT=UNFAITHFUL unless the evidence clearly and directly supports the claim. Contradiction, unrelated, or only loose support => VERDICT=UNFAITHFUL.

CLAIM: ${claim}

EVIDENCE:
${evidence}"
  # Arg-style invocation + </dev/null (matches eval-multi-hop.sh; avoids the
  # stdin-wait delay). Quoting "$prompt" does not re-expand its contents.
  out="$(claude -p "$prompt" </dev/null 2>/dev/null)" || out=""
  verdict="$(printf '%s\n' "$out" | grep -oiE 'VERDICT=(UN)?FAITHFUL' | tail -1 | tr '[:lower:]' '[:upper:]')"
  case "$verdict" in
    *UNFAITHFUL*) echo "UNFAITHFUL" ;;
    *FAITHFUL*)   echo "FAITHFUL" ;;
    *)            echo "UNFAITHFUL" ;;   # default-closed: unparseable => not faithful
  esac
}

floor_fail=0
declare -a fail_lines=()
# First pass: count + record floor failures (deterministic; no decode needed).
while IFS=$'\t' read -r tag page line file anchor c1 _c2 _claim_b64 _evidence_b64; do
  [ -n "$tag" ] || continue
  if [ "$tag" = "BAD" ]; then
    floor_fail=$((floor_fail + 1))
    why=$([ "$c1" = 0 ] && echo "file missing" || echo "anchor unresolved")
    a=$([ -n "$anchor" ] && echo "#$anchor" || echo "")
    fail_lines+=("  ${RED}✗${RESET} $page:$line -> raw/$file$a ($why)")
  fi
done <<< "$cites_tsv"

floor_ok=$((total - floor_fail))

echo "citation-faithfulness — $wiki_dir"
echo "${DIM}C1+C2 deterministic floor:${RESET} $floor_ok/$total citations resolve (broken: $floor_fail)"

# C3 entailment judge over a sample of floor-OK citations.
judged=0; faithful=0; unfaithful=0
if [ "$judge" -eq 1 ]; then
  if ! command -v claude >/dev/null 2>&1; then
    echo "${YELLOW}⚠ C3 skipped:${RESET} no 'claude' CLI on PATH. Floor reported above; re-run with claude installed (or --no-judge to silence)."
    [ "$floor_fail" -gt 0 ] && printf '%s\n' "${fail_lines[@]}"
    exit 3
  fi
  while IFS=$'\t' read -r tag page line file anchor _c1 _c2 claim_b64 evidence_b64; do
    [ "$tag" = "OK" ] || continue
    [ "$sample" -ne 0 ] && [ "$judged" -ge "$sample" ] && continue
    claim="$(decode "$claim_b64")"
    ev="$(decode "$evidence_b64")"
    v="$(judge_one "$claim" "$ev")"
    judged=$((judged + 1))
    if [ "$v" = "FAITHFUL" ]; then
      faithful=$((faithful + 1))
    else
      unfaithful=$((unfaithful + 1))
      a=$([ -n "$anchor" ] && echo "#$anchor" || echo "")
      fail_lines+=("  ${RED}✗${RESET} $page:$line -> raw/$file$a (UNFAITHFUL: evidence doesn't support \"$claim\")")
    fi
  done <<< "$cites_tsv"
  echo "${DIM}C3 entailment judge:${RESET} judged $judged sampled — faithful $faithful, unfaithful $unfaithful"
else
  echo "${DIM}C3 entailment judge:${RESET} skipped (--no-judge); floor only"
fi

# The number: resolve ∧ entail over the judged sample (floor-broken count as unfaithful too).
# Report two figures: the sampled faithfulness rate, and the floor pass rate.
echo
if [ "$judge" -eq 1 ] && [ "$judged" -gt 0 ]; then
  rate=$(python3 -c "print(f'{$faithful/$judged:.3f}')")
  pct=$(python3 -c "print(f'{100*$faithful/$judged:.1f}')")
  echo "${GREEN}faithfulness rate (sampled, resolve ∧ entail):${RESET} $faithful/$judged = ${pct}%"
fi
echo "${GREEN}citation-resolution rate (C1∧C2, all):${RESET} $floor_ok/$total = $(python3 -c "print(f'{100*$floor_ok/$total:.1f}')")%"

if [ "${#fail_lines[@]}" -gt 0 ]; then
  echo; echo "${DIM}failing citations:${RESET}"
  printf '%s\n' "${fail_lines[@]}"
fi

# Optional CI gate on the sampled faithfulness rate.
if [ -n "$min_rate" ] && [ "$judge" -eq 1 ] && [ "$judged" -gt 0 ]; then
  below=$(python3 -c "print(1 if $faithful/$judged < $min_rate else 0)")
  if [ "$below" -eq 1 ]; then
    echo; echo "${RED}FAIL:${RESET} faithfulness rate $rate < --min-rate $min_rate"
    exit 1
  fi
fi
exit 0
