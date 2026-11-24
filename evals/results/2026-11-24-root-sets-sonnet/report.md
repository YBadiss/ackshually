# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-24 16:22:29 +0000
- Questions: `root-sets.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.
- Pages sent: full PDF

## Summary

| Metric | Value |
|---|---|
| Questions run | 12 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 10/12 (83%) (+2 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 12/12 (100%) |
| Quotes matched on claimed page | 35/35 (100%) (+0 found on another page) |
| Quotes matched through fragments (layout-tolerant) / partial | 0 / 0 |
| Answers with every quote matched | 12/12 (100%) |
| Figure boxes sane (inside page, not degenerate/whole page) | – |
| Verdict time median / p90 (s) | 24.0 / 27.1 |
| Step 1 ready median / p90 (s) | 24.7 / 27.9 |
| Step 1 within 5 s | 0/12 (0%) |
| Total answer cost | $2.193 (judge extra: 56407 in / 1604 out tokens) |

## Page selection

| Metric | Value |
|---|---|
| Retrieval recall: every expected page sent | 4/4 (100%) (at least one: 4/4 (100%)) |
| Pages sent (first attempt) | 56/296 (19%); mean excerpt 14.0 pages |
| Full PDF chosen up front | 0/4 (0%)  |
| Excerpt size (attached bytes, median) | 4793 KB |
| Fallback to full PDF (excerpt said not_covered) | 0/4 (0%): ; fallback started at median – s; discarded attempts cost $0.000 |
| Evidence pages remapped (model cited an excerpt position) | 5 |
| Local prepare time (rank + build excerpt), median / max | 1333 / 1739 ms |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 6 | 10.2 / 25.3 | 10.4 / 25.5 | 10.6 / 25.7 | 11.4 / 26.3 | 11.4 / 26.3 | 13.4 / 28.4 |
| warm | 6 | 25.9 / 33.3 | 26.1 / 33.7 | 26.3 / 34.1 | 27.0 / 34.9 | 27.0 / 34.9 | 28.8 / 36.5 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 6 | 4 | 84902 | 0 | 471 | $0.3443 |
| warm | 6 | 4 | 35 | 163143 | 469 | $0.0212 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.34 · 5 q → $0.43 · 20 q → $0.75

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost | Sent | Recall |
|---|---|---|---|---|---|---|---|---|---|---|---|
| rs-01-on | cold | ok | correct | ✓ | 4/4 | 23.8 | 24.3 | 25.9 | $0.7155 | – | – |
| rs-01-off | cold | ok | correct | ✓ | 4/4 | 25.7 | 26.3 | 28.4 | $0.6463 | – | – |
| rs-02-on | warm | ok | correct | ✓ | 2/2 | 34.1 | 34.9 | 36.5 | $0.0228 | – | – |
| rs-02-off | warm | ok | partially_correct | ✓ | 2/2 | 27.1 | 27.9 | 28.8 | $0.0206 | – | – |
| rs-03-on | cold | ok | correct | ✓ | 4/4 | 10.6 | 11.4 | 13.4 | $0.1842 | 1,2,3,13,14,15,16,23,24,25,59,60,61,62 | ✓ |
| rs-03-off | warm | ok | partially_correct | ✓ | 3/3 | 24.0 | 24.7 | 26.7 | $0.0215 | – | – |
| rs-04-on | cold | ok | correct | ✓ | 2/2 | 7.3 | 7.8 | 9.5 | $0.1353 | 16,17,18,62,63,64,65,66,67,71,72,73 | ✓ |
| rs-04-off | warm | ok | correct | ✓ | 2/2 | 21.9 | 22.5 | 23.5 | $0.0197 | – | – |
| rs-05-on | cold | ok | correct | ✓ | 3/3 | 9.7 | 10.4 | 12.0 | $0.1866 | 9,10,11,17,18,19,20,21,22,23,57,58,59,60 | ✓ |
| rs-05-off | warm | ok | correct | ✓ | 3/3 | 26.3 | 27.0 | 28.9 | $0.0214 | – | – |
| rs-06-on | cold | ok | correct | ✓ | 3/3 | 9.0 | 9.6 | 10.9 | $0.1981 | 24,25,26,31,32,33,57,58,59,60,62,63,64,73,74,75 | ✓ |
| rs-06-off | warm | ok | correct | ✓ | 3/3 | 24.4 | 25.1 | 27.1 | $0.0209 | – | – |

## Rulebooks sent

| Id | Books in play | PDF sent | Confidence | Cited |
|---|---|---|---|---|
| rs-01-on | Law of Root + Learning to Play + Riverfolk | 21.9 MB | stated | Law of Root p.3, Law of Root p.11, Law of Root p.2, Law of Root p.12 |
| rs-01-off | Law of Root + Learning to Play | 20.5 MB | stated | Law of Root p.3, Law of Root p.11, Law of Root p.2, Law of Root p.12 |
| rs-02-on | Law of Root + Learning to Play + Riverfolk | 21.9 MB | stated | Law of Root p.12, Riverfolk p.5 |
| rs-02-off | Law of Root + Learning to Play | 20.5 MB | stated | Law of Root p.12 |
| rs-03-on | Law of Root + Learning to Play + Underworld | 22.8 MB → excerpt of 14 pages | stated | Law of Root p.15, Underworld p.4 |
| rs-03-off | Law of Root + Learning to Play | 20.5 MB | stated | Law of Root p.15 |
| rs-04-on | Law of Root + Learning to Play + Marauder | 27.0 MB → excerpt of 12 pages | stated | Law of Root p.17, Marauder p.7 |
| rs-04-off | Law of Root + Learning to Play | 20.5 MB | stated | Law of Root p.17 |
| rs-05-on | Law of Root + Learning to Play + Homeland | 24.0 MB → excerpt of 14 pages | stated | Law of Root p.19, Homeland p.3 |
| rs-05-off | Law of Root + Learning to Play | 20.5 MB | stated | Law of Root p.19, Law of Root p.25 |
| rs-06-on | Law of Root + Learning to Play + Law of Rootbotics | 31.7 MB → excerpt of 16 pages | stated | Law of Rootbotics p.2, Law of Root p.25 |
| rs-06-off | Law of Root + Learning to Play | 20.5 MB | not_covered | Law of Root p.22, Law of Root p.25, Law of Root p.2 |

## Misses

**rs-02-off** — The Riverfolk have 5 funds and someone just removed one of their trade posts. How many funds do they lose, and can they build that trade post again?
- judge **partially_correct**: The outcome matches the rulebook (11.2.5 I): they lose 3 funds (half of 5, rounded up) and the trade post is removed permanently. However, the expected ruling flags that Riverfolk is not in play, and the assistant noted this only as an assumption and then answered with 'stated' confidence. It also added unsupported detail, such as the track space staying empty, and guessed at which trade post was removed.
  - expected: They lose 3 funds (half, rounded up) and the trade post is removed from the game permanently (Law of Root 11.2.5), flagged as Riverfolk content that isn't in play.
  - got: They lose 3 funds; that trade post is gone permanently. (stated)

**rs-03-off** — I guessed the type of a facedown Corvid plot and got it wrong. What happens?
- judge **partially_correct**: The core outcome matches: on a wrong guess the plot stays face down and the shown card goes to the Corvids (13.2.4). But the expected ruling flags this as Underworld content that isn't in play. The assistant only treats the Corvids as in play via an assumption and does not say the rulebook content is outside the expansions in play, so it misses that important condition.
  - expected: The plot stays face down and you give the shown card to the Corvids (Law of Root 13.2.4 Exposure), flagged as Underworld content that isn't in play.
  - got: You give the card you showed to the Corvids. (stated)

