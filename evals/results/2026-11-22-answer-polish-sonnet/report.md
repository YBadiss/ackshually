# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-22 08:35:39 +0000
- Questions: `m1.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.
- Pages sent: full PDF

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 25/28 (89%) (+2 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 27/27 (100%) |
| Quotes matched on claimed page | 84/86 (98%) (+0 found on another page) |
| Answers with every quote matched | 26/28 (93%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 5.0 / 8.4 |
| Step 1 ready median / p90 (s) | 5.6 / 9.2 |
| Step 1 within 5 s | 12/28 (43%) |
| Total answer cost | $0.902 (judge extra: 84660 in / 3904 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 7.9 / 9.9 | 8.4 / 10.3 | 8.4 / 10.7 | 9.2 / 11.0 | 9.2 / 11.0 | 11.8 / 13.1 |
| warm | 23 | 4.0 / 7.2 | 4.4 / 7.7 | 4.8 / 7.7 | 5.1 / 8.3 | 5.1 / 8.3 | 7.1 / 11.2 |
| followup | 1 | 3.6 / 3.6 | 4.0 / 4.0 | 4.3 / 4.3 | 4.7 / 4.7 | 4.7 / 4.7 | 6.3 / 6.3 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 41247 | 0 | 490 | $0.1699 |
| warm | 23 | 4 | 27 | 40319 | 514 | $0.0093 |
| followup | 1 | 4 | 397 | 34643 | 341 | $0.0085 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.17 · 5 q → $0.21 · 20 q → $0.35

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 4/4 | 10.7 | 11.0 | 13.1 | $0.1437 |
| pg-02 | warm | ok | correct | ✓ | 4/4 | 5.3 | 5.6 | 8.2 | $0.0092 |
| pg-03 | warm | ok | correct | ✓ | 3/3 | 5.0 | 5.8 | 7.8 | $0.0076 |
| pg-04 | warm | ok | correct | ✓ | 3/3 | 6.2 | 6.9 | 9.6 | $0.0095 |
| pg-05 | warm | ok | correct | ✓ | 2/2 | 6.0 | 6.7 | 8.2 | $0.0074 |
| pg-06 | followup | ok | correct | ✓ | 1/1 | 4.3 | 4.7 | 6.3 | $0.0085 |
| pg-07 | warm | ok | correct | TODO | 3/3 | 5.3 | 6.4 | 8.0 | $0.0077 |
| pg-08 | warm | ok | partially_correct | ✓ | 3/3 | 5.6 | 6.0 | 7.9 | $0.0078 |
| rt-01 | cold | ok | correct | ✓ | 3/3 | 8.4 | 9.2 | 11.8 | $0.2523 |
| rt-02 | warm | ok | correct | ✓ | 4/4 | 6.4 | 7.3 | 11.7 | $0.0151 |
| rt-03 | warm | ok | partially_correct | ✓ | 2/3 | 8.8 | 9.2 | 12.9 | $0.0139 |
| rt-04 | warm | ok | correct | ✓ | 3/4 | 8.9 | 9.3 | 11.2 | $0.0109 |
| rt-05 | warm | ok | correct | ✓ | 3/3 | 6.8 | 7.0 | 9.1 | $0.0110 |
| rt-06 | warm | ok | incorrect | ✓ | 3/3 | 7.7 | 8.3 | 10.4 | $0.0115 |
| az-01 | cold | ok | correct | ✓ | 4/4 | 4.6 | 5.0 | 7.2 | $0.0675 |
| az-02 | warm | ok | correct | ✓ | 3/3 | 2.7 | 3.5 | 5.8 | $0.0068 |
| az-03 | warm | ok | correct | ✓ | 3/3 | 3.1 | 3.5 | 5.2 | $0.0060 |
| az-04 | warm | ok | correct | ✓ | 3/3 | 1.9 | 2.7 | 5.2 | $0.0078 |
| az-05 | warm | ok | correct | ✓ | 3/3 | 3.0 | 3.4 | 4.8 | $0.0059 |
| az-06 | warm | ok | correct | ✓ | 3/3 +box | 2.8 | 3.2 | 6.3 | $0.0089 |
| az-07 | warm | ok | correct | ✓ | 3/3 | 2.5 | 2.9 | 4.7 | $0.0058 |
| du-01 | cold | ok | correct | ✓ | 3/3 | 7.0 | 7.4 | 9.4 | $0.2161 |
| du-02 | warm | ok | correct | ✓ | 2/2 | 3.3 | 3.9 | 5.1 | $0.0089 |
| du-03 | warm | ok | correct | ✓ | 4/4 | 4.8 | 5.1 | 7.1 | $0.0101 |
| du-04 | warm | ok | correct | ✓ | 3/3 | 2.8 | 3.6 | 5.4 | $0.0101 |
| du-05 | warm | ok | correct | ✓ | 3/3 | 4.2 | 4.9 | 6.7 | $0.0098 |
| du-06 | warm | ok | correct | ✓ | 4/4 | 2.9 | 3.6 | 6.1 | $0.0116 |
| du-07 | warm | ok | correct | ✓ | 2/2 | 2.6 | 2.9 | 5.0 | $0.0104 |

## Misses

**pg-08** — do i gotta put a house down round one or can i chill and start later
- judge **partially_correct**: The core ruling is right and stated by the rulebook: players need not choose starting cities in round one and may start later, possibly to influence player order. But step 3 adds claims the pages do not support. It says the house "moves to the bottom row of the player order track" because the player built nothing, but the rulebook moves the house to the bottom row after buying a power plant or finishing the build phase, not as a result of skipping. It also says "you start later for 10 Elektro", which is only the starting-city cost and is not specifically tied to starting later. The round-one power plant purchase is supported.
  - expected: You can wait: players do not have to choose their starting cities in the first round and may start their network in a later round.
  - got: You can wait; starting later is allowed. (stated)

**rt-03** — can my guys walk from a spot the cats own to another spot the cats also own?
- judge **partially_correct**: The main verdict and reasoning match the rulebook: moving requires ruling the origin or destination clearing, and if the cats rule both, you rule neither, so the move is blocked. However, the branches contain claims the pages do not support. The Vagabond branch says the Vagabond can move regardless of who rules, but the pages say nothing about that. The Eyrie branch says the Eyrie rule tied clearings, which contradicts the page text, since on a tie no one is ruler. That branch is wrong and invented, so the answer is only partially correct.
  - expected: No. To move you must rule the clearing you move from or the clearing you move to.
  - got: No, you must rule at least one of the two clearings. (stated)
- step 3 p.5: not matched (best error 24%) — “They don’t rule this clearing either, so they cannot move here.”

**rt-04** — If I have to spend a fox card, can I spend a bird card instead? And the other way round?
- step 3 p.10: not matched (best error 31%) — “you may take any number of extra actions by spending one bird card per extra action.”

**rt-06** — wait can my cats leave a spot where we're tied with the birds
- judge **incorrect**: The assistant gets the core outcome (cats can leave only if they rule the destination) right, but its reasoning contradicts the rulebook. It says the Eyrie rule this clearing and so the Marquise does not, as if the Eyrie ruling it were the established situation. The question describes a tie with the birds, and the Eyrie's Lords of the Forest rule only matters if the birds are the Eyrie. On a tie no one rules, as page 5 says. The expected ruling treats the Eyrie ruling tied clearings as a branch, not the default. The assistant also does not give the key reason that the starting clearing cannot be the ruled one on a tie. Its stated verdict and branch are the right direction, but it misstates the tie logic by asserting that the Eyrie rule it, and it gives no Eyrie-branch distinction for who is moving.
  - expected: Only if you rule the clearing you move to: on a tie no one rules your starting clearing (for you), so it can't be the one that lets you move. Branch: if you are the Eyrie, you rule tied clearings (Lords of the Forest).
  - got: No, unless she rules the destination clearing. (stated)

