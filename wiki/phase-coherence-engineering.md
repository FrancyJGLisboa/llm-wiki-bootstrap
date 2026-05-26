---
title: "Phase Coherence Engineering"
type: concept
source: external
updated: 2026-05-26
tags: [smoke, fictional, field]
---

# Phase Coherence Engineering

## Definition / TL;DR

**Phase coherence engineering** is the (fictional) discipline of holding distributed sensor arrays in mutual phase alignment without continuous wired synchronisation. It was founded by [[dr-alma-voss]] at the Linnaean Institute in 2019 (source: raw/smoke-source.md#the-field).

> This page is part of the smoke fixture. The field is invented; nothing here is real-world knowledge. See [[smoke-source-summary]] for the full provenance.

## Body

The field exists because of a hard wall in the previous approach (drift compensation, GPS-disciplined): stations more than 4 km apart could not stay phase-coherent for longer than 11 minutes using any of the then-known methods (source: raw/smoke-source.md#the-field).

The field's **central artifact** is the [[quortex-protocol]] — a sequence of carrier-phase rotations applied to each station's reference oscillator on a fixed schedule. The protocol uses 47 phase rotations of 7.65° each per coherence window, deliberately summing to 359.55° rather than a full 360° so that no two consecutive windows present the same phase signature to a passive observer (source: raw/smoke-source.md#the-quortex-protocol).

### Adjacent terms (mentioned but not asserted by this source)

The source names three related terms without developing them, explicitly so that step 4 of `/wiki-ingest` has plausible cross-reference targets (source: raw/smoke-source.md#related-concepts-for-future-tests-not-exercised-here):

- **Drift compensation** — the older approach the Quortex protocol replaced; used active GPS disciplining and failed beyond 4 km.
- **Linnaean Institute** — Voss's affiliation; "a made-up research consortium."
- **Coherence window** — the time interval over which a station maintains phase alignment with its neighbours. With Quortex applied, windows extend to several hours.

These are not promoted to their own pages yet — they are referenced once and not structurally important. `/wiki-lint` will surface them as gaps if the corpus grows.

## Related

- [[quortex-protocol]] — the field's central artifact
- [[dr-alma-voss]] — the founder
- [[smoke-source-summary]] — the source this page is derived from

## Open questions on this page

- The source does not name competing fields, predecessor disciplines beyond "drift compensation", or any successor work after Voss's 2019 paper.
