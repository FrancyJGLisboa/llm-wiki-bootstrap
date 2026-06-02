# Talking points — LLM Wiki @ LSEG (10-min lightning)

Audience: LSEG **sales specialists, customer support managers, account managers / pre-sales,
sales leadership**. All non-technical; all already use AI chats.

**The whole talk in one sentence:** *You already ask AI chats questions — this is that, but
grounded in our own products, with receipts, and it never forgets.*

**Three things to land, no matter what gets cut:**
1. It's the *just-ask* experience they already know — not a developer tool they must learn.
2. Every answer comes **with a source** (the "receipts" — say this word, point at it in the demo).
3. It **compounds**: ask once, the team has it forever.

Pacing: ~45–60s per slide, ~2:30 demo. If you're over time, cut slide 5 detail and demo step 2d.

---

## Slide 1 — Hook (~30s)
- Open warm: "How many of you, this week, needed an answer you *knew* existed somewhere — a
  spec, a price, what we told a client last quarter — and couldn't find it fast?"
- "That gap is what this fixes. Knowledge on tap — and crucially, **with receipts.**"
- Don't explain the tool yet. Just plant "on tap, with receipts."

## Slide 2 — The pain + AI chats (~60s)
- Left column: the everyday reality. Read 2–3, let them nod.
- Pivot hard to the right column — **this is the bridge**: "Now, plenty of you already use
  AI chats for this. Good instinct. But you've felt the three problems: it makes things up,
  it doesn't know *our* products, and it forgets everything the moment you close it."
- "Right instinct, wrong tool. Here's the right one."

## Slide 3 — What it is (~60s)
- "It's the same *just-ask* feeling — except three things are true that aren't true of a chatbot."
- Walk the stack 1→2→3. Land hardest on layer 3: "Every answer cites where it came from."
- Avoid the words "RAG," "ingest," "pipeline," "frontmatter." Never say them.

## Slide 4 — Knowledge compounds (~50s)
- "Today, knowledge is a tax you pay over and over." (left column)
- "With this, you pay it *once.*" (right column) — "The first time anyone asks, the answer
  gets filed. The next person gets it instantly. It never starts from zero again."

## Slide 5 — Learns from your work (~45s)
- "Here's the part that does itself. The work you already do — a resolved ticket, an answer
  on a deal call — *becomes* the knowledge base. Automatically. And tagged with where it
  came from."
- The line that lands: "**The tribal knowledge that usually walks out the door? It stays.**"

## Slide 6 — The role grid (~75s — THE HEART, slow down)
Don't read the cells. Say ONE vivid line per role, looking at people who hold that role:

- **Sales specialist:** *"You're on a call, the prospect asks a detail about a feed, and
  instead of 'let me get back to you,' you've got the answer — and the source — in five seconds."*
- **Support manager:** *"It's the fifth time this week someone's asked the same thing, and a
  new rep is tapping a senior on the shoulder again. Now the answer's already there — it
  captured itself from the last time you solved it."*
- **Account manager / pre-sales:** *"You walk into a renewal with a customer you half-remember.
  This walks in with you — their setup, their integrations, their history, all sourced."*
- **Leadership:** *"You stop asking 'where did that claim come from?' Everyone tells the same
  story, new hires ramp faster, and every answer is defensible."*

## Slide 7 — Live demo (~2:30 — see demo-runbook.md)
- **Frame first** (mandatory): "What you'll see is the engine — what *you* do is just the
  last step, asking." Then run extract → ingest → query.
- Point at the citation when it appears and say the word "**receipts**."
- If anything wobbles, switch to the fallback without apology (runbook §3).

## Slide 8 — How you get it + why it's safe (~50s)
- Be direct — this is where you keep credibility: "Honest answer to the question you're all
  thinking: no, you won't be typing in a terminal. A champion on the team sets it up and
  keeps it current — **you just ask it**, like the chat you use today. A friendlier front
  door is on the roadmap."
- Then the trust case (matters to leadership *and* compliance): "Every claim is sourced.
  It's your files, you can inspect them, there's no black box and no vendor lock-in."

## Slide 9 — Close (~25s)
- The ask, said plainly: "Give me one product area. We'll stand up its wiki this week, and
  you just ask it. If it doesn't save you time, we drop it."
- Last line, then stop talking: "**Knowledge that compounds — with receipts.**"

---

## Objection prep (Q&A)

**"Do we have to use a terminal / install VS Code?"** ← the big one, answer confidently.
> "Not you. A technical champion runs the engine. Your experience is exactly what you saw in
> the demo's last step — ask a question, get a sourced answer. Same muscle as the AI chat
> you use now. The terminal is plumbing; you live in the tap."

**"How is this different from ChatGPT / Copilot?"**
> "Three ways: it knows *our* products because we feed it ours; it cites its source so you
> can verify; and it remembers — every answer makes the next one better. A general chatbot
> does none of those."

**"Is it ever wrong / does it hallucinate?"**
> "It answers from what we've given it and shows you the source, so you can check in one
> click. When it doesn't know, it can look it up and then *file* what it found — so the gap
> closes permanently instead of being re-asked."

**"Who maintains it? Isn't that a lot of work?"**
> "That's the point of slide 5 — it largely maintains itself from the work you're already
> doing. The champion curates sources and sanity-checks; the AI does the filing and linking."

**"Where does our data live? Is it secure?"**
> "On our own files, git-tracked, fully inspectable — not in someone else's cloud product.
> No lock-in. That's deliberate for a regulated data business." *(If pushed on the AI model
> itself, defer to IT/security on the approved-model question — don't improvise policy.)*

**"What does it cost / what's the lift to start?"**
> "Start is one product area and a champion who already has the AI tooling. Lightweight by
> design — files and slash commands, no new platform to buy."

**"Can it handle PDFs / spreadsheets / web pages?"**
> "Yes — documents, spreadsheets, web pages, even images. You saw a document go in live."

---

## Hard "don't"s
- Don't say RAG, ingest, pipeline, frontmatter, markdown, repo, git (except the one trust
  beat where "git-tracked = inspectable" helps leadership).
- Don't oversell self-serve today — be honest it's champion-operated now. Credibility > polish.
- Don't ask the wiki a question in the demo that your doc can't answer. Pre-test it.
- Don't quote the synthetic "Meridian" numbers as if they're a real LSEG product.
