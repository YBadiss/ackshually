# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-21 19:56:56 +0000
- Questions: `m1.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.
- Pages sent: full PDF

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 27/28 (96%) (+1 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 26/27 (96%) |
| Quotes matched on claimed page | 76/78 (97%) (+0 found on another page) |
| Answers with every quote matched | 27/28 (96%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 4.8 / 7.3 |
| Step 1 ready median / p90 (s) | 5.9 / 9.2 |
| Step 1 within 5 s | 8/28 (29%) |
| Total answer cost | $0.556 (judge extra: 81092 in / 3616 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 6.4 / 8.6 | 6.7 / 8.6 | 7.2 / 9.3 | 7.9 / 10.3 | 7.9 / 10.3 | 9.1 / 10.9 |
| warm | 23 | 3.8 / 6.6 | 4.1 / 6.9 | 4.4 / 7.3 | 5.4 / 9.2 | 5.4 / 9.2 | 6.2 / 10.6 |
| followup | 1 | 4.0 / 4.0 | 4.4 / 4.4 | 4.8 / 4.8 | 6.3 / 6.3 | 6.3 / 6.3 | 6.3 / 6.3 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 32060 | 8478 | 479 | $0.0858 |
| warm | 23 | 4 | 26 | 39612 | 490 | $0.0089 |
| followup | 1 | 4 | 254 | 33935 | 276 | $0.0068 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.09 · 5 q → $0.12 · 20 q → $0.25

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 3/3 | 6.7 | 7.6 | 8.8 | $0.0084 |
| pg-02 | warm | ok | correct | ✓ | 3/3 | 6.0 | 6.9 | 8.1 | $0.0082 |
| pg-03 | warm | ok | correct | ✓ | 2/2 | 5.5 | 6.0 | 6.9 | $0.0063 |
| pg-04 | warm | ok | correct | ✗ | 3/3 | 4.8 | 6.4 | 7.7 | $0.0095 |
| pg-05 | warm | ok | correct | ✓ | 1/1 | 4.2 | 5.4 | 5.4 | $0.0059 |
| pg-06 | followup | ok | correct | ✓ | 1/1 | 4.8 | 6.3 | 6.3 | $0.0068 |
| pg-07 | warm | ok | correct | TODO | 3/3 | 4.5 | 6.5 | 7.1 | $0.0087 |
| pg-08 | warm | ok | correct | ✓ | 3/3 | 4.4 | 5.1 | 6.1 | $0.0070 |
| rt-01 | cold | ok | correct | ✓ | 2/2 | 9.3 | 10.3 | 10.9 | $0.1571 |
| rt-02 | warm | ok | partially_correct | ✓ | 3/3 | 9.4 | 11.2 | 12.0 | $0.0123 |
| rt-03 | warm | ok | correct | ✓ | 4/4 | 7.3 | 9.2 | 10.6 | $0.0126 |
| rt-04 | warm | ok | correct | ✓ | 3/3 | 6.5 | 7.6 | 8.3 | $0.0106 |
| rt-05 | warm | ok | correct | ✓ | 1/3 | 9.3 | 10.4 | 11.5 | $0.0117 |
| rt-06 | warm | ok | correct | ✓ | 3/3 | 7.0 | 9.2 | 10.0 | $0.0122 |
| az-01 | cold | ok | correct | ✓ | 4/4 | 4.1 | 4.9 | 6.3 | $0.0424 |
| az-02 | warm | ok | correct | ✓ | 3/3 | 2.7 | 3.7 | 4.7 | $0.0063 |
| az-03 | warm | ok | correct | ✓ | 3/3 | 3.4 | 4.0 | 4.9 | $0.0053 |
| az-04 | warm | ok | correct | ✓ | 3/3 | 2.5 | 4.1 | 5.2 | $0.0074 |
| az-05 | warm | ok | correct | ✓ | 3/3 | 3.4 | 4.2 | 5.2 | $0.0061 |
| az-06 | warm | ok | correct | ✓ | 3/3 +box | 2.5 | 4.8 | 6.2 | $0.0086 |
| az-07 | warm | ok | correct | ✓ | 3/3 | 2.6 | 3.3 | 4.4 | $0.0057 |
| du-01 | cold | ok | correct | ✓ | 3/3 | 7.2 | 7.9 | 9.1 | $0.1353 |
| du-02 | warm | ok | correct | ✓ | 2/2 | 4.8 | 5.9 | 6.5 | $0.0097 |
| du-03 | warm | ok | correct | ✓ | 4/4 | 4.8 | 5.8 | 7.0 | $0.0103 |
| du-04 | warm | ok | correct | ✓ | 3/3 | 3.0 | 3.7 | 4.9 | $0.0095 |
| du-05 | warm | ok | correct | ✓ | 3/3 | 3.2 | 5.1 | 5.9 | $0.0108 |
| du-06 | warm | ok | correct | ✓ | 2/2 | 3.4 | 5.3 | 6.1 | $0.0105 |
| du-07 | warm | ok | correct | ✓ | 2/2 | 3.6 | 5.2 | 5.8 | $0.0100 |

## Misses

**pg-04** — Early game: can I build a house in Berlin if my friend already has one there?
- cited pages [7] don't include an expected page

**rt-02** — The cats and I both have 2 pieces in a clearing. Who rules it?
- judge **partially_correct**: The core ruling is right: a tie means nobody rules, except the Eyrie, who rule tied clearings (Lords of the Forest). But the assistant's first branch is wrong. It says that if you are the Eyrie, the Eyrie rule the clearing 'between you and the Marquise', which assumes the Eyrie must have pieces there. The expected ruling requires that, and it is also muddled, because the player's faction is never stated. The second branch, that tokens and the Vagabond pawn do not add to rule, is supported by the rulebook. However, it treats the player's own 2 pieces as possibly including tokens, which changes the premise of the question (2 pieces each). The answer is right in outline but hedged and cluttered.
  - expected: Nobody rules it when tied — except the Eyrie, who rule tied clearings where they have pieces (Lords of the Forest).
  - got: If those pieces are all warriors and buildings, it's a tie and nobody rules it, unless you are the Eyrie, who rule on ties. (stated)

**rt-05** — As the Woodland Alliance, does spreading sympathy into a clearing with 3 Marquise warriors cost the normal amount?
- step 1 p.15: not matched (best error 33%) — “You must spend supporters as shown by the cost on your Sympathy track.”
- step 2 p.15: not matched (best error 41%) — “If the target clearing has three or more warriors of another player, you must spend another matching supporter to place ”

