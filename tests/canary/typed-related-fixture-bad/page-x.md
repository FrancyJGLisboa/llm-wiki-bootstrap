---
title: Page X (malformed)
type: concept
source: analysis
updated: 2026-05-27
tags: [canary, typed-relations, malformed]
---

# Page X

Canary fixture for the REJECT side of the lint. The lines below contain
structurally-malformed verb tokens. The lint MUST exit non-zero when it sees any
single-target Related line whose token between `]]` and the em-dash does not match
`[a-z][a-z0-9-]*`.

## Related

- [[page-a]] 5badverb — starts with a digit (illegal)

## Open questions on this page

- none
