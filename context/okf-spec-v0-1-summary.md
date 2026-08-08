---
title: OKF Spec v0.1 Summary
type: summary
source: external
updated: 2026-07-07
tags: [okf, google, spec, source-summary]
---

# OKF Spec v0.1 Summary

## Definition / TL;DR

Per-source recap of Google's Open Knowledge Format v0.1 specification (`GoogleCloudPlatform/knowledge-catalog`, `okf/SPEC.md`) — a deliberately minimal spec for [[open-knowledge-format]] bundles. Note: the raw snapshot is a condensed rendering, not the verbatim spec (`extraction_status: degraded`).

## Body

The spec defines a knowledge bundle as a directory tree of markdown files with YAML frontmatter, readable "without tools" by humans and "without SDKs" by agents — "If you can `cat` a file, you can read OKF; if you can `git clone` a repo, you can ship it" (source: raw/okf-spec-v0-1.md#core-structure).

Main takeaways:

- **One hard requirement.** Every concept document needs parseable YAML frontmatter with a non-empty `type` field — the only mandatory key. The value is free-form (e.g. "BigQuery Table", "Playbook", "Metric") (source: raw/okf-spec-v0-1.md#required-elements).
- **Recommended (optional) fields:** `title`, `description` (single-sentence summary), `resource` (URI of the underlying asset), `tags`, `timestamp` (ISO 8601 last-modified) (source: raw/okf-spec-v0-1.md#recommended-fields).
- **Two reserved filenames:** `index.md` (progressive-disclosure directory listing) and `log.md` (chronological update history). Every other `.md` file is a concept (source: raw/okf-spec-v0-1.md#reserved-filenames).
- **Links are standard markdown paths** — bundle-absolute (`/tables/customers.md`) or relative (`./other.md`). Links assert that a relationship exists; the semantics live in surrounding prose. **Broken links are tolerated** (source: raw/okf-spec-v0-1.md#cross-linking).
- **Permissive conformance.** A bundle conforms if all non-reserved `.md` files have parseable frontmatter with non-empty `type`. Consumers must gracefully handle missing optional fields, unknown types, and unrecognized frontmatter keys (source: raw/okf-spec-v0-1.md#conformance).

The overlap (and the gaps) relative to this system's schema are analyzed in [[okf-vs-llm-wiki-bootstrap]].

## Related

- [[open-knowledge-format]] — the entity this spec defines
- [[okf-vs-llm-wiki-bootstrap]] — field-by-field comparison with this system
- [[google-cloud-okf-blog-summary]] — the announcement context around the spec
- [[layer-schema]] — this system's analogue of a format spec

## Open questions on this page

- The raw snapshot is condensed, not verbatim — does the full SPEC.md contain conformance details (e.g. nesting rules, frontmatter size limits) lost in the summary? Re-extract to upgrade.
