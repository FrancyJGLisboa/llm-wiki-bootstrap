#!/usr/bin/env python3
"""scripts/wiki-graph-walk.py — deterministic causal traversal over the KG.

Consumes the JSONL knowledge graph that scripts/wiki-to-kg.py emits (one
`{"source","verb","target"}` triple per line) and walks it from a start node in
a chosen causal direction, returning the nodes reached at each hop. This is the
authoritative traversal `/wiki-query` shells out to: a capable LLM can *guess* a
plausible ordering of a small causal graph, but only a deterministic walk is
*correct and traceable every time* — and only a walk with a visited-set is safe
on a cyclic graph (a ring would otherwise loop forever).

Direction (mirrors AGENTS.md / wiki-query.md "Causal relations", source→target):
  down (downstream effects): forward along causes/enables/contributes-to/prevents
                             (source→target); caused-by is reversed (target→source).
  up   (root causes):        backward along the same edges.

Bounded + cycle-safe: each node is visited once (BFS, shortest hop wins), and
--max-hops caps the depth. Deterministic: neighbours are visited in sorted order
and output is sorted by (hop, node).

Stdlib only. Read-only.

Usage:
  scripts/wiki-to-kg.py --causal-only wiki/ | scripts/wiki-graph-walk.py --start <slug>
  scripts/wiki-graph-walk.py --start <slug> [--direction down|up] [--max-hops N] [--kg <path>]

Output (JSONL, one reached node per line, start excluded):
  {"hop": <int>, "node": <slug>, "via": <verb>}
"""
import argparse
import json
import sys
from collections import deque

# Causal verbs read source→target as cause→effect; caused-by is the inverse.
FORWARD_VERBS = {"causes", "enables", "contributes-to", "prevents"}
REVERSE_VERBS = {"caused-by"}


def load_triples(fh):
    triples = []
    for line in fh:
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        triples.append((d["source"], d["verb"], d["target"]))
    return triples


def build_adjacency(triples):
    """Return (forward, backward): adj[node] = sorted list of (neighbour, verb).

    forward = downstream (cause→effect); backward = upstream (effect→cause).
    An unrecognised verb is treated as a plain forward source→target edge.
    """
    forward, backward = {}, {}

    def add(adj, a, b, verb):
        adj.setdefault(a, []).append((b, verb))

    for s, v, t in triples:
        if v in REVERSE_VERBS:
            add(forward, t, s, v)   # "t caused-by s" ⇒ s causes t ⇒ downstream of s is t
            add(backward, s, t, v)
        else:                       # FORWARD_VERBS or unknown
            add(forward, s, t, v)
            add(backward, t, s, v)
    for adj in (forward, backward):
        for node in adj:
            adj[node] = sorted(set(adj[node]))
    return forward, backward


def walk(adj, start, max_hops):
    """BFS from start; visited-set makes it cycle-safe. Returns [(hop, node, via)]."""
    visited = {start}
    queue = deque([(start, 0)])
    reached = []
    while queue:
        node, hop = queue.popleft()
        if max_hops is not None and hop >= max_hops:
            continue
        for nxt, verb in adj.get(node, []):
            if nxt in visited:
                continue
            visited.add(nxt)
            reached.append((hop + 1, nxt, verb))
            queue.append((nxt, hop + 1))
    reached.sort(key=lambda r: (r[0], r[1]))
    return reached


def main():
    ap = argparse.ArgumentParser(description="Deterministic causal traversal over the KG.")
    ap.add_argument("--start", required=True, help="start node slug")
    ap.add_argument("--direction", choices=("down", "up"), default="down",
                    help="down = downstream effects (default); up = root causes")
    ap.add_argument("--max-hops", type=int, default=None,
                    help="cap traversal depth (default: full reachable closure)")
    ap.add_argument("--kg", default=None, help="KG JSONL path (default: stdin)")
    args = ap.parse_args()

    if args.max_hops is not None and args.max_hops < 1:
        print("error: --max-hops must be >= 1", file=sys.stderr)
        return 2

    if args.kg:
        with open(args.kg, encoding="utf-8") as fh:
            triples = load_triples(fh)
    else:
        triples = load_triples(sys.stdin)

    forward, backward = build_adjacency(triples)
    adj = forward if args.direction == "down" else backward

    for hop, node, via in walk(adj, args.start, args.max_hops):
        print(json.dumps({"hop": hop, "node": node, "via": via}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
