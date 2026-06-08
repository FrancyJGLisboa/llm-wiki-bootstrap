#!/usr/bin/env bash
# scripts/privacy-scan.sh — fail-closed privacy scanner for SHARED wiki brains.
#
# A shared brain (`/wiki-skill --scope shared`) serves everyone from one wiki, so
# a personal/secret fact promoted into it leaks to all users — and a commit/push
# is irreversible (cached, indexed). `/wiki-learn`'s gate is *told* to drop such
# facts, but that is soft (LLM judgment). This script is the mechanical backstop:
# it scans shared content for things that must never reach a shared brain and
# fails closed if it finds any.
#
# What it flags (near-zero false-positive, high-value signals):
#   - a surviving `(preference)` capture tag  — in a shared brain the gate MUST
#     drop preference-tagged facts, so any that survive prove the gate failed.
#   - email addresses
#   - secret/credential shapes (sk-…, AKIA…, gh[pousr]_…, github_pat_…, AIza…,
#     xox[baprs]-…, PEM private-key headers)
#
# (Phone numbers are deliberately NOT scanned: the regex matches dates, IDs, and
# coordinates, training users to bypass the block. The signals above carry the
# value without the noise.)
#
# Shared detection (the scan only acts on a SHARED brain):
#   --shared            force shared mode (used by the in-loop /wiki-learn call).
#   else                auto-detect: a SKILL.md at the wiki root whose body says
#                       `Scope: **shared**` (the marker /wiki-skill stamps).
#   not shared          no-op: prints a note and exits 0.
#
# Usage:
#   scripts/privacy-scan.sh [<path>...] [--shared] [--wiki-root <dir>]
#     <path>...     files or directories to scan (default: raw/ wiki/)
#     --wiki-root   where to look for SKILL.md for auto-detect (default: .)
#
# Exit code:
#   0 — not a shared brain, OR shared and clean.
#   1 — shared brain with at least one flagged line (fail closed).
#   2 — usage / environment error.

set -uo pipefail

shared_forced=0
wiki_root="."
paths=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --shared)    shared_forced=1; shift ;;
    --wiki-root) wiki_root="${2:?--wiki-root needs a path}"; shift 2 ;;
    --) shift; while [ "$#" -gt 0 ]; do paths+=("$1"); shift; done ;;
    -*) echo "privacy-scan: unknown flag: $1" >&2; exit 2 ;;
    *)  paths+=("$1"); shift ;;
  esac
done

if [ "${#paths[@]}" -eq 0 ]; then
  paths=(raw wiki)
fi

# ── Shared-brain detection ───────────────────────────────────────────────────
is_shared=0
if [ "$shared_forced" -eq 1 ]; then
  is_shared=1
elif [ -f "$wiki_root/SKILL.md" ] && grep -qE '^Scope:[[:space:]]+\*\*shared\*\*' "$wiki_root/SKILL.md"; then
  is_shared=1
fi

if [ "$is_shared" -eq 0 ]; then
  echo "privacy-scan: not a shared brain (no forced --shared, no 'Scope: **shared**' in $wiki_root/SKILL.md); skipping."
  exit 0
fi

# ── Collect target files ─────────────────────────────────────────────────────
files=()
for p in "${paths[@]}"; do
  if [ -d "$p" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$p" -type f -name '*.md' | sort)
  elif [ -f "$p" ]; then
    files+=("$p")
  fi
  # silently skip non-existent paths: raw/ or wiki/ may legitimately be absent.
done

if [ "${#files[@]}" -eq 0 ]; then
  exit 0
fi

# ── Scan ─────────────────────────────────────────────────────────────────────
# Each category: a label and an extended-regex. grep -nE reports line numbers.
EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
SECRET_RE='(sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

total=0
scan_category() {
  local label="$1" regex="$2"
  local hits
  hits=$(grep -nE "$regex" "${files[@]}" /dev/null 2>/dev/null || true)
  if [ -n "$hits" ]; then
    printf 'privacy-scan: %s — must not reach a shared brain:\n' "$label" >&2
    printf '%s\n' "$hits" | sed 's/^/    /' >&2
    total=$((total + $(printf '%s\n' "$hits" | grep -c .)))
  fi
}

# The `(preference)` capture tag is a literal; grep -F via -nF can't take -E, so
# match it as a fixed string inside an -E alternation-free pass.
pref_hits=$(grep -nF '(preference)' "${files[@]}" /dev/null 2>/dev/null || true)
if [ -n "$pref_hits" ]; then
  printf 'privacy-scan: preference-tagged fact — the shared-brain gate must drop these:\n' >&2
  printf '%s\n' "$pref_hits" | sed 's/^/    /' >&2
  total=$((total + $(printf '%s\n' "$pref_hits" | grep -c .)))
fi

scan_category "email address" "$EMAIL_RE"
scan_category "secret/credential" "$SECRET_RE"

if [ "$total" -gt 0 ]; then
  printf 'privacy-scan: FAILED — %d flagged line(s) in shared content.\n' "$total" >&2
  printf '  Remove the offending content before it enters the shared brain.\n' >&2
  printf '  (For /wiki-learn: re-distill and drop the facts — do not hand-edit raw/.)\n' >&2
  exit 1
fi

exit 0
