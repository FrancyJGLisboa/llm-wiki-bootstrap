---
title: Implicit Constraints
type: analysis
source: analysis
updated: 2026-05-25
tags: [system, analysis, design-constraints]
---

# Implicit Constraints

> **This page is `source: analysis`.** The constraints below aren't named in the video — they're inferences about what any faithful implementation of the LLM-wiki pattern must honor. They're listed here so future maintainers (and forks of this project) don't accidentally violate them.

## Definition / TL;DR

The video shows *what* the LLM-wiki pattern is. This page lists *what an implementation must avoid* to stay faithful: rules that hold even though the video never states them outright.

## The constraints

### 1. The LLM is the sole writer of the wiki layer

[[layer-wiki]] is owned by the LLM. Users do not edit wiki pages directly. **If you let users edit `wiki/` by hand, you lose the consistency guarantee** (cross-references decay, conventions drift, the LLM and human disagree on truth). The pattern only works because there's a single writer.

Practical implication: a UI / CLI for this system should make wiki-page editing a function of slash commands, never a generic "open in editor."

### 2. Raw sources are immutable to the LLM

The LLM may **read** `raw/` but never **write** to it. If the LLM could rewrite raw sources, the audit trail breaks: claims in the wiki could no longer be traced back to a stable source. The user can edit `raw/` (e.g., to fix a transcription error); [[operation-ingest]] detects the change via hash.

### 3. The schema is the only place the user steers conventions

Out-of-band conventions ("just remember to always tag like this") don't survive across LLM sessions or model changes. Anything the user wants the LLM to do consistently must be written into [[layer-schema]] (`AGENTS.md`). This is what makes the schema layer load-bearing.

### 4. The link convention must be known to the LLM, not the viewer

`[[wiki-link]]` is a textual convention the LLM resolves by string match. **The system does not assume any particular renderer turns it into a clickable link.** This is what lets the wiki be viewer-agnostic — works in `cat`, VSCode preview, GitHub web, Obsidian, none. See [[four-principles]] #3 (file-over-app).

### 5. The LLM needs filesystem write + read

To do [[operation-ingest]], the LLM must be able to: read arbitrary files in `raw/` and `wiki/`, create new files in `wiki/`, update files in `wiki/`, and append to `log.md`. Any agentic tool that gates these is unsuitable as a host.

### 6. Web search is optional but enables [[query-as-write-loop]]

Without WebSearch, [[operation-query]] can only return what's in the wiki — no backfill from external knowledge. The pattern still works, but one engine of compounding is disabled.

### 7. Knowledge compounds: every write touches multiple files

[[ingest-pipeline]] step 4 ("update existing entity / concept pages") means a single source typically writes to many pages, not one. If your implementation only writes a single summary page per ingest, you've lost the compounding effect. The video is explicit: *"a single source might touch 10 to 15 wiki pages."* `(source: raw/karpathy-llm-wiki-video-transcript.md#3:50)`

### 8. Maintenance is a first-class operation, not an afterthought

[[operation-lint]] is named as one of the three core operations in the video. It's not "something you'd add later if you have time." The whole reason the pattern works (per [[division-of-labor]]) is that the LLM does maintenance — which means maintenance must be invocable cheaply, on demand, and produce concrete output.

### 9. The system has no viewer dependency

This is a constraint we (the project) add on top of the video. The video shows Obsidian as the viewer. **The pattern itself does not require Obsidian** — what it requires is that markdown be the storage format. Any choice that makes Obsidian (or any specific viewer) load-bearing trades portability for convenience. We refuse the trade.

Concretely: no callouts (`> [!note]`), no dataview blocks, no embedded queries, no Obsidian-specific link syntax (path-relative `[[folder/page]]`), nothing that fails to render in plain CommonMark.

### 10. The schema and the slash commands must be portable

The user's tool may change (Claude Code today, Cursor tomorrow, a hosted IDE next year). Conventions encoded in `AGENTS.md` should not assume a specific tool. Slash command implementations may be tool-specific (today: `.claude/commands/`), but the *spec* in [[commands]] should be tool-agnostic so porting is mechanical.

## Why these matter

A naive port of the pattern can technically tick all the boxes (raw folder, wiki folder, schema file, slash commands) while violating constraints 1, 7, or 8 — and the result will rot exactly like a human-maintained wiki. The constraints aren't optional polish; they're what makes the pattern *be* the pattern.

## Related

- [[core-idea]] — what these constraints serve
- [[four-principles]] — #3 (file-over-app) drives constraint 9 specifically
- [[layer-wiki]] — codifies constraint 1
- [[layer-raw-sources]] — codifies constraint 2
- [[layer-schema]] — codifies constraint 3
- [[commands]] — implementations that honor 5, 6, 7, 8, 10

## Open questions on this page

- Are there constraints we're missing? (Plausibly: privacy — raw sources may contain PII; the wiki effectively reframes that PII. No formal guidance from the video on this.)
- Is constraint 1 (LLM-only writes wiki) absolute, or are there edge cases where direct edits are fine? (Typos, redactions, manual rollback after a bad ingest?)
- How strictly should constraint 9 be enforced? (E.g., if a user *wants* Obsidian features in their personal wiki, do we allow them to opt in but not require it?)
