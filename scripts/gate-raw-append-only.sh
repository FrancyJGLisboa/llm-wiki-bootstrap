#!/usr/bin/env bash
# scripts/gate-raw-append-only.sh — gate RAW-APPEND-ONLY.
#
# RULE: `raw/` is append-only. A change to an existing raw source may touch
# nothing but the three ingest-commitment frontmatter fields — `ingested_hash`,
# `ingested_at`, `ingested_pages` — written as the last step of /wiki-ingest.
# Adding a new raw file is always allowed. Editing a body, changing any other
# frontmatter field, deleting a source, or renaming one is not.
#
# WHY THIS GATE EXISTS: this is hard rule #1 (AGENTS.md "What the LLM must NOT
# do", item 1; CLAUDE.md rule 1) and until now it lived only in prose. Every
# other gate in this repo rests on it. `raw/` is the evidence layer: citations
# resolve into it (citation-audit.py), hash-drift detection compares against it
# (wiki-lint-hash-drift.sh), the faithfulness gate entails claims from it. If a
# raw body is quietly edited, hash-drift fires on the SYMPTOM — "the body moved,
# re-ingest" — and the actual event, an unauthorised write to immutable
# evidence, is never named. Silent corruption of the substrate.
#
# DETECTION: a unified-diff parser, not a file linter. The rule is about a
# CHANGE, so the artifact examined is the diff. For each file under `raw/`:
#   - new file           -> allowed outright (extract)
#   - deleted / renamed  -> violation
#   - modified           -> every +/- line must be one of the three fields
#                           (or a `- wiki/…` continuation of an
#                           `ingested_pages:` block list)
#
# SCOPE: paths under `raw/` only. Everything else in the diff is ignored —
# wiki/, scripts/, docs/ are owned by the agent by design.
#
# EXIT: 0 = compliant · 1 = violation found · 2 = the gate itself failed
#       (no git, unreadable diff, bad revision range).
#
# MODES:
# HISTORY / RATCHET: the wired path is --worktree, which examines only what is
# changing now — so the past is never required to be fixed (deterministic-gates
# §6). For the record, `--range <sha>^!` over every commit touching raw/ finds
# three pre-existing violations, all pre-dating this gate:
#   a76196f  chore: cut to core            (raw/causal-smoke-source.md deleted)
#   60d30e3  chore: backfill extraction_method on legacy raws  (2 files)
#   15b8f6c  feat: initial bootstrap       (root-commit artefact)
# 60d30e3 is the exact shape this gate exists to stop: a bulk rewrite of a
# non-ingest frontmatter field across committed evidence.
#
# MODES:
#   --worktree            (default) staged + unstaged changes vs HEAD
#   --range <rev-range>   e.g. origin/main...HEAD, or a single SHA
#   --diff <file>         read a unified diff from a file ("-" for stdin);
#                         this is the fixture mode
#
# RUNTIME: bash + git + awk. No LLM, no network, no key.
# WIRED AT: scripts/smoke-all.sh (R30) → CI, in --worktree mode.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RULE_ID="RAW-APPEND-ONLY"

die2() { printf 'gate-raw-append-only: %s\n' "$1" >&2; exit 2; }

MODE=worktree
ARG=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --worktree) MODE=worktree; shift ;;
    --range)    MODE=range; ARG="${2:-}"; [ -n "$ARG" ] || die2 "--range needs a revision range"; shift 2 ;;
    --diff)     MODE=diff;  ARG="${2:-}"; [ -n "$ARG" ] || die2 "--diff needs a file (or -)"; shift 2 ;;
    *)          die2 "unknown argument: $1" ;;
  esac
done

tmp="$(mktemp -d)" || die2 "mktemp failed"
trap 'rm -rf "$tmp"' EXIT
DIFF="$tmp/input.diff"

