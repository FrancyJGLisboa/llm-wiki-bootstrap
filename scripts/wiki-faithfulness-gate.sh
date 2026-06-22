#!/usr/bin/env bash
# scripts/wiki-faithfulness-gate.sh — ingest/promote-time faithfulness gate.
#
# For each target wiki page, extracts every (source: raw/<file>#<anchor>) claim
# via scripts/citation-audit.py (REUSED — no second citation parser), judges each
# resolving claim against its cited evidence with a 3-way verdict
# (SUPPORTED | UNSUPPORTED | CONTRADICTED), and applies an asymmetric policy:
#
#   CONTRADICTED  -> block (exit 3) in BOTH modes
#   BAD floor row -> block (exit 3) in BOTH modes   (broken citation pointer)
#   non-raw cite  -> block (exit 3) in BOTH modes: a `(source: X)` whose target
#                    isn't raw/<file> or 'analysis' must be snapshotted to raw/
#                    first (reuses citation-audit.py --no-bare-urls allowlist)
#   UNSUPPORTED   -> block (exit 3) in --mode promote;
#                    in --mode ingest, append a FAITHFULNESS UNVERIFIED marker to
#                    the claim's line (line count preserved) and pass
#   SUPPORTED     -> pass
#
# The verdict source is INJECTABLE so the deterministic oracle can run offline:
#   --verdicts <file>  : look verdicts up by "<page-relpath>:<line>" (TAB) VERDICT;
#                        a missing key defaults to UNSUPPORTED (default-closed);
#                        NO `claude` call is made on this path.
#   (no --verdicts)    : call `claude -p` with a strict, default-closed 3-way prompt.
#
# C3 entailment inherently needs an LLM, so this is a WRITE-TIME gate (ingest +
# promote), not a keyless-CI gate. The deterministic floor that CI/offline enforces
# is citation-audit C1/C2 (+ --coverage); C3 entailment runs here when a judge is
# present, and FAILS CLOSED (exit 3) when none is — unless --allow-unjudged is set.
#
# Usage:
#   wiki-faithfulness-gate.sh --mode ingest|promote [--raw <dir>] \
#                             [--verdicts <file>] [--allow-unjudged] <page.md> [<page.md> ...]
#
# Flags:
#   --allow-unjudged   : proceed when no judge is available (no claude, no --verdicts);
#                        prints a loud FAITHFULNESS UNVERIFIED warning and enforces only
#                        the citation floor (C1/C2). Default = fail closed (exit 3).
#
# Exit: 0 = all pass / only ingest-flagged; 3 = blocked; 2 = usage/setup error.
#
# Portable to bash 3.2 (macOS): no associative arrays.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/citation-audit.py"

mode=""; raw_dir=""; verdicts=""; allow_unjudged=0
pages=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) mode="$2"; shift 2 ;;
    --raw) raw_dir="$2"; shift 2 ;;
    --verdicts) verdicts="$2"; shift 2 ;;
    --allow-unjudged) allow_unjudged=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -*) echo "error: unknown flag $1" >&2; exit 2 ;;
    *) pages+=("$1"); shift ;;
  esac
done

case "$mode" in ingest|promote) ;; *) echo "error: --mode must be ingest|promote" >&2; exit 2 ;; esac
[ "${#pages[@]}" -gt 0 ] || { echo "error: at least one target page required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 required" >&2; exit 2; }
command -v openssl >/dev/null 2>&1 || { echo "error: openssl required" >&2; exit 2; }
[ -f "$AUDIT" ] || { echo "error: citation-audit.py not found at $AUDIT" >&2; exit 2; }
[ -n "$verdicts" ] && [ ! -f "$verdicts" ] && { echo "error: verdicts file not found: $verdicts" >&2; exit 2; }

