# Gold questions — Grain Markets and Other Stuff (40-episode corpus)

`scripts/eval-retrieval.sh` reads this file the same way it reads
`tests/eval/retrieval-questions.md`. The corpus here is 40 staged YouTube
transcripts of a daily US grain-market podcast (2020-09 through 2026-05), listed
in `main-sources.txt`. The 10 files in `reserved-sources.txt` are held out and
are not referenced by any question below.

**Why these questions and not others.** The subject matter — corn, soybeans,
USDA reports, China, tariffs — sits squarely in the model's pretraining. A
question like "what does stocks-to-use mean" or "was 2012 a drought year"
measures the model, not retrieval, and scores nothing here. Every question below
instead targets **this host's specific stated position, number, prediction,
analogy or anecdote on one specific date**. That pairing exists only in the
transcripts. An agent can only answer by actually reaching the episode.

**A1 (42 questions)** are single-episode point lookups across four modalities:
`figure` (a number he quoted and what he said it implied), `opinion` (a stated
position or verdict), `reasoning` (a causal chain he laid out), `anecdote` (a
story, analogy or on-air aside). The count sits above the nominal ~30 for one
reason: every one of the 40 source files is cited by at least one question, so a
retrieval failure localises to a specific file rather than to "the corpus". Four
files carry a second A1 question because they hold two independently checkable
claims; nothing here is padding.

**A2 (12 topics, 24 questions)** are point-in-time conflict pairs. Each topic is
one where the host's position **demonstrably reversed** across the sampled
years, with both positions verified present in the corpus. The `-asof` leg asks
for the position held on a specific date and must not be answered with the later
view; the `-both` leg asks how it changed and must name both positions. The
`-both` leg carries no `cite-contains` (it spans two episodes) and instead
carries a `forbids-pattern` blocking the false pass where an answer recites both
positions but waves the earlier one off as merely stale — each was genuinely
held at its own time, and calling the earlier one "outdated" is a
point-in-time-reasoning failure, not a synthesis.

**Leak rule.** No token in an `expects:` list appears anywhere in its own
question text. A question that contains its own answer measures nothing. This
was checked on every question.

**Verification.** Every `cite-contains` string was grepped against the named
transcript and matches verbatim, byte-for-byte, including the auto-caption
artefacts (`smok and mirrors`, `488 000`). Strings were chosen to be all
lowercase in the source so they match under either a case-sensitive or a
case-insensitive comparison. `expects` tokens are short (a number, a name, a
distinctive noun) so that harmless rewording does not fail a correct answer.

## A1 — single-episode, point-in-time

### A1-2020-wet-blanket
On 16 September 2020, what two-word phrase did the host use for what ethanol was
doing to the corn market?
modality: opinion
expects: wet blanket
cite-contains: ethanol is still really a wet blanket
max-span: 15
cite-file-matches: ^2020-09-16-

### A1-2020-stocks-use-2005
On 28 September 2020 the host said the projected US corn stocks-to-use ratio
would be the highest since a particular year. What year did he name, and what
spot corn price did he say analysts would call too high against it?
modality: figure
expects: 2005, 362
cite-contains: that would be the highest level since 2005
max-span: 15
cite-file-matches: ^2020-09-28-

### A1-2020-fund-combined-long
In his 14 December 2020 fund-position update, what combined net long across corn,
soybeans and SRW wheat did the host put on screen, and what year-end risk did he
attach to it?
modality: figure
expects: 488, liquidation
cite-contains: net long of 488 000 contracts
max-span: 15
cite-file-matches: ^2020-12-14-

### A1-2020-basscat-analogy
In December 2020 the host used an analogy about a manufacturer in Arkansas whose
products he owns personally, to argue against buying grain back after a
profitable sale. What does that manufacturer make?
modality: anecdote
expects: bass, boat
cite-contains: bass cat does not go and immediately try to buy the boats back
max-span: 15
cite-file-matches: ^2020-12-17-

