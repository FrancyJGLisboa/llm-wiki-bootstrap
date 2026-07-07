---
source_url: https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing/
source_type: article
source_title: "How the Open Knowledge Format can improve data sharing"
source_author: "Google Cloud"
fetched_at: 2026-07-07
ingested_hash: 8d5556f60b157b294060240de9e8104a2b57274a9cf831e52265f9e1091bc3d8
ingested_at: 2026-07-07 06:20
ingested_pages: [wiki/google-cloud-okf-blog-summary.md, wiki/open-knowledge-format.md, wiki/okf-vs-llm-wiki-bootstrap.md, wiki/core-idea.md]
extraction_method: webfetch
extraction_status: degraded
notes: |
  Full-page fetch was blocked by the local context-gate egress hook
  (TRIFECTA_CLAMP). Body below is the partial content of this URL as
  returned by web search immediately before the clamp engaged — announcement
  substance is present, but this is NOT the complete article. To upgrade:
  re-run /wiki-extract on this URL from a fresh session or after
  allowlisting cloud.google.com in context-gate.
---

# How the Open Knowledge Format can improve data sharing (partial)

## Overview

Google introduced the Open Knowledge Format (OKF), an open specification that formalizes the LLM-wiki pattern into a portable, interoperable format. This is a vendor-neutral, agent- and human-friendly standard for representing the metadata, context, and curated knowledge that modern AI systems need.

## Format Structure

As published, OKF v0.1 represents knowledge as a directory of markdown files with YAML frontmatter, with a small set of agreed-upon conventions that let wikis written by different producers be consumed by different agents without translation. An OKF bundle is a directory of markdown files representing concepts: anything you want to capture, including tables, datasets, metrics, playbooks, runbooks, and APIs. Each concept is one file.

## BigQuery Integration

Google is publishing reference implementations at both the producer and consumer ends: an enrichment agent that walks a BigQuery dataset, drafts an OKF concept document for every table and view, then runs a second LLM pass that crawls authoritative documentation and enriches each concept with citations, schemas, and join paths.

## Vendor-Neutral Design

OKF is not tied to any specific cloud, database, model provider, or agent framework. It will never require a proprietary account or SDK to read, write, or serve.

## Key Features

The full v0.1 specification (including conformance criteria, cross-linking rules, and the small number of reserved filenames) fits on a single page. The OKF specification, reference implementations, and sample bundles are available on GitHub.
