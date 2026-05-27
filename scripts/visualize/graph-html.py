#!/usr/bin/env python3
"""Bespoke wiki-graph HTML generator.

Walks an input directory recursively for *.md files, parses [[kebab-case]]
references, and emits a self-contained HTML file with a D3 force-directed
graph. Edges carry a per-edge `verb` derived from the AGENTS.md "Typed
relations" convention (annotated ``## Related`` lines). Verbs in body prose
or in `index.md` and `## Open questions` blocks default to ``related-to``.

Stdlib only — no external dependencies on the Python side. D3 v7 is loaded
from CDN by default; pass --inline (with d3.v7.min.js dropped next to this
script) to embed it for offline use.

The graph data is emitted as a dedicated <script id="graph-data"
type="application/json"> block so smoke tests can parse it without regex
heuristics over the whole HTML. A `<select id="verb-filter">` plus a
`filterByVerb(...)` JS handler let users narrow the rendered edges to a
single verb; each `<line>` carries a `data-verb` attribute so the filter
works without a re-layout.

Spec: .scratch/visualization-tools/GOAL.md §5 (original) +
.scratch/typed-wikilinks-semantic-viz/GOAL.md §5 (typed extension).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LINK_RE = re.compile(r"\[\[([a-z][a-z0-9-]*)\]\]")
TYPED_LINE_RE = re.compile(r"^\s*-\s+\[\[([a-z][a-z0-9-]*)\]\](.*)$")
VERB_RE = re.compile(r"^[a-z][a-z0-9-]*$")
RELATED_HEADING_RE = re.compile(r"^## Related\s*$")
SECTION_RE = re.compile(r"^## ")
D3_CDN = "https://d3js.org/d3.v7.min.js"
EM_DASH = "—"
IMPLICIT_VERB = "related-to"


def collect_pages(root: Path) -> list[Path]:
    """Recursive *.md walk — required to reach wiki/journal/* and any subdirs."""
    return sorted(root.rglob("*.md"))


def classify_related_line(line: str) -> list[tuple[str, str]] | None:
    """Parse one ``## Related`` list line.

    Returns a list of ``(target, verb)`` tuples — typically one element, but
    multi-link lines yield one per link (all with ``related-to``). Returns
    ``None`` if the line is not a recognised relation list item.
    """
    m = TYPED_LINE_RE.match(line)
    if not m:
        return None
    first_target = m.group(1)
    rest_after_first_link = m.group(2)
    all_targets = LINK_RE.findall(line)

    # Multi-link line: every link is implicit related-to, no verb attaches.
    if len(all_targets) > 1:
        return [(t, IMPLICIT_VERB) for t in all_targets]

    # Single-target line: extract the verb token (if any).
    rest = rest_after_first_link.lstrip()
    for sep in (EM_DASH, "--"):
        idx = rest.find(sep)
        if idx >= 0:
            rest = rest[:idx]
            break
    rest = rest.strip()
    if not rest:
        return [(first_target, IMPLICIT_VERB)]

    verb = rest.split()[0]
    if VERB_RE.fullmatch(verb):
        return [(first_target, verb)]
    # Malformed verb — graph degrades to implicit; lint flags it separately.
    return [(first_target, IMPLICIT_VERB)]


def build_graph(pages: list[Path]) -> tuple[list[dict], list[dict]]:
    """Return (nodes, links). Drop dangling links and self-loops; dedup edges.

    Typed relations from ``## Related`` win over implicit body-prose links: if
    the same (src, tgt) pair appears in both contexts, the typed verb is kept.
    """
    stems = [p.stem for p in pages]
    if len(set(stems)) != len(stems):
        seen: set[str] = set()
        dupes: list[str] = []
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

    typed_edges: dict[tuple[str, str], str] = {}
    implicit_edges: set[tuple[str, str]] = set()

    for page in pages:
        src = page.stem
        body = page.read_text(encoding="utf-8", errors="replace")
        in_related = False
        for raw_line in body.splitlines():
            if RELATED_HEADING_RE.match(raw_line):
                in_related = True
                continue
            if SECTION_RE.match(raw_line) and not RELATED_HEADING_RE.match(raw_line):
                in_related = False

            consumed_as_related = False
            if in_related:
                classified = classify_related_line(raw_line)
                if classified is not None:
                    consumed_as_related = True
                    for tgt, verb in classified:
                        if tgt == src or tgt not in node_set:
                            continue
                        # Typed edge wins; if verb is implicit, only fill an empty slot.
                        if verb != IMPLICIT_VERB:
                            typed_edges[(src, tgt)] = verb
                        elif (src, tgt) not in typed_edges:
                            typed_edges.setdefault((src, tgt), IMPLICIT_VERB)

            if consumed_as_related:
                continue

            # Outside ## Related, or inside it but not a recognised list line:
            # treat every link as implicit related-to (does not overwrite typed).
            for match in LINK_RE.finditer(raw_line):
                tgt = match.group(1)
                if tgt == src or tgt not in node_set:
                    continue
                if (src, tgt) not in typed_edges:
                    implicit_edges.add((src, tgt))

    edges: dict[tuple[str, str], str] = dict(typed_edges)
    for pair in implicit_edges:
        edges.setdefault(pair, IMPLICIT_VERB)

    links = sorted(
        ({"source": s, "target": t, "verb": v} for ((s, t), v) in edges.items()),
        key=lambda e: (e["source"], e["target"], e["verb"]),
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
  svg {{ width: 100vw; height: calc(100vh - 36px); display: block; }}
  #controls {{ padding: 8px 12px; background: #1a1a1a; border-bottom: 1px solid #333; font-size: 13px; }}
  #controls label {{ margin-right: 8px; }}
  #verb-filter {{ background: #222; color: #ddd; border: 1px solid #444; padding: 2px 6px; }}
  .node circle {{ fill: #69b3a2; stroke: #ddd; stroke-width: 1.5px; }}
  .node text {{ fill: #ddd; font-size: 11px; pointer-events: none; }}
  .link {{ stroke-opacity: 0.7; }}
</style>
</head>
<body>
<div id="controls">
  <label for="verb-filter">Filter by verb:</label>
  <select id="verb-filter"><option value="all">all</option></select>
  <span id="verb-legend" style="margin-left:16px;"></span>
</div>
{d3_block}
<script id="graph-data" type="application/json">{graph_json}</script>
<svg id="graph"></svg>
<script>
const data = JSON.parse(document.getElementById('graph-data').textContent);
const svg = d3.select('#graph');
const width = window.innerWidth, height = window.innerHeight - 36;

// Distinct verbs across all edges, sorted; populate the filter <select>.
const verbs = Array.from(new Set(data.links.map(l => l.verb))).sort();
const select = document.getElementById('verb-filter');
for (const v of verbs) {{
  const opt = document.createElement('option');
  opt.value = v;
  opt.textContent = v;
  select.appendChild(opt);
}}
const verbColor = d3.scaleOrdinal(d3.schemeCategory10).domain(verbs);

// Legend
const legend = document.getElementById('verb-legend');
for (const v of verbs) {{
  const sw = document.createElement('span');
  sw.style.marginRight = '10px';
  sw.innerHTML = `<span style="display:inline-block;width:10px;height:10px;background:${{verbColor(v)}};margin-right:4px;border-radius:2px;"></span>${{v}}`;
  legend.appendChild(sw);
}}

const simulation = d3.forceSimulation(data.nodes)
  .force('link', d3.forceLink(data.links).id(d => d.id).distance(80))
  .force('charge', d3.forceManyBody().strength(-200))
  .force('center', d3.forceCenter(width / 2, height / 2));

const link = svg.append('g').attr('class', 'links').selectAll('line')
  .data(data.links).enter().append('line')
  .attr('class', 'link')
  .attr('data-verb', d => d.verb)
  .attr('stroke', d => verbColor(d.verb));

const node = svg.append('g').attr('class', 'nodes').selectAll('g')
  .data(data.nodes).enter().append('g').attr('class', 'node')
  .call(d3.drag()
    .on('start', (e, d) => {{ if (!e.active) simulation.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; }})
    .on('drag',  (e, d) => {{ d.fx = e.x; d.fy = e.y; }})
    .on('end',   (e, d) => {{ if (!e.active) simulation.alphaTarget(0); d.fx = null; d.fy = null; }}));

node.append('circle').attr('r', 7);
node.append('text').attr('dx', 10).attr('dy', 4).text(d => d.id);

// Filter edges by verb; "all" shows everything.
function filterByVerb(verb) {{
  link.style('display', d => (verb === 'all' || d.verb === verb) ? null : 'none');
}}
select.addEventListener('change', e => filterByVerb(e.target.value));

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
