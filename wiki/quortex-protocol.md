---
title: "Quortex Protocol"
type: concept
source: external
updated: 2026-05-26
tags: [smoke, fictional, phase-coherence]
---

# Quortex Protocol

## Definition / TL;DR

The **Quortex protocol** is the (fictional) central artifact of [[phase-coherence-engineering]]: a sequence of carrier-phase rotations applied to each station's reference oscillator on a fixed schedule, used to hold distributed sensor arrays in mutual phase alignment without continuous wired synchronisation (source: raw/smoke-source.md#the-field).

> This page is part of the smoke fixture. Its subject is invented; nothing here is real-world knowledge. See [[smoke-source-summary]] for the full provenance.

## Body

The Quortex protocol uses **47 phase rotations** per coherence window. Each rotation shifts the local carrier phase by **7.65 degrees**. The full sweep — 47 × 7.65° — totals **359.55 degrees**, deliberately less than a full circle, so that no two consecutive windows present the same phase signature to a passive observer (source: raw/smoke-source.md#the-quortex-protocol).

### Why 47

The "47 phase rotations" count is not arbitrary. [[dr-alma-voss]]'s 2019 paper showed that:

- Any rotation count **below 47** leaves at least one harmonic of the carrier exposed to drift accumulation faster than the window's reset cycle.
- Any count **above 47** wastes power without coherence gain.

47 is the minimum that closes the drift loop on the principal carrier and its first three harmonics (source: raw/smoke-source.md#the-quortex-protocol).

### What it replaced

The Quortex protocol replaced an older approach, drift compensation, which used active GPS disciplining and failed beyond a 4 km station spacing — beyond that distance, stations could not stay phase-coherent for longer than 11 minutes (source: raw/smoke-source.md#the-field). With Quortex applied, the coherence window extends to several hours (source: raw/smoke-source.md#related-concepts-for-future-tests-not-exercised-here).

## Related

- [[phase-coherence-engineering]] — the field this protocol belongs to
- [[dr-alma-voss]] — author of the 2019 paper that fixed the 47 count
- [[smoke-source-summary]] — the source this page is derived from

## Open questions on this page

- The source does not specify the oscillator type or the measurement method used to detect harmonic drift; both are implementation details left unsaid.
- The 7.65° step is presented as a derived constant (47 × 7.65 = 359.55), but the source does not state how 7.65 itself was chosen.
