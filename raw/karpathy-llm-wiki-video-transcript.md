---
source_url: n/a
source_type: video-transcript
source_title: "LLM-wiki knowledge bases (Karpathy concept) — YouTube walkthrough"
source_author: third-party YouTube creator (not Karpathy)
fetched_at: 2026-05-25
ingested_hash: "3054546faf0d367042739f090547e4714d47ea2caf82fd9fcf98cb17e40d612e"
ingested_at: 2026-05-25 06:45
ingested_pages:
  - wiki/index.md
  - wiki/core-idea.md
  - wiki/problem-with-naive-rag.md
  - wiki/three-layer-architecture.md
  - wiki/layer-raw-sources.md
  - wiki/layer-wiki.md
  - wiki/layer-schema.md
  - wiki/operation-ingest.md
  - wiki/operation-query.md
  - wiki/operation-lint.md
  - wiki/ingest-pipeline.md
  - wiki/division-of-labor.md
  - wiki/four-principles.md
  - wiki/karpathy-llm-wiki-video-transcript-summary.md
  - wiki/knowledge-compounds.md
  - wiki/query-as-write-loop.md
  - wiki/use-cases.md
  - wiki/commands.md
  - wiki/implicit-constraints.md
  - wiki/open-questions.md
  - wiki/source-attribution.md
  - wiki/glossary.md
notes: |
  Pasted by the user into the conversation that bootstrapped this project.
  Section headers (with timestamps) are preserved from the YouTube transcript export.
  This is the YouTuber's walkthrough of the pattern, NOT Karpathy's tweet verbatim.
  Karpathy quotes appearing in this transcript are the YouTuber's paraphrase / reading.
---

# Karpathy LLM-Wiki Knowledge Base — Video Transcript

## Intro: Andrej Karpathy's tweet and the concept of LLM knowledge bases (0:00)

So, I'm sure many of you saw this tweet from Andre Karpathy last week talking about LLM knowledge bases. It caught a lot of interest as kind of a new way to use AI as a research tool. And the core concept was to use LLMs to build personal knowledge bases for various topics of your research interest.

He breaks down how he did it here. And there were a couple other follow-up tweets as well as other researchers and AI enthusiasts talking about the way that they've done this kind of tooling.

So in today's video, we're going to build this for ourselves. First, I'm going to kind of break down what the concept is and why it's useful uh compared to other alternatives. And then we're going to actually build this out together in Claude Code. So you'll see a good example of how you would actually build this out. So wait, wait till the end for that.

## The problem with RAG and why LLM-powered wikis are better (0:51)

So let's start with the problem. Right now most people's experience with LLMs and documents look like RAG — retrieval-augmented generation. You upload some files to ChatGPT or NotebookLM or whatever tool and when you ask a question it retrieves some chunks and generates an answer.

And that works fine for simple questions. But here's the issue. Nothing accumulates. Every time you ask a question, the LLM is rediscovering knowledge from scratch. It's repiecing together fragments every single time. So if you ask something subtle that requires synthesizing five different documents, it has to find and connect all those pieces on every query. There's no memory, no cross references, no accumulated understanding.

But this LLM-powered wiki pattern flips this. Instead of retrieving at query time, the LLM builds a persistent interlinked wiki up front. The cross references are already there. Contradictions are already flagged. The synthesis already reflects everything you've already fed it. Knowledge compounds instead of being thrown away after each conversation.

And this is the key quote from Karpathy when discussing this. *The LLM incrementally builds and maintains a persistent wiki, structured interlinked markdown files sitting between you and your raw sources.* And the critical thing is you never write the wiki yourself. The LLM writes and maintains all of it. You're in charge of the important stuff — finding the good sources, exploring, asking the right questions. The LLM handles all the grunt work, the summarizing, the cross-referencing, the filing, the bookkeeping — all the stuff that makes knowledge bases useful, but that no one actually wants to do.

## The three-layer architecture: Raw Sources, Wiki, and Schema (2:32)

So there are many ways we can do this, but the basic architecture has three different layers based on what Karpathy was describing, and it's fairly clean.

On the left you have **raw sources**. So articles, papers, images, datasets, whatever you're collecting. You know, I'm sure most of us who are in this field find interesting articles, find interesting tweets, interesting GitHubs, and these are your raw sources and these are immutable. The LLM reads them but never touches them. They're your source of truth.

In the middle is the **wiki** itself, a directory of markdown files that the LLM owns entirely — summaries, entity pages, concept pages, comparisons. The LLM creates these, updates them when new sources come in, and maintains all the cross references, keeps everything consistent.

