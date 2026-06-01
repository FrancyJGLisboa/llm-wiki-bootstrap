---
description: Learn from an interaction — distill a session into durable facts, gate them, capture as a raw source, and ingest into the wiki. The write half of a self-updating wiki brain.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [<transcript-file>] [--dry-run] [--scope-dir <path>]
---

You are executing `/wiki-learn $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to turn an **interaction** into wiki knowledge: distill the session into durable, novel facts, pass them through a notability gate, capture the kept ones as a raw source, and ingest them. This is the batched, session-end **write** half of a self-updating wiki brain — the read half is plain `/wiki-query`.

## Read first

**Run from the wiki root** (the directory with `raw/`, `wiki/`, `AGENTS.md`, `log.md`) — or, if `--scope-dir <path>` is given (per-user brains), treat that path as the wiki root for the whole run. If `AGENTS.md` is absent there, you are not in a wiki: tell the user to run `/wiki-init` first, then stop.

Read `wiki/index.md` (what already exists) so the gate's novelty check has context.

## Parse arguments

- `--dry-run` — if present, run steps 1–3 only and **report** the gate decisions without writing anything. Use this to inspect/tune the gate.
- `--scope-dir <path>` — optional wiki root override (per-user layout: `wikis/<user-id>/`).
- `<transcript-file>` — optional path to a saved transcript to learn from. If **omitted**, learn from the **current session conversation** (the turns you and the user just exchanged).

## Step 1 — Gather the transcript

If a `<transcript-file>` was given, read it. Otherwise use the current session: the user/assistant turns of this conversation. Number the turns so each candidate fact can cite the turn(s) it came from (`#turn-N`).

## Step 2 — Distill candidate facts

Extract atomic candidate facts from the transcript — durable statements, decisions, preferences, definitions, or entities. Drop task-scratch ("let's try X"), tool output, and conversational filler. Each candidate is one sentence + the turn anchor(s) it came from.

## Step 3 — Notability gate (keep only what's worth learning)

This gate is what keeps the brain getting **smarter** with use instead of bloating. A candidate is **kept only if ALL four hold**:

- **Durable** — still true/relevant next session (not ephemera, not this task's scratch state).
- **Novel** — not already entailed by an existing wiki page. Glob/grep `wiki/` to check; if a page already says it, drop it (or route to Step 5 as an *update*, not a new fact).
- **Attributable** — you can cite the specific turn(s) it came from.
- **In-scope** — about this wiki's domain (see `AGENTS.md` → Domain conventions) or the user's stable preferences.

Tag each kept candidate:

- **`preference`** — about the user (their choices, conventions, identity). High trust *as a preference*.
- **`factual`** — a verifiable claim about the world. Promote with its origin marked as **user-asserted**, never as authority — the citation makes this honest.

**Privacy.** Drop candidates that are sensitive personal/medical/financial details mentioned in passing unless the user clearly intends them remembered (mirrors `/wiki-query`'s promotion guard). In a **shared** brain (no `--scope-dir`, one wiki for everyone), also drop `preference`-tagged and any personally-identifying candidates — personal facts must not leak into a shared brain.

If `--dry-run`: report the candidates, each with its gate verdict (kept/dropped + which criterion failed) and tag, then **stop**. Write nothing.

## Step 4 — Capture the kept facts as a raw source

Write the kept candidates to a single raw source via the extract procedure (this is the sanctioned way to create a `raw/` file — see `AGENTS.md`; `/wiki-learn` never writes `wiki/` directly):

- Derive a session id and filename `raw/session-<YYYY-MM-DD>.md` (append `-2`, `-3`, … on collision with an existing session file for today).
- Structure the kept candidates so each is reachable by a **resolvable anchor** — the citation floor (`scripts/citation-audit.py`) only accepts an anchor that resolves to a heading slug, a `#L<n>` line range, or a `#M:SS` timestamp. Put each turn's facts under a `## turn-<N>` heading (its GitHub slug is `turn-<N>`), so the downstream citation `(source: raw/session-<date>.md#turn-N)` resolves. Run the inline-text extract with the interaction source type:

  ```
  /wiki-extract --text --title "Session <YYYY-MM-DD>" --source-type interaction <the kept candidates, grouped under per-turn headings>
  ```

  The captured body should read like:

  ```markdown
  ## turn-7
  (preference) Francy prefers uv over pip for Python.

  ## turn-12
  (factual) Resend free tier is 3000 emails/month.
  ```

  One `## turn-<N>` heading per turn that contributed a kept fact (group multiple facts from the same turn under one heading); the `(preference)` / `(factual)` tag is preserved inline so the ingest keeps the distinction.

## Step 5 — Ingest into the wiki

Run `/wiki-ingest raw/session-<YYYY-MM-DD>.md` to synthesize the captured facts into `wiki/` pages. The ingest pipeline already does the right thing here; hold it to these points:

- Every promoted claim cites the interaction it came from: `(source: raw/session-<date>.md#turn-N)`.
- **Contradictions** — when a new fact disagrees with an existing page, apply **latest-wins-with-trail**: update the page to the new claim **and** preserve the superseded one with the existing flag format so nothing is silently lost:

  ```markdown
  > CONTRADICTION FLAGGED YYYY-MM-DD: session now says <new>. Supersedes earlier <old> (source: raw/session-<date>.md#turn-N).
  ```

  Never create a duplicate page for a fact that contradicts an existing one — update + flag the existing page. In a **shared** brain, do not pick a winner across different users' claims: flag and attribute both, leave for review.

## What you must NOT do

- Write to `wiki/` directly. Synthesis goes through `/wiki-ingest`; capture goes through `/wiki-extract`.
- Edit existing files in `raw/` (you only *create* a new `raw/session-*.md`; the `ingested_*` frontmatter is `/wiki-ingest`'s job).
- Promote chatter, task-scratch, or anything that fails any one of the four gate criteria. When in doubt, drop it — a smaller true brain beats a bloated noisy one.
- Promote sensitive personal details without clear intent, or leak `preference`/PII into a **shared** brain.
- Skip the gate to "capture everything" — the gate is the point.

## Output

```
/wiki-learn complete[ — dry run].

Scope:      <wiki root> (<shared | per-user wikis/<id>>)
Distilled:  <C> candidates from <T> turns
Gate:       <K> kept (<P> preference, <F> factual), <D> dropped
Captured:   raw/session-<date>.md         (skipped on dry run)
Ingested:   wiki/<file> (new), wiki/<file> (updated)   (skipped on dry run)
Contradictions: none | <n> flagged (latest-wins-with-trail)

Next: /wiki-query "<something the session taught>"  to confirm the brain learned it.
      /wiki-lint  to review any flagged contradictions.
```
