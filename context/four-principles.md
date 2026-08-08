---
title: The Four Principles
type: concept
source: video
updated: 2026-05-25
tags: [foundations, philosophy, principles]
---

# The Four Principles

## Definition / TL;DR

LLM-wikis stay valuable because they're (1) **explicit**, (2) **yours**, (3) **file-over-app**, and (4) **bring-your-own-AI**. These four properties are what distinguishes the pattern from alternatives like opaque memory systems, vendor-hosted notebooks, or proprietary knowledge stores.

## Body

From the video: *"This is why this approach wins, and there are four principles behind it that make it really compelling."* `(source: raw/karpathy-llm-wiki-video-transcript.md#6:25)`

### 1. Explicit

*"The knowledge is all visible in a navigable wiki which most of us are familiar with. You can see exactly what the AI knows and what it doesn't know. There's no hidden embeddings. There's no opaque memory system."* `(source: raw/karpathy-llm-wiki-video-transcript.md#6:25)`

Implication: every claim is auditable. If the LLM says X, you can find the wiki page that says X and the raw source it cites. No vector-store mystery. No "the model just remembers."

### 2. Yours

*"You can customize it yourself. These are all local files on your computer. You're not locked into any provider's system and you keep everything yourself."* `(source: raw/karpathy-llm-wiki-video-transcript.md#6:25)`

Implication: portability. The wiki survives if you switch LLM providers, change tools, lose internet. The user is the storage operator.

### 3. File-over-app

*"Everything is in universal formats — markdown and images. This means it's interoperable with any tool, any CLI, any viewer. The entire Unix toolkit works on your data."* `(source: raw/karpathy-llm-wiki-video-transcript.md#6:25)`

Implication: tooling is decoupled from data. `grep`, `git`, `find`, any markdown viewer, any editor — all work natively. You're not negotiating with a SaaS API for access to your own notes. See [[implicit-constraints]] for how this project honors the principle (no Obsidian dependency).

### 4. Bring your own AI

*"You can plug in Claude, GPT, Codex, open-source models, whatever you want. You can even fine-tune a model on your wiki so it knows your data in its weights, not just in its context."* `(source: raw/karpathy-llm-wiki-video-transcript.md#6:25)`

Implication: the wiki survives model churn. A new SOTA model next year? Plug it in. Self-hosting concerns? Use a local model. The pattern is model-agnostic by construction.

### Why these four together

Each addresses a way prior knowledge-base patterns have failed:

- Without **explicit**, you get vendor-flavored "memory" you can't audit.
- Without **yours**, the data is hostage to a service.
- Without **file-over-app**, you have a closed ecosystem disguised as a knowledge tool.
- Without **BYO AI**, you're locked to whichever model the vendor ships today.

## Related

- [[core-idea]] — what these principles are properties of
- [[knowledge-compounds]] — what these principles together enable
- [[layer-wiki]] — markdown files implement #3
- [[layer-schema]] — `AGENTS.md` implements #2 + #3 (yours, file-over-app) by being cross-tool
- [[implicit-constraints]] — how this project enforces these (e.g., no viewer dependency for #3)

## Open questions on this page

- Which principle does this project violate most, if any? (`AGENTS.md` naming is "yours-flavored" but mildly conventional — could in principle be renamed.)
- Are there hidden 5th and 6th principles the video skipped? (E.g., "incremental" — knowledge grows source-by-source, not in one upload?)
- How do these principles interact? E.g., *yours* and *BYO AI* compound: you can switch model AND data location independently.
