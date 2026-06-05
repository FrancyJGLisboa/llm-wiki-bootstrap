# Sealed causal-traversal eval questions

`scripts/eval-causal.sh` runs each question against a **typed** variant (causal
verbs intact + `wiki/_kg.jsonl`) and a **baseline** (verbs stripped, no KG).
Graded by **word-boundary numeric match** on the integer `Code`.

The fixture nodes are pseudonyms with neutral bodies; each carries a unique
integer `Code` (visible in BOTH variants). Every chain target has **one causal
(`causes`) incoming edge plus one or more non-causal (`related-to`) decoy
edges**. Stripping the verb (baseline) makes all incoming links look identical,
so the baseline cannot tell which neighbour is the *causal* predecessor and must
guess among the decoys. Typed reads `wiki/_kg.jsonl` (`--causal-only`), which
keeps only the `causes` edge, and answers correctly.

Per question: `### Q<n>`, text, `expects:` (the integer Code), `baseline-absent:`, `hops:`.

### Q1
Several nodes link to Qorra, but exactly one of those links is causal — that node directly causes Qorra. Reply with that node's integer Code only.
expects: 4271
baseline-absent: true
hops: 1

### Q2
Several nodes link to Zundle, but exactly one directly causes it (the causal edge). Reply with that node's integer Code only.
expects: 5836
baseline-absent: true
hops: 1

### Q3
Several nodes link to Morth; exactly one of them directly causes Morth. Reply with that causal predecessor's integer Code only.
expects: 6914
baseline-absent: true
hops: 1

### Q4
Several nodes link to Plenk; exactly one directly causes it. Reply with that causal predecessor's integer Code only.
expects: 3508
baseline-absent: true
hops: 1

### Q5
Several nodes link to Drask; exactly one directly causes it. Reply with that causal predecessor's integer Code only.
expects: 7162
baseline-absent: true
hops: 1
