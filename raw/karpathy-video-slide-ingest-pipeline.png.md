---
source_url: n/a
source_type: image
source_title: "Slide: What happens when you ingest a source (Deep Dive)"
source_author: third-party YouTube creator (not Karpathy)
fetched_at: 2026-05-25
ingested_hash: "cfe8e91ada2df4764ca68650feb585d570ea6b2cc8152f82e8f1c4fc34443424"
ingested_at: 2026-05-25 08:30
ingested_pages:
  - wiki/karpathy-video-slide-ingest-pipeline-summary.md
  - wiki/ingest-pipeline.md
  - wiki/source-attribution.md
  - wiki/index.md
extraction_method: llm-vision
notes: |
  Vision-extracted sidecar for the binary at the same path with `.png` instead
  of `.png.md`. The slide was shared by the user as a screenshot from the same
  source video as `karpathy-llm-wiki-video-transcript.md`. It corresponds to
  the spoken "What happens when you ingest a source" section (around
  4:46-5:30 in the transcript).

  Adding this as a second raw source dogfoods the image-acquisition convention
  (binary + sidecar). It also adds two pieces of information not in the
  transcript verbatim: (a) the slide-mandated file names `index.md` and
  `log.md`, (b) step 6's explicit mention of a one-line summary in the index
  entry.
---

# Slide — "What happens when you ingest a source"

## Header

**DEEP DIVE**
**What happens when you ingest a source**

## Body (verbatim, numbered 01–07)

- **01 LLM reads the raw source** — article, paper, transcript, dataset
- **02 Extracts key information** — concepts, entities, claims, data points
- **03 Writes a summary page** in the wiki with metadata and tags
- **04 Updates entity & concept pages** — new info integrated into existing knowledge
- **05 Flags contradictions** where new data conflicts with existing claims
- **06 Updates `index.md`** — catalog entry with link and one-line summary
- **07 Appends to `log.md`** — timestamped record of what changed

Footer hint: `→ or click to navigate`

## Visual description

Dark-blue background, white serif heading "What happens when you ingest a source," small "DEEP DIVE" eyebrow label above. Seven left-aligned numbered items (01–07) in light gray with the first ~3 words of each line in white-bold, the remainder in slightly muted gray. Clean slide deck aesthetic — no charts, no diagrams. The page-name styling (`index.md`, `log.md`) is rendered as inline code, which makes them prescriptive about file naming.

## Differences vs the transcript at the same timestamp

- Transcript says generically "updates the index, the master catalog of everything in the wiki" → slide says specifically `index.md` and "catalog entry with link and **one-line summary**." Both are consistent; the slide is more prescriptive.
- Transcript says "appends to the log — a timestamped record" → slide says specifically `log.md`. **Filename divergence vs. this project's `CHANGELOG.md` is resolved by renaming to `log.md` (decision: align with the source video).**
- Transcript and slide agree on steps 1-5 verbatim.