### A1-2020-sentiment-follows-price
The fifth item on the host's December 2020 list of bull-market marketing
mistakes was ag media. What one-line rule did he give about the causal direction
between market mood and market direction, and what did he say he deliberately
tries to be when he goes on TV or radio?
modality: opinion
expects: sentiment, boring
cite-contains: sentiment in markets largely follows price
max-span: 15
cite-file-matches: ^2020-12-17-

### A1-2020-usda-carryout-halved
In his 2020 year-end review the host said USDA's US corn carryout projection had
moved enormously during the year. What were the June and December figures he put
on screen, and which demand category did he name as one of the two causes?
modality: figure
expects: 3.32, 1.7, export
cite-contains: 3.32 billion bushels was what they projected in june
max-span: 15
cite-file-matches: ^2020-12-29-

### A1-2021-march-madness
In the February 2021 crop-insurance conversation, what nickname did the guest
give the mid-month deadline for ARC/PLC elections and crop-insurance changes?
modality: anecdote
expects: madness
cite-contains: i call that march madness
max-span: 15
cite-file-matches: ^2021-02-02-

### A1-2021-may-first-study
In April 2021 the host back-tested one specific forward-sale timing rule for
new-crop corn over the 21 years since 2000. How many of those years came out
favourable, and what did he say about that result relative to what he had
expected before running it?
modality: figure
expects: 13, skewed
cite-contains: 13 years out of the 21 in which
max-span: 15
cite-file-matches: ^2021-04-22-

### A1-2021-social-media-skew
In a short July 2021 clip recorded while driving to a speech, what claim did the
host make about how attention to crop conditions is distributed on social media?
modality: opinion
expects: 10, 80, 90
cite-contains: is getting 80 to 90 percent of the attention
max-span: 15
cite-file-matches: ^2021-07-07-

### A1-2021-parana-emergency
On 27 July 2021 the host reported an emergency declaration in Argentina tied to
low river levels. How long did the declaration run, and what share of Argentina's
agricultural exports did he say moves on that river?
modality: figure
expects: 180, 80
cite-contains: this is a 180 day water emergency
max-span: 15
cite-file-matches: ^2021-07-27-

### A1-2021-phase-one-benchmark-flaw
In the October 2021 China discussion, what did the host and his guest identify as
the fundamental design flaw in the Phase One agreement's agricultural targets,
and what unit did they say should have been used instead?
modality: reasoning
expects: dollars, bushels
cite-contains: benchmarked in dollars which makes it essentially impossible to track
max-span: 15
cite-file-matches: ^2021-10-06-

### A1-2022-ethanol-grind-risk
On 10 March 2022 the host laid out a risk to corn's ethanol demand that he said
was "not real yet". What did he say about US ethanol inventories at that moment,
and what consumer fuel did the chain start with?
modality: reasoning
expects: record, gasoline
cite-contains: ethanol stocks in the united states are record high seasonally
max-span: 15
cite-file-matches: ^2022-03-10-

### A1-2022-soy-acres-third-time
On 1 April 2022 the host noted US soybean acreage would exceed corn acreage for
only the third time on record. Which two earlier years did he name, and how many
acres did the survey imply farmers would switch?
modality: figure
expects: 2018, 1983, 3.8
cite-contains: the other two years that this occurred were 2018 and 1983
max-span: 15
cite-file-matches: ^2022-04-01-

### A1-2022-soy-peso
In September 2022 Argentina gave soybean sellers a special exchange rate. What
rate did the host quote against the official one, and what was his verdict on how
much it would actually matter?
modality: figure
expects: 200, 139, game changer
cite-contains: at a rate of 200 pesos per dollar the official rate is 139
max-span: 15
cite-file-matches: ^2022-09-06-

### A1-2022-profarmer-gap
Ahead of the September 2022 WASDE, what did the host say the gap between USDA's
standing corn yield and the lowest private yield estimate was worth in bushels,
and whose estimate was the low one?
modality: figure
expects: 600 million, pro farmer
cite-contains: that's like 600 million bushels
max-span: 15
cite-file-matches: ^2022-09-09-

