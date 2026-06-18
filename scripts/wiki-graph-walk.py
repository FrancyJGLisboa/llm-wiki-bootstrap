#!/usr/bin/env python3
"""scripts/wiki-graph-walk.py — traverse the KG to answer causal/connection queries.

Reads KG edges (JSONL {source,verb,target}, e.g. from wiki-to-kg.py) on stdin
and answers multi-hop questions deterministically — the key-free floor under
"what caused X / what does X enable / how does A connect to B". No LLM.

Causal normalization (cause → effect):
  causes / contributes-to / enables : source → target
  caused-by                         : target → source   (X caused-by Y ⇒ Y→X)
  prevents                          : NEGATIVE — excluded from causal chains
                                      (kept for --path, which is sign-agnostic)

Modes:
  --causes-of  <node>   transitive upstream causes, ordered root → node
  --effects-of <node>   transitive downstream effects, ordered node → leaf
  --path <a> <b>        shortest connection path (edges treated undirected)

Stdlib-only, deterministic (sorted tie-breaks). Usage:
  wiki-to-kg.py --causal-only wiki/ | wiki-graph-walk.py --causes-of <node>
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import deque

_FWD = {"causes", "contributes-to", "enables"}   # source → target
_REV = {"caused-by"}                              # target → source
_SIGNLESS_SKIP = {"prevents"}                     # negative; not a causal chain edge


def load_edges(stream):
    edges = []
    for line in stream:
        line = line.strip()
        if not line:
            continue
        o = json.loads(line)
        edges.append((o["source"], o["verb"], o["target"]))
    return edges


def causal_graph(edges):
    """Return fwd/back adjacency over normalized cause→effect edges."""
    fwd, back = {}, {}
    for s, v, t in edges:
        if v in _FWD:
            cause, effect = s, t
        elif v in _REV:
            cause, effect = t, s
        else:
            continue  # prevents / related-to / non-causal: not a causal edge
        fwd.setdefault(cause, set()).add(effect)
        back.setdefault(effect, set()).add(cause)
    return fwd, back


def _reach(adj, start):
    """All nodes reachable from start (exclusive), with BFS distance."""
    dist, q = {}, deque([(start, 0)])
    seen = {start}
    while q:
        n, d = q.popleft()
        for m in sorted(adj.get(n, ())):
            if m not in seen:
                seen.add(m)
                dist[m] = d + 1
                q.append((m, d + 1))
    return dist


def _chain(nodes_by_dist, node, descending):
    """Order nodes by distance then alpha; join into a readable chain."""
    ordered = sorted(nodes_by_dist, key=lambda n: (nodes_by_dist[n], n), reverse=descending)
    return ordered


def undirected_path(edges, a, b):
    adj = {}
    for s, _v, t in edges:
        adj.setdefault(s, set()).add(t)
        adj.setdefault(t, set()).add(s)
    prev, q, seen = {a: None}, deque([a]), {a}
    while q:
        n = q.popleft()
        if n == b:
            path = []
            while n is not None:
                path.append(n)
                n = prev[n]
            return list(reversed(path))
        for m in sorted(adj.get(n, ())):
            if m not in seen:
                seen.add(m)
                prev[m] = n
                q.append(m)
    return []


def main(argv):
    ap = argparse.ArgumentParser(prog="wiki-graph-walk.py")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--causes-of", metavar="NODE")
    g.add_argument("--effects-of", metavar="NODE")
    g.add_argument("--path", nargs=2, metavar=("A", "B"))
    args = ap.parse_args(argv)

    edges = load_edges(sys.stdin)
    fwd, back = causal_graph(edges)

    if args.causes_of:
        node = args.causes_of
        anc = _reach(back, node)              # upstream causes
        chain = sorted(anc, key=lambda n: (anc[n], n), reverse=True)  # root → node
        if not chain:
            print(f"no recorded causes of {node}")
            return 0
        print(" → ".join(chain + [node]))
        return 0

    if args.effects_of:
        node = args.effects_of
        desc = _reach(fwd, node)              # downstream effects
        chain = sorted(desc, key=lambda n: (desc[n], n))  # node → leaf
        if not chain:
            print(f"no recorded effects of {node}")
            return 0
        print(" → ".join([node] + chain))
        return 0

    a, b = args.path
    path = undirected_path(edges, a, b)
    if not path:
        print(f"no path between {a} and {b}")
        return 0
    print(" → ".join(path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
