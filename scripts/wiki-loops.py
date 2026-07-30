#!/usr/bin/env python3
"""scripts/wiki-loops.py — find feedback loops in the wiki's causal graph.

Reads KG JSONL (scripts/wiki-to-kg.py output) on stdin and reports every
simple cycle in the causal subgraph, classified by polarity the way a causal
loop diagram is: a cycle whose edges are all reinforcing-signed is a
REINFORCING loop; a cycle with an ODD number of inhibiting edges is a
BALANCING loop (Meadows: the odd negative link flips the whole loop's sign).

Verb → edge normalization (causal vocabulary only; everything else ignored):
    causes, enables, contributes-to   positive edge  source → target
    prevents                          negative edge  source → target
    caused-by                         positive edge  target → source

Receipts guarantee carried through: wiki-to-kg.py marks causal edges with
"sourced" (the source page carries at least one raw citation). A loop
containing any unsourced edge is labelled so — a feedback loop is a composed
claim, and composition must not launder an uncited link into fact.

Deterministic, stdlib-only, read-only. Usage:
    python3 scripts/wiki-to-kg.py wiki/ | python3 scripts/wiki-loops.py
"""

from __future__ import annotations

import json
import sys

POSITIVE = {"causes", "enables", "contributes-to"}
NEGATIVE = {"prevents"}
REVERSED = {"caused-by"}  # b caused-by a  ≡  a causes b (positive)

MAX_LOOP_LEN = 8
MAX_LOOPS = 50


def read_edges(stream):
    """Yield (u, v, sign, verb, sourced) for every causal edge on stdin."""
    for line in stream:
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except ValueError:
            continue
        verb = e.get("verb", "")
        u, v = e.get("source"), e.get("target")
        if not u or not v or u == v:
            continue
        sourced = bool(e.get("sourced", False))
        if verb in POSITIVE:
            yield u, v, +1, verb, sourced
        elif verb in NEGATIVE:
            yield u, v, -1, verb, sourced
        elif verb in REVERSED:
            yield v, u, +1, verb, sourced


def simple_cycles(adj, nodes):
    """Enumerate simple cycles as node tuples, each exactly once.

    Standard ordering trick: DFS only through nodes ranked >= the start node,
    closing back to the start — every cycle is found once, rooted at its
    minimum-rank node. Bounded by MAX_LOOP_LEN / MAX_LOOPS.
    """
    rank = {n: i for i, n in enumerate(nodes)}
    cycles = []

    def dfs(start, node, path, on_path):
        if len(cycles) >= MAX_LOOPS or len(path) > MAX_LOOP_LEN:
            return
        for nxt in sorted(adj.get(node, ())):
            if nxt == start and len(path) >= 2:
                cycles.append(tuple(path))
            elif nxt not in on_path and rank[nxt] > rank[start]:
                on_path.add(nxt)
                dfs(start, nxt, path + [nxt], on_path)
                on_path.discard(nxt)

    for start in nodes:
        dfs(start, start, [start], {start})
    return cycles


def main() -> int:
    # edge_info[(u, v)] = list of (sign, verb, sourced) — parallel edges kept.
    edge_info: dict[tuple[str, str], list[tuple[int, str, bool]]] = {}
    for u, v, sign, verb, sourced in read_edges(sys.stdin):
        rec = (sign, verb, sourced)
        if rec not in edge_info.setdefault((u, v), []):
            edge_info[(u, v)].append(rec)

    adj: dict[str, set[str]] = {}
    node_set: set[str] = set()
    for (u, v) in edge_info:
        adj.setdefault(u, set()).add(v)
        node_set.update((u, v))
    nodes = sorted(node_set)

    print("== Feedback loops (causal subgraph) ==")
    if not edge_info:
        print("No causal edges in the graph — nothing to loop.")
        return 0

    cycles = simple_cycles(adj, nodes)
    if not cycles:
        print("No feedback loops: the causal graph is acyclic.")
        return 0

    for cyc in sorted(cycles, key=lambda c: (len(c), c)):
        pairs = [(cyc[i], cyc[(i + 1) % len(cyc)]) for i in range(len(cyc))]
        # Polarity over every combination of parallel edges per pair.
        parities = {+1}
        verbs, all_cited = [], True
        for (u, v) in pairs:
            recs = edge_info[(u, v)]
            signs = {s for s, _, _ in recs}
            parities = {p * s for p in parities for s in signs}
            verbs.append("/".join(sorted({vb for _, vb, _ in recs})))
            if not any(srcd for _, _, srcd in recs):
                all_cited = False
        if parities == {+1}:
            kind = "reinforcing"
        elif parities == {-1}:
            kind = "balancing"
        else:
            kind = "mixed (parallel edges disagree)"
        path = " -> ".join(cyc + (cyc[0],))
        cited = "all edges cited" if all_cited else "contains uncited edge"
        print(f"{kind}: {path}   [{', '.join(verbs)}]  ({cited})")

    if len(cycles) >= MAX_LOOPS:
        print(f"(truncated at {MAX_LOOPS} loops)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
