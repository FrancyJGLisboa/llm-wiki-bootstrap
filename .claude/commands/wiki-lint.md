---
description: Health-check the wiki. Find broken links, orphans, contradictions, stale claims, unresolved open questions, and gaps.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [--apply]
---

You are executing `/wiki-lint $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to find problems in the wiki and either report them or fix them, depending on the `--apply` flag.

## Read first

**Run from the wiki root** (the directory with `raw/`, `wiki/`, `AGENTS.md`, `log.md`). If `AGENTS.md` is absent, you're not in a wiki: tell the user to run `/wiki-init` first (or `cd` into their wiki), then stop.

Read `AGENTS.md` (the conventions you're enforcing). Glob `wiki/` to list all pages.

## Mode

- Default (no `--apply`): **report only**. Print a structured list of issues. Do not modify any file.
- `--apply` in `$ARGUMENTS`: **propose fixes** with diffs, then ask the user "Apply these N fixes? [Y/n]". If yes, write them.

## Checks to run

### 1. Broken wiki-links

For every `[[<name>]]` reference in every page in `wiki/`, verify that `wiki/<name>.md` exists.

- Report: `wiki/<page>.md: broken link [[<name>]]`.
- Fix proposal (if `--apply`): either remove the link, or create a stub page `wiki/<name>.md` with a TODO body, depending on whether the linked concept appears in other pages.

### 2. Orphans

For every page in `wiki/`, check whether any other page links to it (excluding `wiki/index.md`).

- Report: `wiki/<page>.md: no inbound links from other wiki pages`.
- Fix proposal: either add it to `wiki/index.md`, link from a relevant page, or propose deletion (`--apply` only deletes if the user confirms).

### 3. Contradictions

Scan every page in `wiki/` for the literal token `CONTRADICTION FLAGGED` left by previous `/wiki-ingest` runs. The producer format (see `/wiki-ingest` step 5) is a blockquote line:

```
> CONTRADICTION FLAGGED YYYY-MM-DD: <description>. Contradicts [[other-page]], which says <claim>.
```

Match it mechanically with `grep -rn 'CONTRADICTION FLAGGED' wiki/` (the token is the stable contract; the date and prose vary).

- Report each one: file, line, the date, and the `[[other-page]]` it references. Suggest a resolution path (which claim is older? which has a stronger source? does a web search help?).
- Do not auto-resolve. The user decides.

### 4. Stale claims

For pages with `updated:` older than 90 days AND claims that look time-sensitive (dates, version numbers, dollar amounts, named events), surface them.

- Report: `wiki/<page>.md: time-sensitive claims, last updated <date>`.
- Fix proposal: re-run `/wiki-ingest` on the raw source if available; otherwise suggest a `/wiki-query` to refresh.

### 5. Unresolved open questions

For each page, parse the `## Open questions on this page` section.

- Report the questions, grouped by page.
- Fix proposal (if `--apply`): for any question where you can confidently answer from current wiki + web search, answer it inline (move the answer into the relevant body section, remove the question).

### 6. Gaps

Look for concepts referenced multiple times across the wiki **without their own page**. These are candidate page creations.

- Report: `concept "<X>" referenced in <N> pages, no dedicated page exists`.
- Fix proposal: create the page (using web search if needed to populate it).

### 7. Schema drift

Verify every wiki page has:
- Valid YAML frontmatter
- All required fields (`title`, `type`, `source`, `updated`, `tags`)
- A `Related` section with ≥ 2 `[[wiki-links]]` (so the page joins the web) — **except** `navigation` pages (e.g. `index.md`) and `journal` entries, which join the web through their body/index structure and need no `## Related` section
- An `Open questions on this page` section (may be empty list)

Verify links use `[[kebab-case]]` form (not `[[Title Case]]` or path-relative).

- Report violations.
- Fix proposal: normalize.

### 8. Near-duplicate pages

Surface pages that say the same thing in different words — the bloat a
self-updating brain accumulates when `/wiki-learn`'s novelty gate (a grep) misses
a paraphrase from a later session. Run the deterministic detector:

```bash
scripts/wiki-near-duplicates.py wiki/
```

It flags pairs by lexical overlap (Jaccard of content words ≥ threshold) and by a
structural signal (identical `[[link]]` set + identical numbers). The threshold is
a heuristic — pass `--threshold` to tune.

- Report each pair: `wiki/<a>.md <-> wiki/<b>.md (why)`.
- Do **not** auto-merge (like contradictions, merging is a judgment call). Suggest
  a merge path: keep the richer page, fold in unique claims from the other with
  their citations, redirect inbound `[[links]]`, then delete the thinner page
  (`--apply` only deletes on user confirm). The user decides.

If `scripts/wiki-near-duplicates.py` is absent (an older generated wiki), skip
this check.

## Output (report mode)

```
/wiki-lint report — YYYY-MM-DD HH:MM

# Summary
- N broken links
- N orphan pages
- N contradictions
- N stale claims
- N unresolved open questions
- N gaps
- N schema-drift issues
- N near-duplicate page pairs

# Details
[grouped output by check]

Run /wiki-lint --apply to propose fixes.
```

## Output (`--apply` mode)

```
/wiki-lint proposed fixes — YYYY-MM-DD HH:MM

[list of proposed diffs / actions]

Apply N fixes? [Y/n]
```

After user confirms, write the fixes. Append to `log.md`:

```markdown
## YYYY-MM-DD HH:MM — /wiki-lint --apply

- Fixed N broken links: <list>
- Removed N orphan pages: <list>
- Resolved N open questions in: <list>
- Added N gap pages: <list>
```

## What you must NOT do

- Auto-apply without `--apply` AND user confirmation.
- Modify `raw/`.
- Silently delete pages. Always confirm.
- Make up "fixes" for contradictions — the user resolves those.
- Use Obsidian-specific syntax in any page you touch.
