# Deterministic Gates

Doctrine for making coding agents produce reliable deterministic gates.
Project-agnostic; this copy is the one context-compiler-bootstrap agents follow.

**Gates already live here** — read them before proposing a new one:
`scripts/wiki-lint-*.sh` (asserted-at, causal, commitment, hash-drift,
typed-relations), `scripts/citation-audit.py` (`--coverage`, `--no-bare-urls`),
`scripts/wiki-faithfulness-gate.sh`, `scripts/corpus-health.py`, and the
`scripts/verify-*.sh` family that proves each of them still fires.
Cross-cutting: `scripts/gate-ratchet.sh` (§6) watches every other gate's counts,
and `scripts/lib/gate-lib.sh` carries the shared exit-code discipline — source
it rather than re-implementing `die2`.

## Core principle

Never accept the agent's claim that a gate works — demand the artifact.
A gate that never fires is indistinguishable from a broken gate, and that is
how most of them are born. Everything below is engineering around that.

## 1. Standing rule

No rule in this repository lives in prose alone.
If a rule can be verified by a script, it MUST exist as an executable script
with an exit code, not as an instruction in a markdown file.

Before claiming that any rule is enforced, paste the terminal output showing:

- (a) the gate FAILING on a fixture that violates the rule,
- (b) the gate PASSING on clean code.

Without both outputs, the task is not complete.

## 2. Inventory — run this before any code is written

Do not write code in this step.

Scan this repository and its commit history and list candidate rules that could
become gates. Extract only rules EVIDENCED by the material: patterns already
present in the code, repeated fixes in the history, warning comments, things
that have already broken. Do not include generic best practices you happen to
know but that are not evidenced here.

For each candidate, one line with:

```
rule | evidence (file/commit) | violation frequency | cost if it slips through (silent vs. loud)
```

Sort by cost of the silent failure. Stop and show me the list.

> Silent failures come first because a bug that blows up already has a
> natural gate — the user.

## 3. Triage — deterministic vs. opinionated

For each rule in the list, classify it:

- **DETERMINISTIC** — verifiable by parsing/AST/schema/command with an exit
  code. Write out the exact detection mechanism.
- **HEURISTIC** — requires judgement. Goes into a verifier agent's rulebook,
  not into a script.
- **UNVERIFIABLE** — cannot be checked. Discard it, do not pretend.

Forbidden: a script that calls an LLM and presents itself as a deterministic
gate. That is a heuristic wearing a script costume.

Prefer a parser/AST over regex. If you use regex, write down which cases it
gets wrong.

## 4. Gate contract — the implementation prompt

Implement gate `<X>` following this contract in full:

- rule id and a one-sentence statement of the rule
- detection mechanism
- scope: which files are included, which are excluded, and why
- exit codes: `0` = compliant | `1` = violation found | `2` = the gate itself
  failed (missing dependency, parse error). Never collapse `2` into `0`.
- failure output: `path:line`, rule id, and how to fix it
- fixtures committed to the repo: one file that VIOLATES (must exit 1)
  and one CLEAN file (must exit 0)
- target runtime
- wiring point: hook, pre-commit, or CI

> Exit code 2 is the detail almost everyone forgets. A gate that dies from
> a broken dependency and returns 0 is worse than no gate at all.

## 5. Mutation proof — the verification prompt

Prove this gate works:

1. Break the code in 5 different ways that violate the rule, including two
   edge cases, and paste the gate's output catching each one.
2. Run it against the entire repository and tell me how many real violations
   exist.
3. List 3 ways to violate the rule that this gate does NOT catch. If you
   cannot think of any, you have not understood the problem space — think
   again.
4. Revert the mutations.

> Item 3 is what pulls the agent out of overstating its own delivery.

## 6. Ratchet and anti-bypass

Existing violations are recorded in a committed baseline.
The gate fails if the count GOES UP; it never requires me to fix the past.

Additionally: count suppressions (`nolint`, `eslint-disable`, pragma, config
exclusions) as violations in the same baseline. If suppression does not enter
the ratchet, you will route around the gate instead of obeying it — and I want
that to be impossible, not merely discouraged.

**Implemented here** by `scripts/gate-ratchet.sh` (rule `RATCHET-NO-INCREASE`)
against the committed baseline `gates/baseline.tsv`, wired at
`scripts/smoke-all.sh` (R36) → CI.

Every gate exposes `--count`, printing `<violations>TAB<suppressions>` and
exiting 0; the ratchet, not the gate, decides whether the number is acceptable.
A gate that exits 2 under `--count` fails the ratchet as a gate error — a
broken gate never reads as compliant. Two directions are enforced: a recorded
count may not be exceeded, and **a gate with no baseline row is itself a
violation**, so a new gate cannot escape the ratchet by never being registered.

Downward moves are silent — lowering a row is the reward for fixing something.
Raising one requires editing the file and writing the reason in the note
column, which makes the increase an artifact in review rather than an accident.

Known limits, stated rather than implied: this is a *count* ratchet, not an
identity ratchet — two violations swapped for two others keeps the total flat
and passes. Per-gate stable violation identifiers would be needed for the
stronger version, and the diff-based and reachability-based gates here cannot
produce them.

## 7. Continuous harvest — standing instruction

Whenever we fix a bug or a regression in this session, before closing it out:
which gate would have caught this automatically? Classify it as deterministic
or heuristic and implement it using the standard contract. If no gate would be
viable, say so explicitly and explain why.

## Caveat

Too many gates becomes friction, and past a certain point the agent spends more
time negotiating with the gates than producing. The signal that you have gone
too far is when it starts proposing scope exclusions — which is why section 6
counts suppressions.
