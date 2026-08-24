#!/usr/bin/env bash
# scripts/gate-doc-paths.sh — gate DOC-PATH-RESOLVES.
#
# RULE: a repository path named in prose must exist, and a static asset that a
# SHIPPED doc or a SHIPPED script depends on must itself ship.
#
# WHY THIS GATE EXISTS: scripts/gate-doc-claims.sh recomputes a NUMBER stated in
# prose so a count cannot rot. Nothing did the same for a PATH, and paths rotted
# in exactly the place that costs most — the first commands a stranger types.
# Four shipped defects, all of this one shape:
#
#   1. README.md advertised `./scripts/run-client-decision-demo.sh` and
#      `./scripts/run-client-decision-benchmark.sh` under "Reproducible
#      demonstration". Neither ever existed. The first line a skeptic runs was
#      `No such file or directory`.
#   2. README.md linked docs/CLIENT-DECISION-PROFILE.md and docs/BENCHMARK.md.
#      Neither was ever written.
#   3. docs/QUICKSTART.md SHIPS (it is in the installer manifest) and its first
#      code block called scripts/package-vscode-extension.sh, which does NOT
#      ship. So did its "Verify installation" block. Both were guaranteed to
#      fail in every generated compiler — the defect is invisible from the dev
#      repo, where the scripts are present.
#   4. .claude/commands/ctx-gate.md ships and instructs the agent to edit
#      scripts/smoke-all.sh, which does not ship.
#   5. verify-guided-workspace.sh SHIPS and ran four tests from
#      tests/guided-workspace/; two were missing from the manifest, so the
#      documented "Verify installation" step and the VS Code task both died in
#      every generated compiler. A doc-only scan cannot see that, which is why
#      the rule covers shipped scripts too.
#
# Cases 3 and 4 are why rule R2 exists and why "does it exist here?" is not
# enough: a doc is correct in the repo it was authored in and wrong in the
# artifact it was mailed out in.
#
# DETECTION: extract markdown links and backticked/bare script paths from every
# tracked .md, resolve each against the directory the doc will actually live in,
# and cross-check the shipped set against scripts/installer-skeleton-manifest.txt.
# Not pattern-hunting for "things that look like paths" — only two concrete
# forms, both of which a reader would try to follow.
#
# FAILURE MODES — the honest ones:
#   - It checks paths a reader could copy. It does NOT check that the command
#     behind the path does what the prose claims.
#   - Placeholders (`<target-dir>`, `$VAR`, `*`) are skipped, so a doc naming a
#     genuinely wrong path inside a placeholder form is not caught.
#   - R2 covers scripts and directories named in shipped docs. A shipped doc
#     naming a shipped script that is BROKEN in the target is I5/I6's job in
#     scripts/verify-create-context-compiler.sh, not this gate's.
#   - Anchors (#section) are ignored; a link to a real file with a dead anchor
#     passes.
#
# RUNTIME: bash 3.2+, git, python3. No LLM, no network, no key.
#
# Usage:
#   scripts/gate-doc-paths.sh [--repo DIR] [--count]
#
# Exit: 0 clean · 1 violations · 2 the gate could not run.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/gate-lib.sh"
gate_init "gate-doc-paths" "DOC-PATH-RESOLVES"
gate_need git python3

REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  REPO="${2:?--repo needs a directory}"; shift 2 ;;
    --count) GATE_COUNT_MODE=1; shift ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$REPO" ] || gate_die "not a directory: $REPO"

# The scan lives in its own module. Keeping it inline would put backticks inside
# a heredoc inside $( ), which bash's parser miscounts while looking for the
# closing paren — a gate that dies at parse time reports nothing and exits 2.
SCAN="$SCRIPT_DIR/lib/doc-paths-scan.py"
[ -f "$SCAN" ] || gate_die "missing scanner: $SCAN"

findings="$(cd "$REPO" && python3 "$SCAN")" || gate_die "scan failed (see stderr above)"

if [ -n "$findings" ]; then
  while IFS="$(printf '\t')" read -r where fix; do
    [ -n "$where" ] && gate_violation "$where" "$fix"
  done <<EOF
$findings
EOF
fi

gate_verdict "clean — every path named in a tracked doc resolves, and every scripts/ or tests/ asset a shipped doc or script depends on ships."