case "$MODE" in
  worktree)
    command -v git >/dev/null 2>&1 || die2 "git not found (cannot read the worktree diff)"
    cd "$REPO_ROOT" || die2 "cannot cd to $REPO_ROOT"
    git rev-parse --git-dir >/dev/null 2>&1 || die2 "$REPO_ROOT is not a git repository"
    # HEAD may not exist in a repo with no commits; treat that as gate failure
    # rather than silently passing an unexaminable tree.
    git rev-parse --verify HEAD >/dev/null 2>&1 || die2 "no HEAD commit to diff against"
    git diff HEAD -- raw/ > "$DIFF" 2>"$tmp/err" || die2 "git diff failed: $(cat "$tmp/err")"
    ;;
  range)
    command -v git >/dev/null 2>&1 || die2 "git not found"
    cd "$REPO_ROOT" || die2 "cannot cd to $REPO_ROOT"
    git rev-parse --git-dir >/dev/null 2>&1 || die2 "$REPO_ROOT is not a git repository"
    git diff "$ARG" -- raw/ > "$DIFF" 2>"$tmp/err" || die2 "git diff $ARG failed: $(cat "$tmp/err")"
    ;;
  diff)
    if [ "$ARG" = "-" ]; then
      cat > "$DIFF" || die2 "reading diff from stdin failed"
    else
      [ -r "$ARG" ] || die2 "cannot read diff file: $ARG"
      cat "$ARG" > "$DIFF" || die2 "reading $ARG failed"
    fi
    ;;
esac

awk -v rule="$RULE_ID" '
  function flush_file() {
    # nothing to carry between files; state resets in the diff --git branch
  }
  function violation(msg,   _) {
    printf "%s: %s\n", path, rule > "/dev/stderr"
    printf "  %s\n", msg          > "/dev/stderr"
    printf "  FIX: raw/ is read-only evidence. Revert this change. Only /wiki-ingest\n" > "/dev/stderr"
    printf "  may write, and only ingested_hash / ingested_at / ingested_pages.\n"      > "/dev/stderr"
    violations++
  }

  # ── file header ──
  /^diff --git / {
    path = $4; sub(/^b\//, "", path)
    in_raw   = (path ~ /^raw\//)
    is_new   = 0; is_gone = 0; is_rename = 0; reported = 0
    next
  }
  /^new file mode /   { is_new = 1;    next }
  /^deleted file mode/ { is_gone = 1;
    if (in_raw) violation("raw source DELETED. Sources are evidence; wiki pages cite into them and hash-drift detection compares against them.")
    next }
  /^rename (from|to) / {
    if (in_raw && !is_rename) { is_rename = 1;
      violation("raw source RENAMED. Every `(source: raw/<file>#anchor)` citation pointing here now dangles.") }
    next }

  # ── noise we never inspect ──
  /^(index |similarity index |--- |\+\+\+ |@@ |old mode |new mode )/ { next }

  !in_raw  { next }
  is_new   { next }   # a brand-new raw file is an extract: allowed wholesale
  is_gone  { next }
  is_rename { next }

  # ── content lines of a MODIFIED raw file ──
  /^[+-]/ {
    line = substr($0, 2)
    # The three ingest-commitment fields — the only authorised writes.
    if (line ~ /^ingested_hash:/)  next
    if (line ~ /^ingested_at:/)    next
    if (line ~ /^ingested_pages:/) next
    # A block-style `ingested_pages:` list continues as `  - wiki/<page>.md`.
    # Narrow on purpose: only list items pointing into wiki/ are exempt, so
    # this cannot be used to smuggle arbitrary lines past the gate.
    if (line ~ /^[[:space:]]+- wiki\/[^[:space:]]+$/) next

    if (!reported) {
      violation(sprintf("modified outside the ingest-commitment fields. First offending line:\n    %s", $0))
      reported = 1
    }
    next
  }

  END { exit (violations > 0 ? 1 : 0) }
' "$DIFF"
status=$?

if [ "$status" -eq 1 ]; then
  printf 'gate-raw-append-only: violation(s) found — %s\n' "$RULE_ID" >&2
  exit 1
elif [ "$status" -ne 0 ]; then
  die2 "awk exited $status (parse failure)"
fi

if [ -s "$DIFF" ]; then
  printf 'gate-raw-append-only: clean — raw/ changes are additions or ingest commitments only.\n'
else
  printf 'gate-raw-append-only: clean — no changes under raw/.\n'
fi
exit 0
