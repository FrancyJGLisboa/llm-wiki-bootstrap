---
description: Turn a deterministic rule into an executable gate — full contract, committed fixtures, a five-way mutation proof, and three declared blind spots — then wire it into CI and the ratchet.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: <RULE-ID> [--dry-run]
---

Build the gate for `$ARGUMENTS`. This is `docs/deterministic-gates.md` §4 and §5
as a command.

**The governing principle:** never accept the claim that a gate works — produce
the artifact. You are not finished when the gate exists. You are finished when
you have pasted terminal output showing it FAIL on a fixture that violates the
rule and PASS on a clean one. Without both outputs the task is not complete, no
matter how correct the script looks.

## Step 0 — Refuse if this is not a gateable rule

Read `wiki/rules/**/$1*.md`. Stop, and say why, if any of these hold:

- **The page does not exist.** Nothing authorises this gate. Run `/ctx-rules`
  first.
- **`rule_class` is not `deterministic`.** A heuristic rule belongs in a
  reviewer's rulebook. Writing a script for it produces a gate that is
  confidently wrong on the cases that matter.
- **The detection would need an LLM call.** This is the one refusal that is not
  negotiable. A script that asks a model whether the rule holds is a heuristic
  in a script costume: it can answer differently on the same input tomorrow, so
  it cannot ratchet, and its green is not evidence of anything. Say so plainly
  and reclassify the rule as `heuristic`.
- **`detection` is empty or states an intention rather than a mechanism.**
  "Check the dates are right" is not a mechanism. Fix the rule page first.

`--dry-run` stops after step 1.

## Step 1 — State the contract in full

Restate all eight clauses from `docs/deterministic-gates.md` §4, filling any the
rule page leaves blank. Do not write code until every one is answered:

1. **rule id** and a one-sentence statement of the rule
2. **detection mechanism** — prefer a parser over a regex. If you use a regex,
   write down which cases it gets wrong; that text is the start of `known_gaps`.
3. **scope** — which files are in, which are out, **and why each exclusion
   exists**. Exclusions cost: each one counts as a suppression in the ratchet.
4. **exit codes** — `0` compliant, `1` violation, `2` the gate itself failed.
   Never collapse `2` into `0`.
5. **failure output** — `path:line`, the rule id, and how to fix it. A gate that
   says only "violation" gets suppressed; one that says what to do gets obeyed.
6. **fixtures** — one file that VIOLATES (must exit 1), one CLEAN (must exit 0)
7. **target runtime** — and every external dependency, each of which is `gate_die`
   (exit 2) when missing
8. **wiring point** — hook, pre-commit, or CI

## Step 2 — Scaffold

```bash
bash scripts/new-gate.sh <RULE-ID>
```

Writes `gates/<RULE-ID>.sh` from `templates/gate/gate.sh.tmpl` (which already
sources `scripts/lib/gate-lib.sh`, wires exit 0/1/2, supports `--count` for the
ratchet, and fails loudly when its scope matches zero files), plus the fixture
directory `gates/fixtures/<RULE-ID>/`.

Fill in the detection. Two things the template will not do for you:

- **Report every violation, not the first.** A gate that stops at one finding
  makes fixing a batch an N-run loop.
- **Never let an empty scope pass.** A glob matching nothing is
  indistinguishable from universal compliance and is the most common way a gate
  quietly stops working. The template's `checked` counter guards this — keep it.

## Step 3 — Prove it (§5) — this is the step that cannot be skipped

1. **Break the rule five different ways, including two edge cases.** Paste the
   gate's actual output catching each one. Not a description of the output —
   the output.
2. **Run it against the whole repository** and report how many real violations
   exist. That number becomes the gate's baseline row.
3. **List three ways to violate the rule that this gate does NOT catch.** If you
   cannot think of any, you have not understood the problem space — think again.
   Every gate has blind spots; a gate whose author cannot name them is a gate
   whose author has only confirmed that it passes. Write these into the rule
   page's `known_gaps` and the script's FAILURE MODES header.
4. **Revert every mutation.** Confirm with `git status` that the tree is clean
   apart from the new gate and its fixtures.

Then prove both directions explicitly:

```bash
bash gates/<RULE-ID>.sh gates/fixtures/<RULE-ID>/violating.<ext>   # must be exactly 1
bash gates/<RULE-ID>.sh gates/fixtures/<RULE-ID>/clean.<ext>       # must be exactly 0
```

**Exactly 1, not merely non-zero.** Exit 2 means the gate itself broke; a check
that accepts any non-zero would read that as a successful catch.

## Step 4 — Wire it

- Add a row to `gates/baseline.tsv` with the **real** violation count from step
  3.2 as the starting number. Recording 0 when the repo has 12 makes the gate
  red on arrival and it will be disabled by lunchtime; recording the true count
  means the rule holds from here on without demanding the past be fixed first.
- Add the fixture invocations to `scripts/gate-fixtures.tsv`, or leave them at
  `gates/fixtures/<RULE-ID>/` for the convention-based discovery.
- Wire the gate into CI so it actually fires — an unwired gate reads as coverage
  and never does anything. In the bootstrap repo that means adding it to
  `scripts/smoke-all.sh` as the next `R<n>`; `scripts/gate-reachable.sh` is what
  proves it. Neither script ships to a generated compiler, so in a generated
  compiler wire the gate into whatever runs your checks and skip the reachability
  proof — do not report this step as done when the scripts are absent.
- Verify the whole set still holds:

```bash
bash scripts/gate-fixtures.sh    # every gate still discriminates
bash scripts/gate-ratchet.sh     # nothing went up; this gate is registered
# bootstrap repo only — absent in a generated compiler:
[ -f scripts/gate-reachable.sh ] && bash scripts/gate-reachable.sh
```

## Step 5 — Close the loop on the rule page

Set `gate: gates/<RULE-ID>.sh`, `fixtures:`, `wiring:`, and the three-plus
`known_gaps` from step 3.3. Append a `log.md` entry naming the rule, the gate,
and the real violation count recorded in the baseline.

`/ctx-lint` should now report `R-01` clear for this rule.

## Output

```
/ctx-gate <RULE-ID> — YYYY-MM-DD HH:MM

# Contract
<the eight clauses>

# Mutation proof
<5 mutations, each with the gate's pasted output>
Repository scan: <n> real violation(s)

# Known gaps (declared, not discovered)
1. ... 2. ... 3. ...

# Wiring
gates/<RULE-ID>.sh · baseline row <n>/<s> · smoke-all.sh R<n>
gate-fixtures: <result>  gate-ratchet: <result>  gate-reachable: <result>
```

## What you must NOT do

- Claim the gate works without pasting both fixture outputs.
- Write a gate for a `heuristic` or `unverifiable` rule.
- Write a gate that calls an LLM and present it as deterministic.
- Let exit 2 collapse into 0, or accept "non-zero" where 1 is required.
- Record a baseline of 0 when the repository has real violations.
- Skip step 3.3, or fill it with restatements of the same gap.
- Leave the gate unwired, or `gate:` unset on the rule page.
