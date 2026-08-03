# Cross-Temporal Question Set — Grain Markets Corpus

**What this measures.** Whether a system can locate one topic in two or more
differently-dated episodes of a single podcast and reconcile them — including
correctly reporting when the host's position did *not* move. Every question is
constructed so that reading any single cited episode is insufficient: the answer
requires at least two dated observations placed against each other.

**Provenance.** Authored from `raw/` only, by an agent deliberately isolated from
the wiki, scripts, pipeline, and any pre-existing eval artifacts. No web search
was used. Nothing outside the 22 raw transcript files was read.

**Harness fields, added after authoring.** The question text and `expects:`
tokens are the isolated author's, unedited. Two fields were added mechanically
afterwards and are *not* author judgment: `cite-file-matches:` (an ERE over the
dates already named in `requires:`) and the `A1-` id prefix, which is what routes
a question into `eval-corpus.sh`'s dated-citation bucket — without it a question
scores in no bucket and the date leg silently reports `0/0 n/a`.

**Measured result (2026-08-03, 82-page wiki).** Both arms scored **26/30** on the
answer leg and **30/30** on the date leg — identical. See `runs/`. The arm with a
forced temporal router fired it 30/30 and changed nothing; the deficit it was
built to fix did not reproduce at n=30. Do not infer from an earlier 3/6 that
cross-temporal retrieval is broken here — that was noise.

**Corpus.** 22 episode transcripts of *Grain Markets and Other Stuff* (host:
Joe, Standard Grain), `asserted_at` spanning 2020-09-16 through 2022-12-16.
All 22 files are cited by at least one question.

**Composition achieved.**
- 30 questions total
- `change: no` — 16 (position materially unchanged across dates)
- `change: yes` — 14 (position, framing, or figure genuinely moved)
- Questions spanning 3 or more distinct dates — 9 (one spans 4)
- Modalities: reasoning 12, figure 9, opinion 5, advice 3, anecdote 1

**Grading.** `expects` tokens are graded by case-insensitive substring match
against the answer text. Tokens were chosen to appear verbatim in the
transcripts and to be short enough to survive ordinary rewording.

---

### A1-T1-china-shift-to-brazil-timing
In late September 2020 the host made a specific call about when China would stop
buying US soybeans and why; in February 2021 he revisited that same call. Did his
reasoning hold, and what did he say about how surprising the outcome should be?
modality: reasoning
requires: 2020-09-28-morning-92820-1fizn-o8_aa.md@2020-09-28, 2021-02-25-did-china-just-cancel-gsxzqzh8m7u.md@2021-02-25
expects: matter of when, couple months, cheaper
cite-file-matches: ^(2020-09-28|2021-02-25)
change: no

### A1-T2-fund-corn-length-characterization
On 14 Dec 2020 and again on 6 Sep 2022 the host reported the managed-money net
long in corn and characterized how unusual it was. Give both figures and both
characterizations.
modality: figure
requires: 2020-12-14-quick-update-fund-positions-e9mpfxboelm.md@2020-12-14, 2022-09-06-argentinas-soy-peso-efdf-k6x14m.md@2022-09-06
expects: 265, 205, not extreme
cite-file-matches: ^(2020-12-14|2022-09-06)
change: yes

### A1-T3-brazil-record-crop-confidence
Trace how the host's confidence in a record Brazilian soybean crop evolved from
his first mention in September 2020 through late February 2021. Quote the hedged
language he used at the start and the language he used at the end.
modality: opinion
requires: 2020-09-16-morning-91620-soybeans-push-higher-kzoa0bo1uec.md@2020-09-16, 2020-09-28-morning-92820-1fizn-o8_aa.md@2020-09-28, 2021-02-25-did-china-just-cancel-gsxzqzh8m7u.md@2021-02-25
expects: probable, very possible, record bean crop
cite-file-matches: ^(2020-09-16|2020-09-28|2021-02-25)
change: yes

### A1-T4-corn-condition-rating-july-2021
The host cited the national corn good-to-excellent rating on two occasions three
weeks apart in July 2021. What were the two figures?
modality: figure
requires: 2021-07-07-crops-and-social-media-uyoznkvamay.md@2021-07-07, 2021-07-27-crop-ratings-decline-markets-higher-pq7lhf4nkno.md@2021-07-27
expects: 64, good to excellent
cite-file-matches: ^(2021-07-07|2021-07-27)
change: no