### A1-2022-goldman-faded
In December 2022 Goldman Sachs forecast a large commodity gain for the following
year. What did the host's new contributor say about how the bank's public calls
are treated inside the industry, and what year-to-date move had the host just
quoted for SRW wheat?
modality: opinion
expects: faded, 14 cents
cite-contains: says publicly is faded internally
max-span: 15
cite-file-matches: ^2022-12-16-

### A1-2023-vilsack-talk-tough
In February 2023 the US agriculture secretary criticised Mexico's new GMO corn
decree. What was the host's read on why the secretary was speaking that way, and
for what share of his audience did he say the matter was a non-issue?
modality: opinion
expects: talk tough, 99
cite-contains: job here is to talk tough
max-span: 15
cite-file-matches: ^2023-02-15-

### A1-2023-corn-analog-year
On the 4 May 2023 episode, the analyst on the show compared December corn's new
low with the May low of one earlier year and the recovery that followed it. Which
year did he name, and what recovery level did he cite?
modality: reasoning
expects: 2013, 570
cite-contains: before we recovered back to that 570 level
max-span: 15
cite-file-matches: ^2023-05-04-

### A1-2023-funds-flip-beans
In May 2023 the host said fund positioning in soybeans had, in real time, crossed
a line for the first time in years. What was the shift, and what year did he say
it was the first time since?
modality: figure
expects: short, 2020
cite-contains: net short the soybean market for the first time since 2020
max-span: 15
cite-file-matches: ^2023-05-22-

### A1-2023-adm-decatur
After the September 2023 explosion at the Decatur processing complex, what annual
capacity did the host give for the ethanol plant at that site, and how far did the
local corn basis bid move between Friday and Monday?
modality: figure
expects: 375, 35 cents
cite-contains: 375 million gallons per year
max-span: 15
cite-file-matches: ^2023-09-12-

### A1-2023-brazil-corn-ethanol
In September 2023 the host explained why Brazil's shift toward making ethanol from
corn instead of cane could eventually help US growers. What cost gap did he cite
between the two feedstocks, and through what channel did he say the US benefit
would arrive?
modality: reasoning
expects: 16, export
cite-contains: was 16 percent less than producing the biofuel from sugarcane
max-span: 15
cite-file-matches: ^2023-09-25-

### A1-2023-milei-not-bearish
When Argentina elected a new president in November 2023, soybeans opened sharply
lower overnight. What did the host say about that reaction, and what physical
reason did he give for it?
modality: opinion
expects: crush, planting
cite-contains: they've got no soybeans to crush
max-span: 15
cite-file-matches: ^2023-11-20-

### A1-2023-reflation-trade
In November 2023 the host was asked whether record money-market cash could rotate
into commodities. What did he say would have to happen first, and what total cash
balance did he cite?
modality: reasoning
expects: reflation, 5.76
cite-contains: a reflation trade like a return to inflation
max-span: 15
cite-file-matches: ^2023-11-27-

### A1-2024-bean-imports
In February 2024 the host and his contributor discussed US buyers taking delivery
of Brazilian soybeans. What USDA import figure did they cite for the year, and how
far back did they say you would have to go to find one that large?
modality: figure
expects: 30 million, 2012
cite-contains: the largest since shortly after the drought of 2012
max-span: 15
cite-file-matches: ^2024-02-02-

### A1-2024-smoke-and-mirrors
In April 2024 the host contrasted two corn stocks-to-use projections by how much
faith he put in each. Which figure did he say you could hang your hat on, which
did he dismiss, and what phrase did he use for the dismissal?
modality: opinion
expects: 14.9, 17.2, mirrors
cite-contains: that's all smok and mirrors
max-span: 15
cite-file-matches: ^2024-04-10-

### A1-2024-china-share
In April 2024 the host cited figures for the US slice of China's soybean imports.
What did he say it had fallen to for 2023 and from what level, and what
counterweight did he offer to all the bearish demand talk?
modality: figure
expects: 33, rally
cite-contains: shrank to 24% from 33% in 2021
max-span: 15
cite-file-matches: ^2024-04-30-

