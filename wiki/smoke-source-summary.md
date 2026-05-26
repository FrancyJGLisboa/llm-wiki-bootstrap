---
title: "Source Summary — Phase Coherence Engineering Primer (Smoke Fixture)"
type: summary
source: external
updated: 2026-05-26
tags: [source-summary, smoke, fictional, fixture]
---

# Source Summary — Phase Coherence Engineering Primer (Smoke Fixture)

## Definition / TL;DR

This is the per-source summary for `raw/smoke-source.md`, the end-to-end smoke fixture for `llm-wiki-bootstrap`. The source is an **intentionally fictional** primer on "phase coherence engineering," written so its content cannot overlap with any real-world LLM training corpus. If a wiki page produced from this source carries forward the source's literal anchors — "Quortex protocol", "Dr. Alma Voss", "47 phase rotations" — that is empirical evidence that `/wiki-ingest` actually read the file (source: raw/smoke-source.md#why-this-matters-for-the-smoke).

## What this source provides

The fixture introduces three load-bearing anchors that the smoke checks grep for verbatim:

- The [[quortex-protocol]] — the field's central artifact, a sequence of carrier-phase rotations applied to each station's reference oscillator (source: raw/smoke-source.md#the-field).
- [[dr-alma-voss]] — founder of the field, affiliated with the Linnaean Institute, who published the 2019 paper that fixed the rotation count (source: raw/smoke-source.md#the-field).
- The "47 phase rotations" anchor — the Quortex protocol uses **47 phase rotations** per coherence window, each shifting the local carrier by 7.65° for a 359.55° total sweep (source: raw/smoke-source.md#the-quortex-protocol).

The 47-rotation count is not arbitrary: Voss's 2019 paper showed any count below 47 leaves a harmonic exposed to drift faster than the window's reset cycle, and any count above 47 wastes power without coherence gain (source: raw/smoke-source.md#the-quortex-protocol).

## What this source does NOT provide

- Any real-world reference. The discipline, the protocol, the founder, and the institution are invented. Treat every claim as fixture content, not knowledge.
- Mathematical derivation of the 47 count beyond Voss's narrative explanation.
- Implementation details (hardware, oscillator type, drift-measurement method).

## Why this source exists

It exists to answer one question for a first-time user of `llm-wiki-bootstrap`: when I drop a source into `raw/` and run `/wiki-ingest`, does the LLM actually read the source and write durable wiki pages about it, or does it merely sound like it did? Because the field is fictional, a wiki page that uses the literal string "47 phase rotations" can only have come from this file (source: raw/smoke-source.md#why-this-matters-for-the-smoke).

The smoke check `C2` requires a newly-created `wiki/*.md` to contain the literal "Quortex" string; `C4` requires the literal "47 phase rotations" in a `/wiki-query` answer that also cites `raw/smoke-source.md`.

## Related

- [[quortex-protocol]] — the artifact this source defines
- [[dr-alma-voss]] — the founder this source introduces
- [[phase-coherence-engineering]] — the (fictional) field this source primes

## Open questions on this page

- Should the smoke fixture be expanded to also exercise contradiction-flagging (step 5 of the ingest pipeline)?
- Should the "Related concepts" stub terms in the source (drift compensation, Linnaean Institute, coherence window) be promoted to their own pages, or remain as broken `[[links]]` to be surfaced by `/wiki-lint`?
