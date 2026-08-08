#!/usr/bin/env bash
# scripts/gate-command-aliases.sh — gate ALIAS-RESOLVES.
#
# RULE: every alias command file delegates to a canonical command file that
# exists and is itself canonical — no dangling targets, no alias-to-alias
# chains, no cycles.
#
# WHY THIS GATE EXISTS: this directory now holds three naming generations —
# canonical `ctx-*.md`, short aliases (`ingest.md`, `query.md`), and deprecated
# `wiki-*.md` forwarders kept for backward compatibility. 28 files, of which 19
# contain no procedure at all and only point somewhere else. A forwarder whose
# target was renamed does not fail loudly: the agent reads a file that says
# "execute .claude/commands/ctx-foo.md verbatim", cannot find it, and improvises.
# That failure surfaces as a bad wiki edit, not as an error.
#
# The rename that created this gate proved the point. A path-rewriting pass with
# a boundary bug rewrote `scripts/wiki-discover.py` to `scripts/ctx-discover.py`
# in five files while the script kept its old name — /ctx-discover, its verify
# oracle, and the installer manifest all pointed at a file that did not exist.
#
# DETECTION: frontmatter, not prose. A file is an ALIAS iff its `description:`
# begins "Alias for /<name>" or "Deprecated alias for /<name>"; everything else
# is CANONICAL. The delegation target is then read from the body as
# `.claude/commands/<target>.md` and cross-checked against the name in the
# description, so the two cannot drift apart silently.
#
# Keying on frontmatter is deliberate. The obvious alternative — "does the body
# name another command file?" — misfires immediately: ctx-query.md legitimately
# references ctx-compile.md to explain that step 5.5 mirrors it. That is a
# cross-reference, not a delegation, and a prose-matching gate cannot tell them
# apart.
#
# FAILURE MODES — the honest ones:
#   - An alias that words its description differently ("Short form of /x") reads
#     as CANONICAL and is never checked. Fails OPEN. The convention is enforced
#     only by this gate's own error message, not by anything upstream.
#   - A canonical file whose description happens to start with "Alias for /" is
#     misread as an alias. No such file exists here; the cost if one appears is
#     a false positive, which is the safe direction.
#   - The gate proves the target file EXISTS and is canonical. It cannot prove
#     the target still contains the procedure the alias promises — a canonical
#     file gutted to a stub passes.
#
# SCOPE: .claude/commands/*.md only. Nothing else in the repo declares commands.
#
# EXIT: 0 = every alias resolves · 1 = a dangling target, a chain, or a cycle
#       · 2 = the gate itself failed (no command directory, unreadable file).
#
# MODES:
#   (default)      check this repository
#   --repo <dir>   check the tree at <dir> — fixture mode
#   --count        print "<violations>TAB<suppressions>" and exit 0
#
# RUNTIME: bash 3.2+ + awk + grep. No LLM, no network, no key.
# WIRED AT: scripts/smoke-all.sh (R37) → CI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate-lib.sh
. "$SCRIPT_DIR/lib/gate-lib.sh" || { printf 'gate-command-aliases: cannot source lib/gate-lib.sh\n' >&2; exit 2; }
gate_init "gate-command-aliases" "ALIAS-RESOLVES"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  ROOT="${2:-}"; [ -n "$ROOT" ] || gate_die "--repo needs a directory"; shift 2 ;;
    --count) GATE_COUNT_MODE=1; shift ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || gate_die "not a directory: $ROOT"
cd "$ROOT" || gate_die "cannot cd to $ROOT"

CMD_DIR=".claude/commands"
[ -d "$CMD_DIR" ] || gate_die "no $CMD_DIR directory — there are no commands to check, which is not the same as every command being fine"

tmp="$(mktemp -d)" || gate_die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# ── classify every command file ──
# Emits: <name><TAB>alias|canonical<TAB><declared-target-or-dash>
: > "$tmp/classified"
files=0
for f in "$CMD_DIR"/*.md; do
  [ -f "$f" ] || continue
  files=$((files + 1))
  name="$(basename "$f" .md)"

  # description: from the frontmatter block only (between the first two ---).
  desc="$(awk '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---"  { exit }
    infm && /^description:/ { sub(/^description:[[:space:]]*/, ""); print; exit }
  ' "$f")"

  if [ -z "$desc" ]; then
    gate_violation "$f:1" \
"command file has no \`description:\` in its frontmatter, so it cannot be
       classified as an alias or a canonical procedure. Add one."
    printf '%s\tcanonical\t-\n' "$name" >> "$tmp/classified"
    continue
  fi

  # "Alias for /x." or "Deprecated alias for /x." — quotes optional.
  target="$(printf '%s' "$desc" | sed -nE 's/^"?(Deprecated a|A)lias for \/([a-z0-9-]+).*/\2/p')"
  if [ -n "$target" ]; then
    printf '%s\talias\t%s\n' "$name" "$target" >> "$tmp/classified"
  else
    printf '%s\tcanonical\t-\n' "$name" >> "$tmp/classified"
  fi
done

[ "$files" -gt 0 ] || gate_die "no *.md files under $CMD_DIR — the gate is inspecting nothing"

# ── check each alias ──
aliases=0
while IFS="$(printf '\t')" read -r name kind target; do
  [ "$kind" = alias ] || continue
  aliases=$((aliases + 1))
  f="$CMD_DIR/$name.md"

  # 1. the declared target must exist
  if [ ! -f "$CMD_DIR/$target.md" ]; then
    gate_violation "$f:2" \
"description delegates to /$target, but $CMD_DIR/$target.md does not exist.
       Either restore that file or repoint this alias at a command that exists."
    continue
  fi

  # 2. the body must name the same target — description and body must agree,
  #    or a rename that updated one and not the other passes silently.
  if ! grep -qF "$CMD_DIR/$target.md" "$f"; then
    gate_violation "$f:1" \
"description delegates to /$target but the body never names
       \`$CMD_DIR/$target.md\`. The agent reads the body, not the description,
       so these disagreeing means the alias sends work to the wrong place."
    continue
  fi

  # 3. the target must itself be canonical — no alias-to-alias chains, which is
  #    also what makes cycles impossible: an alias may only point at a
  #    non-alias, so no cycle can be constructed.
  target_kind="$(awk -F"$(printf '\t')" -v t="$target" '$1==t {print $2; exit}' "$tmp/classified")"
  if [ "$target_kind" = alias ]; then
    gate_violation "$f:2" \
"delegates to /$target, which is itself an alias. Chains break when the middle
       link is removed and make the real procedure hard to find. Point this
       directly at the canonical command file."
  fi
done < "$tmp/classified"

[ "$aliases" -gt 0 ] || gate_die "classified $files command file(s) and found no aliases at all — the alias convention has changed and this gate is now checking nothing"

gate_verdict "clean — $aliases alias(es) across $files command file(s) all resolve to a canonical target."
