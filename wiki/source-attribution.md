---
title: Source Attribution
type: analysis
source: analysis
updated: 2026-05-25
tags: [meta, honesty, attribution]
---

# Source Attribution

> **This page is `source: analysis`.** It's a transparency page about what this wiki was built from, and where the LLM-wiki pattern is genuinely Karpathy's vs. the YouTuber's interpretation vs. this project's design choices.

## Definition / TL;DR

This wiki was distilled from **a single source**: a YouTube video walkthrough by a third-party creator who saw Karpathy's tweet on LLM knowledge bases and built a trading-strategies wiki in Claude Code as a demo. **Karpathy himself was not the speaker** in the source video. Anything quoted as "Karpathy" is a paraphrase or reading by the YouTuber.

## Why this matters

Three layers of provenance get easily confused if not flagged:

1. **What Karpathy actually tweeted.** The original tweet that started this whole conversation. We do not have its text in `raw/` — only the YouTuber's account of it.
2. **What the YouTuber said about Karpathy's tweet.** This is what's in `raw/karpathy-llm-wiki-video-transcript.md`. It includes paraphrases of Karpathy presented as quotes.
3. **What this project decided.** Design choices we (the project authors) made on top of the pattern: the 5-slash-command split, the [[layer-schema]] format, the [[implicit-constraints]], the page template. None of these are Karpathy's; some are extrapolated from his framing, others are pure project decisions.

Conflating these three is easy and misleading. Source-honesty (per [[four-principles]] *Explicit*) requires we mark the seams.

## How this wiki marks the seams

Every page has frontmatter:

```yaml
source: video | analysis | external | mixed
```

- `source: video` — the page's claims come from the YouTube transcript (and inline `(source: raw/...#timestamp)` citations point to where).
- `source: analysis` — the page is interpretation, **not** a literal extraction. A visible note at the top of the body says so.
- `source: external` — the page was promoted from a web-search backfill via [[query-as-write-loop]], with the source URL captured.
- `source: mixed` — the page combines `video` and `analysis` content; both are present and the analysis sections should be visibly marked.

A reader who wants only the literal video content runs: `grep -l "source: video" wiki/*.md`. A reader who wants the project's interpretation runs: `grep -l "source: analysis" wiki/*.md`.

## What we do NOT have in `raw/`

- Karpathy's original tweet (text or URL)
- The follow-up tweets the YouTuber mentions (Farza, Eu Jin)
- Eu Jin's diagram that the YouTuber says broke down the pattern nicely
- Any of Karpathy's own writing about the system

If you want the wiki to reflect Karpathy more directly, the natural next step is to fetch the original tweet(s) into `raw/` and run `/wiki-ingest`. That would add a `source: external` lineage that's closer to ground truth.

## The video's own attribution caveats

The YouTuber occasionally distinguishes Karpathy's claims from their own commentary, but not consistently. A safe default reading: **anything in quotation marks is a paraphrase**, not verbatim. Anything outside quotation marks is more reliably the YouTuber's own framing.

## What the project authors decided (and is not in the video)

- The five-slash-command split (`/wiki-init`, `/wiki-fetch`, `/wiki-ingest`, `/wiki-ask`, `/wiki-lint`) — see [[commands]].
- The split into separate `/wiki-fetch` and `/wiki-ingest` (the video treats source-drop and processing as a single act).
- Using `AGENTS.md` as the canonical schema name (the video says "like a CLAUDE.md").
- The `[[wiki-link]]` syntax as a *textual-only* convention without a viewer dependency — see [[implicit-constraints]] #9.
- The frontmatter spec (the video doesn't show what raw or wiki frontmatter looks like).
- The 7-step pipeline being formally codified as a checklist (the video lists the steps but doesn't structure them as a contract).
- Hash-based delta detection on raw files (the video doesn't say how the LLM knows what's been ingested).

These are reasonable extrapolations, but they're ours.

## Related

- [[core-idea]] — the central claim, attributed to Karpathy via paraphrase
- [[four-principles]] — *Explicit* underwrites this whole attribution exercise
- [[implicit-constraints]] — other project decisions, marked as ours
- [[open-questions]] — what we don't have answers for

## Open questions on this page

- Should we fetch the original Karpathy tweets and re-derive parts of the wiki from them? (Doable; would strengthen `source: video` claims and add `source: external` ones.)
- How to handle future ingestions where the same idea appears in multiple raw sources with slightly different framings — pick one canonical, or note both?
