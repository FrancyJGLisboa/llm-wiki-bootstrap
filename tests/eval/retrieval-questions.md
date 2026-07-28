# Retrieval questions — cross-modality, point-in-time

`scripts/eval-retrieval.sh` reads this file. Each question is run through
`/wiki-query "<Q>" --no-promote` against a wiki built by the real installer and
populated through the real `/wiki-extract` → `/wiki-ingest` path — so a failure
here is a failure a user would hit, not a fixture artifact.

Every needle (`NEEDLE-<MODALITY>-<hex>`) is planted past the boundary its
extractor truncates or flattens at, and appears in no pretraining corpus. An
agent can only produce one by actually reaching it.

## Per-question format

```
### <check>-<id>
Question text on one or more lines.
modality: csv | email | report | vintage | absent | conflict
expects: token1, token2          # all must appear in the answer  (scores R1/R2/R3)
cite-contains: token             # the cited passage must contain this (scores R4)
max-span: N                      # ...within N lines               (scores R4)
forbids-pattern: <ERE>           # answer must NOT match this (fabrication guard)
refusal: true                    # answer must decline (scores R3)
```

`forbids-pattern` is an ERE, not a bare token, on purpose. A *good* answer to
"what was it as of April?" may well add "later revised to 389" — forbidding the
token `389` would score the best answer as a failure. What must be forbidden is
the shape of a fabrication (a throughput figure attached to a quarter the corpus
has no report for), not the mention of a real neighbouring fact.

`cite-contains` / `max-span` are omitted on questions where no citation is
expected (the refusal check). A question with `refusal: true` scores R3; all
others score R1 (needle), R2 (vintage), or M1 (conflict) on `expects`, and R4
on the citation.

`M1-conflict` is graded on synthesis: the corpus holds two coequal scoped
answers (production vs sandbox retention), and `expects:` lists both figures
AND both scope words — a pick-one answer fails on the missing tokens. Its
`forbids-pattern` guards the other false pass: reciting both figures while
waving one off as stale/outdated, when the two docs are disjoint scopes, not
vintages of each other.

## Questions

### R1-csv
In the 2026 sales dataset, one order is flagged as a disputed shipment held for
audit. What is the note token on that row, and which order ID is it?
modality: csv
expects: NEEDLE-CSV-7f3a91, ORD-00947
cite-contains: NEEDLE-CSV-7f3a91
max-span: 5

### R1-email
In the Q3 platform cutover planning thread, who closed out the cutover date
question, what date did they set, and what ticket did they file it under?
modality: email
expects: NEEDLE-EML-4c2d80, Dan, 2026-08-19
cite-contains: NEEDLE-EML-4c2d80
max-span: 20

### R1-report
In the Platform Review 2026, the instrumentation gap is tracked under a
specific identifier and blocks reproducing one class of figures. What is the
identifier, and what does it block?
modality: report
expects: NEEDLE-DOC-9b17e5, latency
cite-contains: NEEDLE-DOC-9b17e5
max-span: 40

### R2-asof
What was sustained throughput as of 2026-04-15? Answer with the figure that was
of record on that date, not the current one.
modality: vintage
expects: 412
cite-contains: 412
max-span: 40
forbids-pattern: ^[^a-zA-Z0-9]{0,4}(389|999)

### R2-current
Per the most recently published capacity report, what is sustained throughput?
modality: vintage
expects: 389
cite-contains: 389
max-span: 40
forbids-pattern: ^[^a-zA-Z0-9]{0,4}412

### T2-silent-asof
What was the ingest retry budget, in attempts per message, as of 2026-03-01?
modality: vintage
expects: 3 attempts
cite-contains: 3 attempts
max-span: 40
forbids-pattern: ^[^a-zA-Z0-9]{0,4}(7|seven)\b

### T2-silent-current
According to the most recently published retry budget memo, what is the ingest
retry budget in attempts per message?
modality: vintage
expects: 7 attempts
cite-contains: 7 attempts
max-span: 40
forbids-pattern: ^[^a-zA-Z0-9]{0,4}(3|three)\b

### M1-conflict
How long are application logs retained before being purged?
modality: conflict
expects: 180 days, 30 days, production, sandbox
cite-contains: 30 days
max-span: 40
forbids-pattern: [Oo]utdated|[Oo]bsolete|[Ss]tale

### R3-absent
What was sustained throughput in Q2 2026?
modality: absent
refusal: true
forbids-pattern: Q2[^.]{0,80}[0-9]{3} ?GB
