---
source_url: https://example.com/malformed
source_type: article
fetched_at: 2026-05-30
extraction_method: manual
ingested_hash: ""

This file opens its frontmatter but never closes it — there is no second `---`.
body-hash.sh must reject this (exit 1) instead of returning the empty-string SHA.
