---
name: {{NAME}}
description: >-
  {{DOMAIN}}. A self-updating wiki brain — answers from an llm-wiki and learns
  from each interaction. Activates for questions about {{DOMAIN}}, and on
  triggers like {{TRIGGERS}}.
---

# {{NAME}}

A **self-updating wiki skill**: your knowledge base is a live llm-wiki (`wiki/` +
`raw/`, pure CommonMark, `[[links]]`, cited claims) that you both **answer from**
and **write back to** as you are used. The brain compounds with use.

Scope: **{{SCOPE}}**.

## Operating procedure

> **Portability:** the steps below name slash commands like `/wiki-query` and
> `/wiki-learn`. In a host where those are not registered as commands (e.g. when
> this folder is installed under `.claude/skills/`), follow the equivalent
> workflow body bundled in this folder — `.claude/commands/wiki-<name>.md` — by
> path instead. The folder is self-contained: every workflow it references ships
> inside it.

### Read (every turn)
Answer the user from the wiki. Run the read half of `/wiki-query` — locate
relevant pages via `wiki/index.md` + grep, follow `[[links]]`, synthesize, and
cite each non-trivial claim as `[[page-name]]`. Use **`/wiki-query --no-promote`**
during the session — promotion is deferred to session end so the gate sees the
whole conversation. If the wiki can't answer, say so plainly (don't invent).

### Learn (at session end)
Run **`/wiki-learn`** once, on the session just completed. It distills the
conversation into durable facts, passes them through the notability gate
(durable ∧ novel ∧ attributable ∧ in-scope; each tagged `preference` vs
`factual`, with a privacy guard), captures the kept ones as a
`raw/session-*.md` source, and `/wiki-ingest`s them — citing the originating
turn and applying latest-wins-with-trail for contradictions. Use `--dry-run`
first if you want to inspect the gate's decisions before writing.

The gate is the point: a smaller true brain beats a bloated noisy one. When in
doubt about a candidate, drop it.

## Integrity (non-negotiable)
- Writes flow **raw → wiki**, never straight into `wiki/`. `/wiki-learn` captures
  via `/wiki-extract` and synthesizes via `/wiki-ingest`; it never edits `wiki/`
  by hand. This is what keeps the brain auditable instead of an opaque memory blob.
- Every learned claim cites the interaction it came from
  (`(source: raw/session-<date>.md#turn-N)`), so a `factual` claim's origin is
  transparently "the user said so", not an authority.

<!-- SCOPE:per-user -->
## Per-user brains
Each user gets an isolated brain. The active brain lives at `wikis/<user-id>/`
(a full wiki root: `AGENTS.md`, `wiki/`, `raw/`, `log.md`). On first contact with
a new user, create their brain by copying the seed wiki root into
`wikis/<user-id>/`. Run all wiki commands from that directory, and pass
`--scope-dir wikis/<user-id>/` to `/wiki-learn`. Never read or write another
user's directory — isolation is the privacy guarantee, so personal facts and
`preference`-tagged candidates stay in that user's brain only.
<!-- /SCOPE:per-user -->

<!-- SCOPE:shared -->
## Shared brain
One wiki at the package root serves everyone; knowledge compounds across all
users. Because it is shared, `/wiki-learn` **drops** `preference`-tagged and any
personally-identifying candidates — only domain facts are promoted, so no user's
personal data leaks into the shared brain. Cross-user contradictions are flagged
and attributed, never silently resolved.
<!-- /SCOPE:shared -->

## Maintenance
Periodically run `/wiki-lint` to surface accumulated `CONTRADICTION FLAGGED`
notes, stale claims, and orphans for review. The wiki's `AGENTS.md` is the full
contract for the three-layer model and conventions.
