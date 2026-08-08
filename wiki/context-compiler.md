---
title: Context Compiler
description: The category this system belongs to — a build system whose output is structured, provenance-aware, machine-navigable context that LLMs can navigate, retrieve from, and reason over.
type: analysis
source: mixed
updated: 2026-08-08
tags: [system, framing, architecture, provenance]
---

# Context Compiler

## Definition / TL;DR

A **context compiler** transforms unstructured source material into a structured, provenance-aware, machine-navigable context package that LLMs can navigate, retrieve from, and reason over. It is the name for the category this project occupies: "wiki" describes the *shape of the output*, "context compiler" describes the *function of the system*.

> **This page is `source: mixed`.** The underlying pattern — three layers, ingest/query/lint, human curates and LLM maintains — is from the video. The compiler framing, the five properties, and the vocabulary mapping are this project's own interpretation, not claims made in any raw source.

## Body

### Why the pattern needs a build step

The video's argument starts by rejecting query-time retrieval: chunk-and-embed search returns fragments without the surrounding reasoning, so the wiki is written once, in advance, instead of assembled per question (source: raw/karpathy-llm-wiki-video-transcript.md#0:51). See [[problem-with-naive-rag]].

That decision is what makes this a build system rather than a search index. Work moves from *every query* to *every source* — which is the right place for it, because sources arrive far less often than questions. The [[three-layer-architecture]] is the build's shape: `raw/` is the source tree, `wiki/` is the emitted output, and the schema file is the recipe (source: raw/karpathy-llm-wiki-video-transcript.md#2:32). The three operations — ingest, query, lint — are the build, the read, and the check (source: raw/karpathy-llm-wiki-video-transcript.md#3:50). See [[operation-ingest]] and [[operation-lint]].

The ownership rule completes the analogy: the human curates inputs, the LLM maintains outputs, and neither writes into the other's layer (source: raw/karpathy-llm-wiki-video-transcript.md#5:40). See [[division-of-labor]]. A compiler that let its recipes rewrite `src/` mid-build would lose its cache; the same reasoning applies here.

### The five properties

A system is a context compiler if it has all five. Each is a conformance question, not a feature list.

1. **Transformation.** There is an input language and a build step — heterogeneous material is parsed and normalized, not hand-authored. Here: `/wiki-extract` dispatches by format, and `/wiki-ingest` runs the pipeline that reads a source, extracts concepts and entities, writes the summary, updates existing pages, and flags contradictions (source: raw/karpathy-llm-wiki-video-transcript.md#4:46). See [[ingest-pipeline]].
2. **Target schema.** The output has a specification a third party could validate against — page template, closed type enum, link grammar, causal vocabulary. See [[layer-wiki]] and [[layer-schema]].
3. **Provenance.** Every claim points back at the bytes it came from, and the build fails when that mapping breaks. This is the property that most separates a compiler from a folder of notes; it is also the one the video does not specify, and this project's largest addition to the pattern. See [[source-attribution]].
4. **Navigability.** A machine can traverse the output by following structure rather than by similarity search — plain `[[links]]` resolved by string match, with no viewer or index server in the loop. See [[four-principles]].
5. **Packaging.** The result is a portable, verifiable artifact: a versioned bundle with a hash manifest and its own verifier inside, so a recipient confirms integrity offline.

### Where the analogy breaks

The middle of the pipeline is model judgment, not a deterministic transform. Reading a source and deciding which concepts it introduces produces defensible output, not identical bytes. So the guarantee is **not reproducible output — it is verifiable output**: determinism is scoped to the cache key, the [[synthesis-artifacts]], and the package manifest, while soundness is enforced by gates that fail the build when a citation stops resolving.

Two features also sit outside a strict compiler model, and are better named than hidden:

- **Query-time promotion.** `/wiki-query` may web-search on a gap and write the result back into `raw/` and `wiki/` mid-run. A compiler doesn't do that; a *package manager* does. A gap is an unresolved dependency, and resolving it is a build action subject to the same rules as any other acquisition. See [[query-as-write-loop]].
- **The viewer tier.** Flashcards, slides, diagrams, and graph views consume an already-built package; they are not build stages. That the output is human-readable as well as machine-navigable is a property of plain markdown, not a compromise.

### Why the framing matters

Organizing folders well is a claim about *operating* context. It leaves open who builds the folders and who keeps them true — which is tractable by hand at fifty files and not at five hundred sources. Naming the build layer separates two different products: the runtime that deploys and shares a package, and the compiler that produces one worth deploying. This project is the second. The value compounds because each ingested source is cross-referenced against everything already there (source: raw/karpathy-llm-wiki-video-transcript.md#15:10) — see [[knowledge-compounds]].

Full treatment, including the conformance table and the vocabulary mapping: `docs/CONTEXT-COMPILER.md`.

## Related

- [[three-layer-architecture]] — the compiler's source / output / recipe split
- [[problem-with-naive-rag]] — why the work moves to build time
- [[ingest-pipeline]] — the build step in detail
- [[source-attribution]] — the provenance property, mechanized
- [[query-as-write-loop]] — promotion framed as dependency resolution
- [[synthesis-artifacts]] — the deterministic, generated part of the output

## Open questions on this page

- Does the category need a conformance test suite that a *different* implementation could run, or is it only meaningful as a description of this one?
- Packaging is a shell script rather than a command surface. Should the emit stage be first-class in the schema, or does that re-introduce the monolithic exporter that `[[commands]]` deliberately rejected?
