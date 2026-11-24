# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-24 16:29:15 +0000
- Questions: `root-sets.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.
- Pages sent: **page selection** — top 4 BM25 pages + 0 neighbour(s), as pdf, full PDF if ≥75% of pages, re-ask with full PDF on not_covered

## Summary

| Metric | Value |
|---|---|
| Questions run | 12 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 8/12 (67%) (+4 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 12/12 (100%) |
| Quotes matched on claimed page | 32/32 (100%) (+0 found on another page) |
| Quotes matched through fragments (layout-tolerant) / partial | 0 / 0 |
| Answers with every quote matched | 12/12 (100%) |
| Figure boxes sane (inside page, not degenerate/whole page) | – |
| Verdict time median / p90 (s) | 4.3 / 5.3 |
| Step 1 ready median / p90 (s) | 4.9 / 5.9 |
| Step 1 within 5 s | 8/12 (67%) |
| Total answer cost | $0.777 (judge extra: 40518 in / 1646 out tokens) |

## Page selection

| Metric | Value |
|---|---|
| Retrieval recall: every expected page sent | 12/12 (100%) (at least one: 12/12 (100%)) |
| Pages sent (first attempt) | 48/760 (6%); mean excerpt 4.0 pages |
| Full PDF chosen up front | 0/12 (0%)  |
| Excerpt size (attached bytes, median) | 1489 KB |
| Fallback to full PDF (excerpt said not_covered) | 1/12 (8%): rs-06-off; fallback started at median 4.0 s; discarded attempts cost $0.065 |
| Evidence pages remapped (model cited an excerpt position) | 3 |
| Local prepare time (rank + build excerpt), median / max | 408 / 696 ms |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 6 | 3.7 / 4.5 | 4.0 / 4.7 | 4.3 / 4.7 | 4.9 / 5.7 | 4.9 / 5.7 | 6.4 / 7.2 |
| warm | 6 | 3.8 / 4.8 | 4.6 / 29.3 | 4.6 / 29.5 | 5.2 / 30.2 | 5.2 / 30.3 | 6.7 / 31.7 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 6 | 4 | 13950 | 0 | 456 | $0.0604 |
| warm | 6 | 4 | 15565 | 26710 | 419 | $0.0691 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.06 · 5 q → $0.34 · 20 q → $1.37

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost | Sent | Recall |
|---|---|---|---|---|---|---|---|---|---|---|---|
| rs-01-on | cold | ok | correct | ✓ | 4/4 | 3.4 | 4.1 | 5.8 | $0.0583 | 11,58,59,63 | ✓ |
| rs-01-off | cold | ok | partially_correct | ✓ | 3/3 | 4.7 | 5.7 | 7.2 | $0.0627 | 11,18,38,46 | ✓ |
| rs-02-on | warm | ok | partially_correct | ✓ | 2/2 | 3.7 | 4.5 | 5.6 | $0.0600 | 12,13,60,61 | ✓ |
| rs-02-off | warm | ok | partially_correct | ✓ | 2/2 | 4.1 | 4.8 | 5.7 | $0.0649 | 12,13,24,45 | ✓ |
| rs-03-on | cold | ok | correct | ✓ | 4/4 | 3.8 | 4.4 | 5.9 | $0.0623 | 14,15,60,61 | ✓ |
| rs-03-off | warm | ok | correct | ✓ | 3/3 | 4.4 | 4.8 | 6.3 | $0.0726 | 2,14,15,24 | ✓ |
| rs-04-on | cold | ok | correct | ✓ | 2/2 | 4.3 | 4.9 | 6.4 | $0.0567 | 17,63,65,66 | ✓ |
| rs-04-off | warm | ok | correct | ✓ | 2/2 | 5.3 | 5.9 | 7.0 | $0.0610 | 1,17,18,32 | ✓ |
| rs-05-on | cold | ok | correct | ✓ | 3/3 | 4.3 | 4.9 | 6.8 | $0.0618 | 10,19,58,59 | ✓ |
| rs-05-off | warm | ok | partially_correct | ✓ | 2/2 | 4.6 | 5.2 | 6.7 | $0.0716 | 10,18,19,22 | ✓ |
| rs-06-on | cold | ok | correct | ✓ | 3/3 | 3.9 | 4.4 | 5.6 | $0.0605 | 32,58,59,63 | ✓ |
| rs-06-off | warm | ok | correct | ✓ | 2/2 | 29.5 | 30.3 | 31.7 | $0.0848 | 12,22,25,32 → full | ✓ |

## Rulebooks sent

| Id | Books in play | PDF sent | Confidence | Cited |
|---|---|---|---|---|
| rs-01-on | Law of Root + Learning to Play + Riverfolk | 21.9 MB → excerpt of 4 pages | stated | Law of Root p.11, Riverfolk p.3 |
| rs-01-off | Law of Root + Learning to Play | 20.5 MB → excerpt of 4 pages | stated | Learning to Play p.6, Law of Root p.11 |
| rs-02-on | Law of Root + Learning to Play + Riverfolk | 21.9 MB → excerpt of 4 pages | stated | Law of Root p.12, Riverfolk p.5 |
| rs-02-off | Law of Root + Learning to Play | 20.5 MB → excerpt of 4 pages | stated | Law of Root p.12 |
| rs-03-on | Law of Root + Learning to Play + Underworld | 22.8 MB → excerpt of 4 pages | stated | Law of Root p.15, Underworld p.4 |
| rs-03-off | Law of Root + Learning to Play | 20.5 MB → excerpt of 4 pages | stated | Law of Root p.15 |
| rs-04-on | Law of Root + Learning to Play + Marauder | 27.0 MB → excerpt of 4 pages | stated | Law of Root p.17, Marauder p.7 |
| rs-04-off | Law of Root + Learning to Play | 20.5 MB → excerpt of 4 pages | stated | Law of Root p.17 |
| rs-05-on | Law of Root + Learning to Play + Homeland | 24.0 MB → excerpt of 4 pages | stated | Law of Root p.19, Homeland p.3 |
| rs-05-off | Law of Root + Learning to Play | 20.5 MB → excerpt of 4 pages | stated | Law of Root p.19 |
| rs-06-on | Law of Root + Learning to Play + Law of Rootbotics | 31.7 MB → excerpt of 4 pages | stated | Law of Rootbotics p.2, Law of Rootbotics p.7 |
| rs-06-off | Law of Root + Learning to Play | 20.5 MB → excerpt of 4 pages | not_covered | Law of Root p.22, Law of Root p.2 |

## Misses

**rs-01-off** — I'm playing the Lizard Cult. Can I use a bird card as wild to pay for a ritual?
- judge **partially_correct**: The verdict matches: bird cards are not wild for Cult rituals (10.2.2). But the assistant omits that the Lizard Cult is Riverfolk Expansion content not in play, and only mentions it in an assumption. Its reasoning also adds an unsupported claim that a bird card cannot match a clearing of any suit for building. That contradicts 10.2.2 as it applies to rituals, though it may be a muddled paraphrase. The rule itself (10.2.2) is cited correctly in substance.
  - expected: No: bird cards are not wild for Cult rituals (Law of Root 10.2.2), flagged as Riverfolk content that isn't in play.
  - got: No, bird cards are not wild for Cult rituals. (stated)

**rs-02-on** — The Riverfolk have 5 funds and someone just removed one of their trade posts. How many funds do they lose, and can they build that trade post again?
- judge **partially_correct**: The outcome matches: they lose 3 funds (half of 5, rounded up) and the trade post is permanently removed and cannot be rebuilt. The Law of Root 11.2.5 supports this. However, the assistant says the learning guide 'says the same', but the guide only says 'remove half of your funds' without 'rounded up', and the response misses that the Law of Root overrides the guide on this point. This is a minor misattribution; the core answer is right, so it is mostly correct, but the claim that the guide says the same is inaccurate regarding rounding.
  - expected: They lose 3 funds (half, rounded up) and the trade post leaves the game for good. The Law of Root (rules reference, 11.2.5 Trade Disruption) adds 'rounded up', which the Riverfolk learning guide leaves out; it overrides the guide.
  - got: They remove 3 funds, and that trade post is gone forever. (stated)

**rs-02-off** — The Riverfolk have 5 funds and someone just removed one of their trade posts. How many funds do they lose, and can they build that trade post again?
- judge **partially_correct**: The outcome is right: 3 funds lost and the trade post is permanently removed (11.2.5 Trade Disruption). But the expected ruling also flags this as Riverfolk content that isn't in play, and the assistant only says it assumes the expansion is in play, so it never flags the Riverfolk as out of play.
  - expected: They lose 3 funds (half, rounded up) and the trade post is removed from the game permanently (Law of Root 11.2.5), flagged as Riverfolk content that isn't in play.
  - got: They lose three funds, and that trade post is gone permanently. (stated)

**rs-05-off** — With the frogs in the game, can I draw from the Pond instead of the deck when I draw cards?
- judge **partially_correct**: The outcome matches: the first card of a draw may come from the top of the Pond (16.2.3), and the assistant's extra detail is supported by the pages. But the expected ruling flags this as Homeland content that is not in play, and the assistant instead assumes it is in play and gives a flat yes. It does mention Homeland as an assumption, but it frames it as being in play, not as out of scope.
  - expected: Yes, the first card you draw may come from the top of the Pond (Law of Root 16.2.3), flagged as Homeland content that isn't in play.
  - got: Yes, you may take the first card from the Pond. (stated)

