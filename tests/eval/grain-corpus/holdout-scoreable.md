# Holdout questions (sealed)

This set is an anti-Goodhart control. It was authored independently, from ten
reserved transcripts that no other eval question touches, and its contents were
never shown to the agent that builds or tunes the wiki. It is scored once, at
the end, and never used for tuning, prompt iteration, or ingest changes. If it
is ever consulted while improving the system, it stops being a holdout and must
be replaced.

Format matches `tests/eval/retrieval-questions.md`. Every `cite-contains` phrase
was verified verbatim (case-sensitive `grep -F`) in the cited transcript, and no
`expects` token appears in its own question text.

## Questions

### H-reownership-2020
On the September 24, 2020 morning show, the host said he almost never advises a
certain kind of strategy, but that he might do it on a limited basis this year
for one particular crop. What strategy was it, and which crop?
modality: opinion
expects: ownership, bean
cite-contains: rare occasion that i ever advise
max-span: 15
cite-file-matches: ^2020-09-

### H-cancellation-cushion-2021
In the February 2021 episode about export cancellations, the host argued the
soybean export program was not going to turn into a disaster. What proportion of
what had been sold did he cite, and what had already happened to it?
modality: figure
expects: 85, shipped
cite-contains: we've already shipped like 85 percent
max-span: 15
cite-file-matches: ^2021-02-

### H-ballgame-2021
In the May 2021 episode on where to invest, the host weighed whether to keep
buying stocks monthly despite fearing an earlier-than-expected rate hike. What
time horizon did he invoke to justify staying the course, and what did he call
it?
modality: opinion
expects: 25, ball
cite-contains: this is like a 25 year ball game
max-span: 15
cite-file-matches: ^2021-05-

### H-nashville-project-2021
In that same May 2021 episode, the host mentioned something he had made with a
couple of friends in Nashville that might soon change the podcast's opening.
What was it, and what was he waiting on before using it?
modality: anecdote
expects: record, masters
cite-contains: i made a record with a couple
max-span: 15
cite-file-matches: ^2021-05-

### H-dollar-thesis-2022
In the March 30, 2022 episode, the host relayed the long-term view on the US
dollar given by a mainstream investor he had watched being interviewed on Yahoo
Finance. Who was it, and what was the view?
modality: opinion
expects: munger, zero, 100
cite-contains: goes to zero over the next 100 years
max-span: 15
cite-file-matches: ^2022-03-

### H-currency-integrity-2022
In the March 30, 2022 episode, what specific event did the host point to as the
moment the United States began compromising the integrity of its own currency,
and what metaphor did he use for it?
modality: reasoning
expects: 2008, pandora
cite-contains: we kind of opened pandora's box
max-span: 15
cite-file-matches: ^2022-03-

### H-risk-off-analogy-2022
In the June 2022 episode, the host defended a historical analogy he says he has
been told a hundred times is wrong. What single prior instance did he point to,
pairing a corn price level with a collapse in another market, and in what year?
modality: reasoning
expects: 2008, seven
cite-contains: corn was seven dollars and the stock
max-span: 15
cite-file-matches: ^2022-06-

