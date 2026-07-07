---
title: Open Knowledge Format
type: entity
source: mixed
updated: 2026-07-07
tags: [okf, google, spec, standards]
---

# Open Knowledge Format

## Definition / TL;DR

The Open Knowledge Format (OKF) is Google Cloud's v0.1 open specification (June 2026, `GoogleCloudPlatform/knowledge-catalog`) that formalizes the LLM-wiki pattern — a bundle is a directory of markdown files with YAML frontmatter, one concept per file — so knowledge written by different producers can be consumed by different agents without translation.

## Body

Google presents OKF as "an open specification that formalizes the LLM-wiki pattern into a portable, interoperable format" (source: raw/google-cloud-okf-blog.md#overview) — a direct standardization of the [[core-idea]] this wiki documents.

The format itself is deliberately minimal (source: raw/okf-spec-v0-1.md#core-structure):

- A bundle is a directory tree of markdown files; each non-reserved `.md` file is one concept (a table, metric, playbook, runbook, API…) (source: raw/google-cloud-okf-blog.md#format-structure).
- The **only mandatory frontmatter key is `type`**, a free-form string; `title`, `description`, `resource`, `tags`, and `timestamp` are recommended but optional (source: raw/okf-spec-v0-1.md#required-elements).
- Two reserved filenames: `index.md` (progressive disclosure) and `log.md` (change history) (source: raw/okf-spec-v0-1.md#reserved-filenames).
- Cross-links are ordinary markdown paths; **broken links are tolerated**, and consumers must gracefully handle unknown fields, unknown types, and unparseable files (source: raw/okf-spec-v0-1.md#cross-linking).

**What OKF deliberately excludes:** any maintenance process. The Devsplainers commentary puts it sharply — Google "kept the folder and left out the part that keeps it alive," dropping Karpathy's instructions for how the AI maintains the wiki (source: raw/devsplainers-okf-llm-wiki-video-transcript.md#3:29). The spec's `timestamp` field has no process behind it, and the permissive-reader rule absorbs (rather than prevents) messy LLM output (source: raw/devsplainers-okf-llm-wiki-video-transcript.md#4:54).

**Origin and strategy:** OKF came from Google's BigQuery/data-analytics side, not its AI lab. The reference producer is an enrichment agent that walks a BigQuery dataset and drafts one OKF concept per table/view, with a second LLM pass adding citations, schemas, and join paths (source: raw/google-cloud-okf-blog.md#bigquery-integration). The stated commitment is vendor-neutrality — no proprietary account or SDK ever required to read, write, or serve a bundle (source: raw/google-cloud-okf-blog.md#vendor-neutral-design) — though the launch tooling is Google-stack-shaped, and adoption at launch was near zero outside Google (source: raw/devsplainers-okf-llm-wiki-video-transcript.md#7:15).

How this system's schema relates to OKF — near-isomorphic container, plus the lifecycle OKF omits — is analyzed in [[okf-vs-llm-wiki-bootstrap]].

## Related

- [[core-idea]] caused-by — OKF is a formalization of the LLM-wiki pattern Karpathy proposed
- [[okf-vs-llm-wiki-bootstrap]] — field-by-field overlap and gap analysis
- [[okf-spec-v0-1-summary]] — the spec, summarized per-source
- [[google-cloud-okf-blog-summary]] — the announcement, summarized per-source
- [[devsplainers-okf-llm-wiki-video-transcript-summary]] — third-party commentary and critiques
- [[layer-schema]] — this system's stricter analogue of an interchange spec

## Open questions on this page

- Will OKF get a v0.2, and will it add any process/maintenance semantics — or stay container-only?
- Does any non-Google producer or consumer ship OKF support? (At launch: effectively none.)
- What is "Google's own knowledge product … just renamed" that the video alludes to? The degraded blog snapshot doesn't name it.
