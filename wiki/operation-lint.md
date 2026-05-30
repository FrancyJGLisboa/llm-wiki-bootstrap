---
title: Operation — Lint
type: concept
source: video
updated: 2026-05-25
tags: [operations, lint, maintenance]
---

# Operation — Lint

## Definition / TL;DR

**Lint** is the maintenance pass. The LLM scans the wiki and finds contradictions, stale claims, orphan pages (no inbound links), missing cross-references, and gaps where a web search could fill in. It reports the issues and proposes edits.

## Body

From the video: *"This is the maintenance pass. You ask the LLM to health-check the wiki — find contradictions, stale claims, orphan pages with no links, missing cross references, gaps that could be filled with a web search. So the LLM is good at suggesting new questions to investigate and this keeps the wiki healthy as it grows."* `(source: raw/karpathy-llm-wiki-video-transcript.md#3:50)`

### What lint catches

- **Broken `[[wiki-links]]`** — links to pages that don't exist
- **Orphan pages** — pages with no inbound links from anywhere else in the wiki
- **Contradictions** — claims in different pages that disagree
- **Stale claims** — claims tied to a date or version that's now old
- **Missing cross-references** — page A talks about a concept that has its own page B, but doesn't link to B
- **Unresolved open questions** — the "Open questions on this page" blocks that have aged
- **Gaps** — places where a web search would clearly help, but hasn't been run

### Why lint is its own operation `(analysis)`

[[operation-ingest]] runs *per source* — it only touches pages it can see are relevant to the source being ingested. Lint runs *over the whole wiki*. They're different cost shapes (ingest is bounded by source size; lint is bounded by wiki size) and different cadences (ingest fires on every fetch; lint fires when the user asks, or periodically).

### Why this is the antidote to wiki rot

Per [[division-of-labor]] and the video: humans abandon wikis because maintenance burden grows faster than value. Lint is the LLM's contribution to keeping that from happening — it's the operation that addresses the actual reason wikis go stale.

## Related

- [[operation-ingest]] — runs per source; lint runs over the whole wiki
- [[operation-query]] — lint can identify "gaps" by looking at unresolved open questions
- [[division-of-labor]] — lint is the LLM doing the work humans hate
- [[ingest-pipeline]] — step 5 (flag contradictions) is a *micro-lint* during ingest; full lint is broader

## Open questions on this page

- What cadence makes sense? On every `/wiki-ingest`? Scheduled? After every N pages added?
- Should lint *propose* edits and require confirmation, or *apply* them when it's confident? (Current default: `--apply` flag required; otherwise propose only.)
- How does lint handle a contradiction where both sides are sourced — flag for the user, or pick one?
