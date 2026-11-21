# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-21 18:57:18 +0000
- Questions: `m1.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 27/28 (96%) (+1 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 27/27 (100%) |
| Quotes matched on claimed page | 76/78 (97%) (+0 found on another page) |
| Answers with every quote matched | 27/28 (96%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 4.8 / 7.7 |
| Step 1 ready median / p90 (s) | 6.0 / 8.8 |
| Step 1 within 5 s | 12/28 (43%) |
| Total answer cost | $0.639 (judge extra: 81229 in / 3582 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 5.0 / 8.8 | 5.7 / 9.0 | 6.0 / 9.7 | 6.8 / 11.5 | 6.8 / 11.5 | 8.4 / 11.5 |
| warm | 23 | 3.9 / 6.6 | 4.2 / 7.3 | 4.4 / 7.7 | 5.0 / 8.8 | 5.0 / 8.8 | 6.3 / 10.2 |
| followup | 1 | 3.8 / 3.8 | 4.2 / 4.2 | 4.9 / 4.9 | 6.0 / 6.0 | 6.0 / 6.0 | 7.1 / 7.1 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 40539 | 0 | 493 | $0.1063 |
| warm | 23 | 4 | 27 | 39611 | 491 | $0.0090 |
| followup | 1 | 4 | 228 | 33935 | 430 | $0.0083 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.11 · 5 q → $0.14 · 20 q → $0.28

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 4/4 | 6.0 | 6.8 | 8.4 | $0.0902 |
| pg-02 | warm | ok | correct | ✓ | 3/3 | 6.4 | 7.1 | 8.1 | $0.0076 |
| pg-03 | warm | ok | correct | ✓ | 2/2 | 6.2 | 6.8 | 7.6 | $0.0060 |
| pg-04 | warm | ok | correct | ✓ | 3/3 | 6.1 | 8.8 | 10.2 | $0.0108 |
| pg-05 | warm | ok | correct | ✓ | 1/1 | 5.6 | 6.6 | 6.6 | $0.0056 |
| pg-06 | followup | ok | correct | ✓ | 2/2 | 4.9 | 6.0 | 7.1 | $0.0083 |
| pg-07 | warm | ok | correct | TODO | 3/3 | 4.8 | 6.2 | 7.0 | $0.0078 |
| pg-08 | warm | ok | correct | ✓ | 3/3 | 4.5 | 5.0 | 6.3 | $0.0070 |
| rt-01 | cold | ok | correct | ✓ | 2/2 | 9.7 | 11.5 | 11.5 | $0.1576 |
| rt-02 | warm | ok | correct | ✓ | 3/3 | 9.7 | 12.5 | 12.5 | $0.0123 |
| rt-03 | warm | ok | partially_correct | ✓ | 3/3 | 6.5 | 8.5 | 9.8 | $0.0125 |
| rt-04 | warm | ok | correct | ✓ | 3/3 | 7.7 | 8.5 | 9.4 | $0.0107 |
| rt-05 | warm | ok | correct | ✓ | 1/3 | 9.4 | 11.2 | 12.3 | $0.0126 |
| rt-06 | warm | ok | correct | ✓ | 3/3 | 7.0 | 8.6 | 9.7 | $0.0117 |
| az-01 | cold | ok | correct | ✓ | 3/3 | 4.0 | 4.8 | 6.3 | $0.0420 |
| az-02 | warm | ok | correct | ✓ | 3/3 | 2.9 | 3.6 | 4.7 | $0.0061 |
| az-03 | warm | ok | correct | ✓ | 3/3 | 3.3 | 3.9 | 5.0 | $0.0055 |
| az-04 | warm | ok | correct | ✓ | 2/2 | 2.7 | 4.2 | 5.3 | $0.0063 |
| az-05 | warm | ok | correct | ✓ | 3/3 | 3.6 | 4.4 | 5.3 | $0.0061 |
| az-06 | warm | ok | correct | ✓ | 3/3 +box | 2.7 | 4.4 | 5.9 | $0.0082 |
| az-07 | warm | ok | correct | ✓ | 3/3 | 2.6 | 3.2 | 4.2 | $0.0056 |
| du-01 | cold | ok | correct | ✓ | 3/3 | 4.9 | 5.6 | 7.2 | $0.1354 |
| du-02 | warm | ok | correct | ✓ | 3/3 | 4.4 | 6.0 | 6.9 | $0.0107 |
| du-03 | warm | ok | correct | ✓ | 3/3 | 3.3 | 4.1 | 5.1 | $0.0095 |
| du-04 | warm | ok | correct | ✓ | 3/3 | 2.9 | 4.6 | 6.0 | $0.0116 |
| du-05 | warm | ok | correct | ✓ | 3/3 | 2.8 | 3.6 | 5.4 | $0.0104 |
| du-06 | warm | ok | correct | ✓ | 2/2 | 3.0 | 4.9 | 5.5 | $0.0103 |
| du-07 | warm | ok | correct | ✓ | 3/3 | 3.0 | 4.8 | 6.0 | $0.0110 |

## Misses

**rt-03** — can my guys walk from a spot the cats own to another spot the cats also own?
- judge **partially_correct**: The core ruling is right: moving requires ruling the origin or destination clearing, and a faction that rules neither cannot move. But the verdict opens with "Only if you are the Marquise", which is a branch and not the direct answer. The asker is not the cats, and the cats rule both clearings, so the answer is simply no. The Vagabond branch is supported by the rulebook (Nimble). However, it adds that he must exhaust a boot, and the page shown says only that he can move regardless of ruling, so that detail is not verified. The Eyrie tie remark is also muddled, since a tie means no one rules and has nothing to do with the Marquise ruling both clearings.
  - expected: No. To move you must rule the clearing you move from or the clearing you move to.
  - got: Only if you are the Marquise. For any other faction, no: you must rule the clearing you move from or the one you move to, and the Marquise rules both. (inferred)

**rt-05** — As the Woodland Alliance, does spreading sympathy into a clearing with 3 Marquise warriors cost the normal amount?
- step 1 p.15: not matched (best error 33%) — “You must spend supporters as shown by the cost on your Sympathy track.”
- step 2 p.15: not matched (best error 41%) — “If the target clearing has three or more warriors of another player, you must spend another matching supporter to place ”

