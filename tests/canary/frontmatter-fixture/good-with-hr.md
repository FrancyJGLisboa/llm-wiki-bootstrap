---
source_url: https://example.com/with-hr
source_type: article
fetched_at: 2026-05-30
extraction_method: manual
ingested_hash: ""
---

This body is well-formed but contains a markdown horizontal rule below, which is
a legitimate `---` line. The guard must NOT reject this file.

---

Section after the thematic break. The hashing awk still treats only the first
two `---` as frontmatter delimiters, so this content is part of the body.
