#!/usr/bin/env bash
# scripts/verify-multi-wiki.sh — oracle for the multi-wiki factory.
#
# Two modes:
#
#   (default, no args)   Deterministic checks M1-M3 against a throwaway
#                        workspace (mktemp). Always safe to run; needs no LLM.
#     M1  scaffold+register — new-wiki.sh creates <ws>/<name>/ whose base tree
#         EQUALS the skeleton manifest, and appends exactly one well-formed
#         registry line (in_workspace:true, seeded:false).
#     M2  enumerate+drift   — two creates list both; deleting a dir flags
#         MISSING; an unregistered dir flags UNREGISTERED; prune --apply removes
#         the dangling entry.
#     M3  escape-hatch+safety — --target registers an out-of-workspace wiki by
#         absolute path (in_workspace:false); refuse-clobber still holds.
#     E1-E9 edge battery — default-workspace resolution, missing --domain,
#         relative --target absolutization, adversarial-domain JSON escaping,
#         empty-registry listing, mark-seeded/has error paths, non-slug
#         rejection, and duplicate-name fail-fast (no orphan dir).
#
#   --seeded <wiki-dir> [--domain-term <term>]
#                        Structural checks M4-M5 on an already-seeded wiki
#                        (output of the /wiki-new command).
#     M4  schema-valid — every wiki/*.md has title+type+source+updated+tags;
#         all [[links]] resolve; index.md links every seed page; every
#         concept/entity seed declares source: analysis + an interpretive note.
#     M5  domain-relevant — >=3 seed pages; if --domain-term given, it appears
#         in index.md and at least one seed page.
#
# Mirrors scripts/verify-create-llm-wiki.sh in shape and exit semantics.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/installer-skeleton-manifest.txt"

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
# Seeded-wiki structural checks (M4-M5)
# ---------------------------------------------------------------------------
verify_seeded() {
  local wiki_root="$1" term="$2"
  local wdir="$wiki_root/wiki"
  [ -d "$wdir" ] || { fail "M4 no wiki/ dir under $wiki_root"; return; }

  # Collect seed pages: wiki/*.md excluding index.md (journal/ is user-owned).
  local pages page slug
  local seeds=() all=()
  for page in "$wdir"/*.md; do
    [ -e "$page" ] || continue
    all+=("$page")
    case "$(basename "$page")" in index.md) ;; *) seeds+=("$page") ;; esac
  done

  # M4a — frontmatter completeness on every wiki page.
  local fm_bad=""
  for page in "${all[@]}"; do
    if ! awk '
      /^---$/{n++; next}
      n==1 && /^title:/{t=1}
      n==1 && /^type:/{ty=1}
      n==1 && /^source:/{s=1}
      n==1 && /^updated:/{u=1}
      n==1 && /^tags:/{g=1}
      END{exit !(t&&ty&&s&&u&&g)}' "$page"; then
      fm_bad="${fm_bad} $(basename "$page")"
    fi
  done
  if [ -z "$fm_bad" ]; then ok "M4a every wiki page has title+type+source+updated+tags"
  else fail "M4a incomplete frontmatter:${fm_bad}"; fi

  # M4b — all [[links]] resolve to a wiki/<slug>.md within this wiki.
  local broken="" tok
  for page in "${all[@]}"; do
    # Extract [[kebab-slug]] tokens (ignores typed-relation verbs after ]]).
    for tok in $(grep -oE '\[\[[a-z0-9][a-z0-9-]*\]\]' "$page" 2>/dev/null | sed 's/^\[\[//; s/\]\]$//' | sort -u); do
      [ -f "$wdir/$tok.md" ] || broken="${broken} $(basename "$page"):[[${tok}]]"
    done
  done
  if [ -z "$broken" ]; then ok "M4b all [[links]] resolve"
  else fail "M4b broken links:${broken}"; fi

  # M4c — index.md links every seed page.
  local missing_idx=""
  if [ -f "$wdir/index.md" ]; then
    for page in "${seeds[@]}"; do
      slug="$(basename "$page" .md)"
      grep -qF "[[$slug]]" "$wdir/index.md" || missing_idx="${missing_idx} $slug"
    done
    if [ -z "$missing_idx" ]; then ok "M4c index.md links every seed page"
    else fail "M4c index.md does not link:${missing_idx}"; fi
  else
    fail "M4c no index.md"
  fi

  # M4d — every concept/entity seed declares source: analysis + an interpretive note.
  local prov_bad=""
  for page in "${seeds[@]}"; do
    local ptype
    ptype="$(awk '/^---$/{n++} n==1 && /^type:/{print $2; exit}' "$page")"
    case "$ptype" in
      concept|entity)
        awk '/^---$/{n++} n==1 && /^source:[[:space:]]*analysis/{ok=1} END{exit !ok}' "$page" \
          || prov_bad="${prov_bad} $(basename "$page"):source"
        # Interpretive disclaimer somewhere in the body. NOTE: this accepted-phrasing
        # set is coupled to the disclaimer wording in .claude/commands/wiki-new.md —
        # keep the two in sync (the command's verify-and-fix loop self-heals a miss,
        # but don't let prompt and oracle drift apart silently).
        grep -qiE 'interpretation|interpretive|not extracted|no raw source|analysis, not' "$page" \
          || prov_bad="${prov_bad} $(basename "$page"):disclaimer"
        ;;
    esac
  done
  if [ -z "$prov_bad" ]; then ok "M4d concept/entity seeds are source: analysis + disclosed"
  else fail "M4d provenance gaps:${prov_bad}"; fi

  # M5a — at least 3 seed pages.
  if [ "${#seeds[@]}" -ge 3 ]; then ok "M5a >=3 seed pages (${#seeds[@]})"
  else fail "M5a only ${#seeds[@]} seed page(s), need >=3"; fi

  # M5b — domain term present (only if provided).
  if [ -n "$term" ]; then
    local in_index=0 in_seed=0
    grep -qiF "$term" "$wdir/index.md" 2>/dev/null && in_index=1
    for page in "${seeds[@]}"; do
      if grep -qiF "$term" "$page"; then in_seed=1; break; fi
    done
    if [ "$in_index" -eq 1 ] && [ "$in_seed" -eq 1 ]; then
      ok "M5b domain term '$term' present in index + a seed"
    else
      fail "M5b domain term '$term' missing (index=$in_index seed=$in_seed)"
    fi
  else
    note "[M5b skipped — no --domain-term given]"
  fi
}

# ---------------------------------------------------------------------------
# Deterministic factory checks (M1-M3)
# ---------------------------------------------------------------------------
verify_deterministic() {
  local WS; WS="$(mktemp -d)"
  note "[verifier] temp workspace: $WS"

  local expected actual reg lines
  expected="$(sort < "$MANIFEST" | sed '/^$/d')"

  # M1 — scaffold + register.
  if ! "$SCRIPT_DIR/new-wiki.sh" demo-a --workspace "$WS" --domain "supply-chain risk" >"$WS/.m1.log" 2>&1; then
    fail "M1 new-wiki.sh failed — see $WS/.m1.log"; cat "$WS/.m1.log" >&2; rm -rf "$WS"; return
  fi
  if [ ! -d "$WS/demo-a" ]; then fail "M1 demo-a dir not created"; else
    actual="$(cd "$WS/demo-a" && find . -type f -not -path './.git/*' | sed 's|^\./||' | sort)"
    if [ "$expected" = "$actual" ]; then ok "M1 base tree equals skeleton manifest"
    else fail "M1 base tree DIFFERS from manifest:"; diff <(echo "$expected") <(echo "$actual") | sed 's/^/    /' >&2; fi
  fi
  reg="$WS/registry.jsonl"
  lines="$(grep -c '' "$reg" 2>/dev/null || echo 0)"
  if [ "$lines" -eq 1 ] \
     && grep -q '"name":"demo-a"' "$reg" \
     && grep -q '"in_workspace":true' "$reg" \
     && grep -q '"seeded":false' "$reg"; then
    ok "M1 exactly one well-formed registry entry (in_workspace:true, seeded:false)"
  else
    fail "M1 registry entry malformed/duplicated ($lines line(s))"; cat "$reg" >&2 2>/dev/null || true
  fi

  # M2 — enumerate + drift.
  "$SCRIPT_DIR/new-wiki.sh" demo-b --workspace "$WS" --domain "vineyard ops" >/dev/null 2>&1
  local list_out
  list_out="$("$SCRIPT_DIR/registry.sh" --workspace "$WS" list)"
  if printf '%s' "$list_out" | grep -q 'demo-a' && printf '%s' "$list_out" | grep -q 'demo-b'; then
    ok "M2 list enumerates both wikis"
  else
    fail "M2 list missing a wiki"; printf '%s\n' "$list_out" >&2
  fi
  rm -rf "$WS/demo-a"          # registered-but-missing
  mkdir -p "$WS/orphan-wiki"   # on-disk-but-unregistered
  list_out="$("$SCRIPT_DIR/registry.sh" --workspace "$WS" list)"
  if printf '%s' "$list_out" | grep -q 'MISSING'; then ok "M2 deleted wiki flagged MISSING"
  else fail "M2 deleted wiki not flagged"; fi
  if printf '%s' "$list_out" | grep -q 'UNREGISTERED'; then ok "M2 stray dir flagged UNREGISTERED"
  else fail "M2 stray dir not flagged"; fi
  # --yes: non-interactive oracle stands in for the explicit [y/N] confirm that
  # prune --apply now requires (the destructive-action guardrail).
  "$SCRIPT_DIR/registry.sh" --workspace "$WS" prune --apply --yes >/dev/null 2>&1
  if ! grep -q '"name":"demo-a"' "$reg"; then ok "M2 prune --apply removed the dangling entry"
  else fail "M2 prune did not remove dangling demo-a"; fi

  # M3 — escape hatch + safety.
  local EXT; EXT="$(mktemp -d)/deal-x"
  "$SCRIPT_DIR/new-wiki.sh" deal-x --workspace "$WS" --target "$EXT" --domain "M&A" >/dev/null 2>&1
  if grep -q '"name":"deal-x"' "$reg" \
     && grep -q '"in_workspace":false' "$reg" \
     && grep -qF "\"path\":\"$EXT\"" "$reg"; then
    ok "M3 --target registered out-of-workspace by absolute path (in_workspace:false)"
  else
    fail "M3 escape-hatch entry wrong"; grep deal-x "$reg" >&2 2>/dev/null || true
  fi
  if "$SCRIPT_DIR/new-wiki.sh" deal-x --workspace "$WS" --target "$EXT" --domain x >/dev/null 2>&1; then
    fail "M3 refuse-clobber FAILED — re-created over existing non-empty target"
  else
    ok "M3 refuse-clobber holds (re-create over existing dir refused)"
  fi

  rm -rf "$WS" "$(dirname "$EXT")"
}

# ---------------------------------------------------------------------------
# Edge battery (E1-E9) — deterministic, no LLM. Each check isolates its own
# throwaway workspace. Setup creates that may fail are guarded with `|| true`
# so a regression surfaces as a failed assertion, not a suite abort.
# ---------------------------------------------------------------------------
verify_edges() {
  local WS line

  # E1 — default workspace resolves to $HOME/llm-wikis when --workspace omitted
  #      and LLM_WIKI_WORKSPACE is unset.
  local FAKEHOME; FAKEHOME="$(mktemp -d)"
  ( export HOME="$FAKEHOME"; unset LLM_WIKI_WORKSPACE 2>/dev/null || true
    "$SCRIPT_DIR/new-wiki.sh" defwork --domain d >/dev/null 2>&1 ) || true
  if [ -d "$FAKEHOME/llm-wikis/defwork" ] && [ -f "$FAKEHOME/llm-wikis/registry.jsonl" ]; then
    ok "E1 default workspace resolves to \$HOME/llm-wikis"
  else fail "E1 default workspace not created under \$HOME/llm-wikis"; fi
  rm -rf "$FAKEHOME"

  WS="$(mktemp -d)"

  # E2 — missing --domain registers an empty domain (optional at the shell layer).
  "$SCRIPT_DIR/new-wiki.sh" nodomain --workspace "$WS" >/dev/null 2>&1 || true
  if grep -q '"name":"nodomain","domain":""' "$WS/registry.jsonl"; then
    ok "E2 missing --domain -> empty domain field"
  else fail "E2 missing --domain not handled"; fi

  # E3 — relative --target is absolutized in the registry + git-inited.
  local RELBASE; RELBASE="$(mktemp -d)"
  ( cd "$RELBASE" && "$SCRIPT_DIR/new-wiki.sh" relt --workspace "$WS" --target ./sub/relwiki >/dev/null 2>&1 ) || true
  if grep -qF "\"path\":\"$RELBASE/sub/relwiki\"" "$WS/registry.jsonl" && [ -d "$RELBASE/sub/relwiki/.git" ]; then
    ok "E3 relative --target absolutized + git-inited"
  else fail "E3 relative --target mishandled"; fi
  rm -rf "$RELBASE"

  # E4 — adversarial domain cannot hijack the path field (JSON escaping holds).
  "$SCRIPT_DIR/new-wiki.sh" advdom --workspace "$WS" \
    --domain 'evil","path":"/etc/passwd","in_workspace":false,"x":"' >/dev/null 2>&1 || true
  line="$(grep '"name":"advdom"' "$WS/registry.jsonl" 2>/dev/null || true)"
  if printf '%s' "$line" | grep -q '"path":"advdom"'; then
    ok "E4 adversarial domain JSON-escaped (path not hijacked)"
  else fail "E4 adversarial domain hijacked the path field"; fi

  # E5 — empty workspace lists cleanly.
  local EMPTY; EMPTY="$(mktemp -d)"
  if "$SCRIPT_DIR/registry.sh" --workspace "$EMPTY" list | grep -q 'No wikis registered'; then
    ok "E5 empty registry -> 'No wikis registered'"
  else fail "E5 empty registry not handled"; fi
  rm -rf "$EMPTY"

  # E6 — mark-seeded on an absent name fails.
  if "$SCRIPT_DIR/registry.sh" --workspace "$WS" mark-seeded ghost >/dev/null 2>&1; then
    fail "E6 mark-seeded on absent name did not fail"
  else ok "E6 mark-seeded on absent name exits nonzero"; fi

  # E7 — has reflects presence/absence.
  if "$SCRIPT_DIR/registry.sh" --workspace "$WS" has nodomain >/dev/null 2>&1 \
     && ! "$SCRIPT_DIR/registry.sh" --workspace "$WS" has ghost >/dev/null 2>&1; then
    ok "E7 has: exit 0 for present, 1 for absent"
  else fail "E7 has subcommand wrong"; fi

  # E8 — non-slug name rejected (failure path).
  if "$SCRIPT_DIR/new-wiki.sh" "Bad Name" --workspace "$WS" >/dev/null 2>&1; then
    fail "E8 non-slug name was accepted"
  else ok "E8 non-slug name rejected"; fi

  # E9 — duplicate name fails fast with no orphan dir (dir gone, entry remains).
  "$SCRIPT_DIR/new-wiki.sh" dupe --workspace "$WS" --domain d >/dev/null 2>&1 || true
  rm -rf "$WS/dupe"
  if "$SCRIPT_DIR/new-wiki.sh" dupe --workspace "$WS" --domain d >/dev/null 2>&1; then
    fail "E9 duplicate name was re-created"
  elif [ -d "$WS/dupe" ]; then
    fail "E9 duplicate attempt left an orphan dir"
  else ok "E9 duplicate name fails fast, no orphan dir"; fi

  rm -rf "$WS"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
MODE="deterministic"
SEED_DIR=""
TERM=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --seeded) MODE="seeded"; SEED_DIR="$2"; shift 2 ;;
    --domain-term) TERM="$2"; shift 2 ;;
    *) echo "error: unknown arg $1" >&2; exit 2 ;;
  esac
done

[ -f "$MANIFEST" ] || { fail "manifest missing: $MANIFEST"; exit 1; }

if [ "$MODE" = "seeded" ]; then
  [ -d "$SEED_DIR" ] || { echo "error: --seeded dir not found: $SEED_DIR" >&2; exit 2; }
  echo "Verifying seeded wiki: $SEED_DIR"
  verify_seeded "$SEED_DIR" "$TERM"
else
  echo "Verifying deterministic factory (M1-M3)"
  verify_deterministic
  echo
  echo "Edge battery (E1-E9)"
  verify_edges
fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s) red.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s All checks green.\n" "$GREEN" "$RESET"
exit 0