### A1-T5-forecasting-humility
Across four episodes spanning more than two years the host stated his own stance
on whether market direction can be forecast. Characterize that stance and cite
the phrasing he used on at least two of those occasions.
modality: opinion
requires: 2020-12-17-top-5-bull-market-mistakes-x0ghzx4clvg.md@2020-12-17, 2021-02-02-crop-insurance-101-for-2021-zjkxvfwws1s.md@2021-02-02, 2021-05-03-i-dont-know-where-to-invest-6mkwca5alfm.md@2021-05-03, 2022-12-16-goldman-predicts-commodity-rally-new-contributors-wt7p6oxnpok.md@2022-12-16
expects: predict, i'm not one of them, tricky
cite-file-matches: ^(2020-12-17|2021-02-02|2021-05-03|2022-12-16)
change: no

### A1-T6-media-and-social-media-distortion
In December 2020 and again in July 2021 the host warned about a distortion in
what farmers see and hear. Describe the mechanism he named each time and how the
two warnings relate.
modality: advice
requires: 2020-12-17-top-5-bull-market-mistakes-x0ghzx4clvg.md@2020-12-17, 2021-07-07-crops-and-social-media-uyoznkvamay.md@2021-07-07
expects: sentiment follows price, 10 or 20, skew
cite-file-matches: ^(2020-12-17|2021-07-07)
change: no

### A1-T7-recession-versus-labor-market
Twice in 2022 — once by the host in March and once by a guest contributor in
December — the same rhetorical objection to recession talk was raised. State the
objection and the labor-market statistic cited on each date.
modality: reasoning
requires: 2022-03-30-potential-russian-withdrawal-rattles-markets-5nsmww2ikfe.md@2022-03-30, 2022-12-16-goldman-predicts-commodity-rally-new-contributors-wt7p6oxnpok.md@2022-12-16
expects: 11 million, recession, never happened
cite-file-matches: ^(2022-03-30|2022-12-16)
change: no

### A1-T8-2008-as-the-reference-crash
In June 2022 the host invoked a specific historical episode as his risk-off
worry, and in December 2022 a contributor invoked the same year on a different
basis. What was each argument?
modality: reasoning
requires: 2022-06-13-could-the-fed-kill-the-grain-markets-inflation-m2o1l1gj4fy.md@2022-06-13, 2022-12-16-goldman-predicts-commodity-rally-new-contributors-wt7p6oxnpok.md@2022-12-16
expects: 2008, seven dollars, similar structure
cite-file-matches: ^(2022-06-13|2022-12-16)
change: no

### A1-T9-rate-hike-warning-and-outcome
In May 2021 the host set out a worry about Fed policy that ran against the
consensus he described. Thirteen months later he reported what actually happened.
Describe the worry, in his own phrasing, and the June 2022 data that bore on it.
modality: reasoning
requires: 2021-05-03-i-dont-know-where-to-invest-6mkwca5alfm.md@2021-05-03, 2022-06-13-could-the-fed-kill-the-grain-markets-inflation-m2o1l1gj4fy.md@2022-06-13
expects: too hot too fast, 8.6, 75 basis point
cite-file-matches: ^(2021-05-03|2022-06-13)
change: no

### A1-T10-money-printing-thesis
Across May 2021, March 2022 and September 2022 the host developed a single thesis
about currency debasement, applying it to two different countries. State the
thesis and how he applied it in each of the three episodes.
modality: opinion
requires: 2021-05-03-i-dont-know-where-to-invest-6mkwca5alfm.md@2021-05-03, 2022-03-30-potential-russian-withdrawal-rattles-markets-5nsmww2ikfe.md@2022-03-30, 2022-09-06-argentinas-soy-peso-efdf-k6x14m.md@2022-09-06
expects: money printing, integrity, cautionary tale
cite-file-matches: ^(2021-05-03|2022-03-30|2022-09-06)
change: no

