---
title: OKF vs This System
type: analysis
source: analysis
updated: 2026-07-07
tags: [okf, analysis, positioning, schema]
---

# OKF vs This System

## Definition / TL;DR

Field-by-field comparison of [[open-knowledge-format]] with this system's schema. Conclusion: the containers are near-isomorphic — but OKF standardizes only the container, while this system's entire value is the lifecycle OKF omits (ingest, lint, citations, ownership rules). This system is, in effect, OKF plus the part Google dropped.

## Body

This page is interpretation, not extracted from any single source — the OKF side is cited; the mapping and conclusions are ours.

### The containers converge

| | OKF v0.1 | This system (`AGENTS.md`) |
|---|---|---|
| Unit | directory of `.md` + YAML frontmatter, one concept per file (source: raw/okf-spec-v0-1.md#core-structure) | same (`wiki/`) |
| Reserved files | `index.md`, `log.md` (source: raw/okf-spec-v0-1.md#reserved-filenames) | `wiki/index.md`, `log.md` — same names |
| Required frontmatter | `type`, free-form string (source: raw/okf-spec-v0-1.md#required-elements) | `type` from a controlled vocabulary, plus `title`/`source`/`updated`/`tags` |
| Links | markdown paths; broken links tolerated (source: raw/okf-spec-v0-1.md#cross-linking) | `[[wikilinks]]`; broken links fail [[operation-lint]] |
| Freshness | optional `timestamp` field, no process | `updated` field + stale-claim lint |
| Provenance | none | citation-coverage gate; web sources must snapshot to `raw/` |
| Maintenance | out of scope | [[ingest-pipeline]], [[operation-lint]], [[synthesis-artifacts]] |

The convergence is no accident: Google describes OKF as a formalization of the LLM-wiki pattern (source: raw/google-cloud-okf-blog.md#overview), and this system is an implementation of that same pattern. Even the reserved filenames match.

### The three catches, already answered here

The Devsplainers commentary names three weaknesses of container-only standardization (source: raw/devsplainers-okf-llm-wiki-video-transcript.md#4:54). Each maps to an existing mechanism in this system:

1. **Staleness — "a field is not a process."** OKF has a `timestamp`; nothing updates it. Here, freshness is a *process*: `/wiki-lint` checks stale claims, `/wiki-ingest` re-processes on body-hash change, and every mutation appends to `log.md`.
2. **The messy librarian.** OKF handles LLM-mangled markdown by ordering readers to forgive it. Here the librarian is *checked instead of forgiven*: lint fails on broken links and schema drift, citations are audited deterministically, and derived views are regenerated mechanically so they cannot drift.
3. **Container, not meaning.** OKF's free-form `type` lets every producer speak a different language. Here `type` is a controlled vocabulary (concept / entity / summary / analysis / navigation / journal) and causal `## Related` verbs are canonicalized, so meaning is machine-traversable.

### The moat, named

The video's closing observation — the skill is "what's locked versus what the AI can rewrite, what stops it drifting over a long run" (source: raw/devsplainers-okf-llm-wiki-video-transcript.md#6:15) — is precisely this system's [[three-layer-architecture]] (raw immutable, wiki LLM-owned, schema co-evolved) plus the `wiki/journal/` user-owned exception. What OKF cannot standardize, the schema layer here makes explicit. <!-- FAITHFULNESS UNVERIFIED: raw/devsplainers-okf-llm-wiki-video-transcript.md#6:15 does not clearly support this claim -->

### Practical consequence

Because the containers are so close, exporting a wiki built here into an OKF bundle is mostly mechanical (rewrite `[[slug]]` → `./slug.md`, map `updated` → `timestamp`, derive `description` from each TL;DR). That makes wikis built by this system consumable by any OKF-aware tool without giving up the stricter internal invariants. Interop is one-way strictness: we can always relax into OKF; an arbitrary OKF bundle does not meet our gates.

## Related

- [[open-knowledge-format]] — the entity being compared
- [[three-layer-architecture]] — the ownership model OKF has no analogue of
- [[implicit-constraints]] — the invariants that make this system stricter than OKF
- [[operation-lint]] — the process answer to OKF's permissive-reader rule
- [[devsplainers-okf-llm-wiki-video-transcript-summary]] — where the three catches come from

## Open questions on this page

- Should this system emit OKF-recommended fields (`description`, `resource`) natively, or only at export time?
- If OKF gains adoption, is an OKF *import* path worth building (relaxed bundle → gated wiki), and what would the triage of unmet invariants look like?
