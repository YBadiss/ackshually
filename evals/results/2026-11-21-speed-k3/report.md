# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-21 20:01:21 +0000
- Questions: `m1.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.
- Pages sent: **page selection** — top 3 BM25 pages + 0 neighbour(s), as pdf, full PDF if ≥75% of pages, re-ask with full PDF on not_covered

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 26/28 (93%) (+1 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 25/27 (93%) |
| Quotes matched on claimed page | 76/78 (97%) (+0 found on another page) |
| Answers with every quote matched | 27/28 (96%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 3.8 / 9.1 |
| Step 1 ready median / p90 (s) | 4.7 / 10.9 |
| Step 1 within 5 s | 18/28 (64%) |
| Total answer cost | $0.727 (judge extra: 82532 in / 3499 out tokens) |

## Page selection

| Metric | Value |
|---|---|
| Retrieval recall: every expected page sent | 21/27 (78%) (at least one: 24/27 (89%)) |
| Pages sent (first attempt) | 84/422 (20%); mean excerpt 3.0 pages |
| Full PDF chosen up front | 0/28 (0%)  |
| Excerpt size (attached bytes, median) | 1685 KB |
| Fallback to full PDF (excerpt said not_covered) | 4/28 (14%): pg-06, pg-07, rt-02, rt-06; fallback started at median 3.6 s; discarded attempts cost $0.098 |
| Evidence pages remapped (model cited an excerpt position) | 0 |
| Local prepare time (rank + build excerpt), median / max | 89 / 374 ms |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 3.0 / 3.4 | 3.8 / 4.2 | 3.8 / 4.2 | 4.7 / 5.0 | 4.7 / 5.0 | 6.0 / 6.1 |
| warm | 23 | 2.7 / 3.2 | 3.8 / 8.5 | 3.8 / 9.1 | 4.6 / 10.7 | 4.6 / 10.9 | 5.5 / 11.7 |
| followup | 1 | 3.7 / 3.7 | 9.5 / 9.5 | 9.8 / 9.8 | 11.1 / 11.1 | 11.1 / 11.1 | 11.9 / 11.9 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 9551 | 0 | 494 | $0.0288 |
| warm | 23 | 4 | 7738 | 8789 | 484 | $0.0251 |
| followup | 1 | 8 | 11011 | 33935 | 422 | $0.0352 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.03 · 5 q → $0.13 · 20 q → $0.51

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost | Sent | Recall |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 3/3 | 4.2 | 5.0 | 6.1 | $0.0324 | 3,5,9 | ✓ |
| pg-02 | warm | ok | correct | ✓ | 3/3 | 4.5 | 6.0 | 7.1 | $0.0330 | 5,7,8 | ✓ |
| pg-03 | warm | ok | correct | ✓ | 2/2 | 3.9 | 4.6 | 4.7 | $0.0307 | 4,5,12 | ✓ |
| pg-04 | warm | ok | correct | ✗ | 2/2 | 3.9 | 5.7 | 6.3 | $0.0281 | 8,10,12 | ✗ |
| pg-05 | warm | ok | correct | ✓ | 2/2 | 4.1 | 5.0 | 5.0 | $0.0277 | 3,8,10 | ✓ |
| pg-06 | followup | ok | correct | ✓ | 2/2 | 9.8 | 11.1 | 11.9 | $0.0352 | 2,3,8 → full | ✓ |
| pg-07 | warm | ok | correct | TODO | 3/3 | 9.1 | 10.9 | 11.7 | $0.0375 | 4,5,6 → full | – |
| pg-08 | warm | ok | correct | ✓ | 3/3 | 4.0 | 5.0 | 6.1 | $0.0050 | 4,5,6 | ✓ |
| rt-01 | cold | ok | correct | ✓ | 2/2 | 2.1 | 4.2 | 4.7 | $0.0259 | 9,14,20 | ✓ |
| rt-02 | warm | ok | correct | ✓ | 3/3 | 11.2 | 13.3 | 14.0 | $0.0343 | 2,10,11 → full | ✗ |
| rt-03 | warm | ok | incorrect | ✗ | 2/2 | 2.9 | 5.6 | 6.6 | $0.0283 | 2,11,19 | ✗ |
| rt-04 | warm | ok | correct | ✓ | 4/4 | 4.3 | 4.9 | 6.1 | $0.0295 | 3,6,14 | ✓ |
| rt-05 | warm | ok | correct | ✓ | 1/3 | 2.5 | 3.1 | 4.2 | $0.0267 | 2,14,15 | ✓ |
| rt-06 | warm | ok | correct | ✓ | 4/4 | 9.4 | 11.5 | 12.7 | $0.0334 | 8,12,13 → full | ✗ |
| az-01 | cold | ok | correct | ✓ | 3/3 | 3.8 | 4.7 | 6.0 | $0.0265 | 2,3,4 | ✗ |
| az-02 | warm | ok | correct | ✓ | 2/2 | 3.8 | 4.6 | 5.5 | $0.0051 | 2,3,4 | ✓ |
| az-03 | warm | ok | correct | ✓ | 3/3 | 3.8 | 4.6 | 5.9 | $0.0056 | 2,3,4 | ✓ |
| az-04 | warm | ok | correct | ✓ | 3/3 | 3.3 | 4.9 | 6.0 | $0.0275 | 3,5,6 | ✓ |
| az-05 | warm | ok | correct | ✓ | 4/4 | 2.6 | 3.4 | 4.8 | $0.0055 | 3,5,6 | ✓ |
| az-06 | warm | ok | correct | ✓ | 2/2 +box | 3.8 | 5.7 | 7.4 | $0.0281 | 3,4,5 | ✓ |
| az-07 | warm | ok | correct | ✓ | 3/3 | 3.6 | 4.3 | 5.3 | $0.0049 | 3,4,5 | ✓ |
| du-01 | cold | ok | correct | ✓ | 4/4 | 2.4 | 3.0 | 4.5 | $0.0304 | 8,11,13 | ✓ |
| du-02 | warm | ok | correct | ✓ | 2/2 | 2.2 | 3.3 | 3.9 | $0.0303 | 11,12,13 | ✓ |
| du-03 | warm | ok | correct | ✓ | 3/3 | 2.3 | 3.4 | 4.2 | $0.0321 | 10,11,19 | ✓ |
| du-04 | warm | ok | correct | ✓ | 4/4 | 2.2 | 3.1 | 4.4 | $0.0309 | 10,17,19 | ✓ |
| du-05 | warm | ok | partially_correct | ✓ | 2/2 | 2.0 | 3.0 | 4.0 | $0.0300 | 6,16,20 | ✗ |
| du-06 | warm | ok | correct | ✓ | 3/3 | 2.5 | 4.2 | 5.1 | $0.0319 | 9,13,20 | ✓ |
| du-07 | warm | ok | correct | ✓ | 2/2 | 2.3 | 3.8 | 4.5 | $0.0310 | 12,13,20 | ✓ |

## Misses

**pg-04** — Early game: can I build a house in Berlin if my friend already has one there?
- cited pages [12] don't include an expected page

**rt-03** — can my guys walk from a spot the cats own to another spot the cats also own?
- judge **incorrect**: The rulebook (page 5) states: "To move, you must rule the clearing you are moving from or moving to." If the cats own both spots, the cats' warriors can move there only if the mover rules one end; as asked, the answer is no for the opposing player who rules neither. The assistant says "likely yes" and claims the excerpt states no restriction, which is wrong. Its example also shows the Marquise moving from a ruled clearing, consistent with the actual rule, but it wrongly concludes that ruling is not required. It also falsely says the movement rule is not in the pages.
  - expected: No. To move you must rule the clearing you move from or the clearing you move to.
  - got: Likely yes in general: the excerpt doesn't state any restriction on moving into or out of Marquise-ruled clearings, but it also doesn't give the full movement rule, so this is inferred. (inferred)
- cited pages [11, 19] don't include an expected page

**rt-05** — As the Woodland Alliance, does spreading sympathy into a clearing with 3 Marquise warriors cost the normal amount?
- step 1 p.15: not matched (best error 33%) — “You must spend supporters as shown by the cost on your Sympathy track.”
- step 2 p.15: not matched (best error 41%) — “If the target clearing has three or more warriors of another player, you must spend another matching supporter to place ”

**du-05** — Someone just hit 10 points mid-round. Does the game end right now?
- judge **partially_correct**: The core outcome is right: the game does not end immediately, but is checked at the end of the round (page 6, page 13 Phase 5). However, the response omits that the end is checked after combat and Makers (Phase 5 Recall), that an empty Conflict deck also triggers it, and that Endgame Intrigue cards are played before the winner is declared. It also says players can lose points, which is plausible but unsupported. The answer is directionally correct but misses the Endgame Intrigue step.
  - expected: No. The game ends at the end of that round (after combat and Makers), when a player has 10+ VP or the Conflict deck is empty; Endgame Intrigue cards are then played.
  - got: No. The game ends at the end of the round, not immediately, and whoever has the most Victory Points then wins. (stated)

