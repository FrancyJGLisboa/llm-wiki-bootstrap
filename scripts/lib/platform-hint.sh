#!/usr/bin/env bash
# scripts/lib/platform-hint.sh — set $INSTALL_CMD to the host's package-install
# prefix (e.g. "brew install", "apt install") for dependency-hint messages.
#
# SOURCE it, do not exec it:
#   . "$SCRIPT_DIR/lib/platform-hint.sh"       # from scripts/*
#   . "$SCRIPT_DIR/../lib/platform-hint.sh"    # from scripts/visualize/*
#
# Consumers should set a default INSTALL_CMD *before* sourcing and guard the
# source with `[ -f … ] &&`, so a missing/renamed helper never breaks the caller:
#   INSTALL_CMD="<your-package-manager> install"
#   [ -f "$HELPER" ] && . "$HELPER"

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
