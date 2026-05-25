---
title: Layer — Schema
type: concept
source: mixed
updated: 2026-05-25
tags: [architecture, schema, conventions]
---

# Layer — Schema

## Definition / TL;DR

The schema is the configuration file that tells the LLM how this particular wiki is structured: link convention, page template, what counts as which `type`, naming rules, ingest workflow. In this project it's [`AGENTS.md`](../AGENTS.md) at the project root.

## Body

From the video: *"On the right is the schema, and this is the configuration file basically like a CLAUDE.md. And this tells the LLM how the wiki is structured, what the conventions are, what workflows to follow. So you and the LLM co-evolve this over time as you figure out what works for your domain."* `(source: raw/karpathy-llm-wiki-video-transcript.md#3:18-3:50)`

### Why a separate file (not embedded in the wiki)

The schema is **read every session** by the agentic tool — it's the standing context the LLM has when operating on this directory. Putting it in a top-level conventional file (`AGENTS.md`, `CLAUDE.md`, etc.) lets the tool auto-load it. Putting it inside the wiki would require explicit loading every time, defeating the purpose.

### Cross-tool portability `(analysis)`

We chose `AGENTS.md` as the canonical schema name. Reasons:

- Emerging cross-tool standard (Claude Code recent versions, Codex, others adopting)
- Tool-agnostic by design — no Claude / Cursor / Gemini-specific naming
- For tools that don't auto-load `AGENTS.md`, the README documents the one-line symlink: `ln -s AGENTS.md CLAUDE.md` (or equivalent)
- The five slash commands (`/wiki-init` etc.) also instruct explicit reading of `AGENTS.md` so that auto-load behavior is a bonus, not a requirement

### What lives in the schema

- Description of the three layers
- The five slash commands (names + 1-line purpose; full spec is in [[commands]])
- Page template (frontmatter spec + standard sections)
- Link convention
- Raw source frontmatter spec
- `log.md` format
- Hard rules ("LLM must NOT edit `raw/`", etc.)

### Co-evolution

The schema is the **one place** in the system where the user is a peer writer with the LLM. The user edits to steer conventions; the LLM proposes edits via [[operation-lint]] when it notices ambiguity or drift. Either party may change it; changes should be surfaced to the other.

## Related

- [[three-layer-architecture]] — where this fits
- [[layer-raw-sources]] — what the schema describes the conventions for
- [[layer-wiki]] — what the schema configures the LLM to write
- [[commands]] — the five slash commands that operate per this schema

## Open questions on this page

- At what cadence should the schema be reviewed? Currently: ad-hoc. Worth a `/wiki-lint --schema-review` mode?
- What happens when the schema changes and existing wiki pages don't match the new convention? Should `/wiki-ingest` or `/wiki-lint` migrate them?
- Should the schema be split (e.g., `AGENTS.md` for cross-tool basics + `SCHEMA.md` for project-specific) once the system grows?
