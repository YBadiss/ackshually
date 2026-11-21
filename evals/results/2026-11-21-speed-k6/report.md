# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-21 20:05:23 +0000
- Questions: `m1.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.
- Pages sent: **page selection** — top 6 BM25 pages + 0 neighbour(s), as pdf, full PDF if ≥75% of pages, re-ask with full PDF on not_covered

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 26/28 (93%) (+0 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 25/27 (93%) |
| Quotes matched on claimed page | 77/79 (97%) (+0 found on another page) |
| Answers with every quote matched | 27/28 (96%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 3.3 / 6.9 |
| Step 1 ready median / p90 (s) | 4.9 / 8.1 |
| Step 1 within 5 s | 15/28 (54%) |
| Total answer cost | $1.113 (judge extra: 86419 in / 3493 out tokens) |

## Page selection

| Metric | Value |
|---|---|
| Retrieval recall: every expected page sent | 23/27 (85%) (at least one: 25/27 (93%)) |
| Pages sent (first attempt) | 168/422 (40%); mean excerpt 6.0 pages |
| Full PDF chosen up front | 7/28 (25%) selection covers n/N pages |
| Excerpt size (attached bytes, median) | 1543 KB |
| Fallback to full PDF (excerpt said not_covered) | 3/28 (11%): pg-06, pg-07, rt-02; fallback started at median 5.7 s; discarded attempts cost $0.140 |
| Evidence pages remapped (model cited an excerpt position) | 4 |
| Local prepare time (rank + build excerpt), median / max | 100 / 399 ms |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 3.2 / 5.6 | 4.0 / 6.5 | 4.3 / 6.5 | 5.1 / 7.2 | 5.1 / 7.2 | 6.9 / 8.3 |
| warm | 23 | 2.5 / 5.1 | 3.3 / 6.9 | 3.3 / 6.9 | 4.6 / 7.7 | 4.6 / 8.1 | 5.7 / 9.0 |
| followup | 1 | 5.4 / 5.4 | 14.5 / 14.5 | 14.8 / 14.8 | 16.0 / 16.0 | 16.0 / 16.0 | 17.0 / 17.0 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 17411 | 0 | 490 | $0.0484 |
| warm | 23 | 4 | 12651 | 8885 | 494 | $0.0375 |
| followup | 1 | 8 | 20181 | 33935 | 356 | $0.0574 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.05 · 5 q → $0.20 · 20 q → $0.78

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost | Sent | Recall |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 3/3 | 6.5 | 7.2 | 8.3 | $0.0553 | 2,3,5,6,7,9 | ✓ |
| pg-02 | warm | ok | correct | ✓ | 4/4 | 6.9 | 8.1 | 9.0 | $0.0543 | 2,3,5,7,8,9 | ✓ |
| pg-03 | warm | ok | correct | ✓ | 3/3 | 4.6 | 5.3 | 6.0 | $0.0542 | 4,5,6,7,8,12 | ✓ |
| pg-04 | warm | ok | correct | ✗ | 3/3 | 5.8 | 7.4 | 8.5 | $0.0536 | 4,5,7,8,10,12 | ✗ |
| pg-05 | warm | ok | correct | ✓ | 1/1 | 5.7 | 6.4 | 6.4 | $0.0503 | 3,4,7,8,10,12 | ✓ |
| pg-06 | followup | ok | correct | ✓ | 1/1 | 14.8 | 16.0 | 17.0 | $0.0574 | 2,3,4,7,8,9 → full | ✓ |
| pg-07 | warm | ok | correct | TODO | 3/3 | 11.8 | 12.9 | 13.7 | $0.0590 | 3,4,5,6,8,12 → full | – |
| pg-08 | warm | ok | correct | ✓ | 3/3 | 6.0 | 7.1 | 7.8 | $0.0059 | 4,5,6,7,8,12 | ✓ |
| rt-01 | cold | ok | correct | ✓ | 2/2 | 3.2 | 4.8 | 5.5 | $0.0421 | 7,8,9,14,20,21 | ✓ |
| rt-02 | warm | ok | correct | ✓ | 3/3 | 10.2 | 12.4 | 13.1 | $0.0510 | 2,7,10,11,12,13 → full | ✗ |
| rt-03 | warm | ok | incorrect | ✗ | 2/2 | 3.2 | 5.1 | 5.7 | $0.0439 | 2,10,11,13,15,19 | ✗ |
| rt-04 | warm | ok | correct | ✓ | 3/3 | 4.5 | 5.2 | 6.4 | $0.0461 | 2,3,6,11,13,14 | ✓ |
| rt-05 | warm | ok | correct | ✓ | 1/3 | 2.9 | 4.5 | 5.7 | $0.0443 | 2,10,11,14,15,18 | ✓ |
| rt-06 | warm | ok | incorrect | ✓ | 4/4 | 3.3 | 4.3 | 5.9 | $0.0437 | 8,10,11,12,13,15 | ✗ |
| az-01 | cold | ok | correct | ✓ | 4/4 | 4.3 | 5.1 | 6.9 | $0.0426 | full | ✓ |
| az-02 | warm | ok | correct | ✓ | 3/3 | 2.9 | 3.8 | 5.0 | $0.0067 | full | ✓ |
| az-03 | warm | ok | correct | ✓ | 3/3 | 3.0 | 4.2 | 4.9 | $0.0054 | full | ✓ |
| az-04 | warm | ok | correct | ✓ | 3/3 | 2.4 | 4.3 | 5.4 | $0.0077 | full | ✓ |
| az-05 | warm | ok | correct | ✓ | 3/3 | 3.2 | 4.0 | 4.8 | $0.0058 | full | ✓ |
| az-06 | warm | ok | correct | ✓ | 3/3 +box | 2.7 | 4.5 | 6.3 | $0.0088 | full | ✓ |
| az-07 | warm | ok | correct | ✓ | 3/3 | 2.8 | 4.2 | 5.3 | $0.0068 | full | ✓ |
| du-01 | cold | ok | correct | ✓ | 3/3 | 4.0 | 4.9 | 5.5 | $0.0537 | 8,11,13,16,19,20 | ✓ |
| du-02 | warm | ok | correct | ✓ | 2/2 | 3.0 | 4.1 | 4.7 | $0.0541 | 11,12,13,16,19,20 | ✓ |
| du-03 | warm | ok | correct | ✓ | 3/3 | 3.3 | 4.1 | 5.0 | $0.0539 | 4,10,11,16,19,20 | ✓ |
| du-04 | warm | ok | correct | ✓ | 3/3 | 3.0 | 4.1 | 5.3 | $0.0533 | 10,16,17,18,19,20 | ✓ |
| du-05 | warm | ok | correct | ✓ | 3/3 | 3.3 | 4.6 | 5.8 | $0.0511 | 6,7,8,13,16,20 | ✓ |
| du-06 | warm | ok | correct | ✓ | 3/3 | 3.3 | 5.2 | 5.7 | $0.0495 | 8,9,13,17,18,20 | ✓ |
| du-07 | warm | ok | correct | ✓ | 2/2 | 3.1 | 4.6 | 5.2 | $0.0527 | 2,10,12,13,19,20 | ✓ |

## Misses

**pg-04** — Early game: can I build a house in Berlin if my friend already has one there?
- cited pages [7, 8] don't include an expected page

**rt-03** — can my guys walk from a spot the cats own to another spot the cats also own?
- judge **incorrect**: The rulebook states that to move you must rule the clearing you are moving from or moving to. A clearing the cats own satisfies this, so the answer is not 'No' as the expected ruling says. Wait: the expected ruling says No, but the rule as written would allow it. Still, the grading standard is the expected outcome, which is No. The assistant answered Yes and said the rules were not in the excerpt, but page 5 states the rule explicitly, so its claim that the excerpt lacks the move rules is wrong and its outcome differs from the expected one.
  - expected: No. To move you must rule the clearing you move from or the clearing you move to.
  - got: Yes. The Marquise's March action lets her take two moves, and the excerpt places no restriction on moving between clearings she rules. The excerpt does not state the general move rules (adjacency, rule requirement at the origin), so this is inferred. (inferred)
- cited pages [2, 11] don't include an expected page

**rt-05** — As the Woodland Alliance, does spreading sympathy into a clearing with 3 Marquise warriors cost the normal amount?
- step 1 p.15: not matched (best error 33%) — “You must spend supporters as shown by the cost on your Sympathy track.”
- step 2 p.15: not matched (best error 41%) — “If the target clearing has three or more warriors of another player, you must spend another matching supporter to place ”

**rt-06** — wait can my cats leave a spot where we're tied with the birds
- judge **incorrect**: The rulebook (page 5) says that to move you must rule the clearing you are moving from or moving to, and that on a tie no one rules it. The assistant says nothing restricts moving out of a tied clearing and that ruling is only needed for building, which contradicts the rulebook. The correct answer is that the cats can leave only if they rule the destination clearing. The assistant also misses that condition entirely, and its branch says the move is allowed regardless of ties or who rules the clearing. It does correctly note that the Eyrie rule tied clearings, but that does not rescue the wrong main verdict.
  - expected: Only if you rule the clearing you move to: on a tie no one rules your starting clearing (for you), so it can't be the one that lets you move. Branch: if you are the Eyrie, you rule tied clearings (Lords of the Forest).
  - got: Yes. Nothing restricts moving out of a tied clearing; ruling only matters for building and similar actions. Note that the Eyrie rule ties, so the Marquise would not rule that clearing anyway. (inferred)

