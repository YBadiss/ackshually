# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-21 21:45:53 +0000
- Questions: `m1.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.
- Pages sent: full PDF

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 26/28 (93%) (+2 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 27/27 (100%) |
| Quotes matched on claimed page | 83/86 (97%) (+0 found on another page) |
| Answers with every quote matched | 25/28 (89%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 5.1 / 8.4 |
| Step 1 ready median / p90 (s) | 5.9 / 8.8 |
| Step 1 within 5 s | 11/28 (39%) |
| Total answer cost | $0.913 (judge extra: 82335 in / 3481 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 7.9 / 11.0 | 8.4 / 11.3 | 8.7 / 11.8 | 9.3 / 12.5 | 9.3 / 12.5 | 11.9 / 14.1 |
| warm | 23 | 3.8 / 6.5 | 4.2 / 6.8 | 4.5 / 7.3 | 5.0 / 7.8 | 5.2 / 7.8 | 6.7 / 11.4 |
| followup | 1 | 5.1 / 5.1 | 5.4 / 5.4 | 6.2 / 6.2 | 6.6 / 6.6 | 6.6 / 6.6 | 7.8 / 7.8 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 41100 | 0 | 555 | $0.1700 |
| warm | 23 | 4 | 27 | 40172 | 560 | $0.0097 |
| followup | 1 | 4 | 412 | 34496 | 386 | $0.0090 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.17 · 5 q → $0.21 · 20 q → $0.35

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 3/3 | 11.8 | 12.5 | 14.1 | $0.1434 |
| pg-02 | warm | ok | correct | ✓ | 4/4 | 5.8 | 6.6 | 7.9 | $0.0087 |
| pg-03 | warm | ok | correct | ✓ | 3/3 | 7.3 | 7.8 | 9.3 | $0.0080 |
| pg-04 | warm | ok | correct | ✓ | 3/3 | 7.1 | 7.8 | 11.4 | $0.0118 |
| pg-05 | warm | ok | correct | ✓ | 1/1 | 5.1 | 5.9 | 6.9 | $0.0075 |
| pg-06 | followup | ok | correct | ✓ | 1/1 | 6.2 | 6.6 | 7.8 | $0.0090 |
| pg-07 | warm | ok | correct | TODO | 3/3 | 5.7 | 6.9 | 7.7 | $0.0076 |
| pg-08 | warm | ok | correct | ✓ | 3/3 | 4.5 | 5.2 | 6.6 | $0.0082 |
| rt-01 | cold | ok | correct | ✓ | 3/3 | 8.7 | 9.3 | 11.9 | $0.2537 |
| rt-02 | warm | ok | partially_correct | ✓ | 3/3 | 8.4 | 8.8 | 11.8 | $0.0136 |
| rt-03 | warm | ok | partially_correct | ✓ | 2/3 | 9.4 | 9.7 | 13.8 | $0.0150 |
| rt-04 | warm | ok | correct | ✓ | 3/3 | 6.7 | 7.4 | 8.6 | $0.0104 |
| rt-05 | warm | ok | correct | ✓ | 3/3 | 6.5 | 6.9 | 8.9 | $0.0116 |
| rt-06 | warm | ok | correct | ✓ | 3/4 | 6.4 | 6.8 | 10.0 | $0.0140 |
| az-01 | cold | ok | correct | ✓ | 4/4 | 4.1 | 4.8 | 6.7 | $0.0675 |
| az-02 | warm | ok | correct | ✓ | 2/3 | 3.0 | 3.8 | 5.7 | $0.0072 |
| az-03 | warm | ok | correct | ✓ | 3/3 | 3.0 | 3.3 | 5.0 | $0.0062 |
| az-04 | warm | ok | correct | ✓ | 3/3 | 2.8 | 3.4 | 5.5 | $0.0075 |
| az-05 | warm | ok | correct | ✓ | 4/4 | 2.7 | 3.2 | 4.9 | $0.0069 |
| az-06 | warm | ok | correct | ✓ | 3/3 +box | 2.8 | 3.7 | 6.7 | $0.0095 |
| az-07 | warm | ok | correct | ✓ | 3/3 | 2.6 | 3.1 | 4.7 | $0.0062 |
| du-01 | cold | ok | correct | ✓ | 3/3 | 6.6 | 7.7 | 8.7 | $0.2152 |
| du-02 | warm | ok | correct | ✓ | 2/2 | 3.0 | 3.3 | 5.5 | $0.0108 |
| du-03 | warm | ok | correct | ✓ | 4/4 | 3.4 | 3.8 | 5.5 | $0.0100 |
| du-04 | warm | ok | correct | ✓ | 4/4 | 4.6 | 5.0 | 7.4 | $0.0112 |
| du-05 | warm | ok | correct | ✓ | 3/3 | 3.0 | 3.8 | 5.7 | $0.0109 |
| du-06 | warm | ok | correct | ✓ | 4/4 | 3.1 | 3.7 | 5.8 | $0.0111 |
| du-07 | warm | ok | correct | ✓ | 3/3 | 4.5 | 5.3 | 6.7 | $0.0101 |

## Misses

**rt-02** — The cats and I both have 2 pieces in a clearing. Who rules it?
- judge **partially_correct**: The core ruling matches: a tie means nobody rules, except the Eyrie, who rule tied clearings (Lords of the Forest). But the assistant omits the key condition that the Eyrie must have pieces there. It also frames the answer as a branch: if you are the Eyrie, you rule. The question is ambiguous about who is the Eyrie, and the assistant never says that if the cats are the Eyrie they would rule. The extra branch about tokens and the Vagabond pawn is supported by the rulebook.
  - expected: Nobody rules it when tied — except the Eyrie, who rule tied clearings where they have pieces (Lords of the Forest).
  - got: Usually nobody: a tie means no one rules. The exception is if you are the Eyrie, who rule a clearing even when tied. (stated)

**rt-03** — can my guys walk from a spot the cats own to another spot the cats also own?
- judge **partially_correct**: The core answer matches: moving requires ruling the origin or destination, and if the cats rule both, you rule neither, so you cannot move. But the assistant adds branches saying the Eyrie may rule on a tie and the Vagabond can move regardless of who rules. The pages say a tie means no one rules, which contradicts the Eyrie branch. The Vagabond claim is not in the pages, and the rulebook says only the Vagabond can enter forests, not that he ignores rule. The Eyrie branch is a wrong claim, and it presents a possible yes where the rulebook gives a flat no. Also, the confidence is 'inferred' while the rule is stated outright.
  - expected: No. To move you must rule the clearing you move from or the clearing you move to.
  - got: No, not unless you rule at least one of the two clearings. A move requires ruling the origin or the destination clearing, and if the cats rule both, you rule neither. (inferred)
- step 3 p.5: not matched (best error 24%) — “They don’t rule this clearing either, so they cannot move here.”

**rt-06** — wait can my cats leave a spot where we're tied with the birds
- step 3 p.5: not matched (best error 44%) — “They do rule this clearing, so they can move here.”

**az-02** — Can I put blue tiles in my third pattern line if there's already a blue tile in the third row of my wall?
- step 1 p.4: not matched (best error 31%) — “Move the rightmost tile of each complete line to the space of the same color in the corresponding line of your wall.”

