# Fixture: VIOLATING — an unknown field leaks into the prompt

<!-- gate-parser: retr_parse_questions -->

Committed fixture for `scripts/gate-eval-prompt-purity.sh`. Running the gate
against this file must exit 1 and name `answer-is:` and `source-hint:`.

This is the real bug, reproduced: neither field is in `retr_parse_questions`'
field list, so the catch-all appends both to the question text. The model is
then asked the question *plus* the answer and the file it lives in — and the
run scores near 100% while measuring nothing.

## Questions

### Q1
What retention window does the wiki give for production logs?
modality: text
expects: 90 days
answer-is: 90 days

### Q2
Which team owns the ingest pipeline?
modality: text
expects: platform
source-hint: ^2021-03-ingest