### A1-2024-saf-feedstock
In July 2024 the host discussed a headline about a 1,400% jump in US sustainable
aviation fuel capacity. Which US plant did he name as the only one able to run the
alcohol-to-jet pathway, and what feedstock did he say it was actually using?
modality: reasoning
expects: lanza, sugar
cite-contains: don't ask me how or why has a lower carbon score
max-span: 15
cite-file-matches: ^2024-07-18-

### A1-2024-where-the-risk-is
In August 2024, amid a global equity sell-off, the host argued the biggest
downside risk across commodities was not in grains. Which market did he point to
instead, and what positioning fact did he use to explain why grains were barely
moving?
modality: reasoning
expects: cattle, short
cite-contains: they've already gotten beat up the funds are already short
max-span: 15
cite-file-matches: ^2024-08-05-

### A1-2024-study-figures
In October 2024 the corn and soybean grower associations commissioned a study on
a renewed US-China trade war. What percentage export declines did it project for
each of the two crops?
modality: figure
expects: 52, 84
cite-contains: corn exports would fall by about 84%
max-span: 15
cite-file-matches: ^2024-10-16-

### A1-2025-stocks-use-shift
In late January 2025 the host explained the corn rally with a change in one
balance-sheet ratio. What was the projection at that point, and what had it been
when the market was bottoming the previous August?
modality: figure
expects: 10.2, 13.9
cite-contains: that projection was 13.9
max-span: 15
cite-file-matches: ^2025-01-30-

### A1-2025-ethanol-stocks-balloon
In February 2025 the host flagged an ethanol inventory print he called scary.
What was the number, what storage-capacity range did he cite for the country, and
what did he say he hoped the explanation was?
modality: figure
expects: 27.6, 26 million, bad data
cite-contains: the stocks number of 27.6 million barrels
max-span: 15
cite-file-matches: ^2025-02-27-

### A1-2025-party-line-derisking
In April 2025 the host relayed an observation from a friend about how one wealth
manager's clients were reacting to the equity sell-off. What split did he
describe, and along what line did it fall?
modality: anecdote
expects: party, 50
cite-contains: they are split distinctly along party affiliation
max-span: 15
cite-file-matches: ^2025-04-09-

### A1-2025-charting-vendor
In April 2025 the host explained on air why the charts on the show had got worse.
Which free consumer charting website did he accuse his expensive data vendor of
white-labelling, and which vendor was it?
modality: anecdote
expects: tradingview, lseg
cite-contains: they took tradingview.com they whitelabeled it
max-span: 15
cite-file-matches: ^2025-04-17-

### A1-2025-croptour-ohio
On the opening day of the August 2025 crop tour, what corn yield did scouts put on
Ohio, and what previous record did that figure top?
modality: figure
expects: 185.7, 185.1
cite-contains: corn yields were pegged at 185.7 bushels per acre
max-span: 15
cite-file-matches: ^2025-08-19-

### A1-2025-brazil-corn-puzzle
In August 2025, despite what everyone agreed was a monster Brazilian corn crop,
the host said Brazilian corn was still losing to US corn on the export market.
What price gap did he quote, and what was the first of the two explanations he
offered for it?
modality: reasoning
expects: 13, 33, holding
cite-contains: cheaper to the tune of $13 per ton or about 33 cents
max-span: 15
cite-file-matches: ^2025-08-19-

### A1-2025-tariff-revenue-bailout
In September 2025 the host said a farmer bailout was near-certain and would be
justified by tariff receipts. What receipts figures did he cite for that year and
the prior year, and what was his objection to the whole framing?
modality: figure
expects: 300 billion, 83, broke
cite-contains: tariff revenue this year will be $300 billion, up from 83 billion
max-span: 15
cite-file-matches: ^2025-09-22-

### A1-2025-bessent-cadence
In December 2025 the host tore into the Treasury Secretary's defence of Chinese
soybean buying. What word did the secretary use for China's buying pace, and what
did the host tell the soybean grower groups to go and do about it?
modality: opinion
expects: cadence, airplane
cite-contains: the time for writing letters to this administration has passed
max-span: 15
cite-file-matches: ^2025-12-04-

