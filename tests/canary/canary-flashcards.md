---
title: Canary Flashcards
type: concept
source: analysis
updated: 2026-05-25
tags: [test, canary]
---

# Canary Flashcards

A fixture used by `scripts/verify-wiki-to-anki.sh` to confirm the exporter
recognises the `## Flashcards` convention and produces a well-shaped CSV.

## Definition / TL;DR

Minimal flashcard set exercising both single-line and wrapped-answer formats,
the raw-citation `Source` column, and the uncited-card exclusion path. Editing
this file's questions, answers, or citations will change the verifier's
expected output — keep it stable unless you also update `verify-wiki-to-anki.sh`.

## Flashcards

- Q: What is the canonical hashing script in this repo?
  A: scripts/body-hash.sh (source: raw/canary.md#hashing)
- Q: What does `/wiki-lint` check?
  A: Broken links, orphans, contradictions, stale claims,
     and unresolved open questions.
  (source: raw/canary.md#lint)
- Q: What happens if a wiki page contains a comma in the question, like "what, why"?
  A: The exporter wraps the field in double quotes so CSV parsers handle it correctly. (source: raw/canary.md#escaping)
- Q: Which card has no receipt and must be excluded from the CSV?
  A: This one — it has no raw citation, so the exporter drops it and warns on stderr.

## Related

- [[canary-smoke-test]] — the markdown-source extraction fixture