# Fail CLOSED: with no injected verdicts AND no judge available we cannot assess
# entailment. A faithfulness gate must not pass what it could not check, so we
# BLOCK (exit 3) by default. The escape hatch is explicit and loud: --allow-unjudged
# proceeds (the deterministic citation floor C1/C2 + BAD-row check still runs) while
# printing a warning that entailment was NOT verified.
unjudged=0
if [ -z "$verdicts" ] && ! command -v claude >/dev/null 2>&1; then
  if [ "$allow_unjudged" -eq 1 ]; then
    unjudged=1
    echo "faithfulness-gate: FAITHFULNESS UNVERIFIED (--allow-unjudged) — no 'claude' CLI and no --verdicts; entailment NOT checked. Only the citation floor (C1/C2) is enforced below." >&2
  else
    echo "faithfulness-gate: BLOCKED — no entailment judge available (no 'claude' CLI on PATH and no --verdicts). A faithfulness gate fails closed. Install the claude CLI, pass --verdicts <file>, or re-run with --allow-unjudged to proceed without entailment checking (citation floor only)." >&2
    exit 3
  fi
fi

WANT="$(mktemp)"; ROOTS="$(mktemp)"; MARKS="$(mktemp)"
trap 'rm -f "$WANT" "$ROOTS" "$MARKS"' EXIT

decode() { printf '%s' "$1" | openssl base64 -d -A; }

# wiki root for a page = path up to and including its nearest 'wiki' ancestor
# (so citation-audit's default raw = <root>/../raw resolves, and the `page`
# column is the relpath we key verdicts on). Falls back to the page's own dir.
resolve_root() {
  local abs d root=""
  abs="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  d="$(dirname "$abs")"
  while [ "$d" != "/" ]; do
    [ "$(basename "$d")" = "wiki" ] && { root="$d"; break; }
    d="$(dirname "$d")"
  done
  [ -z "$root" ] && root="$(dirname "$abs")"
  echo "$root"
}

# 3-way judge: strict, adversarial, default-closed (unparseable => UNSUPPORTED).
judge_claude() {  # $1=claim $2=evidence
  local claim="$1" evidence="$2" out verdict
  local prompt="You are a strict citation auditor. Decide whether the EVIDENCE supports the CLAIM.
Reason in one sentence, then on the FINAL line output exactly one token, nothing else:
VERDICT=SUPPORTED
VERDICT=UNSUPPORTED
VERDICT=CONTRADICTED
Rules: SUPPORTED only if the evidence clearly and directly supports the claim. CONTRADICTED if the evidence states the opposite. Otherwise (unrelated / only loose support) UNSUPPORTED.

CLAIM: ${claim}

EVIDENCE:
${evidence}"
  out="$(claude -p "$prompt" </dev/null 2>/dev/null)" || out=""
  verdict="$(printf '%s\n' "$out" | grep -oiE 'VERDICT=(SUPPORTED|UNSUPPORTED|CONTRADICTED)' | tail -1 | tr '[:lower:]' '[:upper:]')"
  case "$verdict" in
    *CONTRADICTED*) echo CONTRADICTED ;;
    *SUPPORTED*)    echo SUPPORTED ;;
    *)              echo UNSUPPORTED ;;
  esac
}

lookup_verdict() {  # $1=page $2=line  -> verdict (default-closed: UNSUPPORTED)
  local v
  v="$(awk -F'\t' -v k="$1:$2" '$1==k{print $2; exit}' "$verdicts")"
  case "$v" in SUPPORTED|UNSUPPORTED|CONTRADICTED) echo "$v" ;; *) echo UNSUPPORTED ;; esac
}

# Map target pages to (root, relpath); collect unique roots.
for p in "${pages[@]}"; do
  [ -f "$p" ] || { echo "error: not a file: $p" >&2; exit 2; }
  root="$(resolve_root "$p")"
  abs="$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
  rel="${abs#"$root"/}"
  printf '%s\n' "$root" >> "$ROOTS"
  printf '%s\t%s\n' "$root" "$rel" >> "$WANT"
done

# Citation-target floor (BOTH modes): a target page must not carry a citation
# whose target isn't on the allowlist (raw/<file> or 'analysis'). A web source
# must be snapshotted into raw/ first and cited as raw/ — only then is the claim
# coverage-counted and entailment-checkable. This makes both /wiki-ingest and
# /wiki-query promotion mechanically unable to leave a non-raw cite.
# REUSES citation-audit.py --no-bare-urls per target-page root (deterministic,
# raw-dir-independent). Runs on ingest too: an ingest-produced page must not carry
# a non-raw external citation either.
bare=0
while IFS= read -r root; do
  [ -n "$root" ] || continue
  rep="$(python3 "$AUDIT" "$root" --no-bare-urls 2>/dev/null)" || true
  while IFS= read -r hitline; do
    # hitline: "  ✗ <page>:<line> -> (source: <target>)" — only block target pages.
    pg="${hitline#*✗ }"; pg="${pg%%:*}"
    grep -Fxq "$(printf '%s\t%s' "$root" "$pg")" "$WANT" || continue
    bare=$((bare + 1))
    echo "  BLOCK ${hitline#  }  (non-raw citation: snapshot to raw/ and cite raw/<slug>#<anchor>, or use 'analysis')"
  done < <(printf '%s\n' "$rep" | grep -E '✗ .*-> \(source: ')
