#!/usr/bin/env bash
# scripts/smoke-all.sh — umbrella verifier for the end-to-end smoke.
#
# Composes the build phase (LLM-driven, idempotent), the smoke checks
# (C1–C5), and the regression guards (R1–R9) into a single exit-code-
# driven test. This script IS the /goal completion condition for
# .scratch/plug-and-play-curator-smoke/GOAL.md.
#
# Exit 0 iff all 17 checks pass.
#
# --no-build : skip the LLM build phase (which needs the `claude` CLI) and run
#   only the 17 deterministic checks (C1–C5 asserts on the committed artifacts +
#   R1–R12 guards). This is the CI path — the build phase is a precondition that
#   regenerates artifacts, not one of the counted checks, so the committed-in
#   artifacts are verified as-is.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

BUILD=1
[ "${1:-}" = "--no-build" ] && BUILD=0

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=; GREEN=; DIM=; RESET=
fi

section() { printf "\n%s== %s ==%s\n" "$DIM" "$1" "$RESET"; }
ok()   { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"   "$RESET" "$1"; }

failures=0
record_fail() { fail "$1"; failures=$((failures + 1)); }

# ──── BUILD PHASE ────
if [ "$BUILD" = 1 ]; then
  section "Build phase (LLM, idempotent)"
  if ! "$SCRIPT_DIR/smoke-build.sh"; then
    record_fail "smoke-build.sh failed (see tests/smoke/output/build.log)"
    printf "\n%sAborting: build phase did not complete.%s\n" "$RED" "$RESET"
    exit 1
  fi
else
  section "Build phase (skipped: --no-build; verifying committed artifacts)"
fi

# ──── SMOKE CHECKS C1–C5 ────
section "Smoke checks (C1–C5)"
if ! "$SCRIPT_DIR/smoke-check.sh"; then
  record_fail "smoke-check.sh reported one or more C1–C5 failures"
fi

# ──── REGRESSION GUARDS R1–R5 ────
section "Regression guards (R1–R12)"

# R1 — preflight stays green
if "$SCRIPT_DIR/preflight.sh" >/dev/null 2>&1; then
  ok "R1 preflight.sh exits 0"
else
  record_fail "R1 preflight.sh exits non-zero (baseline regression)"
fi

# R2 — anki verifier stays green
if "$SCRIPT_DIR/verify-wiki-to-anki.sh" >/dev/null 2>&1; then
  ok "R2 verify-wiki-to-anki.sh exits 0"
else
  record_fail "R2 verify-wiki-to-anki.sh exits non-zero (baseline regression)"
fi

# R3 — no Obsidian-flavored markdown in non-smoke content
# Patterns live in scripts/r3-obsidian-patterns.txt (avoids shell-quoting
# hazards from inlining backticked regexes).
R3_HITS="$(grep -rE -f "$SCRIPT_DIR/r3-obsidian-patterns.txt" \
            wiki/ tests/canary/ templates/ docs/ 2>/dev/null || true)"
if [ -z "$R3_HITS" ]; then
  ok "R3 no Obsidian-flavored markdown in wiki/ tests/canary/ templates/ docs/"
else
  record_fail "R3 found Obsidian-flavored markdown:"
  printf '%s\n' "$R3_HITS" | sed 's/^/    /'
fi

# R4 — schema and core-script purity stay stable
r4_ok=yes
if ! grep -q '\*\*Schema version:\*\* 2' AGENTS.md; then
  r4_ok=no
  record_fail "R4 AGENTS.md schema version is not 2"
fi
if ! grep -qE '^- .type. — .concept.*entity.*summary.*analysis.*navigation.*journal' AGENTS.md; then
  r4_ok=no
  record_fail "R4 type enum line in AGENTS.md missing one or more expected values"
fi
for f in scripts/body-hash.sh scripts/preflight.sh scripts/verify-extract.sh \
         scripts/verify-wiki-to-anki.sh scripts/wiki-to-anki.sh; do
  if ! head -1 "$f" | grep -q '^#!/usr/bin/env bash'; then
    r4_ok=no
    record_fail "R4 core script $f does not start with '#!/usr/bin/env bash'"
  fi
done
if [ "$r4_ok" = yes ]; then
  ok "R4 schema version + type enum + core-script shebangs intact"
fi

# R5 — multi-wiki factory deterministic oracle (M1–M3) stays green
if "$SCRIPT_DIR/verify-multi-wiki.sh" >/dev/null 2>&1; then
  ok "R5 verify-multi-wiki.sh (factory M1–M3) exits 0"
else
  record_fail "R5 verify-multi-wiki.sh exits non-zero (factory regression)"
fi

# R6 — body-hash.sh frontmatter validation (malformed input fails closed)
if "$SCRIPT_DIR/verify-body-hash.sh" >/dev/null 2>&1; then
  ok "R6 verify-body-hash.sh exits 0 (malformed frontmatter rejected)"
else
  record_fail "R6 verify-body-hash.sh exits non-zero (silent-data-loss guard regressed)"
fi

# R7 — typed-relations lint (was advertised + fixture-backed but never in CI).
# Mirrors the typed-wikilinks GOAL C3/C4: good fixture passes, bad fixture
# fails, and the meta-wiki stays backward-compatible (untyped = implicit).
if "$SCRIPT_DIR/wiki-lint-typed-relations.sh" tests/canary/typed-related-fixture/ >/dev/null 2>&1 \
   && ! "$SCRIPT_DIR/wiki-lint-typed-relations.sh" tests/canary/typed-related-fixture-bad/ >/dev/null 2>&1 \
   && "$SCRIPT_DIR/wiki-lint-typed-relations.sh" wiki/ >/dev/null 2>&1; then
  ok "R7 wiki-lint-typed-relations.sh (good=0, bad≠0, wiki/=0)"
else
  record_fail "R7 wiki-lint-typed-relations.sh typed-relation checks regressed"
fi

# R8 — installer oracle (single-wiki create-llm-wiki: tree shape + no dev-repo
# string leakage + target preflight). Was a manual-only oracle; now a CI guard.
if "$SCRIPT_DIR/verify-create-llm-wiki.sh" >/dev/null 2>&1; then
  ok "R8 verify-create-llm-wiki.sh exits 0 (clean fresh-skeleton install)"
else
  record_fail "R8 verify-create-llm-wiki.sh exits non-zero (installer regression)"
fi

# R9 — citation-faithfulness deterministic floor (C1+C2): the audit must catch
# broken/fabricated citations on the planted fixture (no LLM; the C3 entailment
# judge is a separate manual tool — see scripts/eval-citation-faithfulness.sh).
if "$SCRIPT_DIR/verify-citation-audit.sh" >/dev/null 2>&1; then
  ok "R9 verify-citation-audit.sh exits 0 (citation floor catches fabrications)"
else
  record_fail "R9 verify-citation-audit.sh exits non-zero (citation-audit floor regressed)"
fi

# R10 — skill-install oracle: the /wiki-skill output must satisfy the load
# preconditions + be self-contained once installed into a host (.claude/skills/) —
# i.e. SKILL.md is well-formed, its `name` matches the install dir, and every
# workflow it names is bundled inside the folder so the agent never depends on a
# host-registered slash command. Deterministic: scaffolds + stamps + simulates the
# install (S1-S3, S5). Note: this guards the template + manifest, not the LLM
# stamping path — that is verified by /wiki-skill itself calling this oracle.
if "$SCRIPT_DIR/verify-skill-install.sh" >/dev/null 2>&1; then
  ok "R10 verify-skill-install.sh exits 0 (generated skill is self-contained)"
else
  record_fail "R10 verify-skill-install.sh exits non-zero (skill-install regression)"
fi

# R11 — causal-relationships deterministic oracle: causal-vocabulary lint
# (good/bad/wiki + synonym suggestions), KG exact-tuple materialization +
# input-sensitivity, stdlib-only KG builder, and the schema/ingest/content
# guards (G1–G3). See .scratch/causal-relationships/GOAL.md.
if "$SCRIPT_DIR/verify-causal.sh" >/dev/null 2>&1; then
  ok "R11 verify-causal.sh exits 0 (causal lint + KG + guards)"
else
  record_fail "R11 verify-causal.sh exits non-zero (causal capability regression)"
fi

# R12 — shared-brain privacy guard: the scanner discriminates (clean/dirty),
# auto-detects shared via SKILL.md, the pre-commit HOOK blocks a dirty commit and
# accepts a clean one (tested-path == runtime-path), and the scaffolder ships +
# wires the guard into generated wikis (core.hooksPath). Fail-closed at the
# irreversible commit boundary — the one mechanical exception to soft enforcement.
if "$SCRIPT_DIR/verify-privacy-scan.sh" >/dev/null 2>&1; then
  ok "R12 verify-privacy-scan.sh exits 0 (shared-brain privacy guard + hook + ship)"
else
  record_fail "R12 verify-privacy-scan.sh exits non-zero (privacy guard regression)"
fi

# ──── SUMMARY ────
section "Summary"
if [ "$failures" -eq 0 ]; then
  printf "%sAll 17 checks green.%s\n" "$GREEN" "$RESET"
  exit 0
fi
printf "%s%d check(s) failed.%s See diagnostics above.\n" "$RED" "$failures" "$RESET"
exit 1