### A1-2026-one-post
In March 2026 the host said a single social-media post from the president had
moved markets on an extraordinary scale. What figure did he give for the
equity-market reaction, and what did he say it implied about everything else the
show had been analysing that day?
modality: opinion
expects: 2 trillion, trash
cite-contains: the stock market added $2 trillion in market cap
max-span: 15
cite-file-matches: ^2026-03-24-

### A1-2026-hrw-top-five
In April 2026 the host argued the national winter wheat rating was hiding the
real problem. What average good-to-excellent rating did he compute across the top
five hard red winter states, and what average poor-to-very-poor figure went with
it?
modality: figure
expects: 14.6, 47
cite-contains: average good to excellent rating of just 14.6%
max-span: 15
cite-file-matches: ^2026-04-21-

### A1-2026-nine-lives
In April 2026 the host relayed what growers in the southern plains were telling
him about the state of their crop. What expression did they use?
modality: anecdote
expects: nine lives
cite-contains: wheat's got nine lives
max-span: 15
cite-file-matches: ^2026-04-21-

### A1-2026-wheat-worst-since
In May 2026, what national good-to-excellent winter wheat rating did the show
report, and how far back did the host say you would have to go to find a worse
reading for that week of the year?
modality: figure
expects: 27, 1996
cite-contains: the lowest for the week since 1996
max-span: 15
cite-file-matches: ^2026-05-19-

### A1-2026-brazil-borrowing-costs
In May 2026 the host compared Brazilian farmers' borrowing costs with US rates.
What benchmark policy rate did he cite for Brazil, and what level did he say
private farm loans there could exceed?
modality: figure
expects: 14.5, 17
cite-contains: can be in excess of 17%
max-span: 15
cite-file-matches: ^2026-05-19-

## A2 — contradiction pairs (position reversed across the period)

### A2-blacksea-headlines-asof
What was the host's view, as of November 2022, on whether an escalation involving
Russia and NATO would move the grain markets, and why?
modality: conflict
expects: bullish, wheat, disruption
cite-contains: you'd see a massive disruption to wheat exports
max-span: 15
cite-file-matches: ^2022-11-16-

### A2-blacksea-headlines-both
How did the host's assessment of whether Black Sea war headlines still move the
grain markets change over the period?
modality: conflict
expects: 2022, 2023, spike, care
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-ethanol-corn-demand-asof
As of 10 March 2022, what was the host's stated concern about ethanol's
implications for the US corn balance sheet?
modality: conflict
expects: reduced, record, risk
cite-contains: high gas prices result in drastically reduced consumption
max-span: 15
cite-file-matches: ^2022-03-10-

### A2-ethanol-corn-demand-both
How did the host's view on ethanol as a threat to, or a support for, the US corn
balance sheet change over the period?
modality: conflict
expects: 2022, 2025, risk, fantastic
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-china-bean-commitment-asof
As of 4 December 2025, what was the host's account of whether China was following
through on the soybean volume announced in the White House fact sheet?
modality: conflict
expects: 19, 2.2, lying
cite-contains: because they want your vote
max-span: 15
cite-file-matches: ^2025-12-04-

### A2-china-bean-commitment-both
How did the host's account of whether China followed through on that announced
soybean volume change over the period?
modality: conflict
expects: 2025, 2026, 2.2, 11.9
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-corn-export-standing-asof
As of 10 April 2024, what was the host's view on how US corn stacked up against
rival origins on the world export market, and which origin did he say was
undercutting everyone into China?
modality: conflict
expects: not competitive, ukraine
cite-contains: we're just not competitive we're not competitive
max-span: 15
cite-file-matches: ^2024-04-10-

