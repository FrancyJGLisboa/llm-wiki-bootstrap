---
description: Answer a question from the wiki. Web-search and auto-promote new knowledge if the wiki has gaps.
allowed-tools: Bash, Read, Write, Edit, WebSearch, WebFetch, Glob, Grep
argument-hint: <question> [--no-promote]
---

You are executing `/wiki-ask $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to answer the user's question from the wiki and, when the wiki falls short, to fetch new knowledge and **file it back into the wiki**.

## Read first

Read `AGENTS.md` (conventions). Read `wiki/index.md` to locate relevant pages.

## Parse the question

- Strip a trailing `--no-promote` flag if present; remember it for step 5.
- Treat the rest as the question.
- If no question, ask the user what to ask.

## Steps

### Step 1 — Locate relevant pages

From `wiki/index.md` and via `Grep` over `wiki/`, identify the 3-10 pages most likely to contain relevant material. Read them (frontmatter + body).

### Step 2 — Try to answer from the wiki alone

Synthesize an answer using only what you've read. If the answer is complete and confident, present it to the user with citations: each non-trivial claim should reference the wiki page that supports it as `[[page-name]]`.

If the wiki suffices: skip to step 6 (no promote needed; nothing was newly learned).

### Step 3 — If the wiki is insufficient, search

Identify what's missing. Run `WebSearch` (and `WebFetch` for promising results) to fill the gap. Stay narrow — answer the user's question; don't drift.

### Step 4 — Synthesize the full answer

Combine wiki content + web-search results into a coherent answer. Make sure to cite:
- Wiki sources as `[[page-name]]`
- Web sources as `[<title>](<url>)`

### Step 5 — Promote (default behavior, unless `--no-promote`)

If web search produced **notable** new knowledge, file it back into the wiki. Notability = at least one of:
- Introduces a new term (worth a glossary entry + likely a concept page)
- Makes a new connection between existing pages
- Cites a new external source worth keeping

For each notable piece:
- If a relevant page exists: append the new claim with a `(source: <url>)` citation. Update `updated:` in frontmatter.
- If no page exists and the concept is non-trivial: create a new `wiki/<slug>.md` with `type: concept` or `type: entity`, `source: external`, and cite the URL.
- Update `wiki/index.md` to list the new page(s).
- Append a `CHANGELOG.md` entry:

  ```markdown
  ## YYYY-MM-DD HH:MM — /wiki-ask "<short question>"

  - Web-searched: <urls>
  - Promoted: wiki/<file> (new) | wiki/<file> (updated)
  ```

If `--no-promote` was passed: skip this entire step. Mention to the user that promotion was disabled.

### Step 6 — Present the answer

Give the user:
1. The answer itself (well-formed, scannable).
2. A "Sources" footer listing wiki pages read and any external URLs used.
3. If promoted: a one-line summary of what was filed into the wiki.

## What you must NOT do

- Make up facts when the wiki and the web don't support them. Say "I don't know" instead.
- Promote sensitive content (personal/medical/financial details the user mentioned in passing) without explicit consent.
- Drift from the question. The web search is a tool, not a research expedition.
- Modify `raw/`.
- Use Obsidian-specific markdown in promoted pages.

## Output format

```
<the answer>

---

Sources:
- Wiki: [[page-a]], [[page-b]]
- Web: <urls if used>

Promoted to wiki: wiki/<file> (new) | (nothing — `--no-promote` was set | wiki was sufficient)
```
