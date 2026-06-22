# Selling a wiki — the productized second brain

A wiki built here is a folder of pure CommonMark with provenance. That makes it
a *transferable asset*: you can package it, version it, and sell it to someone
who will query and extend it with their own AI tool. No hosting, no service, no
account — the buyer's own subscription does the reasoning.

This page is the recipe: what makes a wiki sellable, how to structure it, how
to package it, and the one legal rule that is not optional.

## What the buyer is actually buying

Not the markdown — markdown is trivially copied, like an ebook. They are buying:

1. **Your curation** — which sources made the cut, and your synthesis of them.
2. **Provenance with receipts** — every claim cites a raw source the buyer can
   open; `./scripts/verify-bundle.sh` proves **citation integrity**: the bundle
   is intact, every citation resolves to a real raw anchor, and every
   claim-bearing page is sourced. (It does not re-prove semantic entailment —
   that each cited passage truly supports its claim. That C3 check needs an LLM
   and is a write-time guarantee the seller attests to, not reproduced offline.)
   No PDF course or Notion template ships verifiable provenance.
3. **The update stream** — your wiki keeps compounding; theirs goes stale.
   Recurring revenue lives here, not in the artifact (see "Distribution").

Price on reputation and updates. Do not bother with DRM; the moat is you.

## The legal rule (not optional)

**`raw/` must contain only content you have the right to redistribute.**

A personal wiki may ingest anything you can legally read. A *sold* wiki
redistributes its raw layer verbatim — third-party articles, others' tutorials,
or paywalled material in `raw/` makes the bundle copyright infringement.

The clean pattern, which is also the strongest product: your raw layer is your
own work product — your tested prompts, your benchmark runs, your tutorials,
your notes. That is literally what "selling your expertise" means here.
Aggregations of other people's content are both legally radioactive and
worthless as a product (the buyer could collect those links for free).

`scripts/package-wiki.sh` reminds you of this at every run. It cannot check it
for you. This is the human judgment in the loop.

## Recipe: a "working prompts & tutorials" wiki

The schema layer is per-wiki: your wiki's `AGENTS.md` is yours to extend. For a
catalog of coding tutorials and prompts that demonstrably work, add required
frontmatter to your page template:

```yaml
---
title: Structured Extraction From Invoices
type: concept
source: analysis
updated: 2026-06-10
tags: [prompts, extraction]
language: python            # what the code targets
assisted_by: claude-fable-5 # the model the prompt was developed/verified on
verified_on: 2026-06-08     # when it last demonstrably worked
status: working             # working | broken-since-<date> | unverified
---
```

Why these fields earn their keep:

- `assisted_by` + `verified_on` make **model-version rot inspectable**. Prompts
  are model-sensitive; a buyer can see at a glance that a page was verified on
  the model they use, this quarter — instead of discovering staleness in
  production. `/wiki-lint` already hunts stale claims; dated fields give it
  teeth.
- `status` makes honesty cheap. A page marked `broken-since-2026-05` is more
  credible than a catalog where everything silently "works".
- Evidence beats assertion: keep the actual transcript/output of the prompt
  *working* as a raw source, and cite it —
  `(source: raw/extraction-prompt-run-2026-06-08.md#output)`. "Actually works"
  becomes a checkable claim, in the same provenance discipline as everything
  else.

Organize navigation by the axes buyers shop on: an index page per `language`,
a page per `assisted_by` model family, cross-linked with `[[...]]` as usual.
The knowledge graph and dashboards regenerate mechanically.

## Packaging

```bash
./scripts/package-wiki.sh                      # this wiki → dist/<name>-v<date>.tar.gz
./scripts/package-wiki.sh ~/my-wiki --version v1.2.0
```

Packaging is gated — it **refuses** to ship a wiki that fails its own checks:
malformed raw frontmatter (G1), wiki pages missing required keys (G2), any
citation that does not resolve (G3), or any claim-bearing page that carries no
citation (G4 — coverage; a wiki of uncited claims would otherwise package
clean). A bundle that packages is a bundle whose provenance a buyer cannot
trivially break.

The bundle contains the knowledge asset (`raw/`, `wiki/`, `AGENTS.md`,
`log.md`), the slash commands and runtime scripts the buyer needs, a generated
`BUYER-README.md`, a `LICENSE` stub if you ship none (**fill it in**), and a
`MANIFEST` with a SHA-256 per file. It is built from an include list — your
git history, sessions, inbox, and env files cannot leak into it.

The buyer verifies with zero infrastructure:

```bash
./scripts/verify-bundle.sh             # pristine bundle: integrity + citation integrity
./scripts/verify-bundle.sh --post-use  # after they extend it: original files still intact
```

This proves **citation integrity**, not semantic faithfulness: the bundle is
intact, citations resolve, and every claim-bearing page is sourced. It does not
re-run the C3 entailment judge (that each passage supports its claim) — that
needs an LLM and is your write-time attestation, not something the buyer
reproduces offline.

Authenticity is opt-in. By default a bundle is **unsigned** — its MANIFEST
proves "intact since packaging", not "genuinely from you" (tamper + regenerate
the MANIFEST is undetectable). To sign, package with a gpg key id in
`WIKI_SIGN_KEY`; packaging then bundles `MANIFEST.sig` + `MANIFEST.pubkey`, and
`verify-bundle.sh` checks the signature automatically:

```bash
WIKI_SIGN_KEY=<your-gpg-id> ./scripts/package-wiki.sh
```

(The bundled public key is trust-on-first-use, not a chain of trust — it proves
the MANIFEST was signed by whoever holds that key, which the buyer cross-checks
against your published fingerprint. You can also sign the tarball itself:
`gpg --detach-sign dist/<bundle>.tar.gz`.)

## Distribution patterns

- **One-shot**: sell the tarball (Gumroad, Lemon Squeezy). Simple; no updates.
- **Subscription = a private git repo.** Grant buyers read access; every
  `git pull` is the product improving. This is the natural recurring model and
  it needs no new tooling — the wiki is already a repo. Tag releases
  (`git tag -s v1.3.0`) so buyers can pin or audit what changed.
- **Updates as new bundles**: re-run `package-wiki.sh --version vX.Y.Z` per
  release; buyers re-verify each one against its own MANIFEST.

What deliberately does not exist here: payments, DRM, access control, a
marketplace. The artifact layer stays open and verifiable; commerce rails
belong to whatever storefront you choose.
