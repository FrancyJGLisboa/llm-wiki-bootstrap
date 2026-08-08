---
description: Inventory and triage the rules in a repository or a compiled context — list candidates evidenced by the material, classify each deterministic / heuristic / unverifiable, and stop. Writes no code.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: [--scan-repo | --scan-context] [--class deterministic|heuristic|unverifiable]
---

Inventory and triage rules. This is `docs/deterministic-gates.md` §2 and §3 as a
command.

**You do not write code in this command.** Not a gate, not a script, not a
fixture. The output is a list and a classification, and then you stop. Building
a gate is `/ctx-gate <RULE-ID>`, which is separate because a gate only becomes
real once it has failed on a violating fixture — and that proof cannot be
skipped by an eager step that already wrote the script.

## Mode

Parse `$ARGUMENTS`:

- `--scan-repo` (default when `raw/` is empty or absent) — mine the surrounding
  codebase and its git history for rules that already exist implicitly.
- `--scan-context` (default when a compiled `wiki/` exists) — mine the compiled
  context for rules that were filed as prose and never gated.
- `--class <c>` — restrict the report to one class.

## Step 1 — Inventory (§2)

Collect candidate rules **evidenced by the material**. The evidence requirement
is the entire point of this step, so hold it strictly:

- patterns already enforced somewhere in the code
- repeated fixes in the git history (`git log --oneline | grep -iE '^\w+ fix'`,
  then look for the same subject recurring)
- warning comments — `# never`, `# do not`, `# must`, `# careful`, `WARNING`
- things that have already broken: reverts, hotfixes, post-mortems in commit
  bodies
- for `--scan-context`: every `wiki/rules/**` page, plus prose in any page that
  states an obligation (`must`, `never`, `only if`, `no later than`)

**Do not include generic best practices you happen to know.** "Functions should
be small", "always validate input", "prefer composition" — none of these belong
here unless this specific repository shows evidence of them. A candidate with no
file, commit, or line reference is dropped, not softened.

Emit exactly one line per candidate:

```
rule | evidence (file/commit) | violation frequency | cost if it slips (silent|loud)
```

**Sort by cost of the SILENT failure, descending.** A rule whose violation
crashes loudly already has a natural gate — the user notices. The dangerous ones
are those that pass CI, ship, and are discovered later by someone reading the
output and believing it.

Then **stop and show the list.** Do not proceed to step 2 in the same breath —
the list is a decision point for the user, not a formality on the way to
writing code.

## Step 2 — Triage (§3)

For each rule the user keeps, classify it and say why:

- **DETERMINISTIC** — a parser, schema, or command with an exit code can settle
  it. **Write out the exact detection mechanism.** If you cannot state the
  mechanism in one line, it is not deterministic yet; say so rather than
  promising a gate that will not materialise.
- **HEURISTIC** — needs judgement. Goes into a reviewer's rulebook, not a
  script.
- **UNVERIFIABLE** — cannot be checked, even in principle. Discard it
  explicitly. Do not pretend.

Two hard constraints:

- **A script that calls an LLM is not deterministic.** It is a heuristic in a
  script costume. It cannot ratchet, because it may answer differently on the
  same input tomorrow. Classify by what settles the question, not by what the
  check is written in.
- **Prefer a parser over a regex.** If you use a regex anyway, write down which
  cases it gets wrong — that text becomes the rule's `known_gaps`.

## Step 3 — File the rules

Offer to write a `wiki/rules/<class>/RULE-<NNNN>-<slug>.md` page per surviving
rule, following the frontmatter spec in `AGENTS.md` → "Rules and executable
context". On confirmation:

- allocate ids by incrementing the highest existing `RULE-NNNN`; never reuse one
- set `gate: none` on every page, including deterministic ones
- cite the evidence — for `--scan-repo` the evidence is a file or commit, so use
  a normal markdown reference; a `(source: raw/...)` citation applies only when
  the rule came from an ingested document
- unverifiable rules go to `wiki/rules/discarded/` with a `discard_reason`
- append a `log.md` entry naming the counts per class

Then print, for each deterministic rule with no gate:

```
RULE-0007 is deterministic and ungated — build it with:  /ctx-gate RULE-0007
```

## Output

```
/ctx-rules — <mode> — YYYY-MM-DD HH:MM

# Candidates (sorted by cost of silent failure)
<the table>

# Triage
DETERMINISTIC  <n>   (each with its detection mechanism)
HEURISTIC      <n>
UNVERIFIABLE   <n>   (discarded, with reasons)

# Filed
<paths written, or "nothing — inventory only">

# Next
<the /ctx-gate lines, or "no ungated deterministic rules">
```

## What you must NOT do

- Write a gate, a script, or a fixture. That is `/ctx-gate`.
- List a rule you cannot tie to a file, a commit, or a cited passage.
- Classify something as DETERMINISTIC without stating its detection mechanism.
- Call an LLM-based check deterministic.
- Quietly drop an unverifiable rule instead of recording it as discarded.
- Set `gate:` to anything but `none` — you have not proven a gate here.
