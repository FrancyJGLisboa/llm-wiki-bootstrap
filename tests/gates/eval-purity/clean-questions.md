# Fixture: CLEAN — every field is known to the parser

<!-- gate-parser: retr_parse_questions -->

Committed fixture for `scripts/gate-eval-prompt-purity.sh`. Running the gate
against this file must exit 0. Every `field:` line below is in
`retr_parse_questions`' field list, so none reaches the model.

The fenced block below is a FORMAT template that looks exactly like a question.
Both the parser and the gate skip fenced regions; if either stops doing so,
this fixture starts failing, which is the point.

```
### Q<n>
<the question>
expects: <substring>
totally-unknown-field: this line is inside a fence and must be ignored
```

## Questions

### Q1
What retention window does the wiki give for production logs?
modality: text
expects: 90 days
cite-contains: retention
refusal: false

### Q2
Which team owns the ingest pipeline?
modality: text
expects: platform
max-span: 2
forbids-pattern: (unknown|unclear)
requires: wiki/ingest-pipeline.md
change: platform team took ownership in March
cite-file-matches: ^2021-03-
