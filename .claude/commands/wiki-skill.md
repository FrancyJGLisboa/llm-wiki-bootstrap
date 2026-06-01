---
description: Generate a NEW self-updating wiki SKILL — a domain-shaped llm-wiki wrapped as an agent skill that answers from the wiki and learns from each interaction. Factory command — run from the llm-wiki-bootstrap repo.
allowed-tools: Bash, Read, Write, Edit, Glob
argument-hint: <name> --domain "<description>" [--scope per-user|shared] [--workspace <dir>] [--target <path>]
---

You are executing `/wiki-skill $ARGUMENTS` from the `llm-wiki-bootstrap` **factory**. Your job is to produce a **self-updating wiki skill**: a domain-shaped llm-wiki (the brain) wrapped with a `SKILL.md` operating procedure so any agent can answer *from* the wiki and learn *into* it via `/wiki-learn`.

This command is **factory-only** (it lives in this repo, not in the wikis it produces). It is `/wiki-new` plus one extra artifact — the `SKILL.md`. Do not re-implement the wiki creation; reuse it.

## Parse arguments

- `<name>` — first non-flag token; a slug `[a-z0-9][a-z0-9-]*`. Propose a slugified form and ask if the user gave a non-slug.
- `--domain "<description>"` — **required**. If missing, ask before doing anything.
- `--scope per-user|shared` — optional; **default `per-user`** (privacy-safe). Validate the value; reject anything else.
- `--workspace <dir>` / `--target <path>` — optional; pass through verbatim to the scaffolder.

## Step 1 — Create the seeded domain wiki (reuse `/wiki-new`)

Produce a seeded, registered domain wiki **exactly as `/wiki-new` does** — read `.claude/commands/wiki-new.md` and follow its Steps 1–4 verbatim (run `scripts/new-wiki.sh <name> --domain "<description>" [--workspace …] [--target …]`, capture `$WIKI` and `$WS` from its output, author the domain `AGENTS.md` conventions + `wiki/index.md` + 3–5 honest seed pages, then `scripts/registry.sh --workspace "$WS" mark-seeded <name>` and log inside the wiki). **Do not duplicate that logic here** — `/wiki-new` is the single source of truth for domain authoring.

The generated wiki already ships `/wiki-learn` and `/wiki-query` (they are in the installer manifest), so the brain is loop-ready the moment the wiki exists.

## Step 2 — Stamp the SKILL.md (the wrapper)

Read the template `templates/skill/SKILL.md` and write `$WIKI/SKILL.md` from it, substituting:

- `{{NAME}}` → `<name>`
- `{{DOMAIN}}` → the `--domain` description
- `{{SCOPE}}` → `per-user` or `shared`
- `{{TRIGGERS}}` → 3–6 short, natural activation phrases a user of this domain would say (derive from the domain description; comma-separated)

Then resolve the two scope blocks: **keep** the `<!-- SCOPE:<chosen> -->…<!-- /SCOPE:<chosen> -->` block matching the chosen scope and **delete** the other block entirely (including its comment markers). Leave the kept block's content as plain prose (strip its `<!-- SCOPE:… -->` markers too).

For `--scope per-user`: the root wiki you just seeded is the **seed/template** brain. The `SKILL.md` already documents that per-user brains live at `wikis/<user-id>/` (created by copying the seed wiki root on first contact) — you do not need to create any user directory now; the seed is the template.

## Step 3 — Log inside the wiki

Append to `$WIKI/log.md` (newest at top):

```markdown
## YYYY-MM-DD HH:MM — /wiki-skill
- Wrapped as self-updating wiki skill (scope: <per-user|shared>)
- Authored: SKILL.md (read=/wiki-query --no-promote, write=/wiki-learn)
```

## Step 4 — Verify and report

Run the structural oracle (the wiki half must be valid):

```bash
scripts/verify-multi-wiki.sh --seeded "$WIKI" --domain-term "<a salient word from the description>"
```

Then confirm `$WIKI/SKILL.md` exists, its frontmatter `name`/`description` are non-empty, only one scope block remains, and no `{{…}}` placeholders survive. Fix and re-run until green, then report:

```
/wiki-skill complete — <name>-brain

Location:  $WIKI
Workspace: $WS  (registered, seeded)
Domain:    <description>
Scope:     <per-user|shared>
Skill:     SKILL.md authored (read=/wiki-query --no-promote, write=/wiki-learn)
Oracle:    all checks green

Next:
  cd "$WIKI"
  # seed real knowledge:  /wiki-extract <url-or-file>  then  /wiki-ingest
  # use the brain:        /wiki-query "..."   (read)
  # teach it a session:   /wiki-learn         (write, at session end)
```

## What you must NOT do

- Re-implement `/wiki-new`'s scaffold or seed-authoring — delegate to it (Step 1).
- Leave any `{{placeholder}}` or both scope blocks in the final `SKILL.md`.
- Write under `$WIKI/raw/` (no sources yet — that's `/wiki-extract`'s job).
- Edit the **factory** repo's `AGENTS.md`, `wiki/`, `raw/`, or this template. You only write inside the newly created `$WIKI/`.
- Use Obsidian-specific markdown. Pure CommonMark only.
