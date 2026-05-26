#!/usr/bin/env bash
# scripts/visualize/verify-visualizers.sh — smoke harness for the visualization wrappers.
#
# What it asserts (and what it doesn't):
#
#   V2  — Graph generator works against the FLAT canary
#         (tests/canary/graph-fixture/ → 4 nodes, 4 links in <script id="graph-data">)
#   V2b — Graph generator works against the NESTED canary
#         (tests/canary/graph-fixture-nested/ → 2 nodes, 1 link; proves recursion)
#   V4  — For each of marp-cli and mermaid-cli:
#         IF the tool is reachable via `npx -y <pkg>@latest --version`:
#           run a real-input smoke through the wrapper; capture output;
#           assert wrapper exits 0 AND produced an output file.
#         ELSE print `skipped: <toolname> not installed (install: <hint>)`
#              and proceed without failing.
#         Anti-skip-gaming: the AVAILABLE branch MUST run the smoke. It MUST NOT
#         print 'skipped:' when the tool is reachable. (Structural — enforced by
#         this script's control flow.)
#         Also: live-smoke serve.sh via VISUALIZE_DRY_RUN=1 — must exit 0 without
#         binding a port.
#
# Exits 0 iff: graph smokes green AND every present-tool smoke green AND serve dry-run green.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  RED=; GREEN=; YELLOW=; DIM=; RESET=
fi

ok()   { printf "%s✓%s %s\n" "$GREEN"  "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"    "$RESET" "$1"; }
skip() { printf "%s○%s %s\n" "$YELLOW" "$RESET" "$1"; }

failures=0

# Temp scratch dir for marp + mmdc inputs/outputs; cleaned at exit.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ─── V2: flat canary graph smoke ───
graph_assert_counts() {
  local fixture="$1"
  local want_nodes="$2"
  local want_links="$3"
  local label="$4"
  local out="$TMP/graph-${label}.html"
  if ! "$SCRIPT_DIR/graph.sh" "$fixture" > "$out" 2> "$TMP/graph-${label}.err"; then
    fail "graph smoke ($label) — graph.sh exited non-zero"
    cat "$TMP/graph-${label}.err" >&2
    return 1
  fi
  if ! grep -q 'd3' "$out"; then
    fail "graph smoke ($label) — output missing D3 reference"
    return 1
  fi
  local got
  got="$(python3 -c "
import re, json, sys
m = re.search(r'<script id=\"graph-data\"[^>]*>(.*?)</script>', open(sys.argv[1]).read(), re.S)
if not m:
    print('parse-failed')
    sys.exit(1)
d = json.loads(m.group(1))
print(f\"{len(d['nodes'])} {len(d['links'])}\")
" "$out")"
  if [ "$got" = "$want_nodes $want_links" ]; then
    ok "graph smoke ($label): $want_nodes nodes, $want_links links"
  else
    fail "graph smoke ($label): expected $want_nodes nodes + $want_links links, got '$got'"
    return 1
  fi
}

graph_assert_counts "tests/canary/graph-fixture"        4 4 "flat"   || failures=$((failures + 1))
graph_assert_counts "tests/canary/graph-fixture-nested" 2 1 "nested" || failures=$((failures + 1))

# ─── V4 sub-check: marp-cli ───
marp_pkg="@marp-team/marp-cli@latest"
if command -v npx >/dev/null 2>&1 && npx -y "$marp_pkg" --version > "$TMP/marp.ver" 2>&1; then
  # AVAILABLE branch — must run a real smoke.
  cat > "$TMP/marp-input.md" <<'EOF'
---
marp: true
---

# slide 1

---

# slide 2
EOF
  if ./scripts/visualize/slides.sh "$TMP/marp-input.md" -o "$TMP/marp-output.html" >> "$TMP/marp.log" 2>&1 \
     && [ -s "$TMP/marp-output.html" ]; then
    ok "slides smoke: marp-cli rendered $(wc -c < "$TMP/marp-output.html") bytes of HTML"
  else
    fail "slides smoke: marp-cli failed (see $TMP/marp.log)"
    failures=$((failures + 1))
  fi
else
  skip "skipped: marp-cli not installed (install: npx -y $marp_pkg --version)"
fi

# ─── V4 sub-check: mermaid-cli ───
mmd_pkg="@mermaid-js/mermaid-cli@latest"
if command -v npx >/dev/null 2>&1 && npx -y "$mmd_pkg" --version > "$TMP/mmdc.ver" 2>&1; then
  # AVAILABLE branch — must run a real smoke.
  cat > "$TMP/mmdc-input.mmd" <<'EOF'
graph TD
  A --> B
EOF
  if ./scripts/visualize/mermaid.sh "$TMP/mmdc-input.mmd" -o "$TMP/mmdc-output.png" >> "$TMP/mmdc.log" 2>&1 \
     && [ -s "$TMP/mmdc-output.png" ]; then
    ok "mermaid smoke: mmdc rendered $(wc -c < "$TMP/mmdc-output.png") bytes"
  else
    fail "mermaid smoke: mmdc failed (see $TMP/mmdc.log)"
    failures=$((failures + 1))
  fi
else
  skip "skipped: mermaid-cli not installed (install: npx -y $mmd_pkg --version)"
fi

# ─── V4 sub-check: serve.sh dry-run ───
if VISUALIZE_DRY_RUN=1 ./scripts/visualize/serve.sh wiki 8000 > "$TMP/serve.log" 2>&1; then
  if grep -q 'would serve' "$TMP/serve.log"; then
    ok "serve dry-run: prints intent, exits 0 without binding"
  else
    fail "serve dry-run: exit 0 but expected 'would serve' marker missing"
    failures=$((failures + 1))
  fi
else
  fail "serve dry-run: exited non-zero"
  cat "$TMP/serve.log" >&2
  failures=$((failures + 1))
fi

# ─── Summary ───
echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d visualizer smoke(s) red.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
printf "%sPassed.%s All required visualizer smokes green.\n" "$GREEN" "$RESET"
exit 0
