#!/usr/bin/env bash
# scripts/preflight.sh — environment & dependency check for llm-wiki-bootstrap.
#
# Purpose:
#   Verify hard requirements are present, report which optional shell tools
#   the host has, and detect installed AI runtimes. Helps users see whether
#   /wiki-extract's primary handlers will run first-try or fall back to
#   LLM-vision / failed-sidecar.
#
# Usage:
#   ./scripts/preflight.sh
#
# Exit codes:
#   0 — all hard requirements met (optional tools may be missing)
#   1 — at least one hard requirement missing
#
# Idempotent. Safe to re-run. Writes nothing to disk.

set -euo pipefail

# Resolve repo root so the script works from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# TTY-aware colors. Plain output when piped or redirected.
if [ -t 1 ]; then
  RED=$'\033[31m'
  YELLOW=$'\033[33m'
  GREEN=$'\033[32m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED=
  YELLOW=
  GREEN=
  DIM=
  RESET=
fi

# Platform-aware install command for hints.
case "$(uname -s)" in
  Darwin) INSTALL_CMD="brew install" ;;
  Linux)
    if command -v apt >/dev/null 2>&1; then
      INSTALL_CMD="apt install"
    elif command -v dnf >/dev/null 2>&1; then
      INSTALL_CMD="dnf install"
    elif command -v pacman >/dev/null 2>&1; then
      INSTALL_CMD="pacman -S"
    else
      INSTALL_CMD="<your-package-manager> install"
    fi
    ;;
  *) INSTALL_CMD="<your-package-manager> install" ;;
esac

# State tracking
hard_failures=0
have_pdftotext=no
have_pandoc=no
have_xlsx2csv=no
have_python_docx=no
have_python_openpyxl=no
have_ai_tool=no

# Helpers
have() { command -v "$1" >/dev/null 2>&1; }

ok()   { printf "%s✓%s %-15s — %s\n" "$GREEN"  "$RESET" "$1" "$2"; }
warn() { printf "%s⚠%s %-15s — %s\n" "$YELLOW" "$RESET" "$1" "$2"; }
fail() { printf "%s✗%s %-15s — %s\n" "$RED"    "$RESET" "$1" "$2"; hard_failures=$((hard_failures + 1)); }

echo "llm-wiki-bootstrap preflight"
echo "============================"
echo
echo "${DIM}Hard requirements:${RESET}"

# bash itself (we wouldn't be running otherwise, but report the version)
ok "bash" "present (${BASH_VERSION:-unknown})"

# awk
if have awk; then ok "awk" "present"
else fail "awk" "missing — required by scripts/body-hash.sh (install: ${INSTALL_CMD} gawk)"; fi

# openssl
if have openssl; then ok "openssl" "present"
else fail "openssl" "missing — required by scripts/body-hash.sh (install: ${INSTALL_CMD} openssl)"; fi

# git
if have git; then ok "git" "present"
else fail "git" "missing — required (install: ${INSTALL_CMD} git)"; fi

# raw/ permissions
if [ -d "$REPO_ROOT/raw" ]; then
  if [ -w "$REPO_ROOT/raw" ]; then ok "raw/ write" "OK"
  else fail "raw/ write" "no write permission on raw/ (fix: chmod u+w \"$REPO_ROOT/raw\")"; fi
else
  warn "raw/" "directory missing — run mkdir raw, or /wiki-init in your AI tool"
fi

# wiki/ permissions
if [ -d "$REPO_ROOT/wiki" ]; then
  if [ -w "$REPO_ROOT/wiki" ]; then ok "wiki/ write" "OK"
  else fail "wiki/ write" "no write permission on wiki/ (fix: chmod u+w \"$REPO_ROOT/wiki\")"; fi
else
  warn "wiki/" "directory missing — run mkdir wiki, or /wiki-init in your AI tool"
fi

echo
echo "${DIM}Recommended optional tools (enable shell-first extraction):${RESET}"

# pdftotext
if have pdftotext; then ok "pdftotext" "present — PDF primary handler"; have_pdftotext=yes
else warn "pdftotext" "missing — PDF will fall back to LLM-vision (install: ${INSTALL_CMD} poppler)"; fi

# pandoc
if have pandoc; then ok "pandoc" "present — DOCX primary handler"; have_pandoc=yes
else warn "pandoc" "missing — DOCX will try python-docx, then fail (install: ${INSTALL_CMD} pandoc)"; fi

# xlsx2csv
if have xlsx2csv; then ok "xlsx2csv" "present — XLSX primary handler"; have_xlsx2csv=yes
else warn "xlsx2csv" "missing — XLSX will try openpyxl, then fail (install: pip install xlsx2csv)"; fi

# python3 + modules
if have python3; then
  ok "python3" "present"
  if python3 -c "import docx" >/dev/null 2>&1; then
    ok "python-docx" "present — DOCX fallback ready"; have_python_docx=yes
  else
    warn "python-docx" "missing (install: pip install python-docx)"
  fi
  if python3 -c "import openpyxl" >/dev/null 2>&1; then
    ok "openpyxl" "present — XLSX fallback ready"; have_python_openpyxl=yes
  else
    warn "openpyxl" "missing (install: pip install openpyxl)"
  fi
else
  warn "python3" "missing — DOCX/XLSX fallbacks unavailable (install: ${INSTALL_CMD} python3)"
fi

echo
echo "${DIM}AI runtimes on PATH:${RESET}"

for tool in claude cursor code copilot gemini; do
  if have "$tool"; then ok "$tool" "present"; have_ai_tool=yes; fi
done

if [ "$have_ai_tool" = "no" ]; then
  warn "(none)" "no supported AI tool found on PATH — install one of Claude Code, Cursor, VSCode, Copilot CLI, or Gemini CLI."
fi

echo

# Exit on hard failures before printing the summary.
if [ "$hard_failures" -gt 0 ]; then
  printf "%sNot ready.%s %d hard requirement(s) missing. Install them before running any /wiki-* command.\n" \
    "$RED" "$RESET" "$hard_failures"
  exit 1
fi

# Compose extraction-coverage summary.
full="URL, plain text, CSV, image"
partial=""
degraded=""

if [ "$have_pdftotext" = "yes" ]; then
  full="${full}, PDF"
else
  degraded="${degraded}, PDF (LLM-vision fallback)"
fi

if [ "$have_pandoc" = "yes" ]; then
  full="${full}, DOCX"
elif [ "$have_python_docx" = "yes" ]; then
  partial="${partial}, DOCX (python-docx fallback)"
else
  degraded="${degraded}, DOCX (will produce extraction_status: failed sidecar)"
fi

if [ "$have_xlsx2csv" = "yes" ]; then
  full="${full}, XLSX"
elif [ "$have_python_openpyxl" = "yes" ]; then
  partial="${partial}, XLSX (openpyxl fallback)"
else
  degraded="${degraded}, XLSX (will produce extraction_status: failed sidecar)"
fi

# Strip leading ", " from partial / degraded before printing.
partial="${partial#, }"
degraded="${degraded#, }"

printf "%sReady.%s Full first-try: %s.\n" "$GREEN" "$RESET" "$full"
[ -n "$partial" ]  && printf "%sPartial:%s %s.\n"  "$YELLOW" "$RESET" "$partial"
[ -n "$degraded" ] && printf "%sDegraded:%s %s.\n" "$YELLOW" "$RESET" "$degraded"

exit 0