done < <(sort -u "$ROOTS")

judged=0; blocked=0
while IFS= read -r root; do
  [ -n "$root" ] || continue
  audit_args=("$root" --tsv)
  [ -n "$raw_dir" ] && audit_args+=(--raw "$raw_dir")
  tsv="$(python3 "$AUDIT" "${audit_args[@]}")" || { echo "error: audit failed for $root" >&2; exit 2; }

  while IFS=$'\t' read -r tag page line file anchor _c1 _c2 claim_b64 evidence_b64; do
    [ -n "${tag:-}" ] || continue
    grep -Fxq "$(printf '%s\t%s' "$root" "$page")" "$WANT" || continue   # target pages only
    a=$([ -n "$anchor" ] && echo "#$anchor" || echo "")
    absfile="$root/$page"

    if [ "$tag" = "BAD" ]; then
      blocked=$((blocked + 1))
      echo "  BLOCK  $page:$line -> raw/$file$a (broken citation: floor C1/C2 fail)"
      continue
    fi

    if [ "$unjudged" -eq 1 ]; then
      # No judge available but --allow-unjudged: floor (BAD rows above) is enforced,
      # entailment is not. Report and pass this claim without counting it as judged.
      echo "  unver  $page:$line -> raw/$file$a (entailment UNVERIFIED; --allow-unjudged)"
      continue
    fi

    judged=$((judged + 1))
    if [ -n "$verdicts" ]; then
      v="$(lookup_verdict "$page" "$line")"
    else
      v="$(judge_claude "$(decode "$claim_b64")" "$(decode "$evidence_b64")")"
    fi

    case "$v" in
      SUPPORTED)
        echo "  ok     $page:$line -> raw/$file$a (SUPPORTED)" ;;
      CONTRADICTED)
        blocked=$((blocked + 1))
        echo "  BLOCK  $page:$line -> raw/$file$a (CONTRADICTED)" ;;
      UNSUPPORTED)
        if [ "$mode" = "promote" ]; then
          blocked=$((blocked + 1))
          echo "  BLOCK  $page:$line -> raw/$file$a (UNSUPPORTED; blocked on promote)"
        else
          printf '%s\t%s\t%s\n' "$absfile" "$line" \
            "<!-- FAITHFULNESS UNVERIFIED: raw/$file$a does not clearly support this claim -->" >> "$MARKS"
          echo "  FLAG   $page:$line -> raw/$file$a (UNSUPPORTED; marked for lint)"
        fi ;;
    esac
  done <<< "$tsv"
done < <(sort -u "$ROOTS")

# Append markers to the END of each flagged line (line count preserved; idempotent).
if [ -s "$MARKS" ]; then
  while IFS= read -r absfile; do
    [ -n "$absfile" ] || continue
    while IFS= read -r ln; do
      [ -n "$ln" ] || continue
      marker="$(awk -F'\t' -v f="$absfile" -v n="$ln" '$1==f && $2==n{print $3; exit}' "$MARKS")"
      awk -v n="$ln" -v m=" $marker" 'NR==n && index($0,m)==0 {$0=$0 m} {print}' "$absfile" > "$absfile.tmp" \
        && mv "$absfile.tmp" "$absfile"
    done < <(awk -F'\t' -v f="$absfile" '$1==f{print $2}' "$MARKS" | sort -un)
  done < <(cut -f1 "$MARKS" | sort -u)
fi

blocked=$((blocked + bare))
echo "faithfulness-gate (--mode $mode): judged $judged claim(s), blocked $blocked ($bare bare-url)"
[ "$blocked" -gt 0 ] && exit 3
exit 0
