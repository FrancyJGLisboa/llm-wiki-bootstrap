---
description: Export flashcards from the wiki's ## Flashcards sections to an Anki-importable CSV. Wraps scripts/wiki-to-anki.sh. Read-only on raw/ and wiki/.
allowed-tools: Bash, Read, Glob
argument-hint: [target-dir] [--out <path>]
---

You are executing `/wiki-flashcards $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to export spaced-repetition cards declared in `## Flashcards` sections to an Anki-importable CSV. This is an **output command**, not a lifecycle step: it generates **a new output file only** and never edits anything under `raw/` or `wiki/`.

## Read first

No wiki read is required — `scripts/wiki-to-anki.sh` does its own parsing. **Do not reimplement the `## Flashcards` parser here**; the script is the single source of truth (same rule as `scripts/body-hash.sh`). The convention it parses is documented in `AGENTS.md` → "Optional `## Flashcards` section".

## Behavior

1. Parse `$ARGUMENTS`:
   - First non-flag token (if any) = the directory to scan. Default: `wiki`.
   - `--out <path>` = the CSV destination. Default: `anki.csv`.
2. Run `scripts/wiki-to-anki.sh <dir>`, redirecting stdout to the chosen output path:
   `scripts/wiki-to-anki.sh <dir> > <out>`.
3. Report: the output path and how many cards were exported (count the data rows — total lines minus the `Front,Back,Tags` header). Note that each card's Anki tag is its source page slug, which lets the user build per-topic subdecks.
4. If no `## Flashcards` sections exist, the script exits 0 with only the header row — tell the user no cards were found. This is **not** an error.

## What you must NOT do

- Edit anything under `raw/` or `wiki/`. This command is read-only; it only writes the CSV.
- Reimplement the flashcard parser. Always shell out to `scripts/wiki-to-anki.sh`.
- Treat "no flashcards found" as a failure.
