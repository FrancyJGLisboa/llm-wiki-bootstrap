#!/usr/bin/env python3
"""Bespoke wiki-graph HTML generator.

Walks an input directory recursively for *.md files, parses [[kebab-case]]
references, and emits a self-contained HTML file with a D3 force-directed
graph.

Stdlib only — no external dependencies on the Python side. D3 v7 is loaded
from CDN by default; pass --inline (with d3.v7.min.js dropped next to this
script) to embed it for offline use.

The graph data is emitted as a dedicated <script id="graph-data"
type="application/json"> block so smoke tests can parse it without regex
heuristics over the whole HTML.

Spec: .scratch/visualization-tools/GOAL.md §5.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LINK_RE = re.compile(r"\[\[([a-z0-9-]+)\]\]")
D3_CDN = "https://d3js.org/d3.v7.min.js"


def collect_pages(root: Path) -> list[Path]:
    """Recursive *.md walk — required to reach wiki/journal/* and any subdirs."""
    return sorted(root.rglob("*.md"))


def build_graph(pages: list[Path]) -> tuple[list[dict], list[dict]]:
    """Return (nodes, links). Drop dangling links and self-loops; dedup edges."""
    stems = [p.stem for p in pages]
    if len(set(stems)) != len(stems):
        seen = set()
        dupes = []
        for s in stems:
            if s in seen:
                dupes.append(s)
            seen.add(s)
        sys.stderr.write(
            f"error: duplicate page stems (would collide as graph nodes): "
            f"{sorted(set(dupes))}\n"
        )
        sys.exit(1)

    node_set = set(stems)
    nodes = sorted(({"id": s} for s in stems), key=lambda n: n["id"])

    raw_edges: set[tuple[str, str]] = set()
    for page in pages:
        src = page.stem
        body = page.read_text(encoding="utf-8", errors="replace")
        for match in LINK_RE.finditer(body):
            tgt = match.group(1)
            if tgt == src:
                continue  # no self-loops
            if tgt not in node_set:
                continue  # drop dangling — no ghost nodes (see GOAL.md §5)
            raw_edges.add((src, tgt))
    links = sorted(
        ({"source": s, "target": t} for (s, t) in raw_edges),
        key=lambda e: (e["source"], e["target"]),
    )
    return nodes, links


def render_html(nodes: list[dict], links: list[dict], *, inline_d3: str | None) -> str:
    """Render the HTML document. inline_d3 is the embedded D3 source or None."""
    graph_json = json.dumps({"nodes": nodes, "links": links}, sort_keys=True)
    if inline_d3 is not None:
        d3_block = f"<script>{inline_d3}</script>"
    else:
        d3_block = f'<script src="{D3_CDN}"></script>'

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>llm-wiki graph</title>
<style>
  body {{ font-family: -apple-system, system-ui, sans-serif; margin: 0; background: #111; color: #ddd; }}
  svg {{ width: 100vw; height: 100vh; display: block; }}
  .node circle {{ fill: #69b3a2; stroke: #ddd; stroke-width: 1.5px; }}
  .node text {{ fill: #ddd; font-size: 11px; pointer-events: none; }}
  .link {{ stroke: #555; stroke-opacity: 0.6; }}
</style>
</head>
<body>
{d3_block}
<script id="graph-data" type="application/json">{graph_json}</script>
<svg id="graph"></svg>
<script>
const data = JSON.parse(document.getElementById('graph-data').textContent);
const svg = d3.select('#graph');
const width = window.innerWidth, height = window.innerHeight;

const simulation = d3.forceSimulation(data.nodes)
  .force('link', d3.forceLink(data.links).id(d => d.id).distance(80))
  .force('charge', d3.forceManyBody().strength(-200))
  .force('center', d3.forceCenter(width / 2, height / 2));

const link = svg.append('g').attr('class', 'links').selectAll('line')
  .data(data.links).enter().append('line').attr('class', 'link');

const node = svg.append('g').attr('class', 'nodes').selectAll('g')
  .data(data.nodes).enter().append('g').attr('class', 'node')
  .call(d3.drag()
    .on('start', (e, d) => {{ if (!e.active) simulation.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; }})
    .on('drag',  (e, d) => {{ d.fx = e.x; d.fy = e.y; }})
    .on('end',   (e, d) => {{ if (!e.active) simulation.alphaTarget(0); d.fx = null; d.fy = null; }}));

node.append('circle').attr('r', 7);
node.append('text').attr('dx', 10).attr('dy', 4).text(d => d.id);

simulation.on('tick', () => {{
  link
    .attr('x1', d => d.source.x).attr('y1', d => d.source.y)
    .attr('x2', d => d.target.x).attr('y2', d => d.target.y);
  node.attr('transform', d => `translate(${{d.x}},${{d.y}})`);
}});
</script>
</body>
</html>
"""


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate a D3 graph HTML from a directory of wiki markdown files.")
    parser.add_argument("input_dir", type=Path, help="Directory to walk recursively for *.md")
    parser.add_argument("--inline", action="store_true",
                        help="Embed d3.v7.min.js inline (must be present at scripts/visualize/d3.v7.min.js)")
    parser.add_argument("--out", type=Path, default=None,
                        help="Output HTML path (default: stdout)")
    args = parser.parse_args(argv)

    if not args.input_dir.is_dir():
        sys.stderr.write(f"error: not a directory: {args.input_dir}\n")
        return 2

    pages = collect_pages(args.input_dir)
    if not pages:
        sys.stderr.write(f"warning: no *.md files under {args.input_dir}\n")

    nodes, links = build_graph(pages)

    inline_d3: str | None = None
    if args.inline:
        d3_path = Path(__file__).parent / "d3.v7.min.js"
        if not d3_path.is_file():
            sys.stderr.write(
                f"error: --inline requires {d3_path} to exist. Download from "
                f"{D3_CDN} into that location. Falling back to CDN is disabled "
                f"when --inline is specified.\n"
            )
            return 1
        inline_d3 = d3_path.read_text(encoding="utf-8")

    html = render_html(nodes, links, inline_d3=inline_d3)

    if args.out is None:
        sys.stdout.write(html)
    else:
        args.out.write_text(html, encoding="utf-8")

    return 0


if __name__ == "__main__":
    sys.exit(main())
