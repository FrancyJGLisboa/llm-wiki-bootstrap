#!/usr/bin/env bash
# scripts/verify-skill-install.sh — oracle for the /wiki-skill output.
#
# Answers one question: does the folder /wiki-skill produces satisfy the
# structural preconditions to LOAD and OPERATE as an agent skill once installed
# into a host's .claude/skills/<name>/? (Actual activation is proven by the live
# L1-L3 checks in presentations/lseg-sales/demo-runbook.md — these are the
# deterministic, no-LLM preconditions for that.)
# An Agent Skill is a *directory* — SKILL.md at the root over bundled assets —
# and a skill folder's internal .claude/commands/ is NOT registered as host slash
# commands. So the skill is only operable if every workflow its SKILL.md names is
# bundled *inside* the folder (the agent follows the body by path, not a global
# command). These checks encode exactly that self-containment guarantee.
#
# Two modes (mirrors scripts/verify-multi-wiki.sh in shape and exit semantics):
#
#   (default, no args)   Deterministic checks S1-S3,S5 against a throwaway skill.
#                        Always safe to run; needs no LLM. Scaffolds the skeleton
#                        via new-wiki.sh, stamps templates/skill/SKILL.md with
#                        fixed test values, simulates the install, and asserts the
#                        wrapper is well-formed and self-contained. S4 (knowledge
#                        present) is seed-dependent, so it is noted-skipped here.
#     S1  discoverable — SKILL.md at the skill root; frontmatter name+description
#         non-empty; no {{placeholder}} survives; no <!-- SCOPE:… --> markers left.
#     S2  read self-contained — the read workflow (/wiki-query) has a bundled body.
#     S3  write self-contained — /wiki-learn + the workflows it composes
#         (/wiki-extract, /wiki-ingest) have bundled bodies, and scripts/body-hash.sh
#         is present + executable (wiki-ingest's hard dependency; AGENTS.md rule 2).
#     S5  no unbundled-command assumption — EVERY /wiki-… named in SKILL.md's
#         operating procedure resolves to a bundled .claude/commands/<name>.md.
#
#   --skill <wiki-dir>   Structural checks S1-S5 on a real /wiki-skill output
#                        (already seeded + already carries a stamped SKILL.md).
#     S4  knowledge present — wiki/index.md + >=3 seed pages, so a read query has
#         something to answer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_TEMPLATE="$REPO_ROOT/templates/skill/SKILL.md"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=; GREEN=; YELLOW=; DIM=; RESET=
fi
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; failures=$((failures + 1)); }
note() { printf "%s%s%s\n"   "$DIM"   "$1" "$RESET" >&2; }

failures=0

# ---------------------------------------------------------------------------
# Stamp templates/skill/SKILL.md the way /wiki-skill Step 2 does: substitute the
# four placeholders and resolve the scope blocks (keep per-user, drop shared,
# strip the kept block's markers). Used only by the deterministic mode so the
# check has a realistic, fully-stamped SKILL.md without an LLM.
# ---------------------------------------------------------------------------
stamp_skill_md() {
  local dest="$1" name="$2" domain="$3" triggers="$4"
  awk -v name="$name" -v domain="$domain" -v scope="per-user" -v triggers="$triggers" '
    # Drop the shared scope block entirely (per-user is the chosen scope).
    /^<!-- SCOPE:shared -->$/   { drop=1; next }
    /^<!-- \/SCOPE:shared -->$/ { drop=0; next }
    drop { next }
    # Strip the kept (per-user) block markers, keep their content.
    /^<!-- SCOPE:per-user -->$/   { next }
    /^<!-- \/SCOPE:per-user -->$/ { next }
    {
      gsub(/\{\{NAME\}\}/, name)
      gsub(/\{\{DOMAIN\}\}/, domain)
      gsub(/\{\{SCOPE\}\}/, scope)
      gsub(/\{\{TRIGGERS\}\}/, triggers)
      print
    }
  ' "$SKILL_TEMPLATE" > "$dest"
}

