---
description: Surface non-obvious structure across the wiki — multi-hop causal chains, hub concepts, the widest connection, plus open questions and tensions. Read-only; key-free graph analysis.
allowed-tools: Bash, Read
argument-hint: (no args)
---

You are executing `/ctx-discover` from the `llm-wiki-bootstrap` system. Your job is to show the user **what's worth asking about** in their wiki — the connections and causal chains they haven't looked at — without them having to ask a specific question. This is an **output command**: read-only on `raw/` and `wiki/`.

## Read first

**Run from the wiki root** (the directory with `raw/`, `wiki/`, `AGENTS.md`, `log.md`). If `wiki/` is absent, tell the user to run `/ctx-init` first, then stop.

## Steps

1. **Materialize + analyze the graph** (deterministic, no LLM cost):

   ```bash
   python3 scripts/wiki-to-kg.py wiki/ | python3 scripts/wiki-discover.py
   python3 scripts/wiki-to-kg.py wiki/ | python3 scripts/wiki-loops.py
   ```

   This prints a report with four lenses: **Causal chains** (multi-step cause→effect stories), **Most-connected concepts** (the load-bearing ideas), **Widest connection** (the two most distantly-linked ideas and the path between them), and **Feedback loops** (cycles in the causal graph, classified reinforcing vs balancing by edge polarity — an odd number of `prevents` links flips a loop to balancing). A loop is a composed claim: treat one marked "contains uncited edge" as a hypothesis to verify, never as fact.

2. **Add the standing dashboards** the synthesis layer already maintains, if present — these are the other half of "what to look at":
   - `wiki/tensions.md` — flagged contradictions across sources
   - `wiki/open-questions-dashboard.md` — open questions per page
   - `bash scripts/wiki-flows.sh` — the wiki as stocks (pages, sources, open questions, tensions) and flows (log.md operations per month); a month with zero entries means the maintenance loop stalled

   Read them (if they exist) and pull the top few items.

3. **Present + interpret.** Show the report, then add **one line of interpretation per lens** — what's *surprising* or worth a follow-up. Examples: "the longest causal chain runs X→Y→Z — worth a `/ctx-query` on its root cause"; "A and B aren't directly linked but bridge through C — a connection you may not have noticed." Point the user at concrete next moves: `/ctx-query "what caused <node>?"`, or resolving a flagged tension. Do not invent links the graph doesn't contain — every chain/bridge you cite must be in the report.

## What you must NOT do

- Edit any file in `wiki/` or `raw/` (this command is read-only).
- Fabricate connections or causal chains not present in the materialized graph.
- Run with the wiki absent — tell the user to `/ctx-init` first.

## Output

The discovery report (chains / hubs / widest connection), the top tensions and open questions if those dashboards exist, and a short interpretation pointing at concrete `/ctx-query` follow-ups. End with: "Next: `/ctx-query \"what caused <node>?\"` to walk any chain, or `/ctx-lint` to act on a tension."
