#!/usr/bin/env bash
# scripts/smoke-all.sh — umbrella verifier for the end-to-end smoke.
#
# Composes the build phase (LLM-driven, idempotent), the smoke checks
# (C1–C5), and the regression guards (R1–R21) into a single exit-code-
# driven test.
#
# Exit 0 iff all 26 checks pass.
#
# --no-build : skip the LLM build phase (which needs the `claude` CLI) and run
#   only the 26 deterministic checks (C1–C5 asserts on the committed artifacts +
#   R1–R21 guards). This is the CI path — the build phase is a precondition that
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

# ──── REGRESSION GUARDS R1–R21 ────
section "Regression guards (R1–R21)"

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
# -I skips binary files: committed PDFs (tests/canary/canary-scanned.pdf,
# docs/files-*/*.pdf) can match the patterns on raw bytes and produce a
# "Binary file … matches" false positive — R3 is a text-content guard.
# --include='*.md' scopes to markdown: the block-level HTML patterns would
# otherwise flag legitimate standalone .html docs (docs/pitch-*.html). R3 guards
# the wiki's CommonMark purity, not hand-authored HTML artifacts.
R3_HITS="$(grep -rIE --include='*.md' -f "$SCRIPT_DIR/r3-obsidian-patterns.txt" \
            wiki/ tests/canary/ templates/ docs/ 2>/dev/null || true)"
if [ -z "$R3_HITS" ]; then
  ok "R3 no Obsidian-flavored markdown in wiki/ tests/canary/ templates/ docs/"
else
  record_fail "R3 found Obsidian-flavored markdown:"
  printf '%s\n' "$R3_HITS" | sed 's/^/    /'
fi

# R4 — schema and core-script purity stay stable
r4_ok=yes
if ! grep -q '\*\*Schema version:\*\* 4' AGENTS.md; then
  r4_ok=no
  record_fail "R4 AGENTS.md schema version is not 4"
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

# R5 — body-hash.sh frontmatter validation (malformed input fails closed)
if "$SCRIPT_DIR/verify-body-hash.sh" >/dev/null 2>&1; then
  ok "R5 verify-body-hash.sh exits 0 (malformed frontmatter rejected)"
else
  record_fail "R5 verify-body-hash.sh exits non-zero (silent-data-loss guard regressed)"
fi

# R6 — typed-relations lint: good fixture passes, bad fixture fails, and the
# meta-wiki stays backward-compatible (untyped = implicit).
if "$SCRIPT_DIR/wiki-lint-typed-relations.sh" tests/canary/typed-related-fixture/ >/dev/null 2>&1 \
   && ! "$SCRIPT_DIR/wiki-lint-typed-relations.sh" tests/canary/typed-related-fixture-bad/ >/dev/null 2>&1 \
   && "$SCRIPT_DIR/wiki-lint-typed-relations.sh" wiki/ >/dev/null 2>&1; then
  ok "R6 wiki-lint-typed-relations.sh (good=0, bad≠0, wiki/=0)"
else
  record_fail "R6 wiki-lint-typed-relations.sh typed-relation checks regressed"
fi

# R7 — installer oracle (create-llm-wiki: tree shape EQUALS manifest + no dev-repo
# string leakage + target preflight).
if "$SCRIPT_DIR/verify-create-llm-wiki.sh" >/dev/null 2>&1; then
  ok "R7 verify-create-llm-wiki.sh exits 0 (clean fresh-skeleton install)"
else
  record_fail "R7 verify-create-llm-wiki.sh exits non-zero (installer regression)"
fi

# R8 — citation-faithfulness deterministic floor (C1+C2): the audit must catch
# broken/fabricated citations on the planted fixture (no LLM; the C3 entailment
# judge is a separate manual tool — see scripts/eval-citation-faithfulness.sh).
if "$SCRIPT_DIR/verify-citation-audit.sh" >/dev/null 2>&1; then
  ok "R8 verify-citation-audit.sh exits 0 (citation floor catches fabrications)"
else
  record_fail "R8 verify-citation-audit.sh exits non-zero (citation-audit floor regressed)"
