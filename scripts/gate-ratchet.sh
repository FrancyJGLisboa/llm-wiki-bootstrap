#!/usr/bin/env bash
# scripts/gate-ratchet.sh — gate RATCHET-NO-INCREASE.
#
# RULE: no gate's violation count and no gate's suppression count may exceed the
# number recorded for it in gates/baseline.tsv.
#
# WHY THIS GATE EXISTS: deterministic-gates §6 has been in this repo since the
# doctrine was written and was never implemented. Nothing read a baseline,
# nothing failed on an increase, and no baseline file existed. §6 is the clause
# that makes the other gates adoptable — without it, turning on a gate means
# fixing every historical violation first, so the realistic alternative to a
# ratchet is not "a stricter repo", it is "the gate is never turned on".
#
# The second half of §6 is the part that actually bites: suppressions count as
# violations in the same baseline. `scripts/gate-reachable.sh` already computed
# a suppression count and printed it, but nothing consumed the number, so
# appending a line to scripts/gate-standalone.txt silenced an orphan oracle at
# zero cost. Now it moves a watched number.
#
# DETECTION: for each row of gates/baseline.tsv, run the row's command with
# --count, read "<violations>TAB<suppressions>" from stdout, compare against the
# recorded pair. Then check the converse — every gate-*.sh under scripts/, and
# every gate under gates/ and context/gates/, must own a row, so a new gate
# cannot escape by omission.
#
# The gates/ arm is load-bearing and was missing until 2026-08-08: /ctx-gate
# writes its output to gates/<RULE-ID>.sh (scripts/new-gate.sh), which is
# precisely the path a newly built gate takes. Scanning only scripts/ and
# context/gates/ meant the first gate the compiler ever generated for itself was
# exempt from the registration requirement — the escape gates/baseline.tsv
# forbids in its header. It stayed invisible because gates/ held no .sh files
# yet, and because the fixture that would have caught it plants its unregistered
# gate under scripts/.
#
# FAILURE MODES — the honest ones:
#   - A gate that miscounts its own violations ratchets against a wrong number.
#     The counts are only as good as each gate's --count, which is why
#     scripts/gate-fixtures.sh proves each gate discriminates on fixtures.
#   - Lowering a baseline row by hand is silent by design. It is meant to be the
#     reward for fixing something; nothing here verifies the fix happened.
#   - Two violations swapped for two others keeps the total flat and passes.
#     This is a count ratchet, not an identity ratchet. Naming every violation
#     would mean a per-gate stable identifier, which several of these gates
#     (diff-based, reachability-based) cannot produce.
#
# SCOPE: gates only — scripts/gate-*.sh, gates/*.sh, and context/gates/*.sh. The
# wiki-lint-* family and the verify-* oracles are excluded: lints report on user
# content that is expected to churn, and verify-* scripts are tests of the gates,
# which either pass or fail outright and have nothing to ratchet.
#
# EXIT: 0 = no count went up · 1 = an increase, or a gate with no baseline row
#       · 2 = the gate itself failed (missing/unparseable baseline, a listed
#       command missing, or a gate that exited 2 under --count).
#
# MODES:
#   (default)      check this repository
#   --repo <dir>   check the tree at <dir> — fixture mode
#
# RUNTIME: bash 3.2+ (no associative arrays — macOS ships 3.2). No LLM, no
# network, no key.
# WIRED AT: scripts/smoke-all.sh (R36) → CI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/gate-lib.sh
. "$SCRIPT_DIR/lib/gate-lib.sh" || { printf 'gate-ratchet: cannot source lib/gate-lib.sh\n' >&2; exit 2; }
gate_init "gate-ratchet" "RATCHET-NO-INCREASE"

ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) ROOT="${2:-}"; [ -n "$ROOT" ] || gate_die "--repo needs a directory"; shift 2 ;;
    *) gate_die "unknown argument: $1" ;;
  esac
done
[ -d "$ROOT" ] || gate_die "not a directory: $ROOT"
cd "$ROOT" || gate_die "cannot cd to $ROOT"

BASELINE="gates/baseline.tsv"