### A2-corn-export-standing-both
How did the host's view on how US corn stacks up against rival origins on the
world export market change over the period?
modality: conflict
expects: 2024, 2026, ukraine, competitive
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-usda-credibility-asof
As of 29 December 2020, what was the host's assessment of how much weight to put
on USDA's early-season supply and demand projections?
modality: conflict
expects: wrong, gospel
cite-contains: they're not gospel they're just projections
max-span: 15
cite-file-matches: ^2020-12-29-

### A2-usda-credibility-both
How did the host's stance on the trustworthiness of USDA's numbers and reports
change over the period?
modality: conflict
expects: 2020, 2024, gospel, gold standard
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-corn-acreage-shift-asof
As of 22 November 2021, what did the show expect for the size of the shift in US
corn plantings the following spring, and on what basis?
modality: conflict
expects: economics, decline
cite-contains: probably not that much because of where the economics at
max-span: 15
cite-file-matches: ^2021-11-22-

### A2-corn-acreage-shift-both
How did the show's expectation for the 2022 US corn acreage shift change between
the autumn budget work and the spring survey, and what was blamed for the
difference?
modality: conflict
expects: 2021, economics, 3.8, fertilizer
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-tradewar-damage-asof
As of 16 October 2024, what was the host's expectation for what a renewed
US-China tariff fight would do to the grain markets?
modality: conflict
expects: bad, exports
cite-contains: bad for markets it probably is
max-span: 15
cite-file-matches: ^2024-10-16-

### A2-tradewar-damage-both
How did the host's assessment of what a US-China tariff fight actually does to
grain prices change over the period?
modality: conflict
expects: 2024, 2025, bad, better
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-argentina-strikes-asof
As of 28 September 2020, what did the host say about whether an Argentine port
labour stoppage matters to the grain trade?
modality: conflict
expects: impact, movement
cite-contains: it does have the ability to impact the movement of grain
max-span: 15
cite-file-matches: ^2020-09-28-

### A2-argentina-strikes-both
How did the host's view on whether Argentine labour stoppages matter to the grain
trade change over the period?
modality: conflict
expects: 2020, 2025, impact, non-relevant
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-saf-corn-ethanol-asof
As of 12 September 2023, what was the host's stated outlook on what sustainable
aviation fuel would mean for US corn demand?
modality: conflict
expects: optimistic, big deal
cite-contains: optimistic about corn demand via ethanol
max-span: 15
cite-file-matches: ^2023-09-12-

### A2-saf-corn-ethanol-both
How did the host's outlook on what sustainable aviation fuel would mean for US
corn demand change over the period?
modality: conflict
expects: 2023, 2024, optimistic, hurdles
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-china-corn-buyer-asof
As of 6 October 2021, what did the show expect China's role in the world corn
import market to be over the following two to three years?
modality: conflict
expects: 15, 30 million, anomaly
cite-contains: in the neighborhood of 15 to 30 million tons
max-span: 15
cite-file-matches: ^2021-10-06-

### A2-china-corn-buyer-both
How did the show's view on whether China should be treated as a durable buyer of
US corn change over the period?
modality: conflict
expects: 2021, 2024, 15, three
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-dollar-index-asof
As of 18 July 2024, what was the host's view on the usefulness of the widely
quoted dollar index for grain traders, and which currency pair did he say
actually matters?
modality: conflict
expects: outdated, brazilian
cite-contains: the currency pair that matters for you guys
max-span: 15
cite-file-matches: ^2024-07-18-

### A2-dollar-index-both
How did the host's view on whether the widely quoted dollar index matters to the
grain markets change over the period?
modality: conflict
expects: 2024, 2025, brazilian, sentiment
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)

### A2-planting-delays-asof
As of 30 April 2024, what was the host's view on whether slow planting progress
could rally the corn market that spring, and what earlier year did he offer as
the analog for an extreme case?
modality: conflict
expects: missing the boat, 2019
cite-contains: you're probably missing the boat
max-span: 15
cite-file-matches: ^2024-04-30-

### A2-planting-delays-both
How did the host's view on whether slow planting progress can rally the corn
market change over the period?
modality: conflict
expects: 2024, 2025, boat, support
forbids-pattern: (outdated|superseded|no longer relevant|obsolete)
