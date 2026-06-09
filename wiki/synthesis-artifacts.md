---
title: Synthesis Artifacts
type: concept
source: analysis
updated: 2026-06-09
tags: [system, synthesis, ingest, schema-v3]
---

# Synthesis Artifacts

## Definition / TL;DR

This page is interpretation, not extracted from the video. **Synthesis artifacts** are four cross-cutting views the wiki regenerates *mechanically* — without LLM work — from markers that already exist in the pages. They were added in schema v3 (2026-06-09) so the wiki maintains standing aggregate views, not just per-source pages.

## Body

The seven-step [[ingest-pipeline]] writes **source-centric** pages: a summary, the entity/concept pages a source touched, the index, the log. It says nothing about *whole-wiki* views — "what are all the open questions?", "where do pages contradict each other?", "what changed when?". Synthesis artifacts fill that gap.

The key design choice is that synthesis does **no semantic work**. The LLM already did the thinking when it wrote each `## Open questions on this page` section and each `> CONTRADICTION FLAGGED` flag during ingest; synthesis only *aggregates* those markers. That is what makes regenerating on every wiki mutation affordable (zero LLM cost) and safe — output is deterministic, so a run that changes nothing leaves git clean.

### The four artifacts

- `wiki/open-questions-dashboard.md` — every `## Open questions on this page` section, grouped by page. Distinct from the manually-authored [[open-questions]] (system-level gaps); the dashboard links to it.
- `wiki/tensions.md` — every `> CONTRADICTION FLAGGED` flag across the wiki, newest first.
- `wiki/decision-timeline.md` — reverse-chronological activity timeline parsed from `log.md` headers. An activity trail, not a record of domain decisions.
- `wiki/knowledge-graph.json` — the `[[link]]` graph as deterministic JSON, emitted by `scripts/visualize/graph-html.py --json` — the same parser `/wiki-visualize` uses, so the JSON and the rendered graph never diverge.

### When it runs

`scripts/synthesize/all.sh` is the single entrypoint, invoked as the final action of every wiki-mutating command: [[operation-ingest]] always (even a no-op run), [[operation-query]] when it promotes a page, and [[operation-lint]] after `--apply`. Running everywhere — not just on ingest — is what prevents the dashboards from drifting after a promote or a lint-fix.

### Why they're generated, not authored

The three markdown pages are `type: navigation` and carry an `<!-- AUTO-GENERATED -->` marker. Hand-edits are overwritten on the next run, so to change them you change the underlying markers (resolve a question, resolve a contradiction at its raw source). [[operation-lint]] skips them in its authored-page checks.

## Related

- [[ingest-pipeline]] produces-markers-for — the 7 steps write the open-questions and contradiction markers synthesis aggregates
- [[operation-ingest]] runs — invokes synthesis as Step 8
- [[commands]] documented-in — the command surface (including `/wiki-visualize`, whose graph parser synthesis reuses)
- [[open-questions]] aggregated-by — the manual gaps page the dashboard links to

## Open questions on this page

- Should the timeline summarize each log entry (counts of created/updated) rather than just listing the header line?
- Is a committed `knowledge-graph.json` the right home, or should derived artifacts live in a gitignored output dir?