# No baseline has two causes that must not be collapsed:
#   - no gates exist yet. A compiler freshly made by the installer has an empty
#     gates/ until /ctx-gate builds the first one. Nothing to ratchet: clean.
#   - gates exist but nobody recorded their counts. That is the escape this gate
#     exists to close, and it is a violation, not a pass.
if [ ! -r "$BASELINE" ]; then
  _any_gate=0
  for _g in scripts/gate-*.sh gates/*.sh; do
    [ -f "$_g" ] || continue
    case "$_g" in scripts/gate-ratchet.sh) continue ;; esac
    _any_gate=1; break
  done
  if [ "$_any_gate" = 0 ]; then
    gate_verdict "clean — no gates exist yet, so there are no counts to ratchet."
  fi
  gate_violation "$BASELINE:0" \
"gates exist but $BASELINE does not, so no gate's violation count is watched by
       anything. Create it — one row per gate:
         <RULE-ID>TAB<command>TAB<violations>TAB<suppressions>TAB<date>
       Get each pair with: bash <gate> --count"
  gate_verdict "unreachable"
fi

tmp="$(mktemp -d)" || gate_die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

: > "$tmp/registered"
checked=0
lineno=0

# ── every baseline row: recorded vs actual ──
while IFS= read -r row || [ -n "$row" ]; do
  lineno=$((lineno + 1))
  case "$row" in ''|'#'*) continue ;; esac

  gate_id="$(printf '%s' "$row" | cut -f1)"
  command_str="$(printf '%s' "$row" | cut -f2)"
  base_v="$(printf '%s' "$row" | cut -f3)"
  base_s="$(printf '%s' "$row" | cut -f4)"

  [ -n "$gate_id" ]     || gate_die "$BASELINE:$lineno: empty gate id"
  [ -n "$command_str" ] || gate_die "$BASELINE:$lineno: $gate_id has no command"
  case "$base_v" in ''|*[!0-9]*) gate_die "$BASELINE:$lineno: $gate_id violations '$base_v' is not a number" ;; esac
  case "$base_s" in ''|*[!0-9]*) gate_die "$BASELINE:$lineno: $gate_id suppressions '$base_s' is not a number" ;; esac

  # Record the script this row owns, so the converse check below can spot a
  # gate that has no row at all.
  set -- $command_str
  script_path="$1"
  printf '%s\n' "$script_path" >> "$tmp/registered"
  [ -f "$script_path" ] || gate_die "$BASELINE:$lineno: $gate_id names $script_path, which does not exist"

  # shellcheck disable=SC2086
  actual="$(bash $command_str --count 2>"$tmp/err")"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    gate_die "$gate_id exited $rc under --count — a gate that cannot run must never be read as compliant. stderr: $(head -3 "$tmp/err" | tr '\n' ' ')"
  fi

  act_v="$(printf '%s' "$actual" | cut -f1)"
  act_s="$(printf '%s' "$actual" | cut -f2)"
  case "$act_v" in ''|*[!0-9]*) gate_die "$gate_id --count printed '$actual', not '<violations>TAB<suppressions>'" ;; esac
  case "$act_s" in ''|*[!0-9]*) gate_die "$gate_id --count printed '$actual', not '<violations>TAB<suppressions>'" ;; esac

  checked=$((checked + 1))

  if [ "$act_v" -gt "$base_v" ]; then
    gate_violation "$BASELINE:$lineno" \
"$gate_id violations went UP: $base_v -> $act_v (+$((act_v - base_v))). Fix the new
       violations (run: bash $command_str). If they are deliberate, raise the
       number in $BASELINE and say why in the note column — that edit is the
       record of the decision."
  fi

  if [ "$act_s" -gt "$base_s" ]; then
    gate_violation "$BASELINE:$lineno" \
"$gate_id suppressions went UP: $base_s -> $act_s (+$((act_s - base_s))). A
       suppression is a violation here. Remove the exclusion, or raise the
       number in $BASELINE with a note. Proposing scope exclusions is the
       documented signal that there are too many gates — see
       docs/deterministic-gates.md, Caveat."
  fi
done < "$BASELINE"

[ "$checked" -gt 0 ] || gate_die "$BASELINE parsed to zero rows — the ratchet is inspecting nothing"

# ── the converse: a gate with no baseline row escapes the ratchet ──
for f in scripts/gate-*.sh gates/*.sh context/gates/*.sh; do
  [ -f "$f" ] || continue
  # This script has no violations of its own to ratchet, and no --count mode to
  # report them with: "count your own violations" is undefined for the script
  # that reads the baseline. A row naming it would also make it invoke itself
  # once per run, forever. Its coverage comes from fixtures instead — two pairs
  # in scripts/gate-fixtures.tsv, one per arm of the check below.
  [ "$f" = "scripts/gate-ratchet.sh" ] && continue
  grep -qxF "$f" "$tmp/registered" && continue
  gate_violation "$f:1" \
"this gate has no row in $BASELINE, so its violation count is watched by nothing.
       Add a row: <RULE-ID>TAB$f TAB<current violations>TAB<current suppressions>TAB<today>
       Get the numbers with: bash $f --count"
done

gate_verdict "clean — $checked gate(s) at or below baseline, none unregistered."
