#!/usr/bin/env bash
# scripts/visualize/render.sh — render a self-contained HTML poster to PDF or PNG.
#
# Used by /wiki-query --visual pdf|png and /wiki-diagram --pdf|--png to turn the
# HTML poster produced from the infographic generator-contract into a PDF or PNG.
#
# Renderer detection (graceful, optional-dependency posture — never silent):
#   1. a system headless browser (Chrome / Chromium / Edge / Brave), else
#   2. `npx -y -p puppeteer@latest node …` (puppeteer fetches its own Chromium), else
#   3. fail-soft: leave the HTML in place, print an install hint, exit non-zero.
#
# PDF is the high-fidelity path (single-page, vector). PNG is best-effort raster:
# full-page via puppeteer; a tall fixed canvas via system Chrome (--height to tune).
#
# Usage:
#   ./scripts/visualize/render.sh <input.html> --pdf [--out <path>] [--width N] [--height N]
#   ./scripts/visualize/render.sh <input.html> --png [--out <path>] [--width N] [--height N]
#
# Defaults: --out is <input> with the .pdf/.png extension; --width 800 (poster width);
#           --height 2400 (system-Chrome PNG canvas only; ignored by puppeteer full-page).

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: render.sh <input.html> --pdf|--png [--out <path>] [--width N] [--height N]" >&2
  exit 2
fi

input="$1"; shift
fmt=""
out=""
width=800
height=2400

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pdf) fmt="pdf"; shift ;;
    --png) fmt="png"; shift ;;
    --out) out="$2"; shift 2 ;;
    --out=*) out="${1#*=}"; shift ;;
    --width) width="$2"; shift 2 ;;
    --width=*) width="${1#*=}"; shift ;;
    --height) height="$2"; shift 2 ;;
    --height=*) height="${1#*=}"; shift ;;
    *) echo "error: unknown arg $1" >&2; exit 2 ;;
  esac
done

[ -n "$fmt" ] || { echo "error: one of --pdf or --png is required" >&2; exit 2; }
[ -f "$input" ] || { echo "error: input not found: $input" >&2; exit 2; }

# Absolute paths (file:// URL + browsers resolve relative oddly).
in_dir="$(cd "$(dirname "$input")" && pwd)"
in_base="$(basename "$input")"
abs_in="$in_dir/$in_base"
[ -n "$out" ] || out="${abs_in%.html}.$fmt"
case "$out" in /*) abs_out="$out" ;; *) abs_out="$(pwd)/$out" ;; esac
mkdir -p "$(dirname "$abs_out")"

hint() {
  echo "─────────────────────────────────────────────────────────────" >&2
  echo "render: no renderer found — kept the HTML, skipped $fmt." >&2
  echo "  HTML poster: $abs_in" >&2
  echo "  To enable $fmt export, install ONE of:" >&2
  echo "    • Google Chrome / Chromium (https://www.google.com/chrome/), or" >&2
  echo "    • Node.js ≥18 (https://nodejs.org) — puppeteer fetches its own Chromium" >&2
  echo "  Then re-run. Open the HTML in any browser meanwhile." >&2
  echo "─────────────────────────────────────────────────────────────" >&2
}

# --- 1. system headless browser ------------------------------------------
find_browser() {
  local c
  for c in google-chrome-stable google-chrome chromium chromium-browser chrome microsoft-edge brave-browser; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  for c in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

render_with_browser() {
  local bin="$1" tmp; tmp="$(mktemp -d)"
  local common="--headless=new --no-sandbox --disable-gpu --no-first-run --user-data-dir=$tmp"
  local rc=0
  if [ "$fmt" = "pdf" ]; then
    "$bin" $common --no-pdf-header-footer --print-to-pdf="$abs_out" "file://$abs_in" >/dev/null 2>&1 || rc=$?
  else
    "$bin" $common --hide-scrollbars --force-device-scale-factor=2 \
      --window-size="${width},${height}" --screenshot="$abs_out" "file://$abs_in" >/dev/null 2>&1 || rc=$?
  fi
  rm -rf "$tmp"
  [ "$rc" -eq 0 ] && [ -s "$abs_out" ]
}

# --- 2. node + puppeteer (persistent cache) -------------------------------
# puppeteer (+ its own Chromium) is installed ONCE into a persistent cache dir
# and reused — so a browserless user pays the ~150MB download a single time, not
# per render. The script runs FROM the cache dir so Node's standard node_modules
# walk resolves `require('puppeteer')` (npx/-c does not export NODE_PATH for
# require; ESM ignores it entirely). Args pass via env vars.
render_with_puppeteer() {
  command -v npm  >/dev/null 2>&1 || return 1
  command -v node >/dev/null 2>&1 || return 1
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/llm-wiki-render"
  mkdir -p "$cache" || return 1
  if [ ! -f "$cache/node_modules/puppeteer/package.json" ]; then
    echo "render: first run — installing puppeteer (~150MB Chromium) into $cache (one time)…" >&2
    ( cd "$cache" && npm init -y >/dev/null 2>&1 && npm install puppeteer@latest >/dev/null 2>&1 ) \
      || { echo "render: puppeteer install failed (offline?)." >&2; return 1; }
  fi
  cat > "$cache/render.cjs" <<'JS'
const puppeteer = require('puppeteer');
(async () => {
  const input = process.env.RENDER_IN, out = process.env.RENDER_OUT, fmt = process.env.RENDER_FMT;
  const w = parseInt(process.env.RENDER_W, 10) || 800;
  const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: 1000, deviceScaleFactor: 2 });
  await page.goto('file://' + input, { waitUntil: 'networkidle0' });
  const h = await page.evaluate(() => Math.ceil(document.body.scrollHeight));
  if (fmt === 'pdf') {
    await page.pdf({ path: out, width: w + 'px', height: h + 'px', printBackground: true, pageRanges: '1' });
  } else {
    // Tight capture: size the viewport to the content height, then a non-fullPage
    // screenshot — avoids the trailing whitespace fullPage leaves below short content.
    await page.setViewport({ width: w, height: h, deviceScaleFactor: 2 });
    await page.screenshot({ path: out, fullPage: false });
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
JS
  local rc=0
  RENDER_IN="$abs_in" RENDER_OUT="$abs_out" RENDER_FMT="$fmt" RENDER_W="$width" \
    node "$cache/render.cjs" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 0 ] && [ -s "$abs_out" ]
}

# --- dispatch -------------------------------------------------------------
# Test seam: RENDER_DISABLE=1 forces the no-renderer path (used by the oracle to
# exercise fail-soft deterministically regardless of what's installed).
if [ -n "${RENDER_DISABLE:-}" ]; then
  hint
  exit 3
fi

if browser="$(find_browser)"; then
  if render_with_browser "$browser"; then
    echo "✓ rendered $fmt → $abs_out  (via $(basename "$browser"))"
    exit 0
  fi
  echo "render: system browser failed; trying puppeteer…" >&2
fi

if render_with_puppeteer; then
  echo "✓ rendered $fmt → $abs_out  (via node + puppeteer)"
  exit 0
fi

hint
exit 3