And on the right is the **schema** and this is the configuration file basically like a CLAUDE.md. And this tells the LLM how the wiki is structured, what the conventions are, what workflows to follow. So you and the LLM co-evolve this over time as you figure out what works for your domain.

Think of it like this. The wiki is a codebase, and then Obsidian is the IDE, and the LLM is the programmer, and the schema is the style guide.

## Core operations: Ingest, Query, and Lint (3:50)

So there are three core operations.

First is to **ingest**. You drop a new source into a raw folder and tell the LLM to process it. It reads the source, writes a summary page, updates the index, and cross-links it across all relevant existing pages. A single source might touch 10 to 15 wiki pages.

The second is **query**. You ask questions against the wiki. The LLM searches the index, reads the relevant pages, and synthesizes an answer. And here's the clever part — good answers can be filed back into the wiki as new pages. So your explorations compound in the knowledge base just like ingested sources do.

And the third is **lint**. So this is the maintenance pass. You ask the LLM to health-check the wiki — find contradictions, stale claims, orphan pages with no links, missing cross references, gaps that could be filled with a web search. So the LLM is good at suggesting new questions to investigate and this keeps the wiki healthy as it grows.

## What happens when you ingest a source (4:46)

So what happens when you ingest a source? Because this is where the real power in this is.

- **Step 1.** The LLM reads the raw source.
- **Step 2.** It extracts key information — concepts, entities, claims, data points.
- **Step 3.** It writes a summary page in the wiki with metadata and tags.
- **Step 4.** It updates all the existing entity and concept pages, integrating the new information into what's already known.
- **Step 5.** It flags any contradictions when new data conflicts with existing claims.
- **Step 6.** It updates the index, the master catalog of everything in the wiki.
- **Step 7.** It appends to the log — a timestamped record of what's changed and when.

And so one source drops in and the entire wiki gets a little bit smarter. So that's the compounding effect.

## The division of labor: Human curates, LLM maintains (5:40)

So here's the division of labor and it's pretty clean. The **human curates questions and thinks**. You pick the sources, you direct the analysis, you ask the good questions, you decide what actually matters.

The **LLM agent summarizes, cross-references, and maintains**. It writes all of the wiki pages. It keeps cross references up to date. It maintains summaries, flags contradictions.

And here is why this works. Karpathy puts it well. *Humans abandon wikis because the maintenance burden grows faster than the value.* Right? It becomes a huge labor just to maintain once these become a certain size. But LLMs don't get bored. They don't forget to update a cross reference. They can touch 15 files in a single pass. The cost of maintenance drops to near zero. So the wiki actually stays maintained properly.

## The four core principles of LLM wikis (6:25)

So this is why this approach wins and there are four principles behind it that make it really compelling.

**First, it's explicit.** The knowledge is all visible in a navigable wiki which most of us are familiar with. You can see exactly what the AI knows and what it doesn't know. There's no hidden embeddings. There's no opaque memory system.

**Second, it's yours.** You can customize it yourself. These are all local files on your computer. You're not locked into any provider's system and you keep everything yourself.

**Third, it's file over app.** Everything is in universal formats — markdown and images. This means it's interoperable with any tool, any CLI, any viewer. The entire Unix toolkit works with on your data.

**And fourth, you can bring your own AI.** You can plug in Claude, GPT, Codex, open-source models, whatever you want. You can even fine-tune a model on your wiki so it knows your data in its weights, not just in its context. And I think that's probably the next step.

## What you can build with this pattern (7:35)

So what can you build with this? This pattern applies to a lot of different domains.

- **Research** — obviously going deep on a topic over weeks and months, reading papers, building up a comprehensive wiki with an evolving thesis.
- **Personal** — you can track your goals, health, self-improvement. You can build a structured picture of yourself over time.
- **Business** — an internal wiki fed by Slack, meetings, customer calls, always current because the LLM handles maintenance.
- **Reading** — filling each chapter of a book, building out character and theme pages.
- **Due diligence** — obviously.

Today we're going to build one with trading strategies, which is part of a larger project that I've been working on. I've been doing a lot of research on advanced trading strategies and that's the wiki we're going to build today.

## Building our trading strategies wiki in Claude Code (8:35)

So this is the breakdown of what it's going to look like, the directory structure, and it's the same thing that we've said — the raw sources, the wiki itself, and then the schema and workflows in the CLAUDE.md file. Because I'm going to be using this in Claude Code with Opus 4.6.

So what the LLM will build — it will be the strategy pages, the concept pages, the entity pages, cross-referencing, links to everything, and then synthesis pages, comparisons, trade-offs.

