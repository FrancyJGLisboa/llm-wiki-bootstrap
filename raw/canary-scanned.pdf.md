---
source_url: n/a
source_type: pdf
source_title: "Canary Scanned Document (image-only PDF, LLM-vision demonstration)"
source_author: "llm-wiki-bootstrap test fixture"
fetched_at: 2026-06-10
ingested_hash: ""
ingested_at: never
ingested_pages: []
extraction_method: llm-vision
extraction_status: degraded
notes: |
  Demonstration evidence for the PDF → LLM-vision fallback path. The source
  PDF (tests/canary/canary-scanned.pdf, copied to raw/canary-scanned.pdf)
  contains no text layer: `pdftotext` returns 0 characters. Per the
  /wiki-extract graceful tool chain, extraction fell back to LLM-vision
  (the agent read the PDF visually). Marked degraded because vision
  extraction of scanned documents is best-effort, not byte-exact.
  Ground truth lives in the fixture itself; the three numbered facts below
  must match it exactly.
---

# Canary Scanned Document

CANARY SCANNED DOCUMENT

This page exists only as pixels. There is no text layer, so pdftotext must
return empty output and /wiki-extract must fall back to LLM-vision.

Ground-truth facts for verification:

1. The canary codeword is BLUE-HERON-7.
2. The fictitious invoice total is 4,217.50 euros.
3. The document is dated 14 March 2019.