### A1-T11-why-gasoline-demand-is-weak
In September 2020 and September 2022 the host reported weak US gasoline demand
versus the prior year. Give the year-over-year figure he cited each time and the
explanation he offered each time.
modality: reasoning
requires: 2020-09-24-morning-92420-lbqvnhyluz8.md@2020-09-24, 2022-09-09-volatility-expected-traders-prepare-for-usda-report-in3azjnwptc.md@2022-09-09
expects: driving habits, 7.9, hand to mouth
cite-file-matches: ^(2020-09-24|2022-09-09)
change: yes

### A1-T12-ethanol-stocks-seasonal-standing
The host described where US ethanol stocks stood relative to their seasonal
history in March 2022 and again in September 2022. What did he say on each date?
modality: figure
requires: 2022-03-10-russiaukraine-talks-fail-invasion-enters-3rd-week-qzivonmmcdq.md@2022-03-10, 2022-09-09-volatility-expected-traders-prepare-for-usda-report-in3azjnwptc.md@2022-09-09
expects: record high, second highest, 2019
cite-file-matches: ^(2022-03-10|2022-09-09)
change: yes

### A1-T13-weekly-ethanol-production-run-rate
Give the weekly US ethanol production figure the host reported in late September
2020, in March 2022, and in September 2022, and describe the trajectory those
three prints imply.
modality: figure
requires: 2020-09-24-morning-92420-lbqvnhyluz8.md@2020-09-24, 2022-03-10-russiaukraine-talks-fail-invasion-enters-3rd-week-qzivonmmcdq.md@2022-03-10, 2022-09-09-volatility-expected-traders-prepare-for-usda-report-in3azjnwptc.md@2022-09-09
expects: 906, 1.028, 989
cite-file-matches: ^(2020-09-24|2022-03-10|2022-09-09)
change: yes

### A1-T14-corn-acreage-expectation-versus-report
In November 2021 the host's guest was asked directly whether the coming year
would bring a large decline in corn acreage, and gave an answer. In April 2022 the
host reported what USDA's survey actually showed. Contrast the two.
modality: reasoning
requires: 2021-11-22-fertilizer-prices-soar-2022-corn-soybean-budget-update-e954rzg1xtu.md@2021-11-22, 2022-04-01-usda-farmers-to-slash-corn-plantings-sthe8hmqh8u.md@2022-04-01
expects: probably not that much, 3.8 million, fertilizer
cite-file-matches: ^(2021-11-22|2022-04-01)
change: yes

### A1-T15-break-even-numbers-two-sources
The host relied on two different outside sources for cost-of-production numbers
during 2021 — one in February, one in November. Name the sources and give the
soybean break-even figure quoted in the earlier episode.
modality: figure
requires: 2021-02-02-crop-insurance-101-for-2021-zjkxvfwws1s.md@2021-02-02, 2021-11-22-fertilizer-prices-soar-2022-corn-soybean-budget-update-e954rzg1xtu.md@2021-11-22
expects: 8.94, iowa state, barron
cite-file-matches: ^(2021-02-02|2021-11-22)
change: yes

### A1-T16-crush-share-of-soybean-demand
The host stated how much of total US soybean demand domestic crushing accounts
for, once in September 2020 and once in November 2022. Give both statements.
modality: figure
requires: 2020-09-16-morning-91620-soybeans-push-higher-kzoa0bo1uec.md@2020-09-16, 2022-11-16-why-would-ww3-rally-the-grain-markets-gkdxxjoqs0k.md@2022-11-16
expects: about half, 51 percent, crush
cite-file-matches: ^(2020-09-16|2022-11-16)
change: no

### A1-T17-usda-numbers-deserve-error-bars
On two occasions two years apart the host argued that published USDA figures
carry far more uncertainty than traders treat them as carrying. What concrete
evidence did he present in December 2020, and what in September 2022?
modality: opinion
requires: 2020-12-29-grain-marketing-lessons-from-2020-x6v0tnhmrmc.md@2020-12-29, 2022-09-09-volatility-expected-traders-prepare-for-usda-report-in3azjnwptc.md@2022-09-09
expects: 3.32, 1.7, 168.1
cite-file-matches: ^(2020-12-29|2022-09-09)
change: no

