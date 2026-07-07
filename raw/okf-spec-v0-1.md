---
source_url: https://raw.githubusercontent.com/GoogleCloudPlatform/knowledge-catalog/main/okf/SPEC.md
source_type: spec
source_title: "Open Knowledge Format (OKF) v0.1 — SPEC.md"
source_author: "Google Cloud (GoogleCloudPlatform/knowledge-catalog)"
fetched_at: 2026-07-07
ingested_hash: 7d4121eedfa9b5639ba9d7b8a82aaaecb69c0634bde201bf5848269b531b4ec1
ingested_at: 2026-07-07 06:20
ingested_pages: [wiki/okf-spec-v0-1-summary.md, wiki/open-knowledge-format.md, wiki/okf-vs-llm-wiki-bootstrap.md]
extraction_method: webfetch
extraction_status: degraded
notes: |
  Fetched via WebFetch, which returned a faithful condensed rendering (field
  names, reserved filenames, and conformance rules preserved) rather than the
  verbatim spec text. A follow-up verbatim re-fetch was blocked by the local
  context-gate egress hook (TRIFECTA_CLAMP). To upgrade: re-run
  /wiki-extract on this URL from a fresh session or after allowlisting
  raw.githubusercontent.com in context-gate.
---

# Open Knowledge Format (OKF) v0.1 — spec summary

## Core Structure

OKF represents knowledge as a directory tree of markdown files with YAML frontmatter. It's designed to be human-readable without tools and parseable by agents without SDKs.

**Key principle:** "If you can `cat` a file, you can read OKF; if you can `git clone` a repo, you can ship it."

## Required Elements

Every concept document must contain:

1. **YAML frontmatter** (delimited by `---`)
2. **`type` field** — The only mandatory frontmatter key, identifying the concept kind (e.g., "BigQuery Table", "Playbook", "Metric")
3. **Markdown body** — Free-form content, preferably structural

## Recommended Fields

- `title` — Display name
- `description` — Single-sentence summary
- `resource` — URI identifying the underlying asset
- `tags` — Cross-cutting categorization
- `timestamp` — ISO 8601 last-modified time

## Reserved Filenames

- `index.md` — Progressive disclosure directory listings
- `log.md` — Chronological update history

All other `.md` files are concepts.

## Cross-linking

Two link forms are supported:

- **Absolute (bundle-relative):** Start with `/`, e.g., `/tables/customers.md`
- **Relative:** Standard markdown paths, e.g., `./other.md`

Links assert relationships; specifics come from surrounding prose. Broken links are tolerated.

## Conformance

A bundle conforms if all non-reserved `.md` files have parseable frontmatter with a non-empty `type` field. Consumers must gracefully handle missing optional fields, unknown types, and unrecognized frontmatter keys.
