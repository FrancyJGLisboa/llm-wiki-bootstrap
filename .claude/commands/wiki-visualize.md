---
description: Render the wiki as an interactive graph, slides, or mermaid images, or serve it locally. Wraps scripts/visualize/*. Read-only on raw/ and wiki/.
allowed-tools: Bash, Read, Glob
argument-hint: [graph|mermaid|slides|serve] [target] [--out <path>]
---

You are executing `/wiki-visualize $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to turn the wiki (or a single page) into a visual artifact by dispatching to the right script under `scripts/visualize/`. This is an **output command**, not a lifecycle step: it generates **new output files only** and never edits anything under `raw/` or `wiki/`.

## Read first

No wiki read is required — the scripts do their own parsing. **Do not reimplement any parsing logic here**; the scripts are the single source of truth (same rule as `scripts/body-hash.sh`). Consult `AGENTS.md` only if you need the `[[wiki-link]]` / typed-relation conventions to explain output to the user.

## Dispatch

Parse the first token of `$ARGUMENTS` as the subcommand. If it is not one of the four below, treat the whole argument string as a `graph` target.

| Subcommand | Script | Target | Needs |
|---|---|---|---|
| `graph [dir]` (default) | `scripts/visualize/graph.sh` | a directory (default `wiki`) | `python3` |
| `mermaid <page.md>` | `scripts/visualize/mermaid.sh` | a single markdown page | `npx` (Node ≥18) |
| `slides <page.md>` | `scripts/visualize/slides.sh` | a single markdown page | `npx` (Node ≥18) |
| `serve [dir] [port]` | `scripts/visualize/serve.sh` | a directory (default `.`) | `python3` |

Rules:

- **No subcommand** → run `graph` against `wiki/`, writing `wiki-graph.html`:
  `scripts/visualize/graph.sh wiki --out wiki-graph.html`.
- **`graph [dir]`** → `scripts/visualize/graph.sh <dir> --out <out>` (default `<out>` is `wiki-graph.html`). Honor `--out <path>` from `$ARGUMENTS` if present.
- **`mermaid <page>`** / **`slides <page>`** → pass the page through. Honor `-o <out>` / `--out <out>` if present; otherwise let the script derive the output next to the source.
- **`serve [dir] [port]`** → `scripts/visualize/serve.sh <dir> <port>` (defaults: dir `.`, port `8000`). This is a **foreground** server that blocks until Ctrl+C — tell the user the URL (`http://localhost:<port>`) and that it keeps running. Do not background it unless the user asks.

## Tool-presence check (before running)

Each script guards its own dependency and prints an install hint on failure. Surface that hint verbatim rather than swallowing it. Check first and, if the tool is missing, **do not run the script** — just report the hint and stop:

- `graph` / `serve` need `python3`. If `command -v python3` is empty: "python3 not found — install Python 3 (https://www.python.org/downloads/), then re-run."
- `mermaid` / `slides` need `npx` (Node ≥18). If `command -v npx` is empty: "npx not found — install Node.js ≥18 (https://nodejs.org), then re-run. The CLI is downloaded on first run."

## After running

- `graph`: report the output path, then offer the follow-up — "Run `/wiki-visualize serve` to browse it locally."
- `mermaid` / `slides`: report the path(s) of the generated image / HTML.
- `serve`: confirm the URL; it runs until interrupted.

## What you must NOT do

- Edit anything under `raw/` or `wiki/`. This command is read-only on both layers; it only writes output artifacts (`*.html`, `*.png`, `*.svg`).
- Reimplement the graph / slides / mermaid parsing. Always shell out to `scripts/visualize/*`.
- Background `serve.sh` silently — the user expects a foreground server they can stop.