fi

# R9 — auto-commit reliability hook: commits on wiki change, no-ops on clean tree
# and outside a git repo, derives the message from log.md, never pushes. Closes
# the "uncommitted working tree" durability gap. See templates/wiki-settings.json.
if "$SCRIPT_DIR/verify-auto-commit.sh" >/dev/null 2>&1; then
  ok "R9 verify-auto-commit.sh exits 0 (auto-commit reliability hook works)"
else
  record_fail "R9 verify-auto-commit.sh exits non-zero (auto-commit hook regression)"
fi

# R10 — synthesis layer: artifacts generate deterministically, aggregate the
# planted markers, and the graph JSON matches the rendered graph (schema v3).
if "$SCRIPT_DIR/verify-synthesize.sh" >/dev/null 2>&1; then
  ok "R10 verify-synthesize.sh exits 0 (deterministic synthesis + graph parity)"
else
  record_fail "R10 verify-synthesize.sh exits non-zero (synthesis layer regression)"
fi

# R11 — long-source segmenter oracle (C1–C5 of the long-source-tree-retrieval
# GOAL): segment-doc.py is deterministic, lossless, anchored, and tamper-evident.
if "$SCRIPT_DIR/verify-segment-doc.sh" >/dev/null 2>&1; then
  ok "R11 verify-segment-doc.sh exits 0 (segmenter deterministic + lossless + anchored)"
else
  record_fail "R11 verify-segment-doc.sh exits non-zero (long-source segmenter regression)"
fi

# R12 — KG materializer oracle (K1–K5): wiki-to-kg.py extracts the exact
# typed-relation/causal triple set, is input-sensitive, stdlib-only, read-only.
if "$SCRIPT_DIR/verify-wiki-to-kg.sh" >/dev/null 2>&1; then
  ok "R12 verify-wiki-to-kg.sh exits 0 (KG materializer exact + stdlib-only + read-only)"
else
  record_fail "R12 verify-wiki-to-kg.sh exits non-zero (KG materializer regression)"
fi

# R13 — causal lint (L1–L3): accepts canonical causal verbs, rejects synonyms
# with the correct canonical suggestion, real wiki stays clean.
if "$SCRIPT_DIR/verify-causal-lint.sh" >/dev/null 2>&1; then
  ok "R13 verify-causal-lint.sh exits 0 (canonical accepted, synonyms rejected)"
else
  record_fail "R13 verify-causal-lint.sh exits non-zero (causal lint regression)"
fi

# R14 — causal/connection traversal floor (W1–W4): wiki-graph-walk answers
# multi-hop causes-of / effects-of / path over the materialized KG, no LLM.
if "$SCRIPT_DIR/verify-graph-walk.sh" >/dev/null 2>&1; then
  ok "R14 verify-graph-walk.sh exits 0 (causal chains + connection paths traverse)"
else
  record_fail "R14 verify-graph-walk.sh exits non-zero (graph-walk regression)"
fi

# R15 — discovery report (D1–D4): wiki-discover surfaces multi-hop causal chains,
# hub concepts, and the widest connection (graph diameter), deterministically.
if "$SCRIPT_DIR/verify-discover.sh" >/dev/null 2>&1; then
  ok "R15 verify-discover.sh exits 0 (chains + hubs + widest bridge surfaced)"
else
  record_fail "R15 verify-discover.sh exits non-zero (discovery regression)"
fi

# R16 — faithfulness gate (G1–G4, C2, C9): the ingest/promote-time gate blocks
# CONTRADICTED claims in both modes, flags UNSUPPORTED on ingest / blocks on
# promote, passes faithful pages, is deterministic, non-vacuous, and offline with
# injected verdicts. The live C3 judge is exercised by eval-citation-faithfulness.sh.
if "$SCRIPT_DIR/verify-faithfulness-gate.sh" >/dev/null 2>&1; then
  ok "R16 verify-faithfulness-gate.sh exits 0 (faithfulness gate blocks + flags + deterministic)"
