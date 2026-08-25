# What this is

**A context compiler turns a pile of documents into a set of dated, sourced
statements — so you can ask what is true now, what was true then, and how we know.**

This page is the short version, written for anyone. No prior knowledge is assumed
and nothing here requires you to be a developer.

## 1. The problem

You have a year of material about one client: emails, call notes, a few
spreadsheets, some research. Everything is filed. Nothing is lost.

Then someone asks:

> Why do we think they are worried about Q1 supply?

You can find the email. What you cannot do, in any reasonable amount of time, is
answer the three questions that actually matter:

- **What do we believe right now?** The material says six different things, written
  across nine months. Some of it has been overtaken by later evidence.
- **What did we believe in June?** Someone made a decision then. Reconstructing the
  view they had at the time means re-reading everything and mentally deleting
  whatever arrived afterwards.
- **How do we know?** "It's in the notes somewhere" is not an answer when a client
  challenges a number.

Documents record *events*. They do not hold a *view*. Every time the question comes
up, someone rebuilds the view by hand, from scratch, and slightly differently.

## 2. Why the usual answers fall short

**Better filing** doesn't help. The problem isn't that you can't find the document.
It's that no document contains the answer — the answer is spread across twenty of
them, and changes over time.

**Search, including AI search,** answers a different question than the one you
asked. Ask "what do we believe about Q1 supply?" and it returns passages that
*mention* Q1 supply. That is "where is this discussed?", not "what is our current
view, and what replaced what?" It also starts from nothing every single time you
ask.

## 3. The move

Do the work once, when the evidence arrives — not every time someone asks.

> The pattern's bet: stop trying to *retrieve* knowledge at query time. **Write the
> synthesis to disk, once, when each source comes in.**

The reason this is the right trade is one sentence: **sources arrive far less often
than questions.** A new call happens weekly. Questions about that call happen all
day. So pay the cost once, on the rare event, instead of repeatedly on the common
one.

## 4. The unit: five questions every statement carries

When a document comes in, it is broken into individual statements. Each one carries
five things — the same five things a careful person would want before repeating a
claim out loud:

| | The question it answers |
|---|---|
| **Statement** | What do we believe? |
| **Source** | How do we know? — the exact passage it came from, not just "a document" |
| **Time** | When was this true? From when, until when |
| **Certainty** | How sure? — an observation, a fact, an assumption, an inference, or an explicit *unknown* |
| **Relations** | What did it replace? — this one supersedes, updates, confirms or contradicts that one |

Notes and search give you the first row. A context compiler gives you all five.

That is the entire idea. Everything below is a consequence of it.

## 5. What that buys you

Because every statement carries those five things, questions get answerable in a
strict order — each one needs everything above it:

```text
find a fact
  show the exact passage behind it
    say what is true now
      say what was true on a past date
        say which belief replaced which
          flag where two sources disagree
            explain why A affects B across documents
              say "unknown" instead of guessing
```

Keyword search stops at the first line. Filing stops before it.

Those eight are drawn from the twelve test cases in
[`../benchmarks/northstar/README.md`](../benchmarks/northstar/README.md), each
scored against an answer key written independently of the system.

**What the measurement shows so far.** On 2026-08-25 those twelve cases were run
for the first time, at 24 sources and again at 828. A capable AI agent given the
raw folder answered them as well as the compiled package did — including the
temporal and supersession cases — while BM25 retrieval did not. So the ladder
describes what a compiled package is *built to* answer; it does not currently
describe an advantage over an agent that can read your files directly. Full
numbers and limits: [`../benchmarks/northstar/RESULTS.md`](../benchmarks/northstar/RESULTS.md).

## 6. One question, four answers

*Why is 5.70 the current exchange-rate assumption?*

- **A folder of documents, read by a person.** You find the email that says 5.70. You cannot tell
  whether it still holds, or what it replaced.
- **Keyword search over your files.** You get passages mentioning the exchange
  rate, ranked by resemblance to your question. You still have to read them and
  decide which is current. Measured: this arm missed which assumption had been
  replaced.
- **An AI agent with access to the folder.** It reads what it needs and answers.
  Measured: at 24 and at 828 sources it got the current value, the superseded
  one, and the date boundary right. This is the strong alternative, not a
  strawman.
- **A context compiler.** You get the same answer as a structured record: the
  statement, the exact sentence, who said it and when, that it replaced 5.50, and
  what rests on it — without re-deriving any of it per question. Whether that
  record is worth its build cost is the open question; see
  [`../benchmarks/northstar/RESULTS.md`](../benchmarks/northstar/RESULTS.md).

## 7. Why it is called a compiler

A software compiler takes source files, transforms them by known rules into a
different representation, checks the result, and refuses to finish when the result
is broken. This does the same thing with documents: sources in, a defined
transformation, a checked result, a build that fails when a statement loses the
passage it rests on.

Where the comparison stops:

> **There is no AST, and the transform is not reproducible.** [...] Run it twice on
> the same input and you get two defensible outputs, not identical bytes.
>
> So the guarantee on offer is **not** *reproducible output*. It is *verifiable
> output*.

A normal compiler earns trust by producing identical bytes every time. This one
earns it by making every statement traceable to the exact passage behind it, and
failing the build when that link breaks.

## 8. What it is not

- **Not a search engine over your files.** Search does the work at question time and
  starts fresh every time. This does the work once, at arrival.
- **Not a "second brain".** In a second brain you write the notes, maintain the
  links and spot the contradictions yourself. Here you curate *sources*, and the
  build produces the notes, the links and the contradiction flags.
- **Not an AI agent.** It sits underneath agents and produces what they read.

## 9. Where to go next

- To **use** one: [`../START-HERE.md`](../START-HERE.md) — a synthetic demo corpus
  ships with it, so you can see a real answer before supplying anything of your own.
- For the **full argument**, including what is measured and how:
  [`CONTEXT-COMPILER.md`](CONTEXT-COMPILER.md).
- If you **think in build systems**: [`EXPLAIN.md`](EXPLAIN.md) maps the whole thing
  onto `make`, `git` and `eslint`.
- For **every command**: [`../ADVANCED.md`](../ADVANCED.md).
