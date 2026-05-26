---
source_url: n/a (local smoke fixture)
source_type: article
source_title: "Phase Coherence Engineering — A Primer"
source_author: "Smoke test fixture (fictional)"
fetched_at: 2026-05-26
ingested_hash: ba2159c8b5479db823817126786fbce1d2a86d902ce716d70d18294878df562c
ingested_at: 2026-05-26 06:52
ingested_pages: [wiki/smoke-source-summary.md, wiki/quortex-protocol.md, wiki/dr-alma-voss.md, wiki/phase-coherence-engineering.md, wiki/index.md]
extraction_method: passthrough
notes: |
  This file is the end-to-end smoke fixture for llm-wiki-bootstrap. Body
  copied verbatim from tests/smoke/smoke-source.md by scripts/smoke-build.sh.
  Do not edit the body here — edit the fixture and rerun.
---

# Phase Coherence Engineering — A Primer

This file is the end-to-end smoke fixture for `llm-wiki-bootstrap`. It is intentionally about an invented field so that no part of its content overlaps with real-world knowledge in an LLM's training corpus. If `/wiki-ingest` produces a wiki page that uses the literal anchors below, that is empirical evidence the ingest pipeline read this file rather than fabricating from prior knowledge.

The three anchors that the smoke checks grep for, verbatim, are:

- **Quortex protocol**
- **Dr. Alma Voss**
- **47 phase rotations**

Do not change these strings without also updating `tests/smoke/smoke-source.md` *and* `scripts/smoke-check.sh` *and* `.scratch/plug-and-play-curator-smoke/GOAL.md` §3 in lockstep. The smoke is frozen on these strings after step 1's commit.

## The field

Phase coherence engineering is the (fictional) discipline of holding distributed sensor arrays in mutual phase alignment without continuous wired synchronisation. It was founded by **Dr. Alma Voss** at the Linnaean Institute in 2019, after her earlier work on drift compensation in autonomous buoy networks ran into a hard wall: stations more than 4 km apart could not stay phase-coherent for longer than 11 minutes using any of the then-known methods.

The field's central artifact is the **Quortex protocol**, a sequence of carrier-phase rotations applied to each station's reference oscillator on a fixed schedule.

## The Quortex protocol

The Quortex protocol uses **47 phase rotations** per coherence window. Each rotation shifts the local carrier phase by 7.65 degrees. The full sweep — 47 × 7.65° — totals 359.55 degrees, deliberately less than a full circle, so that no two consecutive windows present the same phase signature to a passive observer.

The 47-rotation count is not arbitrary. Voss's 2019 paper showed that any rotation count below 47 leaves at least one harmonic of the carrier exposed to drift accumulation faster than the window's reset cycle; any count above 47 wastes power without coherence gain. 47 is the minimum that closes the drift loop on the principal carrier and its first three harmonics.

## Why this matters for the smoke

A naive curator running `llm-wiki-bootstrap` for the first time wants to know: when I drop a source into `raw/` and run `/wiki-ingest`, does the LLM actually read the source and write durable wiki pages about it, or does it merely sound like it did?

This fixture's content is unfindable in any model's training data. A page on `wiki/quortex-protocol.md` (or any similarly-named page) that uses the literal string "47 phase rotations" is therefore a positive signal: the ingest pipeline ran, the LLM read this file, and the resulting wiki page carries forward the source's exact terminology.

A page that says "the Quortex protocol uses several rotations" would be a *negative* signal — the LLM is hedging because it didn't actually retain the specific number. The smoke check `C2` grep is therefore tight: it requires the literal "Quortex" string in a newly-created page, and `C4` requires the literal "47 phase rotations" in the captured `/wiki-query` answer.

## What `/wiki-query` should be able to answer

After this file is ingested, the query "How many phase rotations does the Quortex protocol use, and who founded phase coherence engineering?" should return an answer that contains both **47** and **Dr. Alma Voss**, with a citation back to `raw/smoke-source.md`.

Anything less — a generic "47 rotations" answer that omits the founder, or an answer that mentions Voss but garbles the rotation count, or an answer with no citation — fails the smoke. The check is unforgiving on purpose: a working LLM librarian must be able to recall a specific number from a freshly-ingested source AND attribute its provenance.

## Related concepts (for future tests, not exercised here)

- **Drift compensation**: the older approach the Quortex protocol replaced. Used active GPS disciplining; failed beyond 4 km.
- **Linnaean Institute**: Voss's affiliation. A made-up research consortium.
- **Coherence window**: the time interval over which a station maintains phase alignment with its neighbours. With Quortex applied, windows extend to several hours.

These are not asserted by the smoke. They exist so that `/wiki-ingest`'s step-4 cross-referencing has plausible terms to link.
