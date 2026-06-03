# Live demo runbook — LLM Wiki @ LSEG

**Goal:** in ≤ 3 minutes, turn a document into a *cited* answer, live. Backs **slide 7**.

**The one rule:** frame it before you touch the keyboard. The room is non-technical —
the terminal will appear "developer-y." Defuse it in one sentence (below) and they'll
lean in instead of tuning out.

---

## 0 · Pre-flight (do this BEFORE you present)

- [ ] Terminal font bumped to ~18–20pt. Dark theme. Window maximized.
- [ ] Claude Code opens cleanly. Test once: `claude` then `/wiki-query "test"` returns *something*.
- [ ] **Safety-net wiki verified.** It's pre-built at `~/llm-wikis/lseg-products/`.
      Run the fallback query once today (Step F below, with `--no-promote`) and confirm you
      get a cited answer.
- [ ] **Your real doc ready.** Know its exact path (or URL). Pick it so that you *already
      know* a question it can answer — never ask the wiki something the doc doesn't cover.
- [ ] Decide your money-shot question in advance and write it on a sticky note.
- [ ] **If you plan to show the visual beat (2d):** run `/wiki-diagram` once today against the
      Meridian wiki and confirm a poster lands in `diagrams/`. It's interactive (shows a menu,
      you pick) and LLM-generated, so it's the *first* thing to drop if time is tight — never
      let it stall the demo.
- [ ] Browser tab open on `presentations/lseg-sales/deck.html` (slide 7) to flip back to.
- [ ] Network: if your doc is a URL, confirm the venue Wi-Fi reaches it. If unsure, use a
      **local file** — no network dependency.

> If anything in pre-flight is shaky, present the **fallback (Step F)** as your main demo.
> It's the identical narrative beat with zero live risk. Nobody knows it was "plan B."

---

## 1 · Frame it (say this, then start typing) — ~10s

> "Quick thing before I type: what you're about to see is the **engine** — how a champion
> sets the wiki up. The part *you'd* do is only the last step, asking a question in plain
> English. Watch what comes back."

---

## 2 · The demo (with your real doc) — ~2 min

Run these one at a time. Talk over each while it works (recovery lines in §4).

```
# 2a · Add the source  (~20s)
/wiki-extract <PATH-OR-URL-TO-YOUR-LSEG-DOC>
```
**Say:** "I'm just handing it the document — no formatting, no setup."

```
# 2b · Build it into the knowledge base  (~40s)
/wiki-ingest
```
**Say:** "Now it reads the doc, writes it up, and files it. Notice it lists the pages it
created — that's the knowledge base growing."

```
# 2c · THE MONEY SHOT — ask a real question  (~40s)
/wiki-query "<a question your doc clearly answers>"
```
**Say:** "Plain English — like any chat. But look —" *(point at the citation)* "— it tells
me **where** the answer came from. That's the difference. Nothing invented."

```
# 2d · OPTIONAL, only if time — turn knowledge into a client-ready visual  (~40s)
/wiki-diagram "compare the three Meridian latency tiers for a buyer"
```
**Say:** "And it doesn't just answer — it'll draw the knowledge for a client deck." It shows
a short menu of diagram types (it scored them); pick the top one. *(Open the generated HTML
poster from `diagrams/`.)*

**Why this beat matters:** the poster is built **from the wiki's own domain content** — not
a generic template. That's the value loop in one move: *knowledge in → audience-ready visual
out.* (Faster alternative if you're tight: `/wiki-query "..." --visual html` auto-picks the
diagram type.) Skip entirely if you're near 3 minutes — **2c is the demo**, this is gravy.

---

## 2+ · Optional advanced beat — build a specialized agent live (TECHNICAL rooms only)

**Do not run this in a non-technical room, and never instead of 2c.** It is 6 steps
vs. 2 and introduces four commands — it's a *stronger story* (the system encoding
*reasoning*, not just facts) but a *riskier* live demo. Two hard prerequisites:

- **Pre-build a `traders-desk` safety-net brain today** (same discipline as the
  Meridian wiki) and rehearse the exact query — otherwise narrate this as a story
  off the slide, don't type it. A cold `/wiki-query` against an unseeded brain
  returns thin answers.
- If anything stalls, fall back to the Meridian demo (Step F). No apology.

**The order matters — `/wiki-skill` builds the brain FIRST (empty), then you fill
it. You cannot ingest first and wrap after.**

```
# 1 · Create the agent's brain (empty, seeded with vocabulary only)
/wiki-skill traders-desk --domain "futures desk decision rules"
cd traders-desk
```
**Say:** "First I'm creating the *agent* — its brain starts empty, just the
vocabulary of the desk."

```
# 2 · Hand it how a trader actually thinks — raw prose, no formatting
/wiki-extract --text --source-type interaction
```
**Say:** "Now a senior trader pastes their decision-making, in plain English."

```
# 3 · Build the reasoning into the brain
/wiki-ingest
```
**Say:** "It extracts the *principles* — not just facts — cross-links them, and
flags where two traders disagree."

```
# 4 · THE MONEY SHOT — ask it a judgment question
/wiki-query "EUR curve just steepened 15bp into a CPI print — what's our play?"
```
**Say:** "It reasons from the desk's *stated* principles —" *(point at the
citation)* "— and tells me whose rule it used. Nothing invented."

