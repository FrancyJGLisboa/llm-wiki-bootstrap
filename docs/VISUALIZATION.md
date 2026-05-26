# Visualize your wiki — open-source, no Obsidian required

The bootstrap is viewer-agnostic by design (pure CommonMark, no rendering dependency). But once your wiki has enough pages, you'll want to *see* it — the connective tissue of `[[wiki-links]]` and the topical clusters. This guide covers the four scripts under `scripts/visualize/` and a short list of heavier alternatives.

All four scripts are opt-in. None modifies your wiki — they read your markdown and emit derived artifacts (HTML, slide decks, diagram images, a local server).

## 1. `graph.sh` — interactive force-directed graph (no install required)

```bash
./scripts/visualize/graph.sh wiki/ > graph.html
open graph.html        # or xdg-open / a browser
```

What it does: walks `wiki/` recursively, parses every `[[kebab-case]]` reference, builds a node-edge graph, emits one self-contained HTML file with a D3 v7 force layout. Drag nodes around; the force simulation keeps the layout readable. The graph data lives in a `<script id="graph-data" type="application/json">` block so external tooling (or you) can extract it programmatically.

**No npm, no Node, no Hugo, no Docker.** Just Python 3 (stdlib only).

D3 is loaded from the public CDN (`d3js.org/d3.v7.min.js`) by default. For offline use, drop `d3.v7.min.js` into `scripts/visualize/` and run with `--inline`:

```bash
curl -fsSL https://d3js.org/d3.v7.min.js > scripts/visualize/d3.v7.min.js
./scripts/visualize/graph.sh wiki/ --inline > graph.html
```

**Dangling-link behavior.** If a wiki page references `[[some-page]]` that doesn't exist as a file, the link is silently dropped from the graph. No ghost nodes; the graph reflects only actual pages and the connections between them.

## 2. `slides.sh` — turn any wiki page into a slide deck (MARP)

```bash
./scripts/visualize/slides.sh wiki/index.md -o slides.html
open slides.html
```

Wraps [`@marp-team/marp-cli`](https://github.com/marp-team/marp-cli) via `npx`. First run downloads marp-cli (~30s). Add `marp: true` to your page's frontmatter and use `---` lines as slide separators. The output is a self-contained HTML deck; pass `--pdf` to MARP for PDF (requires Chromium auto-fetch).

**Install hint** (if `npx` is missing): install Node.js ≥18 from [nodejs.org](https://nodejs.org).

## 3. `mermaid.sh` — render mermaid diagrams to PNG/SVG

```bash
./scripts/visualize/mermaid.sh wiki/ingest-pipeline.md
# → wiki/ingest-pipeline.png next to the source

./scripts/visualize/mermaid.sh some-diagram.mmd -o out.svg
```

Wraps [`@mermaid-js/mermaid-cli`](https://github.com/mermaid-js/mermaid-cli) (mmdc) via `npx`. mmdc auto-detects fenced ` ```mermaid ` blocks in markdown inputs, or takes `.mmd` source files directly. Output format is inferred from the `-o` extension (PNG / SVG / PDF). First run downloads mmdc and Chromium (~30–60s).

Mermaid code stays in your wiki pages as readable plain-text source; this script just gives you optional image renderings to embed elsewhere (e.g., a blog post, a slide, a presentation).

## 4. `serve.sh` — browse the wiki and its visualizations locally

```bash
./scripts/visualize/serve.sh                 # serve current dir on http://localhost:8000
./scripts/visualize/serve.sh wiki            # serve wiki/ specifically
./scripts/visualize/serve.sh wiki 9000       # on a non-default port
```

Wraps `python3 -m http.server`. Useful for opening a generated `graph.html` together with the underlying wiki pages in one browser session. Markdown viewer is browser-dependent — most browsers show source; install a markdown-rendering browser extension if you want WYSIWYG.

For automated checks: setting `VISUALIZE_DRY_RUN=1` prints what it would do and exits without binding the port. (Used by `verify-visualizers.sh`.)

## Verifying your visualization install

```bash
./scripts/visualize/verify-visualizers.sh
```

Runs the graph smoke against the bundled canary fixtures (always; pure Python). For `slides.sh` and `mermaid.sh`, the verifier runs a real input through each wrapper if the underlying npm tool is reachable; otherwise it prints `skipped: ...` and proceeds. `serve.sh` is dry-run smoked via the env var above.

All exits 0 → your visualization stack is working end-to-end.

## Heavier alternatives (recommended; not bundled)

If you want a full static-site experience — search, full graph + backlinks dashboard, theming, deployment to GitHub Pages — these projects work on plain markdown wikis without Obsidian:

- **[Quartz](https://quartz.jzhao.xyz/)** — Hugo-flavoured static publisher specifically designed for Obsidian-style notes. Graph view, backlinks, full-text search, mermaid, theming. The most batteries-included option.
- **[mdBook](https://rust-lang.github.io/mdBook/)** — Rust-based book-style HTML output. Tree-of-contents oriented; less graph-y, more linear.
- **[SilverBullet](https://silverbullet.md/)** — Local-first wiki engine with a plugin ecosystem. Closer to the "live system" feel of Obsidian/Logseq, browser-based.

Each requires its own setup (Node + Hugo for Quartz; Cargo for mdBook; Deno for SilverBullet). Pick one if the four built-in scripts don't reach far enough for your wiki's scale.

## What's intentionally NOT in this directory

- **Docker / Kroki** — diagram server requires container infra. Out of scope for the persona.
- **GUI / Electron app** — out of scope.
- **PDF/PPTX from slides.sh** — MARP can do it, but requires Chromium auto-fetch. Recipe in the MARP docs.
- **Native /wiki-visualize slash command** — these wrappers are plain bash; agentic tools call them via natural language.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `error: python3 not found` from graph.sh | Python 3 missing | Install Python ≥3.8; run `./scripts/preflight.sh` to confirm |
| `error: npx not found` from slides.sh / mermaid.sh | Node missing | Install Node.js ≥18 from [nodejs.org](https://nodejs.org) |
| First marp/mmdc run hangs ~30s | npx is downloading the package | Normal; subsequent runs are cached |
| mmdc fails with "browser couldn't be installed" | Chromium auto-install failed | Run `npx -y puppeteer browsers install chrome` once |
| Graph HTML opens but is blank | D3 CDN unreachable (offline) | Use `--inline` mode (see graph.sh section above) |
| Dangling links missing from graph | Working as designed | `[[link]]` to non-existent pages are silently dropped |