# ---------------------------------------------------------------------------
# Run the skill-install oracle against an installed skill root.
#   $1 — installed skill dir (…/.claude/skills/<name>/)
#   $2 — run_s4: "yes" to assert seeds present (seeded mode), "no" to skip.
# ---------------------------------------------------------------------------
verify_skill_dir() {
  local sk="$1" run_s4="$2"
  local md="$sk/SKILL.md"

  # S1 — discoverable + fully stamped.
  if [ ! -f "$md" ]; then
    fail "S1 no SKILL.md at skill root ($sk)"; return
  fi
  local name_val desc_present
  name_val="$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$md")"
  desc_present="$(awk '/^---$/{n++; next} n==1 && /^description:/{print "y"; exit}' "$md")"
  if [ -n "$name_val" ] && [ "$desc_present" = "y" ]; then
    ok "S1a frontmatter name + description present (name: $name_val)"
  else
    fail "S1a frontmatter name/description missing (name='$name_val' desc='$desc_present')"
  fi
  if grep -q '{{' "$md"; then
    fail "S1b unresolved {{placeholder}} survives in SKILL.md"
  else
    ok "S1b no {{placeholder}} survives"
  fi
  if grep -qE '<!-- /?SCOPE:' "$md"; then
    fail "S1c unresolved <!-- SCOPE:… --> marker left in SKILL.md"
  else
    ok "S1c scope blocks resolved (no SCOPE markers left)"
  fi
  # S1d — the host loader requires a skill's directory basename to equal its
  # frontmatter `name` (empirically 235/236 installed skills satisfy this); a
  # mismatch silently fails to register. The wiki dir is `<name>`, so the
  # frontmatter must be `<name>` too — not `<name>-brain`.
  local base; base="$(basename "$sk")"
  if [ "$base" = "$name_val" ]; then
    ok "S1d skill dir basename == frontmatter name ($base)"
  else
    fail "S1d skill dir '$base' != frontmatter name '$name_val' (won't register in a host)"
  fi

  # S2 — read path self-contained.
  if [ -f "$sk/.claude/commands/wiki-query.md" ]; then
    ok "S2 read workflow bundled (.claude/commands/wiki-query.md)"
  else
    fail "S2 read workflow MISSING — .claude/commands/wiki-query.md not in skill folder"
  fi

  # S3 — write path self-contained (learn + the workflows it composes + body-hash).
  local w missing=""
  for w in wiki-learn wiki-extract wiki-ingest; do
    [ -f "$sk/.claude/commands/$w.md" ] || missing="${missing} $w.md"
  done
  if [ -z "$missing" ]; then
    ok "S3a write workflows bundled (learn + extract + ingest)"
  else
    fail "S3a write workflow(s) MISSING:${missing}"
  fi
  if [ -x "$sk/scripts/body-hash.sh" ]; then
    ok "S3b scripts/body-hash.sh bundled + executable (ingest dependency)"
  elif [ -f "$sk/scripts/body-hash.sh" ]; then
    fail "S3b scripts/body-hash.sh bundled but NOT executable"
  else
    fail "S3b scripts/body-hash.sh MISSING (ingest cannot hash — AGENTS.md rule 2)"
  fi

  # S4 — knowledge present (seeded mode only).
  if [ "$run_s4" = "yes" ]; then
    local seeds=0 page
    if [ -f "$sk/wiki/index.md" ]; then
      for page in "$sk"/wiki/*.md; do
        [ -e "$page" ] || continue
        case "$(basename "$page")" in index.md) ;; *) seeds=$((seeds + 1)) ;; esac
      done
      if [ "$seeds" -ge 3 ]; then ok "S4 knowledge present (index.md + $seeds seed pages)"
      else fail "S4 only $seeds seed page(s), need >=3 for a read query to answer"; fi
    else
      fail "S4 no wiki/index.md — nothing to answer from"
    fi
  else
    note "[S4 skipped — deterministic mode has no LLM-authored seeds]"
  fi

  # S5 — no unbundled-command assumption: every /wiki-… named in SKILL.md must
  # resolve to a bundled command body, or the agent has no workflow to follow.
  local tok unbundled=""
  for tok in $(grep -oE '/wiki-[a-z]+' "$md" | sed 's|^/||' | sort -u); do
    [ -f "$sk/.claude/commands/$tok.md" ] || unbundled="${unbundled} /$tok"
  done
  if [ -z "$unbundled" ]; then
    ok "S5 every /wiki-… in SKILL.md resolves to a bundled command body"
  else
    fail "S5 SKILL.md names command(s) with no bundled body:${unbundled}"
  fi
}

# ---------------------------------------------------------------------------
# Deterministic mode — scaffold + stamp + simulate install, then S1-S3,S5.
# ---------------------------------------------------------------------------
verify_deterministic() {
  local WS HOST; WS="$(mktemp -d)"; HOST="$(mktemp -d)"
  note "[verifier] temp workspace: $WS"
  note "[verifier] temp host:      $HOST"

  if ! "$SCRIPT_DIR/new-wiki.sh" demo-desk --workspace "$WS" \
        --domain "futures desk decision rules" >"$WS/.s.log" 2>&1; then
    fail "scaffold failed — see $WS/.s.log"; cat "$WS/.s.log" >&2
    rm -rf "$WS" "$HOST"; return
  fi
  stamp_skill_md "$WS/demo-desk/SKILL.md" "demo-desk" \
    "futures desk decision rules" "when to go long, position sizing, risk limits"

  # Simulate install: copy the whole wiki folder into a host skills dir.
  local SK="$HOST/.claude/skills/demo-desk"
  mkdir -p "$(dirname "$SK")"
  cp -R "$WS/demo-desk" "$SK"

  verify_skill_dir "$SK" "no"
  rm -rf "$WS" "$HOST"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
MODE="deterministic"
SKILL_DIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --skill) MODE="skill"; SKILL_DIR="$2"; shift 2 ;;
    *) echo "error: unknown arg $1" >&2; exit 2 ;;
  esac
done

[ -f "$SKILL_TEMPLATE" ] || { fail "skill template missing: $SKILL_TEMPLATE"; exit 1; }

if [ "$MODE" = "skill" ]; then
  [ -d "$SKILL_DIR" ] || { echo "error: --skill dir not found: $SKILL_DIR" >&2; exit 2; }
  echo "Verifying installed skill: $SKILL_DIR"
  # A real /wiki-skill output already carries a stamped SKILL.md; check it in place.
  verify_skill_dir "$SKILL_DIR" "yes"
else
  echo "Verifying skill-install self-containment (S1-S3, S5; deterministic)"
  verify_deterministic
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s) red.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s All checks green.\n" "$GREEN" "$RESET"
exit 0
