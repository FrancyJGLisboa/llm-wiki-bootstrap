#!/usr/bin/env python3
"""scripts/wiki-discover.py — surface non-obvious structure across a wiki.

Reads KG edges (JSONL {source,verb,target}, from wiki-to-kg.py) on stdin and
emits a deterministic markdown "discovery report" — the PROACTIVE half of the
discovery story: instead of you asking "what caused X", it shows what's worth
asking about. Three lenses, all key-free graph analysis:

  ## Causal chains        maximal cause→effect paths (the multi-step stories)
  ## Most-connected       hub concepts by undirected degree (the load-bearing ideas)
  ## Widest connection    the graph diameter — the two most distantly-linked
                          ideas and the chain between them (the surprising bridge)

Stdlib-only, deterministic (sorted tie-breaks). Usage:
  wiki-to-kg.py wiki/ | wiki-discover.py
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict, deque

_FWD = {"causes", "contributes-to", "enables"}
_REV = {"caused-by"}


def load(stream):
    edges = []
    for ln in stream:
        ln = ln.strip()
        if ln:
            o = json.loads(ln)
            # wiki-to-kg.py attaches "sourced" only to causal edges; absent on
            # non-causal edges. Default True so the absence never marks a chain.
            edges.append((o["source"], o["verb"], o["target"], o.get("sourced", True)))
    return edges


def causal_fwd(edges):
    fwd, indeg = defaultdict(set), defaultdict(int)
    nodes = set()
    hop_sourced = {}  # (cause, effect) -> all underlying edges carry a receipt
    for s, v, t, sourced in edges:
        if v in _FWD:
            c, e = s, t
        elif v in _REV:
            c, e = t, s
        else:
            continue
        fwd[c].add(e)
        nodes |= {c, e}
        # An uncited edge poisons the hop even if a parallel cited one exists.
        hop_sourced[(c, e)] = hop_sourced.get((c, e), True) and sourced
    for c in fwd:
        for e in fwd[c]:
            indeg[e] += 1
    return fwd, indeg, nodes, hop_sourced


def maximal_chains(fwd, indeg, nodes):
    roots = sorted(n for n in nodes if indeg[n] == 0 and fwd.get(n))
    chains = []

    def walk(n, path):
        nxt = sorted(fwd.get(n, ()))
        nxt = [m for m in nxt if m not in path]  # cycle-safe
        if not nxt:
            if len(path) >= 3:               # ≥2 hops = a real story
                chains.append(path)
            return
        for m in nxt:
            walk(m, path + [m])

    for r in roots:
        walk(r, [r])
    return chains


def undirected(edges):
    adj = defaultdict(set)
    for s, _v, t, _sourced in edges:
        adj[s].add(t)
        adj[t].add(s)
    return adj


def diameter_path(adj):
    """Return the longest shortest-path (one of them) in the undirected graph."""
    best = []
    for start in sorted(adj):
        prev = {start: None}
        q = deque([start])
        order = []
        while q:
            n = q.popleft()
            order.append(n)
            for m in sorted(adj[n]):
                if m not in prev:
                    prev[m] = n
                    q.append(m)
        far = order[-1]
        path = []
        n = far
        while n is not None:
            path.append(n)
            n = prev[n]
        path.reverse()
        if len(path) > len(best) or (len(path) == len(best) and path < best):
            best = path
    return best


def main():
    edges = load(sys.stdin)
    out = []
    out.append("# Discovery report\n")
    if not edges:
        out.append("_No typed relations found — add `## Related` edges to surface structure._")
        print("\n".join(out))
        return 0

    fwd, indeg, nodes, hop_sourced = causal_fwd(edges)
    chains = maximal_chains(fwd, indeg, nodes)
    out.append("## Causal chains")
    if chains:
        for c in sorted(chains, key=lambda p: (-len(p), p)):
            line = f"- {' → '.join(c)}"
            # "Ships with receipts": if any hop rests on an uncited causal edge,
            # the chain can't be surfaced as fact — mark it visibly rather than
            # suppress it (transparency > silent drop).
            hops = zip(c, c[1:])
            if any(not hop_sourced.get(h, True) for h in hops):
                line += "  ⚠ contains uncited edge [unsourced]"
            out.append(line)
    else:
        out.append("- _(none ≥2 hops — encode cause→effect with canonical causal verbs to grow these)_")
    out.append("")

    adj = undirected(edges)
    deg = sorted(adj, key=lambda n: (-len(adj[n]), n))
    out.append("## Most-connected concepts")
    for n in deg[:5]:
        out.append(f"- **{n}** — {len(adj[n])} link(s)")
    out.append("")

    dia = diameter_path(adj)
    out.append("## Widest connection")
    if len(dia) >= 2:
        out.append(f"- {' → '.join(dia)}  _({len(dia) - 1} hops apart)_")
    else:
        out.append("- _(graph too small for a bridge)_")

    print("\n".join(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