### A1-T18-corn-priced-too-high-then-new-highs
At the end of September 2020 the host gave a view on whether the then-current
spot corn price was justified by the balance sheet. Three months later he
described where the corn market and that balance sheet had actually gone. Set the
two against each other.
modality: reasoning
requires: 2020-09-28-morning-92820-1fizn-o8_aa.md@2020-09-28, 2020-12-29-grain-marketing-lessons-from-2020-x6v0tnhmrmc.md@2020-12-29
expects: too high, stocks to use, new highs
cite-file-matches: ^(2020-09-28|2020-12-29)
change: yes

### A1-T19-forward-selling-after-a-punishing-year
At the end of 2020 the host stated whether the year's events would alter his own
marketing approach. In April 2021 he ran a statistical study bearing on the same
question. What did he conclude in each, and do they line up?
modality: advice
requires: 2020-12-29-grain-marketing-lessons-from-2020-x6v0tnhmrmc.md@2020-12-29, 2021-04-22-should-i-forward-contract-corn-on-may-1st-snsrsvgnxfk.md@2021-04-22
expects: responsible, 13 years, may 1st
cite-file-matches: ^(2020-12-29|2021-04-22)
change: no

### A1-T20-carry-structure-and-storage-decisions
In September 2020 the host explained why beans would come out of the field rather
than into the bin, and in February 2021 his guest reached a related conclusion
about where the opportunity lies for stored bushels. What market-structure fact
underlies both, and what did each conclude farmers should watch instead?
modality: reasoning
requires: 2020-09-24-morning-92420-lbqvnhyluz8.md@2020-09-24, 2021-02-02-crop-insurance-101-for-2021-zjkxvfwws1s.md@2021-02-02
expects: no carry, no incentive, basis
cite-file-matches: ^(2020-09-24|2021-02-02)
change: no

### A1-T21-argentine-farmer-selling-behavior
In September 2020 and September 2022 the host explained why Argentine farmers
withhold or are reluctant to market their crop. What did he identify each time,
and what specific policy response did he report in the later episode?
modality: reasoning
requires: 2020-09-24-morning-92420-lbqvnhyluz8.md@2020-09-24, 2022-09-06-argentinas-soy-peso-efdf-k6x14m.md@2022-09-06
expects: capital controls, inflation hedge, 200 pesos
cite-file-matches: ^(2020-09-24|2022-09-06)
change: no

### A1-T22-ukraine-bottleneck-diagnosis
In June 2022 the host stated plainly what the binding constraint on Ukrainian
grain was, and in December 2022 a contributor gave the condition under which the
market would actually react to war headlines. How do the two diagnoses relate?
modality: reasoning
requires: 2022-06-13-could-the-fed-kill-the-grain-markets-inflation-m2o1l1gj4fy.md@2022-06-13, 2022-12-16-goldman-predicts-commodity-rally-new-contributors-wt7p6oxnpok.md@2022-12-16
expects: it's not production, logistics, export capabilities
cite-file-matches: ^(2022-06-13|2022-12-16)
change: no

### A1-T23-ukraine-crop-figures-corn-then-wheat
In June 2022 the host reported a revision to Ukraine's corn crop; in September
2022 he reported estimates for Ukraine's next winter wheat crop. Give the key
figures from each and explain why they point in opposite directions.
modality: figure
requires: 2022-06-13-could-the-fed-kill-the-grain-markets-inflation-m2o1l1gj4fy.md@2022-06-13, 2022-09-06-argentinas-soy-peso-efdf-k6x14m.md@2022-09-06
expects: 25 million, 50 percent, winter wheat
cite-file-matches: ^(2022-06-13|2022-09-06)
change: yes

### A1-T24-how-markets-answered-war-headlines
Across March 2022, November 2022 and December 2022 the host and his contributors
described how speculative money responded to Russia-Ukraine headlines. Trace how
that described response evolved, using the words they used.
modality: reasoning
requires: 2022-03-30-potential-russian-withdrawal-rattles-markets-5nsmww2ikfe.md@2022-03-30, 2022-11-16-why-would-ww3-rally-the-grain-markets-gkdxxjoqs0k.md@2022-11-16, 2022-12-16-goldman-predicts-commodity-rally-new-contributors-wt7p6oxnpok.md@2022-12-16
expects: skittish, numb, de-escalated
cite-file-matches: ^(2022-03-30|2022-11-16|2022-12-16)
change: yes