```
# 5 · OPTIONAL — show it compounds
/wiki-learn
```
**Say:** "And it gets sharper every session — it learns the desk's reasoning as
it's used."

**The honest line you MUST say (don't let the room over-read it):** "This reasons
from what the traders *wrote down* — their articulated rules, every answer cited.
It is not cloning gut feel." Overclaiming "it replicates your best trader's
instinct" is the one thing that gets you caught.

**Why this beat matters:** it moves the story from *"cited answers from a
document"* to *"a specialized agent that reasons the way your desk does, with a
receipt for every call."* That's the board-level pitch — but only land it if the
room is technical and the brain is pre-built.

---

## 3 · Fallback (Step F) — the pre-built LSEG demo wiki

Use this if the live doc fails, the network drops, or you'd rather not risk it. It's a
synthetic but realistic feed fact sheet, already ingested — so a query returns a cited
answer immediately.

```
cd ~/llm-wikis/lseg-products
claude
```
```
/wiki-query "which tier do I need for an OMS, and how are exchange fees billed?" --no-promote
```
> `--no-promote` keeps the demo deterministic on stage: it answers from the wiki only and
> won't trigger a live web-search detour or mutate the wiki mid-demo. (The pages answer
> locally, so it shouldn't fire anyway — but on stage you want zero surprises.)
**Expected answer (already supported by the wiki):**
> Standard tier (median ~25 ms) is the usual fit for an OMS. Exchange fees are billed
> **per entitled venue** and reconciled monthly through the account manager.
> `source: raw/meridian-rt-feed-factsheet.md`

Other safe questions this wiki answers (all cited):
- "Which tier can I use to show prices on a public website?" → *Delayed (15-min), no real-time entitlement.*
- "What's the difference between the latency tiers?" → *Ultra 0.8 ms / Standard 25 ms / Delayed 15 min.*

> Tell the audience plainly: "This is an **illustrative** feed — a stand-in product called
> Meridian — so I'm not quoting real specs at you. The *mechanic* is the point."

---

## 4 · Recovery lines (say these while a command runs, or if it stalls)

- **While it thinks:** "While that runs — the reason this matters is the line at the
  bottom. Most AI gives you an answer. This gives you an answer *and the receipt.*"
- **If it's slow:** "It's reading the whole document right now — first time only. Once it's
  filed, the next person's answer is instant."
- **If it errors / hangs:** "Let me show you the one I prepared earlier —" *(switch to Step F,
  no apology, no fumbling).* "— same thing, on a sample feed."
- **If asked 'is it always right?':** "It only answers from what it's been given, and it
  shows you the source — so you can check it in one click. That's the whole point versus a
  chatbot that guesses."

---

## 5 · Hand back to the deck

After the cited answer lands, flip to **slide 8** ("How you'd use it — and why it's safe").
Close the loop: "So that citation you just saw? That's why a regulated data business can
actually trust this."

---

## Timing budget

| Step | Target |
|---|---|
| Frame | 0:10 |
| 2a extract | 0:20 |
| 2b ingest | 0:40 |
| 2c query (money shot) | 0:40 |
| 2d visual (optional) | 0:30 |
| Hand-back | 0:10 |
| **Total (with optional)** | **~2:30** |

Cut 2d first if you're running long. Never cut 2c.

---

## Appendix · Verify a generated skill installs & operates (pre-pitch, do once — never on stage)

Only needed if you intend to claim *"`/wiki-skill` produces a skill folder you can
drop into any agent and it just works."* Don't assert that on a call until you've
seen it load. This is a one-time engineering check, not a demo beat.

**Deterministic check (no LLM, no network — run it in CI too):**

```
# self-containment oracle: SKILL.md well-formed + every workflow it names is
# bundled inside the folder (so the agent needs no host-registered slash command)
scripts/verify-skill-install.sh                 # deterministic S1-S3,S5
scripts/verify-skill-install.sh --skill <wiki>  # full S1-S5 against a real /wiki-skill output
```

Green here proves the folder is **structurally** a self-contained skill. It runs as
**R10** inside `scripts/smoke-all.sh`.

**Live check (proves it actually activates + operates in a host):**

1. Scaffold a skill: `/wiki-skill demo-desk --domain "futures desk decision rules"`,
   then seed a little knowledge (`/wiki-extract <a-doc>` → `/wiki-ingest`).
2. Install it into a throwaway host project:
   `mkdir -p /tmp/host/.claude/skills && cp -R <wiki-dir> /tmp/host/.claude/skills/demo-desk`
3. `cd /tmp/host && claude`, then say a domain trigger phrase (e.g. *"what's our rule
   on position sizing?"*).
   - **L1 Activates** — the `demo-desk-brain` skill engages.
   - **L2 Read works** — the answer comes back **with a citation**; on something the
     wiki doesn't cover it says so instead of inventing.
   - **L3 Write works** — `/wiki-learn --dry-run` shows the notability gate's
     keep/drop decisions (a full run would write `raw/session-*.md`).

If L1 fails to activate, the host isn't reading the skill's bundled
`.claude/commands/` as slash commands — that's expected; the SKILL.md's
**Portability** note tells the agent to follow `.claude/commands/wiki-<name>.md` by
path. Confirm the agent does that before claiming drop-in portability.
