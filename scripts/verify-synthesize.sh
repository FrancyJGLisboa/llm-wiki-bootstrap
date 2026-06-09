#!/usr/bin/env bash
# scripts/verify-synthesize.sh — verify the synthesis layer against a hermetic
# fixture wiki built in a temp dir (never touches the repo's own wiki/).
#
# Checks:
#   - all.sh exits 0 and creates all four artifacts
#   - DETERMINISM: a second run produces byte-identical artifacts (the guarantee
#     that makes "regenerate on every mutation" churn-free)
#   - CONTENT: a planted `## Open questions` bullet and `> CONTRADICTION FLAGGED`
#     line appear in their dashboards with the right [[link]]
#   - knowledge-graph.json parses; node count == number of *.md files
#   - GRAPH PARITY: graph-html.py --json equals the data the HTML view embeds
#   - generated markdown pages start with frontmatter (lint check #7) + carry the
#     AUTO-GENERATED marker, and don't aggregate themselves on re-run
#
# Usage:   ./scripts/verify-synthesize.sh
# Exit:    0 all checks passed · 1 a check failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -t 1 ]; then
  RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  RED=; YELLOW=; GREEN=; RESET=
fi
failures=0
ok()   { printf "%s✓%s %s\n" "$GREEN"  "$RESET" "$1"; }
warn() { printf "%s⚠%s %s\n" "$YELLOW" "$RESET" "$1"; }
fail() { printf "%s✗%s %s\n" "$RED"    "$RESET" "$1"; failures=$((failures + 1)); }

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 not found (required by the synthesis generators)"
  exit 1
fi

# ---- build a hermetic fixture wiki -----------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/wiki"

cat > "$tmp/wiki/page-a.md" <<'EOF'
---
title: Page A
type: concept
source: analysis
updated: 2026-06-01
tags: [fixture]
---

# Page A

Body links to [[page-b]].

> CONTRADICTION FLAGGED 2026-06-02: A says X. Contradicts [[page-b]], which says not-X.

## Related
- [[page-b]] — sibling

## Open questions on this page
- Does the A approach scale past ten sources?
EOF

cat > "$tmp/wiki/page-b.md" <<'EOF'
---
title: Page B
type: concept
source: analysis
updated: 2026-06-03
tags: [fixture]
---

# Page B

Body links to [[page-a]].

## Related
- [[page-a]] — sibling

## Open questions on this page
- ... (consumed by /wiki-lint)
EOF

cat > "$tmp/log.md" <<'EOF'
# log.md

## 2026-06-04 — schema bump (date-only header, no time)

A summary entry with no HH:MM, like real cut-to-core / schema-bump headers.

## 2026-06-03 09:00 — /wiki-ingest

- Processed: raw/page-b.md (hash abcd1234)

## 2026-06-01 08:00 — /wiki-ingest

- Processed: raw/page-a.md (hash 0badf00d)
EOF

# ---- run + first checks -----------------------------------------------------
if "$SCRIPT_DIR/synthesize/all.sh" "$tmp" >/dev/null 2>&1; then
  ok "all.sh exited 0"
else
  fail "all.sh exited non-zero"; exit 1
fi

for f in open-questions-dashboard.md tensions.md decision-timeline.md knowledge-graph.json; do
  if [ -f "$tmp/wiki/$f" ]; then ok "artifact created: $f"; else fail "missing artifact: $f"; fi
done

# ---- determinism: hash, re-run, hash again ---------------------------------
hash_all() { cat "$tmp/wiki/open-questions-dashboard.md" "$tmp/wiki/tensions.md" \
                 "$tmp/wiki/decision-timeline.md" "$tmp/wiki/knowledge-graph.json" | shasum -a 256 | cut -d' ' -f1; }
h1="$(hash_all)"
"$SCRIPT_DIR/synthesize/all.sh" "$tmp" >/dev/null 2>&1
h2="$(hash_all)"
if [ "$h1" = "$h2" ]; then ok "deterministic: re-run is byte-identical"; else fail "NON-deterministic: artifacts changed on re-run"; fi

