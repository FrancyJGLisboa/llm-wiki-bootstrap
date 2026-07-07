---
source_url: n/a
source_type: video-transcript
source_title: "Devsplainers — OKF and the LLM Wiki (video transcript)"
source_author: "Devsplainers (YouTube channel)"
fetched_at: 2026-07-07
ingested_hash: d1d2986d913d3ffd8da62ce9952b359d6153ecce3f64f0818e9cb3e04d87e542
ingested_at: 2026-07-07 06:20
ingested_pages: [wiki/devsplainers-okf-llm-wiki-video-transcript-summary.md, wiki/open-knowledge-format.md, wiki/okf-vs-llm-wiki-bootstrap.md, wiki/division-of-labor.md]
extraction_method: passthrough
notes: |
  Pasted by the user from the YouTube transcript panel (no URL provided).
  Commentary video covering Karpathy's LLM-wiki gist and Google's Open
  Knowledge Format announcement. Timestamps and chapter titles preserved
  verbatim; [music] markers and YouTube UI chrome are paste artifacts.
  Secondary/opinion source — factual claims about OKF should be cited from
  raw/okf-spec-v0-1.md or raw/google-cloud-okf-blog.md where possible.
---

# Devsplainers — OKF and the LLM Wiki (video transcript)

In this video

Chapters

Transcript

 The idea that broke 2 years of AI orthodoxy
0:00
For two years, the entire AI industry
0:02
agreed on how to give a model memory.
0:05
You chopped your documents into
0:07
thousands of fragments, turned each
0:09
fragment into a long list of numbers,
0:12
and paid to store them in a special
0:14
database. Then this spring, one of the
0:17
most respected names in AI looked at all
0:19
of it and said, "Just use a folder of
0:22
text files." And it worked better. Now
0:25
Google's turned that folder into an
0:27
official standard. Developers are
0:29
calling it the most obvious ID they've
0:31
ever seen. And they might be exactly
 How RAG and vector databases actually work
0:34
right. The complicated version existed
0:36
for a reason. Everything an AI needs to
0:40
do its job is scattered. A metrics
0:42
definition lives in one database. Its
0:45
logic in some pipeline. The reason it
0:47
changed in a six-month-old pull request
0:50
and the rest in the head of an engineer
0:52
who left in March. The standard fix was
0:55
a thing called rag. You take all those
0:57
documents, slice them into chunks, turn
1:00
each chunk into a long list of numbers
1:02
that captures [music] its rough meaning,
1:04
and load them into a vector database.
1:07
Ask a question. The system grabs the
1:10
chunks that [music] look closest to it
1:12
and hands them to the model. It works,
1:14
but it never remembers. [music] Every
1:16
query starts from zero. The model gets a
1:19
fresh pile of disconnected snippets and
1:22
has to work out the same connections it
1:24
worked out an hour [music] ago and the
1:27
hour before that. That respected name,
 The "LLM wiki" idea Google just standardized
1:29
by the way, was Andre Carpathy,
1:31
co-founder of Open AI, former head of AI
1:34
at Tesla. [music] In April, he posted a
1:37
short file to GitHub for an idea he
1:39
called the LLM wiki, [music] and it
1:42
flips rag on its head. Instead of the
1:44
model rederiving everything the moment
1:46
you ask, you built the knowledge up once
1:49
[music]
1:49
into a folder of plain text files that
1:52
link to each other. A living
1:54
encyclopedia the model can read the way
1:56
a developer reads a codebase. People
1:59
hear a folder of notes [music] and
2:01
assume they're the one writing the
2:03
notes. Wrong way around. You don't
2:05
[music] write the wiki. The AI does. You
2:08
bring it new material and ask good
2:10
questions. It handles the summarizing,
2:12
the cross referencing, the filing, all
2:15
the upkeep. Nobody ever keeps up with.
2:18
Carpathy's own line for it. Obsidian is
2:21
the IDE. The LLM is the programmer. The
2:24
wiki is the codebase. The folder is the
2:26
part you own. The model is the worker
2:29
who maintains it. This is where Google
 What Google's Open Knowledge Format really is
2:31
comes in. On June 12th, Google Cloud
2:34
took that loose community idea and
2:36
published it as a formal spec, the open
2:39
knowledge format. The spec is almost
2:42
comically small. A bundle is a folder.
2:45
Every file is one concept. A table, a
2:48
metric, a playbook, whatever you've got.
2:50
The files path is its name. Links
2:53
between files form a graph. There are
2:56
two special file names. one that lists
2:58
what's in a folder and one that logs
3:01
changes. And there's exactly one hard
3:04
rule. Every file has to say what type of
3:07
thing it is in one field. The spec also
3:10
orders any tool reading a bundle to
3:12
forgive almost everything. Unknown
3:15
fields, broken links, even files it
3:17
can't parse. An enterprise standard from
3:20
Google whose defining feature is how
3:22
little it demands [music] and how much
3:24
it lets you break. You could build it in
3:26
an afternoon. One thing Google dropped
3:29
though, Carpathy's instructions for how
3:31
the AI maintains the wiki. They kept the
3:34
folder and left out the part that keeps
3:36
it alive. Back to the reversal. The
 Why a folder of text files beats the vector database
