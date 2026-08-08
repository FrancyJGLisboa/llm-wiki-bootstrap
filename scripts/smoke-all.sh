#!/usr/bin/env bash
# scripts/smoke-all.sh — umbrella verifier for the end-to-end smoke.
#
# Composes the build phase (LLM-driven, idempotent), the smoke checks
# (C1–C5), and the regression guards (R1–R28) into a single exit-code-
# driven test.
#
# Exit 0 iff all 31 checks pass.
#
# --no-build : skip the LLM build phase (which needs the `claude` CLI) and run
#   only the 31 deterministic checks (C1–C5 asserts on the committed artifacts +
#   R1–R28 guards). This is the CI path — the build phase is a precondition that
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
# passes is counted, not narrated. The summary used to print a hardcoded "All 31
# checks green" — so adding two checks left it still claiming 31, and REMOVING a
# check would have left it claiming 31 too. A suite that reports a literal
# instead of its own tally can lose coverage without the number ever moving.
passes=0
ok()   { passes=$((passes + 1)); printf "%s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
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

# ──── REGRESSION GUARDS R1–R28 ────
section "Regression guards (R1–R28)"

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
if ! grep -q '\*\*Schema version:\*\* 5' AGENTS.md; then
  r4_ok=no
  record_fail "R4 AGENTS.md schema version is not 5"
fi
if ! grep -qE '^- .type. — .concept.*entity.*summary.*analysis.*navigation.*journal.*rule' AGENTS.md; then
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

# R7 — installer oracle (create-context-compiler: tree shape EQUALS manifest + no dev-repo
# string leakage + target preflight).
if "$SCRIPT_DIR/verify-create-context-compiler.sh" >/dev/null 2>&1; then
  ok "R7 verify-create-context-compiler.sh exits 0 (clean fresh-skeleton install)"
else
  record_fail "R7 verify-create-context-compiler.sh exits non-zero (installer regression)"
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

# R22 — hash-drift lint oracle (H1–H5): the ingest commitment is enforced —
# a raw body edited after ingest is caught and attributed to the wiki pages
# citing it, never-ingested sources stay quiet, and an unhashable body with a
# recorded hash cannot pass green. H5 gates the repo's REAL raw/.
if "$SCRIPT_DIR/verify-hash-drift.sh" >/dev/null 2>&1; then
  ok "R22 verify-hash-drift.sh exits 0 (drift caught + attributed; real raw/ committed)"
else
  record_fail "R22 verify-hash-drift.sh exits non-zero (hash-drift lint regression)"
fi

# R23 — retrieval-eval oracle (E1–E6): the cross-modality eval's corpus is
# deterministic, its needles sit past every preview boundary, and its graders
# can't be faked (whole-file/wrong-line/oversized citations all fail). Guards the
# measuring instrument itself — no LLM, no spend.
if "$SCRIPT_DIR/verify-retrieval-eval.sh" >/dev/null 2>&1; then
  ok "R23 verify-retrieval-eval.sh exits 0 (corpus fixed, needles deep, graders honest)"
else
  record_fail "R23 verify-retrieval-eval.sh exits non-zero (retrieval-eval instrument regression)"
fi

# R23b — the passive-record monitoring path. Integrity numbers logged on every
# REAL operation are what let wiki-flows.sh trend commitment and citation
# resolution; an unverified recorder would silently log a plausible fiction, and
# a fabricated trend is worse than no trend. Also asserts the recorder never
# writes raw/ and never rewrites prior log.md bytes.
if "$SCRIPT_DIR/verify-metrics.sh" >/dev/null 2>&1; then
  ok "R23b verify-metrics.sh exits 0 (records measured, append-only, trendable)"
else
  record_fail "R23b verify-metrics.sh exits non-zero (monitoring recorder regression)"
fi

# R23d — the published page makes claims to strangers. It was the one artifact
# here with nothing verifying it, and it rotted within hours of publication
# (advertising 31 smoke checks while the CI configuration ran 26). Structural
# numbers are recomputed from the repo; scores must carry a date.
if "$SCRIPT_DIR/verify-site-claims.sh" >/dev/null 2>&1; then
  ok "R23d verify-site-claims.sh exits 0 (site/index.html's numbers still true)"
else
  record_fail "R23d verify-site-claims.sh exits non-zero (the published page states a stale number)"
fi

# R23c — the feedback-loop lens. Polarity is the whole value (an odd number of
# `prevents` legs flips a loop's sign), and it must survive renaming/reordering
# and report an uncited edge instead of laundering it into fact.
if "$SCRIPT_DIR/verify-loops.sh" >/dev/null 2>&1; then
  ok "R23c verify-loops.sh exits 0 (loop detection, polarity, provenance, flows)"
else
  record_fail "R23c verify-loops.sh exits non-zero (systems-lens regression)"
fi

# R24 — the valid-time contract. `fetched_at` alone is transaction time; without
# `asserted_at` an as-of question has nothing structured to resolve against, and
# the eval's as-of leg passes only while the corpus states its vintage in prose.
# A5 is the check that matters: stamping fetched_at as the document date is the
# cheapest way to fake full coverage, so it must be rejected by name.
if "$SCRIPT_DIR/verify-asserted-at.sh" >/dev/null 2>&1; then
  ok "R24 verify-asserted-at.sh exits 0 (dates traceable, unknowns explicit, fetch-stamping blocked)"
else
  record_fail "R24 verify-asserted-at.sh exits non-zero (valid-time contract regression)"
fi

# R25 — /ctx-query's raw-citation contract. R4 measured 0/5, 0/5, 0/7 across
# three eval runs and the cause was a spec gap, not the model: the output
# template never asked for an inline `(source: raw/...)` at all, so the shape
# varied per run and nothing could verify it. Q5 is the load-bearing one — the
# form the doc teaches must stay identical to the form the audit extracts.
if "$SCRIPT_DIR/verify-query-citation-contract.sh" >/dev/null 2>&1; then
  ok "R25 verify-query-citation-contract.sh exits 0 (citation form stated + grader-compatible)"
else
  record_fail "R25 verify-query-citation-contract.sh exits non-zero (/ctx-query citation contract regression)"
fi

# R26 — the entity eval's graders. E1 recall and E2 precision are each trivially
# gameable alone (dump every Title Case phrase / emit only the two obvious
# names), so this asserts each strategy actually LOSES. N7 guards a BSD-sed trap
# that once made E3 read 0% on correct data.
if "$SCRIPT_DIR/verify-entity-eval.sh" >/dev/null 2>&1; then
  ok "R26 verify-entity-eval.sh exits 0 (recall/precision each punish the other's false pass)"
else
  record_fail "R26 verify-entity-eval.sh exits non-zero (entity-eval grader regression)"
fi

# R27 — the real-corpus eval's graders. Every other eval here runs on a corpus
# built to be retrievable; this one runs on content that already exists, where
# the subject matter IS in pretraining. Two ways that measurement goes vacuous
# without anyone noticing: the date leg stops failing (so "cited the right
# episode" degrades to "said the right words"), and the staged timestamp anchors
# stop resolving in one of their two forms (padded vs unpadded), which reads as
# a retrieval failure but is a formatting accident.
if "$SCRIPT_DIR/verify-corpus-eval.sh" >/dev/null 2>&1; then
  ok "R27 verify-corpus-eval.sh exits 0 (date leg can fail; staging deterministic; both anchor forms resolve)"
else
  record_fail "R27 verify-corpus-eval.sh exits non-zero (real-corpus eval grader regression)"
fi

# R28 — /ctx-query's temporal contract. Cross-temporal questions scored 3/6
# against 16/16 for single-source recall, and the failures opened zero files:
# they narrated a trajectory out of the synthesis artifacts, which aggregate the
# timeline away. The router (wiki-timeline.py) and the read floor
# (wiki-metrics.sh --temporal) only work as a pair, so this asserts both — and
# exercises the floor in BOTH directions, since a gate that never blocks and a
# gate that blocks everything are equally useless and look identical in a log.
if "$SCRIPT_DIR/verify-query-temporal-contract.sh" >/dev/null 2>&1; then
  ok "R28 verify-query-temporal-contract.sh exits 0 (router specified; read floor blocks single-date answers)"
else
  record_fail "R28 verify-query-temporal-contract.sh exits non-zero (/ctx-query temporal contract regression)"
fi

# R29 — the eval's own prompt purity. Three separate author-side fields have
# leaked through retr_parse_questions' catch-all into the text sent to the model
# (`requires:`, `change:`, `cite-file-matches:`) — the last one pasted the ERE
# naming the correct source file's date prefix into 54 of 66 prompts, and the
# check it feeds is precisely "did you cite a source of the right date". Every
# figure measured before it was found is suspect. This runs the real parsers on
# the real fixtures and asserts no `field:` line survives into a question.
if "$SCRIPT_DIR/gate-eval-prompt-purity.sh" >/dev/null 2>&1; then
  ok "R29 gate-eval-prompt-purity.sh exits 0 (no author-side metadata reaches the model)"
else
  record_fail "R29 gate-eval-prompt-purity.sh exits non-zero (an eval fixture leaks metadata into the prompt)"
fi

# R30 — raw/ is append-only (AGENTS.md hard rule #1), until now prose-only.
# Every other gate rests on this: citations resolve into raw/, hash-drift
# compares against it, the faithfulness gate entails from it. A quietly edited
# raw body makes hash-drift fire on the symptom and never name the cause.
# Worktree mode, so history is never required to be fixed.
if "$SCRIPT_DIR/gate-raw-append-only.sh" >/dev/null 2>&1; then
  ok "R30 gate-raw-append-only.sh exits 0 (raw/ changes are additions or ingest commitments only)"
else
  record_fail "R30 gate-raw-append-only.sh exits non-zero (unauthorised write to the immutable raw layer)"
fi

# R31 — the gates' own fixtures. A gate that never fires is indistinguishable
# from a broken one; these assert both directions on committed fixtures.
gate_fixtures_ok=1
"$SCRIPT_DIR/gate-eval-prompt-purity.sh" tests/gates/eval-purity/clean-questions.md >/dev/null 2>&1 || gate_fixtures_ok=0
"$SCRIPT_DIR/gate-eval-prompt-purity.sh" tests/gates/eval-purity/dirty-questions.md >/dev/null 2>&1 && gate_fixtures_ok=0
"$SCRIPT_DIR/gate-raw-append-only.sh" --diff tests/gates/raw-append-only/clean.diff >/dev/null 2>&1 || gate_fixtures_ok=0
"$SCRIPT_DIR/gate-raw-append-only.sh" --diff tests/gates/raw-append-only/dirty.diff >/dev/null 2>&1 && gate_fixtures_ok=0
"$SCRIPT_DIR/gate-reachable.sh"   --repo tests/gates/reachable/clean  >/dev/null 2>&1 || gate_fixtures_ok=0
"$SCRIPT_DIR/gate-reachable.sh"   --repo tests/gates/reachable/dirty  >/dev/null 2>&1 && gate_fixtures_ok=0
"$SCRIPT_DIR/gate-doc-claims.sh"  --repo tests/gates/doc-claims/clean >/dev/null 2>&1 || gate_fixtures_ok=0
"$SCRIPT_DIR/gate-doc-claims.sh"  --repo tests/gates/doc-claims/dirty >/dev/null 2>&1 && gate_fixtures_ok=0
"$SCRIPT_DIR/gate-ratchet.sh"     --repo tests/gates/ratchet/clean    >/dev/null 2>&1 || gate_fixtures_ok=0
"$SCRIPT_DIR/gate-ratchet.sh"     --repo tests/gates/ratchet/dirty    >/dev/null 2>&1 && gate_fixtures_ok=0
"$SCRIPT_DIR/gate-command-aliases.sh" --repo tests/gates/command-aliases/clean >/dev/null 2>&1 || gate_fixtures_ok=0
"$SCRIPT_DIR/gate-command-aliases.sh" --repo tests/gates/command-aliases/dirty >/dev/null 2>&1 && gate_fixtures_ok=0
"$SCRIPT_DIR/gate-exec-bits.sh" --repo tests/gates/exec-bits/clean --index tests/gates/exec-bits/clean/index.txt >/dev/null 2>&1 || gate_fixtures_ok=0
"$SCRIPT_DIR/gate-exec-bits.sh" --repo tests/gates/exec-bits/dirty --index tests/gates/exec-bits/dirty/index.txt >/dev/null 2>&1 && gate_fixtures_ok=0
if [ "$gate_fixtures_ok" = 1 ]; then
  ok "R31 all seven gates fail their violating fixture and pass their clean one"
else
  record_fail "R31 a gate no longer discriminates on its own fixtures (it fires on clean input, or misses a planted violation)"
fi

# R32 — the scale eval's own oracle (F1–F7). README names this as one of the
# three oracles that "verify every grader — an eval nobody checks measures
# nothing", and nothing ran it. Found by gate-reachable.sh; it is deterministic
# and key-free, so the fix was to wire it, not to declare it standalone.
if "$SCRIPT_DIR/verify-scale-eval.sh" >/dev/null 2>&1; then
  ok "R32 verify-scale-eval.sh exits 0 (parity/budget/index gates + crash-survival hold)"
else
  record_fail "R32 verify-scale-eval.sh exits non-zero (scale-eval oracle regression)"
fi

# R33 — no orphan oracles. An unwired gate reads as coverage and never fires,
# which is how most broken gates are born. Transitive reachability from the CI
# workflows; declared standalones are printed as suppressions, never silent.
if "$SCRIPT_DIR/gate-reachable.sh" >/dev/null 2>&1; then
  ok "R33 gate-reachable.sh exits 0 (every verify-*/gate-* oracle is reachable from CI)"
else
  record_fail "R33 gate-reachable.sh exits non-zero (an oracle exists that nothing runs)"
fi

# R34 — structural numbers stated in prose are recomputed, not typed. README
# described the suite as running "R1–R4 regression guards" for the two dozen
# commits it took to reach R28: a doc that lies produces no red.
if "$SCRIPT_DIR/gate-doc-claims.sh" >/dev/null 2>&1; then
  ok "R34 gate-doc-claims.sh exits 0 (every bound doc claim recomputes to its stated value)"
else
  record_fail "R34 gate-doc-claims.sh exits non-zero (a documented number no longer matches the repo)"
fi

# R35 — the Context Package Quality scorecard. The project's definition claims
# a package LLMs "can navigate, retrieve from, and reason over"; an unmeasured
# claim is a slogan, so package-quality.sh scores the structural half. But a
# scorecard that only ever prints green launders debt as quality — this oracle
# proves it still detects an unsound package, reads JSON values rather than
# prose labels (a clean package once scored "2 thin" because the label
# "(<2 related)" contains a 2), and never edits what it measures.
if "$SCRIPT_DIR/verify-package-quality.sh" >/dev/null 2>&1; then
  ok "R35 verify-package-quality.sh exits 0 (scorecard detects unsoundness, reads values not labels, read-only)"
else
  record_fail "R35 verify-package-quality.sh exits non-zero (the quality scorecard can no longer be trusted)"
fi

# R36 — the ratchet. deterministic-gates §6 sat in the doctrine unimplemented:
# nothing read a baseline, nothing failed on an increase, and no baseline file
# existed. Without it, adopting a gate means fixing every historical violation
# first — so the realistic alternative to a ratchet is not a stricter repo, it
# is a gate nobody turns on. This also makes suppressions cost something:
# gate-reachable.sh already counted its declared standalones and printed them,
# but nothing consumed the number, so silencing an orphan oracle was free.
if "$SCRIPT_DIR/gate-ratchet.sh" >/dev/null 2>&1; then
  ok "R36 gate-ratchet.sh exits 0 (no gate's violations or suppressions exceed gates/baseline.tsv)"
else
  record_fail "R36 gate-ratchet.sh exits non-zero (a gate's violation or suppression count went up, or a gate has no baseline row)"
fi

# R37 — command aliases resolve. .claude/commands/ now holds three naming
# generations (canonical ctx-*, short aliases, deprecated wiki-* forwarders);
# 19 of the 28 files contain no procedure and only point elsewhere. A forwarder
# whose target was renamed does not fail loudly — the agent cannot find the file
# and improvises, so the damage surfaces as a bad wiki edit, not an error.
if "$SCRIPT_DIR/gate-command-aliases.sh" >/dev/null 2>&1; then
  ok "R37 gate-command-aliases.sh exits 0 (every alias resolves to an existing canonical command, no chains)"
else
  record_fail "R37 gate-command-aliases.sh exits non-zero (an alias points at a missing command, disagrees with its own body, or chains through another alias)"
fi

# R38 — executable bits survive bulk rewrites. Harvested from a real regression
# in this session (deterministic-gates §7): a 128-file rename using
# `cmd "$f" > "$f.new" && mv "$f.new" "$f"` replaced inodes and dropped +x on 55
# scripts. The suite went 20-red and not one message named the cause — each
# oracle reported a "regression" in its own subject. This gate detects nothing
# the suite missed; it exists so the twenty-failure cascade reads as one line.
if "$SCRIPT_DIR/gate-exec-bits.sh" >/dev/null 2>&1; then
  ok "R38 gate-exec-bits.sh exits 0 (every file git records as 100755 is still executable)"
else
  record_fail "R38 gate-exec-bits.sh exits non-zero (a tracked executable lost its +x bit — usually a redirect-and-move rewrite)"
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
  if [ "$BUILD" = 1 ]; then
    printf "%sAll %d checks green here, plus the build phase's own checks above.%s\n" "$GREEN" "$passes" "$RESET"
  else
    printf "%sAll %d checks green (--no-build: the LLM build phase and its checks did not run).%s\n" "$GREEN" "$passes" "$RESET"
  fi
  exit 0
fi
printf "%s%d check(s) failed.%s See diagnostics above.\n" "$RED" "$failures" "$RESET"
exit 1