else
  record_fail "R16 verify-faithfulness-gate.sh exits non-zero (faithfulness gate regression)"
fi

# R17 — citation coverage (vision check #5): the --coverage gate flags pages
# that make claims with no resolving citation, and exempts type:navigation and
# provenance:none. Catches the inverse of R8 — claims with no source at all.
if "$SCRIPT_DIR/verify-citation-coverage.sh" >/dev/null 2>&1; then
  ok "R17 verify-citation-coverage.sh exits 0 (uncited claims flagged, exemptions honored)"
else
  record_fail "R17 verify-citation-coverage.sh exits non-zero (coverage gate regression)"
fi

# R18 — bundle round-trip (V3): package a fixture wiki, verify it (exit 0), then
# tamper (modify a file / add an unmanifested file / break a citation / add an
# uncited claim page) and assert each is rejected. Proves package-wiki + verify-bundle
# gates (incl. G4/B5 coverage) actually bite. No LLM/key.
if "$SCRIPT_DIR/verify-bundle-roundtrip.sh" >/dev/null 2>&1; then
  ok "R18 verify-bundle-roundtrip.sh exits 0 (package/verify gates bite on tamper)"
else
  record_fail "R18 verify-bundle-roundtrip.sh exits non-zero (bundle round-trip regression)"
fi

# R19 — REAL-wiki coverage gate (V5): R17 proves the mechanism on a synthetic
# fixture; this gates the repo's ACTUAL wiki/ so a committed uncited claim fails CI.
if python3 "$SCRIPT_DIR/citation-audit.py" wiki --raw raw --coverage >/dev/null 2>&1; then
  ok "R19 real wiki/ passes citation coverage (every claim-bearing page is sourced)"
else
  record_fail "R19 real wiki/ has an uncited claim-bearing page (citation-audit --coverage)"
fi

# R20 — bare-web-URL guard (V2 gap 3): citation-audit.py --no-bare-urls flags
# bare `(source: <url>)` cites (web sources that dodge the raw/-only floor) and
# passes raw-snapshot cites; the repo's REAL wiki/ must carry zero bare-url cites.
# Closes the "ships with receipts" hole — web sources must be snapshotted to raw/
# before citing so the claim is coverage-counted and entailment-checkable.
if "$SCRIPT_DIR/verify-no-bare-urls.sh" >/dev/null 2>&1; then
  ok "R20 verify-no-bare-urls.sh exits 0 (bare web cites flagged; real wiki/ clean)"
else
  record_fail "R20 verify-no-bare-urls.sh exits non-zero (bare-web-URL guard regression)"
fi

# R21 — OKF export oracle: wiki-to-okf.py holds its four export guarantees —
# (a) non-empty type on every non-reserved .md, (b) zero unconverted canonical
# wikilinks, (c) deterministic/byte-identical, (d) read-only on wiki/ & raw/ —
# plus the field mapping ([[link]]→md, updated→timestamp, TL;DR→description).
if "$SCRIPT_DIR/verify-wiki-to-okf.sh" >/dev/null 2>&1; then
  ok "R21 verify-wiki-to-okf.sh exits 0 (OKF export conformant + deterministic + read-only)"
else
  record_fail "R21 verify-wiki-to-okf.sh exits non-zero (OKF export regression)"
fi

# ──── ADVISORY: log discipline (warn, does not fail the build) ────
# The log is the keystone that makes every other soft rule auditable after the
# fact. This surfaces a HEAD commit that changed wiki/ without a log.md entry —
# warn-not-block (legit non-logged edits exist; exempt with [skip-log]).
section "Advisory (does not fail the build)"
"$SCRIPT_DIR/verify-log-discipline.sh" HEAD | sed 's/^/  /' || true

# ──── SUMMARY ────
section "Summary"
if [ "$failures" -eq 0 ]; then
  printf "%sAll 26 checks green.%s\n" "$GREEN" "$RESET"
  exit 0
fi
printf "%s%d check(s) failed.%s See diagnostics above.\n" "$RED" "$failures" "$RESET"
exit 1