3:39
folder wins and it wins for three
3:41
reasons. First, when the work happens,
3:44
[music] rack does its thinking at
3:45
question time. The wiki does it once
3:48
upfront when the bundle is built.
3:50
Connecting [music] concepts, flagging
3:52
contradictions, writing the summaries.
3:55
pay that cost a single time, then just
3:57
read the finished answer. Second, scale.
4:00
A model can only hold so much in its
4:03
head at once, and a [music] big company
4:05
has thousands of these files. Each
4:08
folder carries a short table of
4:10
contents. [music] The model reads that
4:12
first, picks the one file it needs, and
4:14
skips the other 9,000. It never chokes
4:17
on the whole library. Third, it's only
4:20
text. It lives in Git exactly like code.
4:23
You can div it, review it in a pull
4:25
[music] request, zip the whole thing,
4:27
and hand it to a model running offline
4:29
on a laptop. You don't need a database,
4:31
a server, or an API key to read it. If
4:34
you can open a file, you're good. Two
4:36
quick mixups to clear up. This isn't
4:39
competing with MCP. MCP is the pipe that
4:42
moves data around live. This is the
4:44
cargo that moves through it, and it's
4:46
not an SEO trick. Nothing in it helps a
4:49
search engine find you. It's private
4:51
knowledge for your own agents. The pitch
 The catch: staleness, messy Markdown, and meaning
4:54
is that the AI does the bookkeeping
4:56
humans always abandon. But the spec has
4:59
no mechanism to keep anything current.
5:02
There's a field for a time stamp. Fine.
5:04
A field is not a process. Nothing in the
5:07
format updates itself. This works
5:09
beautifully when one person owns one
5:11
folder. On a shared team folder, it goes
5:14
still in a month. Nobody volunteers to
5:16
tend it and the agent starts answering
5:19
from knowledge that expired back in
5:21
spring. That's catch one. Catch two is
5:24
funnier. The whole idea rest on AI being
5:26
a tireless accurate librarian. In
5:29
practice, language models are bad at
5:31
writing clean markdown at scale. They
5:34
botched the formatting, mangle headers,
5:36
invent links to files that were never
5:38
created. And how did Google fix the
5:40
messy librarian problem? They didn't.
5:43
They changed the spec to order every
5:45
reader to forgive [music] the mess. That
5:47
permissive rule is damage control with a
5:49
nicer name. The deepest catch is the
5:52
last [music] one. The format
5:54
standardizes the container, not the
5:56
meaning. The one required field is a
5:58
free form label. Your team writes big
6:01
query table. Mine writes table. Someone
6:04
else writes relational asset. They're
6:07
all valid, but each is speaking a
6:08
different language. You can ship the box
6:10
anywhere. agreeing on what's inside is
6:13
still on you. Strip all of this back and
 The real moat (and Google's BigQuery strategy)
6:15
you land on a line some developer wrote
6:17
that stuck with me. An agent is
6:20
basically just a folder of markdown
6:22
files. Anyone can write markdown. The
6:24
skill is in how the folder is organized,
6:27
what's locked versus what the AI can
6:29
rewrite, what stops it drifting over a
6:32
long run. The mode is invisible. Two
6:34
folders can look identical. One holds up
6:37
in production while the other slowly
6:39
rots. You can't tell which is which by
6:41
reading the files. No format can hand
6:44
you that. Then there's the part Google
6:45
would rather you skim past. OKF didn't
6:48
come out of Google's AI lab. It came
6:51
from the big query team. Every sample
6:54
data set ships on big query. The
6:56
reference tool that writes the bundles
6:58
runs on Gemini. And the easiest place to
7:01
pour a finished bundle is Google's own
7:03
knowledge product. The one they just
7:05
renamed for exactly this moment. If
7:08
you've seen our video on Gemma 4, I
7:10
guess you can already smell the strategy
7:12
behind this. Will it stick? Hard to say.
 Will OKF actually stick?
7:15
The day it launched, almost nobody
7:18
outside Google was using it, and [music]
7:20
a standard with one user is just a
7:22
suggestion. It could easily be the next
7:25
Google project added to their graveyard.
7:28
The idea underneath it has already won,
7:31
though. The most overfunded field
7:33
[music] in tech spent two years and a
7:35
fortune convincing itself that giving a
7:37
machine memory needed exotic
7:39
infrastructure.
7:41
Then a tidy folder of text files did the
7:44
job better. Whatever happens to the
7:46
format, that part isn't going back in
7:49
the box.

All

From your search

From Devsplainers
