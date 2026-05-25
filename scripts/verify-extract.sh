#!/usr/bin/env bash
# scripts/verify-extract.sh — verify that /wiki-extract produced output with the expected shape.
#
# Purpose:
#   After an AI runtime runs `/wiki-extract <source>`, this script checks that
#   the resulting `raw/<slug>.<ext>` (or its sidecar `.md`) has the expected
#   frontmatter shape: required fields present, non-empty values where
#   applicable, frontmatter delimiters intact, body non-empty.
#
# Scope:
#   Validates SHAPE, not SEMANTICS. The verifier catches:
#     - Output file missing
#     - Frontmatter delimiters missing or malformed
#     - Required field absent or empty
#     - Body content empty
#   It also SURFACES (but does not fail on) extraction_status when present:
#     - ok        → green ✓
#     - degraded  → yellow ⚠ (extraction partial; check sidecar notes)
#     - failed    → yellow ⚠ (extraction failed; check sidecar notes)
#     - other     → yellow ⚠ (unknown value)
#   Exit code stays 0 on degraded/failed — shape is fine, semantics signaled by ⚠.
#   It does NOT catch:
#     - Wrong source_type (e.g., "pdf" labeled on a .md source)
#     - Hallucinated source_title / source_author
#     - extraction_method recorded incorrectly
#   For semantics, eyeball the produced raw/<slug>.* file.
#
# Usage:
#   ./scripts/verify-extract.sh <slug>
#
# Example workflow:
#   # In your AI runtime:
#   /wiki-extract tests/canary/canary-smoke-test.md
#
#   # Then in shell:
#   ./scripts/verify-extract.sh canary-smoke-test
#
# Exit codes:
#   0 — all shape checks passed
#   1 — at least one check failed
#   2 — usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "$#" -ne 1 ]; then
  echo "usage: ./scripts/verify-extract.sh <slug>" >&2
  echo "  where <slug> is the basename of the file you extracted (no path, no extension)" >&2
  exit 2
fi

slug="$1"

# TTY-aware coloring
if [ -t 1 ]; then
  RED=$'\033[31m'
  YELLOW=$'\033[33m'
  GREEN=$'\033[32m'
  RESET=$'\033[0m'
else
  RED=
  YELLOW=
  GREEN=
  RESET=
fi

failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN"  "$RESET" "$1"; }
warn() { printf "%s⚠%s %s\n" "$YELLOW" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"    "$RESET" "$1"; failures=$((failures + 1)); }

# Find the produced file. /wiki-extract may produce one of:
#   raw/<slug>.<ext>           — for text sources (no sidecar)
#   raw/<slug>.<ext>.md        — sidecar for binaries (pdf/docx/xlsx/image/csv)
# Try common patterns in order of likelihood.
target=""
for candidate in \
  "$REPO_ROOT/raw/${slug}.md" \
  "$REPO_ROOT/raw/${slug}.txt" \
  "$REPO_ROOT/raw/${slug}.pdf.md" \
  "$REPO_ROOT/raw/${slug}.docx.md" \
  "$REPO_ROOT/raw/${slug}.xlsx.md" \
  "$REPO_ROOT/raw/${slug}.csv.md" \
  "$REPO_ROOT/raw/${slug}.png.md" \
  "$REPO_ROOT/raw/${slug}.jpg.md" \
  "$REPO_ROOT/raw/${slug}.jpeg.md"; do
  if [ -f "$candidate" ]; then
    target="$candidate"
    break
  fi
done

if [ -z "$target" ]; then
  fail "no file found for slug '${slug}' (looked in raw/${slug}.md and common sidecar patterns)"
  echo
  printf "%sNot ready.%s Run /wiki-extract <source> in your AI tool first, then re-run this verifier.\n" \
    "$RED" "$RESET"
  exit 1
fi

display="${target#$REPO_ROOT/}"
ok "found output: ${display}"

# Extract frontmatter block (lines between the first two ---).
frontmatter=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2) exit; next} c==1{print}' "$target")

if [ -z "$frontmatter" ]; then
  fail "frontmatter empty or delimiters missing — expected --- at line 1 and a closing --- below"
  echo
  printf "%sFailed.%s\n" "$RED" "$RESET"
  exit 1
fi

# Helper to extract a field's value from the frontmatter block.
get_field() {
  echo "$frontmatter" | awk -F': ' -v f="$1" '$1==f { $1=""; sub(/^ /, ""); print; exit }'
}

# Required fields and how to handle missing/empty.
check_required() {
  local field="$1"
  local value
  value=$(get_field "$field")
  if [ -z "$value" ]; then
    fail "field '${field}': missing or empty (required)"
  else
    ok "field '${field}': ${value}"
  fi
}

for field in source_url source_type fetched_at extraction_method; do
  check_required "$field"
done

# ingested_hash should be PRESENT but may be EMPTY (set later by /wiki-ingest).
if echo "$frontmatter" | grep -qE '^ingested_hash:'; then
  hash_value=$(get_field "ingested_hash")
  if [ -z "$hash_value" ] || [ "$hash_value" = '""' ]; then
    ok "field 'ingested_hash': present and empty (correct — /wiki-ingest will populate)"
  else
    warn "field 'ingested_hash': already set to '${hash_value}' — /wiki-extract should leave this empty"
  fi
else
  fail "field 'ingested_hash': missing (should be present, even if empty)"
fi

# extraction_status is optional. When present, surface degraded / failed states explicitly —
# shape is fine but the user needs to see that extraction itself didn't fully succeed.
if echo "$frontmatter" | grep -qE '^extraction_status:'; then
  ext_status=$(get_field "extraction_status")
  case "$ext_status" in
    ok)
      ok "field 'extraction_status': ok"
      ;;
    degraded|failed)
      warn "field 'extraction_status': ${ext_status} — extraction did not fully succeed; check 'notes' in the sidecar for install hints"
      ;;
    *)
      warn "field 'extraction_status': '${ext_status}' (unknown value — expected one of: ok, degraded, failed)"
      ;;
  esac
fi

# Body content (everything after the closing ---) should be non-empty.
body=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$target")
body_nonblank=$(echo "$body" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')

if [ "$body_nonblank" = "0" ]; then
  warn "body has no non-blank lines — did extraction produce content?"
else
  ok "body has ${body_nonblank} non-blank line(s)"
fi

echo

if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d shape check(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi

printf "%sPassed.%s Shape checks all green. (Semantics — correct source_type, accurate metadata — still need a human eye.)\n" \
  "$GREEN" "$RESET"
exit 0
