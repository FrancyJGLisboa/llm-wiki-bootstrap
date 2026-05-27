# Multi-hop questions for typed-relations eval

The `scripts/eval-multi-hop.sh` script reads this file, runs each question against
the **baseline** (verbs stripped from single-target `## Related` lines) and the
**typed** wiki, and grades by literal case-insensitive substring match.

## Per-question format

```
### Q<n>
Question text on one or more lines.
expects: token1, token2, ...
baseline-absent: true|false
```

- `expects`: comma-separated tokens; every token must appear in the answer for the
  question to pass on a given variant.
- `baseline-absent`: `true` means the expected tokens do NOT appear in the
  baseline-stripped fixture prose, so a passing baseline run means the LLM used
  external knowledge / hallucinated. At least 2 questions must be tagged `true`
  (this is C8's second half).

## Questions

### Q1
According to the wiki's typed relations, what single-word verb does the wiki use to describe what EMBRAPA does for brazilian-agribusiness?
expects: enables
baseline-absent: true

### Q2
What is the typed relationship the wiki gives between PRONAF and family-farming-brazil? Name the verb exactly as it appears (kebab-case).
expects: credit-for
baseline-absent: true

### Q3
The wiki tags one pair of pages as complement-of each other. Which two pages are they? Name both page slugs.
expects: family-farming-brazil, brazilian-agribusiness, complement-of
baseline-absent: true

### Q4
In what year was PRONAF created?
expects: 1994
baseline-absent: false

### Q5
According to the wiki, what role did EMBRAPA play in Brazilian agricultural history? Name the body of knowledge it worked on and one specific biome it helped open.
expects: research, Cerrado
baseline-absent: false
