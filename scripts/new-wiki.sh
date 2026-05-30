#!/usr/bin/env bash
# scripts/new-wiki.sh — generate a new wiki AND register it (the factory's
# deterministic half).
#
# Composes the proven primitive `create-llm-wiki.sh` (copy skeleton -> path,
# git init, refuse-clobber) with workspace placement + a registry entry. It does
# NOT author domain seed pages — that is the LLM step in the /wiki-new command,
# which calls this script first and then writes the seeds. Run standalone, this
# yields a registered-but-unseeded skeleton (seeded:false).
#
# Layout:
#   default          ~/llm-wikis/<name>/    (registered with relative path, in_workspace:true)
#   --target <path>  <path>/                (independent repo anywhere; registered with
#                                            absolute path, in_workspace:false)
# The registry (registry.jsonl) always lives at the WORKSPACE root, even for
# --target wikis, so one catalog tracks them all.
#
# Usage:
#   scripts/new-wiki.sh <name> --domain "<desc>" [--workspace <dir>] [--target <path>]
#
# <name> must be a slug: [a-z0-9][a-z0-9-]*  (it becomes a directory name and a
# registry key). Default workspace: ${LLM_WIKI_WORKSPACE:-$HOME/llm-wikis}.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${LLM_WIKI_WORKSPACE:-$HOME/llm-wikis}"

name=""
domain=""
target=""

# First non-flag positional is the name.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --workspace=*) WORKSPACE="${1#*=}"; shift ;;
    --domain) domain="$2"; shift 2 ;;
    --domain=*) domain="${1#*=}"; shift ;;
    --target) target="$2"; shift 2 ;;
    --target=*) target="${1#*=}"; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) echo "error: unknown flag $1" >&2; exit 2 ;;
    *)
      if [ -z "$name" ]; then name="$1"; shift
      else echo "error: unexpected argument '$1'" >&2; exit 2; fi ;;
  esac
done

[ -n "$name" ] || { echo "usage: new-wiki.sh <name> --domain \"<desc>\" [--workspace <dir>] [--target <path>]" >&2; exit 2; }

# --domain is required: it is the registry label and the seed for the LLM domain
# layer. Enforce it here so the contract can't be skipped by a direct caller
# (the /wiki-new prompt also asks for it, but the script is the last line).
[ -n "$domain" ] || { echo "error: --domain \"<description>\" is required (it labels the wiki and seeds its domain layer)" >&2; exit 2; }

# Validate the name: slug only (safe as a dir name and a registry key).
if ! printf '%s' "$name" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
  echo "error: name must be a slug ([a-z0-9][a-z0-9-]*): '$name'" >&2
  exit 2
fi

# Resolve target dir + how it gets registered.
if [ -n "$target" ]; then
  resolved_target="$target"
  in_ws="false"
else
  resolved_target="$WORKSPACE/$name"
  in_ws="true"
fi

# Fail fast on a duplicate registry name BEFORE creating anything — otherwise
# create-llm-wiki.sh would scaffold + git-init a dir that the registry then
# refuses to record, leaving an orphan skeleton behind.
if "$SCRIPT_DIR/registry.sh" --workspace "$WORKSPACE" has "$name" 2>/dev/null; then
  echo "error: a wiki named '$name' is already registered in $WORKSPACE/registry.jsonl" >&2
  echo "       pick another name, or drop a stale entry: scripts/registry.sh --workspace \"$WORKSPACE\" prune --apply" >&2
  exit 1
fi

# Scaffold via the unchanged primitive (handles refuse-clobber + git init).
"$SCRIPT_DIR/create-llm-wiki.sh" "$resolved_target"

# Compute the path stored in the registry.
if [ "$in_ws" = "true" ]; then
  reg_path="$name"
else
  reg_path="$(cd "$resolved_target" && pwd)"   # absolute, post-creation
fi

# Register (seeded:false — the LLM seeding step flips it via registry.sh mark-seeded).
"$SCRIPT_DIR/registry.sh" --workspace "$WORKSPACE" add \
  --name "$name" --domain "$domain" --path "$reg_path" --in-workspace "$in_ws" --seeded false

cat <<EOF

✓ Scaffolded and registered '$name'.
    location:  $resolved_target
    workspace: $WORKSPACE   (registry.jsonl)
    domain:    ${domain:-<none>}   (seeded: no)

This is the deterministic skeleton. To author domain-shaped seed pages, run the
/wiki-new command in your AI tool (it calls this script, then writes the seeds).
EOF
