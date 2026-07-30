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

### H-argentina-cut-2023
In the January 12, 2023 episode, which exchange slashed its Argentine soybean
production estimate, and what were the new and previous numbers?
modality: figure
expects: rosario, 37, 49
cite-contains: pegged the country soybean crop at 37
max-span: 15
cite-file-matches: ^2023-01-

### H-china-conflict-2024
In the January 2024 episode, the host contrasted how the market would read a
US-China conflict against how it read the 2022 invasion of Ukraine. What kind of
shock did he say each one represents, and what phrase did he use for how global
buying would ultimately rearrange itself?
modality: reasoning
expects: demand, musical chairs
cite-contains: musical chairs in regard to demand
max-span: 15
cite-file-matches: ^2024-01-

### H-fed-outcome-call-2024
In the January 2024 episode, what did the host declare about the much-debated
outcome the Fed was chasing, and how did he characterize how widely that view
was held?
modality: opinion
expects: soft landing, already
cite-contains: that's not a popular opinion
max-span: 15
cite-file-matches: ^2024-01-

### H-short-covering-scale-2024
In the October 2024 episode, the host converted the funds' short-covering since
late August into physical terms. How many bushels did he say it worked out to,
and what share of that year's crop did he say that represented?
modality: reasoning
expects: 1.5, 10
cite-contains: that's 1.5 billion bushels
max-span: 15
cite-file-matches: ^2024-10-

### H-sentiment-index-history-2024
In the October 2024 episode, the host disclosed a past professional connection
to the farmer-sentiment index he was discussing. What was that connection, and
which organization was it with?
modality: anecdote
expects: cme, video
cite-contains: used to do a bunch of video work
max-span: 15
cite-file-matches: ^2024-10-

### H-iowa-stake-2025
In the November 2025 episode about the Iowa proposal to tax out-of-state land
owners more heavily, how did the host describe his own personal stake in the
issue, and what did he predict about the proposal's prospects?
modality: opinion
expects: dog, traction
cite-contains: don't have a dog in this fight
max-span: 15
cite-file-matches: ^2025-11-

### H-packer-stock-2025
In the November 2025 episode, the host compared a major meat packer's stock
performance against the S&P 500 measured from the start of 2020. What were the
two figures?
modality: figure
expects: 35, 111
cite-contains: down almost 35% since the start of 2020
max-span: 15
cite-file-matches: ^2025-11-

### H-vanishing-ridge-2026
In the February 2026 episode, the guest retold a meteorologist's account of a
pressure feature that vanished one morning in late July and was blamed for the
dryness that followed in August. What feature was it, and where did he say it
turned up instead?
modality: anecdote
expects: bermuda, morocco
cite-contains: it woke up one morning and it disappeared
max-span: 15
cite-file-matches: ^2026-02-

### H-bitcoin-buyer-verdict-2026
In the February 2026 episode, the host restated a blunt verdict he says he has
given many times on the podcast about a well-known corporate Bitcoin buyer.
What was the verdict, and about whom?
modality: opinion
expects: michael, bankrupt
cite-contains: he's got to go bankrupt
max-span: 15
cite-file-matches: ^2026-02-