### A1-T25-seasonal-high-timing-claim
In December 2020, February 2021 and April 2021 the host or his guest referred to
when grain market highs have typically occurred in recent years. What did they
say, and what word did the host use for the 2020 pattern that violated it?
modality: reasoning
requires: 2020-12-29-grain-marketing-lessons-from-2020-x6v0tnhmrmc.md@2020-12-29, 2021-02-02-crop-insurance-101-for-2021-zjkxvfwws1s.md@2021-02-02, 2021-04-22-should-i-forward-contract-corn-on-may-1st-snsrsvgnxfk.md@2021-04-22
expects: contra seasonal, june july, summer
cite-file-matches: ^(2020-12-29|2021-02-02|2021-04-22)
change: no

### A1-T26-reownership-stance
The host addressed buying back sold bushels on three occasions between September
and December 2020, including once with an analogy from outside agriculture and
once while conceding that year's outcome. Where did he end up?
modality: advice
requires: 2020-09-24-morning-92420-lbqvnhyluz8.md@2020-09-24, 2020-12-17-top-5-bull-market-mistakes-x0ghzx4clvg.md@2020-12-17, 2020-12-29-grain-marketing-lessons-from-2020-x6v0tnhmrmc.md@2020-12-29
expects: bass cat, exception to the rule, ownership
cite-file-matches: ^(2020-09-24|2020-12-17|2020-12-29)
change: no

### A1-T27-us-soybean-export-commitments-arc
Describe how the host and his October 2021 guest characterized the pace of US
soybean export commitments in September 2020, October 2021, and April 2022,
including the shortfall figures cited in the middle episode.
modality: figure
requires: 2020-09-24-morning-92420-lbqvnhyluz8.md@2020-09-24, 2021-10-06-phase-one-trade-deal-where-do-we-stand-wcy6zu79834.md@2021-10-06, 2022-04-01-usda-farmers-to-slash-corn-plantings-sthe8hmqh8u.md@2022-04-01
expects: best on record, 500 million, 100 million
cite-file-matches: ^(2020-09-24|2021-10-06|2022-04-01)
change: yes

### A1-T28-chinese-corn-buying-outlook
In October 2021 the host's China guest gave a forward baseline for Chinese corn
imports and called the prior year's buying by a particular name. In December 2022
the host reported the actual year-over-year change in Chinese purchases of US
corn. Contrast the expectation with the outcome.
modality: opinion
requires: 2021-10-06-phase-one-trade-deal-where-do-we-stand-wcy6zu79834.md@2021-10-06, 2022-12-16-goldman-predicts-commodity-rally-new-contributors-wt7p6oxnpok.md@2022-12-16
expects: 15 to 30, anomaly, 70 percent
cite-file-matches: ^(2021-10-06|2022-12-16)
change: yes

### A1-T29-subscription-price-over-time
The host quotes the monthly price of his subscription service in nearly every
episode. Compare the price quoted in September 2020 and April 2021 with the price
quoted from June 2022 onward.
modality: figure
requires: 2020-09-16-morning-91620-soybeans-push-higher-kzoa0bo1uec.md@2020-09-16, 2021-04-22-should-i-forward-contract-corn-on-may-1st-snsrsvgnxfk.md@2021-04-22, 2022-06-13-could-the-fed-kill-the-grain-markets-inflation-m2o1l1gj4fy.md@2022-06-13
expects: 49, 50
cite-file-matches: ^(2020-09-16|2021-04-22|2022-06-13)
change: yes

### A1-T30-from-solo-experiment-to-contributors
In December 2020 the host described how and why he had started the channel. Two
years later he described his accumulated output and announced a structural change
to how the show would be produced. What changed and what drove it?
modality: anecdote
requires: 2020-12-17-top-5-bull-market-mistakes-x0ghzx4clvg.md@2020-12-17, 2022-12-16-goldman-predicts-commodity-rally-new-contributors-wt7p6oxnpok.md@2022-12-16
expects: experiment, 851, vacation
cite-file-matches: ^(2020-12-17|2022-12-16)
change: yes
