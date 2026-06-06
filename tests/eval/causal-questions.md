# Sealed causal-traversal eval questions

`scripts/eval-causal.sh` runs each question against a **typed** variant (causal
verbs intact + `wiki/_kg.jsonl`) and a **baseline** (verbs stripped, no KG).
Graded by **word-boundary numeric match** on the integer answer.

The fixture is a fully symmetric 6-node ring: every node has one causal
(`causes`) edge plus three non-causal (`related-to`) decoy edges — uniform
degree, identical prose, pseudonym titles, and a unique integer `Code` in each
body (visible to BOTH variants).

**The answer to every question is a SUM of Codes along the causal chain** — a
value that does NOT appear anywhere in the fixture. This defeats the two ways a
blind baseline could otherwise score: it cannot *guess* the sum, and it cannot
*hedge* by listing visible Codes (the sum is not one of them). To produce the
sum you must identify which of each node's four links is causal and follow it —
only the typed variant can, via `wiki/_kg.jsonl --causal-only`.

Per question: `### Q<n>`, text, `expects:` (the integer sum), `baseline-absent:`, `hops:`.

### Q1
Following ONLY causal edges (ignore the non-causal decoy links), start at Vexil and take two steps downstream in the direction of causation. Add the Codes of those two nodes you land on. Reply with the integer sum only.
expects: 12750
baseline-absent: true
hops: 2

### Q2
Following ONLY causal edges, start at Qorra and take two steps downstream in the direction of causation. Add the Codes of those two nodes. Reply with the integer sum only.
expects: 10422
baseline-absent: true
hops: 2

### Q3
Following ONLY causal edges, start at Zundle and take two steps downstream in the direction of causation. Add the Codes of those two nodes. Reply with the integer sum only.
expects: 10670
baseline-absent: true
hops: 2

### Q4
Following ONLY causal edges, start at Morth and take two steps downstream in the direction of causation. Add the Codes of those two nodes. Reply with the integer sum only.
expects: 9211
baseline-absent: true
hops: 2

### Q5
Following ONLY causal edges, start at Plenk and take two steps downstream in the direction of causation. Add the Codes of those two nodes. Reply with the integer sum only.
expects: 6320
baseline-absent: true
hops: 2

### Q6
Following ONLY causal edges, start at Drask and take two steps downstream in the direction of causation. Add the Codes of those two nodes. Reply with the integer sum only.
expects: 10107
baseline-absent: true
hops: 2