# ---- content checks ---------------------------------------------------------
if grep -q "scale past ten sources" "$tmp/wiki/open-questions-dashboard.md" \
   && grep -q "\[\[page-a\]\]" "$tmp/wiki/open-questions-dashboard.md"; then
  ok "open-questions dashboard contains the planted question under [[page-a]]"
else
  fail "open-questions dashboard missing planted question or [[page-a]] link"
fi
# placeholder '...' question must NOT leak in
if grep -q "consumed by /wiki-lint" "$tmp/wiki/open-questions-dashboard.md"; then
  fail "placeholder '...' question leaked into the dashboard"
else
  ok "placeholder '...' question correctly skipped"
fi
if grep -q "2026-06-02" "$tmp/wiki/tensions.md" && grep -q "\[\[page-a\]\]" "$tmp/wiki/tensions.md"; then
  ok "tensions tracker contains the planted contradiction (date + source page)"
else
  fail "tensions tracker missing planted contradiction"
fi
if grep -q "2026-06-03" "$tmp/wiki/decision-timeline.md"; then
  ok "decision timeline parsed timestamped log.md entries"
else
  fail "decision timeline missing timestamped log entries"
fi
# date-only headers (no HH:MM) must NOT be silently dropped
if grep -q "2026-06-04" "$tmp/wiki/decision-timeline.md"; then
  ok "decision timeline includes date-only log header (no HH:MM dropped)"
else
  fail "decision timeline dropped the date-only log header"
fi
# count parity: one timeline bullet per '## ' log header
log_headers="$(grep -c '^## ' "$tmp/log.md" | tr -d ' ')"
timeline_bullets="$(grep -c '^- ' "$tmp/wiki/decision-timeline.md" | tr -d ' ')"
if [ "$log_headers" = "$timeline_bullets" ]; then
  ok "timeline bullet count ($timeline_bullets) == log '## ' headers ($log_headers)"
else
  fail "timeline drops entries: $timeline_bullets bullets vs $log_headers log headers"
fi

# ---- frontmatter-first + AUTO marker ---------------------------------------
for f in open-questions-dashboard.md tensions.md decision-timeline.md; do
  first="$(head -n 1 "$tmp/wiki/$f")"
  if [ "$first" = "---" ]; then ok "$f starts with frontmatter (lint #7)"; else fail "$f first line is not '---' (got '$first')"; fi
  if grep -q "AUTO-GENERATED by scripts/synthesize" "$tmp/wiki/$f"; then ok "$f carries AUTO-GENERATED marker"; else fail "$f missing AUTO-GENERATED marker"; fi
done

# ---- json validity + node count == md count --------------------------------
md_count="$(find "$tmp/wiki" -name '*.md' | wc -l | tr -d ' ')"
node_count="$(python3 -c "import json,sys; print(len(json.load(open('$tmp/wiki/knowledge-graph.json'))['nodes']))" 2>/dev/null || echo ERR)"
if [ "$node_count" = "$md_count" ]; then
  ok "knowledge-graph.json parses; nodes ($node_count) == *.md files ($md_count)"
else
  fail "graph nodes ($node_count) != *.md files ($md_count)"
fi

# ---- graph parity: --json equals HTML-embedded graph-data ------------------
if python3 - "$tmp/wiki" <<'PY'
import json, re, subprocess, sys
wiki = sys.argv[1]
gh = ["python3", __import__("os").path.join("scripts","visualize","graph-html.py"), wiki]
j = json.loads(subprocess.run(gh + ["--json"], capture_output=True, text=True).stdout)
html = subprocess.run(gh, capture_output=True, text=True).stdout
h = json.loads(re.search(r'<script id="graph-data"[^>]*>(.*?)</script>', html, re.S).group(1))
sys.exit(0 if j == h else 1)
PY
then ok "graph parity: --json output equals HTML embedded graph-data"; else fail "graph parity mismatch"; fi

echo
if [ "$failures" -gt 0 ]; then
  printf "%sFailed.%s %d check(s) did not pass.\n" "$RED" "$RESET" "$failures"
  exit 1
fi
warn "semantics — whether the aggregated views are *useful* — still needs a human eye."
printf "%sPassed.%s Synthesis layer checks all green.\n" "$GREEN" "$RESET"
exit 0
