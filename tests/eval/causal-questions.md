# Causal multi-hop eval questions

The `scripts/eval-causal.sh` script reads this file, runs each question against
a typed-causal variant (verbs intact + `wiki/_kg.jsonl`) and a causal-stripped
baseline, and grades by case-insensitive substring on every `expects:` token.
Each question is answerable only by tracing the causal chain — so the typed
variant should beat the baseline.

Format per question: `### Q<n>`, the question text, then `expects:`,
`baseline-absent:`, and `hops:`.

### Q1
What ultimately caused the export ban?
expects: el nino, drought, yield, price
baseline-absent: true
hops: 4

### Q2
What are the downstream effects of the drought?
expects: yield, price, export ban
baseline-absent: true
hops: 3

### Q3
Trace the causal chain from El Nino to the export ban.
expects: drought, yield, price, export ban
baseline-absent: true
hops: 4

### Q4
What did the yield drop cause, directly and indirectly?
expects: price spike, export ban
baseline-absent: true
hops: 2

### Q5
Why was the export ban imposed, tracing back to the climate driver?
expects: price spike, yield drop, drought, el nino
baseline-absent: true
hops: 4