I have given Claude a bunch of the tweets. Like I said this is the Karpathy tweet. I've given some others — some of the other users who have done really well. Farza was one of them. Eu Jin as well. Eu Jin had this really nice diagram that broke it down. So I fed this to Claude along with a couple other tweets people talking about how they did this.

## Claude's plan for building the wiki (10:08)

OK. So it's going to start out in plan mode. Obviously, we were talking about this concept earlier, but I said, "OK, design the plan to build this." So it entered plan mode. It's exploring the documents I just showed you, and then it's going to plan the architecture.

So it finished up its plan here. You can see it's building this LM wiki pattern. We're going to be doing it initially. I have eight transcript files, longish videos on trading concepts and then we can start from here and then build it out. It has some concepts you could see here.

So it's going to create the directory structure, copy the transcript files as the raw sources. It's going to write the CLAUDE.md which is going to be the schema here that it's going to use. We're going to be using Obsidian-style wiki links for everything.

Create the wiki logs, seed the concept pages — you can see what we're working with right now, how granular it's going to get — market structure and liquidity, strategy and execution, psychology. So it goes into every general concept. And you can decide how granular you want to get with this. And then it's going to create the wiki index page. Ingest all the raw. OK, so it's got everything here. Yep, it looks like a good plan.

So it's going to start building for us. OK, it's building out the directories and the transcripts were copied. Now it's writing the schema file, seeding the concept pages. OK, the scaffolding is complete. You can see all the directories. The next step is to ingest the eight raw transcripts. Go ahead.

So it's running two agents right now to ingest the raw sources, create the summaries and then update the concept pages.

## Visualizing the wiki in Obsidian (12:05)

OK, the initial ingest is done and now it's pretty much set up the original structure that we need. Just to visualize it, Karpathy talks about using Obsidian as well as an IDE. But you can download this or just ask your agent to download it. It's a very light file. But this is what we get.

It's probably easier to see. It's a basic file structure. You can see all the files here. This is the wiki — it has all of the knowledge that you were trying to build up based on it.

You could see what we do here. Identity shift, protected stops. It has all the links. You can see the links to other files. So you have a link to "draw on liquidity" here if you want to see this. So this is just a really nice clean visualization of this and you could build out a proper front end like this. I know people have done that but for my purposes this is all I need just to kind of see the information.

## Querying the wiki and automatic backfilling (13:08)

OK. So lastly let's try asking it some questions. I asked "Can you explain draw on liquidity to me?" and it read the files based on it and gave me an answer without having to go do web searches and check everything else. It goes into the core idea of draw on liquidity, types of draws, qualifying and disqualifying draws, concrete examples, how it connects to everything else.

So let me ask "how do draws on liquidity actually appear?" So it read it as well. This is how it appears on the chart — failure swings and unfilled fair-value gaps.

And then if I ask a question "is there any other ways to identify them? Check outside the wiki." If I ask any question based on this wiki information that it doesn't have on hand, it can then do a web search and then it will go and automatically backfill the wiki with the new information that it found. So it found several other "draw on liquidity" identification methods — four of them, five actually. So using these resources, now it's going to continue to build out the wiki again.

And this is really how you develop the knowledge base. It kind of gets smarter on its own as you ask it questions, and if there's information it can't find from the wiki itself, it can do quick searches and then backfill it so that it has all the answers later on.

## Customizing visual outputs and new concept creation (14:40)

And instead of just answering questions, you can also set it up to create markdown files, slideshows, which is a really useful presentation, or matplotlib images and then you can all view them in Obsidian like that. So there's a lot of ways you can customize it visually.

So you can see based on the answer it's writing new concepts — order blocks, breaker blocks, equal highs and lows — so that once these concepts and information is inside the wiki you don't have to go and fetch it every single time you ask about these concepts again.

## The compounding effect of knowledge (15:10)

And I'm doing this with Claude with Opus 4.6. But like I said before, you can use any LLM that does basic research and writing functions or any agent. You can use Open Claude to do this or Hermes agent.

So as Claude says here, this is exactly how the wiki is meant to grow. *You ask a question, I researched beyond the wiki and the new knowledge got filed back as permanent pages. So every future query can now reference order blocks, breaker blocks, equal highs and lows along with the original stuff.* So this is how you really build it up and eventually over time you'd have a really massive knowledge base to work on.

And now you can see in Obsidian it has breaker blocks as a concept — everything linked together — very easy to understand related concepts and links to everything that you need.

## Conclusion and call to action (16:00)

Right? So that was the core concept from Karpathy. He talked about this last week and you just saw us build this together. There's a lot of ways to customize this to exactly what you need and by doing that you can create a really powerful knowledge base.
