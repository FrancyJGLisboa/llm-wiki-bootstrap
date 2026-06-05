---
title: Page X (non-canonical causal verbs)
type: concept
source: analysis
updated: 2026-06-05
tags: [canary, causal, malformed]
---

# Page X

Canary fixture for the REJECT side of the causal lint. Each single-target
`## Related` line below uses a NON-CANONICAL causal synonym; the lint MUST
flag each one with its canonical form, and `wiki-to-kg.py --causal-only`
MUST emit zero causal triples for this directory.

## Related

- [[drought]] results-in — synonym of `causes`
- [[yield-drop]] due-to — synonym of `caused-by`
- [[price-spike]] enabled-by — synonym of `caused-by`

## Open questions

- none
