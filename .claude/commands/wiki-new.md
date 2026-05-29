---
description: Generate a NEW wiki, domain-shaped from a one-line description, and register it in the workspace catalog. Factory command — run from the llm-wiki-bootstrap repo.
allowed-tools: Bash, Read, Write, Edit, Glob
argument-hint: <name> --domain "<description>" [--workspace <dir>] [--target <path>]
---

You are executing `/wiki-new $ARGUMENTS` from the `llm-wiki-bootstrap` **factory**. Your job is to create a brand-new wiki that is already shaped for a domain the user describes in one line — then register it in the local workspace catalog and mark it seeded.

This command is **factory-only**: it lives in this repo, not in the wikis it produces. It has two halves:

1. A **deterministic scaffold** (a shell script — do not reimplement it).
2. An **LLM authoring step** (you) that writes the domain's vocabulary and a few honest seed pages.

## Parse arguments

From `$ARGUMENTS`, extract:

- `<name>` — the first non-flag token. Must be a slug `[a-z0-9][a-z0-9-]*`. If the user gave a non-slug (spaces, capitals), propose a slugified version and ask before proceeding.
- `--domain "<description>"` — required. The one-line domain description. If missing, ask the user for it before doing anything.
- `--workspace <dir>` — optional; pass through verbatim if given.
- `--target <path>` — optional; pass through verbatim if given.

## Step 1 — Deterministic scaffold (shell, do not reimplement)

Run the scaffolder, passing through every flag the user gave:

```bash
scripts/new-wiki.sh <name> --domain "<description>" [--workspace <dir>] [--target <path>]
```

This copies the skeleton, `git init`s it, and appends a registry entry with `seeded:false`. **Read its output** — the `location:` line is the absolute path to the new wiki (call it `$WIKI`), and the `workspace:` line is the workspace root (call it `$WS`). You will write seed files under `$WIKI/` and later mark the entry seeded in `$WS`.

If the script fails (e.g. refuse-clobber), stop and surface the error — do not author anything.

## Step 2 — Author the domain layer (you)

Work entirely inside `$WIKI/`. Author, in this order:

### 2a. Domain conventions in the new wiki's `AGENTS.md`

**Append** (do not rewrite) a clearly-delimited section to `$WIKI/AGENTS.md`:

```markdown
## Domain conventions (<description>)

This wiki is shaped for: **<description>**.

- **Entity page-types here:** <2-4 kinds of named things in this domain, e.g. "organization, instrument, person">
- **Concept page-types here:** <2-4 kinds of ideas/terms, e.g. "strategy, policy, metric">
- **Suggested tags:** <5-8 kebab-case tags this domain will reuse>

These are conventions, not constraints — extend them as the wiki grows.
```

This is the new wiki's own `AGENTS.md` at creation time, so appending here is allowed. **Do not touch the factory repo's `AGENTS.md`.**

### 2b. A domain `wiki/index.md` (navigation)

Overwrite `$WIKI/wiki/index.md` with a `type: navigation` page that links **every** seed page you will create in 2c. Frontmatter must be complete.

### 2c. Three to five seed pages

Create 3–5 pages under `$WIKI/wiki/` (`<slug>.md`), each a `concept` or `entity` for this domain. Every seed page MUST follow the page template and these **hard rules** (the factory's oracle enforces them):

- Complete frontmatter: `title`, `type` (`concept`|`entity`), `source: analysis`, `updated: <today>`, `tags: [...]`.
- **Provenance honesty.** There is no raw source yet, so `source` is `analysis` and the body MUST contain an interpretive disclaimer, e.g. *"This page is interpretation, not extracted from a raw source."* Never write a `(source: raw/...)` citation — there are no raw sources.
- Sections: `## Definition / TL;DR`, `## Body`, `## Related`.
- `[[links]]` may point only to **other pages that exist** (other seeds or the index). No dangling links.
- Pure CommonMark. No Obsidian callouts/dataview/embeds.

**Reference shape for one seed page:**

```markdown
---
title: <Title Case>
type: concept
source: analysis
updated: <today>
tags: [<domain-tag>, concept]
---

# <Title>

## Definition / TL;DR
1–2 sentences defining the term for this domain.

## Body
This page is interpretation, not extracted from a raw source. <Domain-relevant explanation, with inline [[other-seed]] links to related seeds.>

## Related
- [[other-seed]] — why it relates
```

### 2d. (optional) A `wiki/glossary.md`

A short `type: navigation` or `type: concept` glossary is welcome if it helps, under the same rules.

## Step 3 — Mark seeded (shell)

```bash
scripts/registry.sh --workspace "$WS" mark-seeded <name>
```

## Step 4 — Log inside the new wiki

Append an entry to `$WIKI/log.md` (newest at top), e.g.:

```markdown
## <today> <time> — /wiki-new
- Domain: <description>
- Authored: wiki/index.md + <N> seed pages (<slugs>)
- Appended domain conventions to AGENTS.md
```

## Step 5 — Verify and report

Run the structural oracle and surface its result:

```bash
scripts/verify-multi-wiki.sh --seeded "$WIKI" --domain-term "<a salient word from the description>"
```

If any check is red, fix the offending page(s) and re-run until green. Then report:

```
/wiki-new complete — <name>

Location:  $WIKI
Workspace: $WS  (registered, seeded)
Domain:    <description>
Seeded:    wiki/index.md + <N> pages (<slugs>)
Oracle:    all checks green

Next:
  cd "$WIKI"
  # add real sources:  /wiki-extract <url-or-file>  then  /wiki-ingest
  # ask the wiki:       /wiki-query "..."
  # see the catalog:    /wiki-registry   (from the factory)
```

## What you must NOT do

- Reimplement the scaffold or the registry logic — always shell out to `scripts/new-wiki.sh` and `scripts/registry.sh`.
- Write anything under `$WIKI/raw/` — there are no sources yet (that's `/wiki-extract`'s job in the new wiki).
- Fabricate `(source: raw/...)` citations on seed pages. Seeds are `source: analysis`, full stop.
- Edit the **factory** repo's `AGENTS.md`, `wiki/`, or `raw/`. You only write inside the newly created `$WIKI/`.
- Use Obsidian-specific markdown. Pure CommonMark only.
