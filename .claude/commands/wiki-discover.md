---
description: Surface non-obvious structure across the wiki — multi-hop causal chains, hub concepts, the widest connection, plus open questions and tensions. Read-only; key-free graph analysis.
allowed-tools: Bash, Read
argument-hint: (no args)
---

You are executing `/wiki-discover` from the `llm-wiki-bootstrap` system. Your job is to show the user **what's worth asking about** in their wiki — the connections and causal chains they haven't looked at — without them having to ask a specific question. This is an **output command**: read-only on `raw/` and `wiki/`.

## Read first

**Run from the wiki root** (the directory with `raw/`, `wiki/`, `AGENTS.md`, `log.md`). If `wiki/` is absent, tell the user to run `/wiki-init` first, then stop.

## Steps

1. **Materialize + analyze the graph** (deterministic, no LLM cost):

   ```bash
   python3 scripts/wiki-to-kg.py wiki/ | python3 scripts/wiki-discover.py
   ```

   This prints a report with three lenses: **Causal chains** (multi-step cause→effect stories), **Most-connected concepts** (the load-bearing ideas), and **Widest connection** (the two most distantly-linked ideas and the path between them).

2. **Add the standing dashboards** the synthesis layer already maintains, if present — these are the other half of "what to look at":
   - `wiki/tensions.md` — flagged contradictions across sources
   - `wiki/open-questions-dashboard.md` — open questions per page

   Read them (if they exist) and pull the top few items.

3. **Present + interpret.** Show the report, then add **one line of interpretation per lens** — what's *surprising* or worth a follow-up. Examples: "the longest causal chain runs X→Y→Z — worth a `/wiki-query` on its root cause"; "A and B aren't directly linked but bridge through C — a connection you may not have noticed." Point the user at concrete next moves: `/wiki-query "what caused <node>?"`, or resolving a flagged tension. Do not invent links the graph doesn't contain — every chain/bridge you cite must be in the report.

## What you must NOT do

- Edit any file in `wiki/` or `raw/` (this command is read-only).
- Fabricate connections or causal chains not present in the materialized graph.
- Run with the wiki absent — tell the user to `/wiki-init` first.

## Output

The discovery report (chains / hubs / widest connection), the top tensions and open questions if those dashboards exist, and a short interpretation pointing at concrete `/wiki-query` follow-ups. End with: "Next: `/wiki-query \"what caused <node>?\"` to walk any chain, or `/wiki-lint` to act on a tension."
