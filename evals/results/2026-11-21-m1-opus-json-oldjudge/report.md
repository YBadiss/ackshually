# Bench report — claude-opus-5-5 / json / effort low

- Date: 2026-11-21 18:37:22 +0000
- Questions: `m1.json`
- Model: `claude-opus-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 25/28 (89%) (+1 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 27/27 (100%) |
| Quotes matched on claimed page | 91/95 (96%) (+0 found on another page) |
| Answers with every quote matched | 25/28 (89%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 6.1 / 8.2 |
| Step 1 ready median / p90 (s) | 7.6 / 9.9 |
| Step 1 within 5 s | 5/28 (18%) |
| Total answer cost | $1.310 (judge extra: 21813 in / 3278 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 9.0 / 9.0 | 9.2 / 9.4 | 9.6 / 10.1 | 11.1 / 11.4 | 11.1 / 11.4 | 12.7 / 13.2 |
| warm | 23 | 4.8 / 5.9 | 5.0 / 6.9 | 5.5 / 7.8 | 7.2 / 9.7 | 7.4 / 9.7 | 8.5 / 11.6 |
| followup | 1 | 5.2 / 5.2 | 5.4 / 5.4 | 6.1 / 6.1 | 8.0 / 8.0 | 8.0 / 8.0 | 9.2 / 9.2 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 40539 | 0 | 553 | $0.2138 |
| warm | 23 | 4 | 27 | 39611 | 547 | $0.0190 |
| followup | 1 | 4 | 344 | 33935 | 458 | $0.0177 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.21 · 5 q → $0.29 · 20 q → $0.57

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 3/3 | 10.1 | 11.1 | 12.7 | $0.1792 |
| pg-02 | warm | ok | correct | ✓ | 5/5 | 7.4 | 9.7 | 12.2 | $0.0217 |
| pg-03 | warm | ok | correct | ✓ | 3/3 | 8.2 | 8.3 | 8.5 | $0.0139 |
| pg-04 | warm | ok | incorrect | ✓ | 3/3 | 5.5 | 7.8 | 9.3 | $0.0196 |
| pg-05 | warm | ok | correct | ✓ | 2/2 | 6.2 | 8.0 | 8.3 | $0.0135 |
| pg-06 | followup | ok | correct | ✓ | 2/2 | 6.1 | 8.0 | 9.2 | $0.0177 |
| pg-07 | warm | ok | correct | TODO | 3/3 | 6.1 | 8.5 | 9.8 | $0.0181 |
| pg-08 | warm | ok | correct | ✓ | 3/3 | 6.1 | 7.6 | 8.9 | $0.0163 |
| rt-01 | cold | ok | correct | ✓ | 3/4 | 9.6 | 11.4 | 13.2 | $0.3180 |
| rt-02 | warm | ok | correct | ✓ | 4/4 | 9.3 | 11.7 | 13.1 | $0.0248 |
| rt-03 | warm | ok | correct | ✓ | 4/4 | 6.8 | 9.4 | 11.5 | $0.0264 |
| rt-04 | warm | ok | correct | ✓ | 3/4 | 6.5 | 7.6 | 9.3 | $0.0223 |
| rt-05 | warm | ok | correct | ✓ | 1/3 | 6.4 | 7.4 | 9.1 | $0.0224 |
| rt-06 | warm | ok | correct | ✓ | 3/3 | 7.8 | 9.9 | 11.6 | $0.0247 |
| az-01 | cold | ok | correct | ✓ | 4/4 | 4.3 | 6.3 | 8.7 | $0.0877 |
| az-02 | warm | ok | correct | ✓ | 3/3 | 3.3 | 4.1 | 5.8 | $0.0124 |
| az-03 | warm | ok | correct | ✓ | 4/4 | 3.5 | 4.6 | 6.5 | $0.0132 |
| az-04 | warm | ok | correct | ✓ | 3/3 | 3.7 | 6.1 | 7.8 | $0.0159 |
| az-05 | warm | ok | correct | ✓ | 4/4 | 3.8 | 4.5 | 6.1 | $0.0122 |
| az-06 | warm | ok | correct | ✓ | 4/4 +box | 3.6 | 6.0 | 7.9 | $0.0168 |
| az-07 | warm | ok | incorrect | ✓ | 3/3 | 3.2 | 4.3 | 6.0 | $0.0123 |
| du-01 | cold | ok | correct | ✓ | 3/3 | 6.6 | 7.7 | 9.2 | $0.2702 |
| du-02 | warm | ok | correct | ✓ | 3/3 | 4.9 | 6.6 | 7.9 | $0.0201 |
| du-03 | warm | ok | correct | ✓ | 3/3 | 3.7 | 5.0 | 6.3 | $0.0196 |
| du-04 | warm | ok | partially_correct | ✓ | 4/4 | 5.1 | 7.4 | 9.1 | $0.0225 |
| du-05 | warm | ok | correct | ✓ | 3/3 | 3.9 | 5.1 | 6.7 | $0.0205 |
| du-06 | warm | ok | correct | ✓ | 4/4 | 5.8 | 6.9 | 9.6 | $0.0234 |
| du-07 | warm | ok | correct | ✓ | 4/4 | 3.2 | 6.4 | 8.5 | $0.0248 |

## Misses

**pg-04** — Early game: can I build a house in Berlin if my friend already has one there?
- judge **incorrect**: The core ruling (No in Step 1, since a city holds one player's house) matches. But the assistant gets the Step 2 cost wrong: it says the second house costs 15 Elektro, while the expected ruling gives 10 for the first, 15 for the second, and 20 for the third space. That is arguably right, since the first house takes the 10 space. It also omits the rule that a player may never connect to the same city twice, though that is not needed for this question. The added Trust branch (blocked until Step 3 in a two-player game) is unsupported and may contradict the rules, because with two players Step 2 allows two houses. It asserts something the rulebook does not say, so the answer is incorrect.
  - expected: Not in Step 1: each city can only be connected by one player. In Step 2 two players can connect to a city, in Step 3 three (spaces cost 10, 15, 20 Elektro). A player may never connect to the same city twice.
  - got: No. In Step 1 each city can hold only one player's house, so Berlin is closed to you until Step 2 begins, when you could add the second house for 15 Elektro plus connection costs. (stated)

**rt-01** — I'm the attacker. Can I play an ambush card?
- step 3 p.9: not matched (best error 38%) — “At start of battle, defender may play to deal two immediate hits, unless attacker plays a matching ambush card.”

**rt-04** — If I have to spend a fox card, can I spend a bird card instead? And the other way round?
- step 2 p.6: not matched (best error 20%) — “If the action said you must spend a matching card, you could spend a fox or a bird card, since birds are wild.”

**rt-05** — As the Woodland Alliance, does spreading sympathy into a clearing with 3 Marquise warriors cost the normal amount?
- step 1 p.15: not matched (best error 33%) — “You must spend supporters as shown by the cost on your Sympathy track.”
- step 2 p.15: not matched (best error 41%) — “If the target clearing has three or more warriors of another player, you must spend another matching supporter to place ”

**az-07** — can i throw red on the line that's already got blue on it
- judge **incorrect**: The outcome matches the expected ruling (No, only the same color can be added to a line already holding tiles), but the reasoning claims the rulebook gives an exact example about yellow tiles on a line with a blue tile. That example is not confirmed to be in the rulebook, so the response claims the rulebook says something it may not. Under the grading criteria, claiming the rulebook says something it does not makes the response incorrect.
  - expected: No. If a pattern line already holds tiles, you may only add tiles of the same color.
  - got: No. A pattern line that already holds tiles only accepts more tiles of that same color, so red can't go on a line holding blue. Put the red in another legal line or in your floor line. (stated)

**du-04** — I send an agent to a combat space. How many troops can I put into the conflict?
- judge **partially_correct**: The main verdict matches the expected ruling: all troops recruited this turn plus up to 2 from the garrison. However, the extra branch about deploying one troop from supply as a defensive bonus for a space you already control is not in the rulebook (Dune: Imperium has no such rule), so it is a fabricated rule claim. The core answer is right, but this invented detail undermines it.
  - expected: Any troops you recruited this turn, plus up to 2 troops from your garrison.
  - got: You may deploy any or all troops you recruited this turn (from both the board space and the card you played), plus up to two more troops already in your garrison. (stated)

