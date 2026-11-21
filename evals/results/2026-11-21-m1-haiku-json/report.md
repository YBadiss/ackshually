# Bench report — claude-haiku-5-5 / json / effort low

- Date: 2026-11-21 19:01:47 +0000
- Questions: `m1.json`
- Model: `claude-haiku-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 25/28 (89%) (+3 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 27/27 (100%) |
| Quotes matched on claimed page | 75/80 (94%) (+2 found on another page) |
| Answers with every quote matched | 24/28 (86%) |
| Figure boxes sane (inside page, not degenerate/whole page) | – |
| Verdict time median / p90 (s) | 5.5 / 7.8 |
| Step 1 ready median / p90 (s) | 6.6 / 9.1 |
| Step 1 within 5 s | 8/28 (29%) |
| Total answer cost | $0.040 (judge extra: 79759 in / 3571 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 6.5 / 7.2 | 6.7 / 7.4 | 7.0 / 7.8 | 8.0 / 8.7 | 8.0 / 8.7 | 8.6 / 9.2 |
| warm | 23 | 5.0 / 10.1 | 5.1 / 10.3 | 5.3 / 10.7 | 6.2 / 12.0 | 6.2 / 12.0 | 7.0 / 12.8 |
| followup | 1 | 3.6 / 3.6 | 3.8 / 3.8 | 4.1 / 4.1 | 4.5 / 4.5 | 4.5 / 4.5 | 4.6 / 4.6 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 40539 | 0 | 713 | $0.0054 |
| warm | 23 | 4 | 27 | 39611 | 743 | $0.0008 |
| followup | 1 | 4 | 294 | 33935 | 224 | $0.0005 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.01 · 5 q → $0.01 · 20 q → $0.02

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 3/3 | 7.0 | 8.0 | 8.6 | $0.0045 |
| pg-02 | warm | ok | correct | ✓ | 3/3 | 7.2 | 8.7 | 9.7 | $0.0006 |
| pg-03 | warm | ok | correct | ✓ | 3/3 | 4.5 | 4.7 | 5.2 | $0.0005 |
| pg-04 | warm | ok | correct | ✓ | 3/3 | 5.3 | 6.2 | 7.0 | $0.0006 |
| pg-05 | warm | ok | correct | ✓ | 2/2 | 6.9 | 7.2 | 7.6 | $0.0007 |
| pg-06 | followup | ok | correct | ✓ | 1/1 | 4.1 | 4.5 | 4.6 | $0.0005 |
| pg-07 | warm | ok | partially_correct | TODO | 1/2 | 6.3 | 7.2 | 7.8 | $0.0006 |
| pg-08 | warm | ok | correct | ✓ | 3/3 | 12.3 | 13.9 | 15.7 | $0.0009 |
| rt-01 | cold | ok | correct | ✓ | 2/2 | 5.8 | 6.7 | 7.0 | $0.0078 |
| rt-02 | warm | ok | correct | ✓ | 3/3 | 7.8 | 9.1 | 10.0 | $0.0010 |
| rt-03 | warm | ok | correct | ✓ | 5/5 | 11.5 | 13.2 | 14.6 | $0.0015 |
| rt-04 | warm | ok | correct | ✓ | 2/3 | 6.0 | 6.6 | 7.4 | $0.0009 |
| rt-05 | warm | ok | correct | ✓ | 1/3 | 5.0 | 5.9 | 6.6 | $0.0009 |
| rt-06 | warm | ok | correct | ✓ | 4/4 | 10.7 | 12.0 | 12.8 | $0.0014 |
| az-01 | cold | ok | partially_correct | ✓ | 3/3 | 7.8 | 8.7 | 9.2 | $0.0026 |
| az-02 | warm | ok | correct | ✓ | 2/2 | 2.8 | 4.1 | 4.7 | $0.0004 |
| az-03 | warm | ok | correct | ✓ | 2/2 | 6.9 | 8.0 | 8.6 | $0.0006 |
| az-04 | warm | ok | correct | ✓ | 4/4 | 5.0 | 6.7 | 7.3 | $0.0008 |
| az-05 | warm | ok | correct | ✓ | 4/4 | 2.3 | 3.1 | 3.5 | $0.0004 |
| az-06 | warm | ok | correct | ✓ | 3/3 | 5.5 | 6.6 | 7.3 | $0.0009 |
| az-07 | warm | ok | correct | ✓ | 2/2 | 5.3 | 5.9 | 6.2 | $0.0006 |
| du-01 | cold | ok | correct | ✓ | 3/3 | 6.3 | 6.9 | 7.8 | $0.0068 |
| du-02 | warm | ok | correct | ✓ | 3/3 | 2.8 | 3.6 | 4.0 | $0.0007 |
| du-03 | warm | ok | correct | ✓ | 2/2 | 2.5 | 3.3 | 3.7 | $0.0007 |
| du-04 | warm | ok | partially_correct | ✓ | 2/3 | 4.1 | 5.6 | 6.4 | $0.0008 |
| du-05 | warm | ok | correct | ✓ | 3/3 | 2.8 | 3.7 | 4.6 | $0.0008 |
| du-06 | warm | ok | correct | ✓ | 4/4 | 2.5 | 3.9 | 4.6 | $0.0009 |
| du-07 | warm | ok | correct | ✓ | 2/2 | 4.1 | 5.3 | 5.6 | $0.0007 |

## Misses

**pg-07** — Can I lend 20 Elektro to another player and have them pay me back next round?
- judge **partially_correct**: The expected ruling is that the rulebook does not cover loans or player-to-player money transfers, so it is a house-rule decision. The assistant gets part of this right: it says the rules do not address private arrangements and flags its confidence as inferred. But it leads with a flat "No. The rulebook does not allow players to lend or trade money", which claims a prohibition the pages do not state. The pages only show payments to and from the bank and say nothing forbidding lending. The branch about a private side arrangement does say the rules do not address it, but the headline verdict conflicts with the not-covered ruling.
  - expected: Not covered by the rulebook (no rules for loans or trading money between players); treat as a house-rule decision.
  - got: No. The rulebook does not allow players to lend or trade money with each other; Elektro is only paid to or from the bank. Any repayment arrangement between players is outside the rules. (inferred)
- step 1 p.5: matched on p.4 (claimed p.5) — “The player pays their highest bid to the bank and takes the power plant”

**rt-04** — If I have to spend a fox card, can I spend a bird card instead? And the other way round?
- step 3 p.6: not matched (best error 20%) — “If the action said you must spend a matching card, you could spend a fox or a bird card, since birds are wild.”

**rt-05** — As the Woodland Alliance, does spreading sympathy into a clearing with 3 Marquise warriors cost the normal amount?
- step 1 p.15: not matched (best error 33%) — “You must spend supporters as shown by the cost on your Sympathy track.”
- step 2 p.15: not matched (best error 41%) — “If the target clearing has three or more warriors of another player, you must spend another matching supporter to place ”

**az-01** — I'm the first to take from the center. Do I have to take the first-player tile, and does it cost me anything?
- judge **partially_correct**: The assistant correctly says you must take the marker, place it on the leftmost free floor-line space, and lose points for it at the end of Wall-tiling. It never says you start the next round, and the expected ruling includes that. The rulebook supports it: the starting player marker stays with its holder and that player starts the next round. The extra claim that the penalty is -1 on an empty floor line is plausible, but the pages shown do not state the value. The omission of the next-round start makes the answer incomplete.
  - expected: Yes: you must take it, place it on the leftmost free space of your floor line (it counts as a floor tile, so it costs points), and you start the next round.
  - got: Yes, you must take the starting player marker and place it on the leftmost free space of your floor line. It costs you points at the end of the Wall-tiling phase, based on the penalty printed above the space it occupies (-1 if it lands on the leftmost space of an empty floor line). (stated)

**du-04** — I send an agent to a combat space. How many troops can I put into the conflict?
- judge **partially_correct**: The main ruling matches the rulebook: any troops recruited this turn plus up to two from the garrison. But the branch about a defensive bonus from your supply is misapplied. The rulebook ties it to when a Conflict card is revealed for a space you control, which is not part of sending an Agent to a Combat space. The assistant also wrongly limits it to Imperial Basin or Carthag and omits Arrakeen. It adds this as an extra troop allowance on top of the deployment limit, which muddies the answer to the question asked.
  - expected: Any troops you recruited this turn, plus up to 2 troops from your garrison.
  - got: You may deploy any or all troops you recruit during your current turn (from the board space and the card you played), plus up to two more troops from your garrison. (stated)
- step 3 p.16: matched on p.17 (claimed p.16) — “you may deploy up to two more troops from your garrison.”

