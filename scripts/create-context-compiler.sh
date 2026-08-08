#!/usr/bin/env bash
# scripts/create-context-compiler.sh — generate a fresh context-compiler-bootstrap repo at <target-dir>.
#
# Reads `scripts/installer-skeleton-manifest.txt` (the single source of truth) and
# copies every listed path from the dev repo to <target-dir>. Three target-only
# paths are sourced from FRESH templates:
#   wiki/index.md  ←  context/index-FRESH.md
#   README.md      ←  templates/README-fresh.md
#   log.md         ←  hard-coded 3-line stub
#
# What ships and what doesn't is governed entirely by the manifest. No spot-lists
# of forbidden files; the verifier asserts the target's tree shape EQUALS the
# manifest (see scripts/verify-create-context-compiler.sh).
#
# Usage:
#   ./scripts/create-context-compiler.sh <target-dir>
#
# Refuses to clobber: exits 1 if <target-dir> already exists and is non-empty.
# Bash 3.2+. No `cp --parents` (GNU-only); explicit `mkdir -p` before every copy.

set -euo pipefail

# Resolve dev-repo root (one level up from this script).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/installer-skeleton-manifest.txt"

if [ "$#" -ne 1 ]; then
  cat >&2 <<EOF
usage: ./scripts/create-context-compiler.sh <target-dir>

  Generates a fresh context-compiler-bootstrap repo at <target-dir>, ready to use
  without any subsequent wipe step. Reads the skeleton from
  scripts/installer-skeleton-manifest.txt.
EOF
  exit 2
fi

TARGET="$1"

# Refuse to clobber: target may exist but must be empty (or absent).
if [ -d "$TARGET" ]; then
  if [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    echo "error: target '$TARGET' exists and is non-empty — refusing to clobber." >&2
    echo "       Pick a fresh path, or delete the existing target first." >&2
    exit 1
  fi
elif [ -e "$TARGET" ]; then
  echo "error: target '$TARGET' exists and is not a directory." >&2
  exit 1
fi

[ -f "$MANIFEST" ] || { echo "error: manifest missing: $MANIFEST" >&2; exit 1; }

mkdir -p "$TARGET"

# Iterate the manifest; for each path, resolve its source and copy.
copies=0
while IFS= read -r p; do
  # Skip blank lines defensively.
  [ -n "$p" ] || continue

  # Resolve source path per the three target-only specials.
  case "$p" in
    context/index.md)
      source_path="$SRC/context/index-FRESH.md"
      ;;
    README.md)
      source_path="$SRC/templates/README-fresh.md"
      ;;
    gates/baseline.tsv)
      # Seeded at zero for the shipped gates. Without it gate-ratchet arrives
      # RED (gates exist, nothing records their counts) — and a gate that is
      # red on arrival gets disabled rather than obeyed.
      source_path="$SRC/templates/baseline-fresh.tsv"
      ;;
    scripts/gate-fixtures.tsv)
      # The dev repo's table names gates that do not ship (eval-prompt-purity,
      # reachable, doc-claims). A row naming an absent gate is exit 2, not a
      # skip — deliberately, so a gate cannot vanish quietly — so the installed
      # copy lists only the gates that ship.
      source_path="$SRC/templates/gate-fixtures-fresh.tsv"
      ;;
    .claude/settings.json)
      # Sourced from a template so the dev repo keeps no live settings.json of
      # its own — the generated wiki gets the auto-commit Stop hook; this repo
      # does not.
      source_path="$SRC/templates/wiki-settings.json"
      ;;
    log.md)
      # Hard-coded stub; write directly.
      mkdir -p "$TARGET/$(dirname "$p")"
      cat > "$TARGET/$p" <<'EOF'
# log.md

Append-only log of every `/ctx-compile`, `/ctx-query` promotion, and `/ctx-lint --apply` operation. Newest at top.
EOF
      copies=$((copies + 1))
      continue
      ;;
    *)
      source_path="$SRC/$p"
      ;;
  esac

  if [ ! -e "$source_path" ]; then
    echo "error: manifest references missing source: $source_path (for target path: $p)" >&2
    exit 1
  fi

  # Explicit parent-dir creation — Bash 3.2 has no `cp --parents`.
  mkdir -p "$TARGET/$(dirname "$p")"
  # cp -p preserves mode (so executable scripts stay executable).
  cp -p "$source_path" "$TARGET/$p"
  copies=$((copies + 1))
done < "$MANIFEST"

# Initialize a fresh git repo at the target. No initial commit — leave that to the user.
# Compat symlink: `wiki -> context`. The compiled root was renamed in schema v5,
# and ~65 shipped scripts still reference wiki/ by name. The symlink keeps every
# one of them working without a mass rewrite of the oracles that ARE this
# project's safety net. Relative and inside the tree, so package-wiki.sh's
# escaping-symlink guard permits it and tar carries it into bundles.
#
# Not fatal if it cannot be made (Windows without core.symlinks): context/ is
# the real directory and ctx_root() prefers it. Say so rather than failing.
if [ ! -e "$TARGET/wiki" ]; then
  if ( cd "$TARGET" && ln -s context wiki ) 2>/dev/null; then
    :
  else
    printf 'note: could not create the wiki -> context compat symlink.\n' >&2
    printf '      context/ is the real directory and is complete; scripts that\n' >&2
    printf '      hardcode wiki/ will not resolve here. On Windows, enable it with\n' >&2
    printf '      git config --global core.symlinks true\n' >&2
  fi
fi

( cd "$TARGET" && git init -q )

cat <<EOF
✓ Created fresh context-compiler-bootstrap at: $TARGET ($copies files)

Next steps:
  cd "$TARGET"
  ./scripts/preflight.sh           # confirm hard requirements + optional tools
  # then open the directory in Claude Code (or another agentic tool) and
  # run /ctx-extract on your first source.

Repo is git-initialized but uncommitted — review the tree, then:
  git add -A && git commit -m "initial commit"
EOF
