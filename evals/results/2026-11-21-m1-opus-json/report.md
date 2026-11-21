# Bench report — claude-opus-5-5 / json / effort low

- Date: 2026-11-21 18:46:14 +0000
- Questions: `m1.json`
- Model: `claude-opus-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 28/28 (100%) (+0 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 27/27 (100%) |
| Quotes matched on claimed page | 92/96 (96%) (+0 found on another page) |
| Answers with every quote matched | 25/28 (89%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 5.8 / 7.9 |
| Step 1 ready median / p90 (s) | 7.1 / 10.1 |
| Step 1 within 5 s | 4/28 (14%) |
| Total answer cost | $1.330 (judge extra: 91095 in / 3639 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 8.2 / 9.2 | 8.6 / 9.7 | 9.0 / 10.7 | 10.9 / 11.4 | 10.9 / 11.4 | 12.5 / 13.3 |
| warm | 23 | 4.4 / 6.7 | 4.9 / 7.1 | 5.2 / 7.7 | 7.0 / 9.3 | 7.0 / 9.4 | 8.6 / 11.4 |
| followup | 1 | 6.9 / 6.9 | 7.2 / 7.2 | 7.9 / 7.9 | 9.6 / 9.6 | 9.6 / 9.6 | 11.3 / 11.3 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 40539 | 0 | 547 | $0.2137 |
| warm | 23 | 4 | 27 | 39611 | 578 | $0.0196 |
| followup | 1 | 4 | 444 | 33935 | 728 | $0.0236 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.21 · 5 q → $0.29 · 20 q → $0.59

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 3/3 | 10.7 | 11.4 | 13.3 | $0.1805 |
| pg-02 | warm | ok | correct | ✓ | 4/4 | 5.9 | 8.9 | 11.2 | $0.0224 |
| pg-03 | warm | ok | correct | ✓ | 3/3 | 6.7 | 6.9 | 8.1 | $0.0144 |
| pg-04 | warm | ok | correct | ✓ | 4/4 | 5.8 | 8.5 | 10.9 | $0.0219 |
| pg-05 | warm | ok | correct | ✓ | 3/3 | 6.1 | 7.1 | 8.5 | $0.0155 |
| pg-06 | followup | ok | correct | ✓ | 3/3 | 7.9 | 9.6 | 11.3 | $0.0236 |
| pg-07 | warm | ok | correct | TODO | 4/4 | 7.0 | 8.8 | 11.2 | $0.0188 |
| pg-08 | warm | ok | correct | ✓ | 4/4 | 5.1 | 6.6 | 8.6 | $0.0182 |
| rt-01 | cold | ok | correct | ✓ | 2/3 | 9.0 | 10.9 | 12.5 | $0.3174 |
| rt-02 | warm | ok | correct | ✓ | 4/4 | 10.6 | 13.7 | 15.5 | $0.0300 |
| rt-03 | warm | ok | correct | ✓ | 4/4 | 7.7 | 10.1 | 12.0 | $0.0261 |
| rt-04 | warm | ok | correct | ✓ | 3/4 | 6.2 | 7.5 | 9.3 | $0.0226 |
| rt-05 | warm | ok | correct | ✓ | 1/3 | 6.4 | 8.2 | 10.0 | $0.0246 |
| rt-06 | warm | ok | correct | ✓ | 4/4 | 7.7 | 9.4 | 11.4 | $0.0243 |
| az-01 | cold | ok | correct | ✓ | 3/3 | 4.6 | 6.4 | 8.1 | $0.0857 |
| az-02 | warm | ok | correct | ✓ | 3/3 | 3.5 | 4.8 | 6.2 | $0.0128 |
| az-03 | warm | ok | correct | ✓ | 4/4 | 3.5 | 4.4 | 6.4 | $0.0136 |
| az-04 | warm | ok | correct | ✓ | 3/3 | 3.6 | 5.9 | 7.7 | $0.0160 |
| az-05 | warm | ok | correct | ✓ | 3/3 | 3.6 | 4.3 | 5.5 | $0.0111 |
| az-06 | warm | ok | correct | ✓ | 3/3 +box | 3.6 | 5.6 | 7.5 | $0.0157 |
| az-07 | warm | ok | correct | ✓ | 3/3 | 3.1 | 5.2 | 6.7 | $0.0140 |
| du-01 | cold | ok | correct | ✓ | 3/3 | 5.6 | 6.7 | 8.3 | $0.2710 |
| du-02 | warm | ok | correct | ✓ | 3/3 | 5.1 | 6.7 | 8.0 | $0.0205 |
| du-03 | warm | ok | correct | ✓ | 3/3 | 6.3 | 8.6 | 10.1 | $0.0220 |
| du-04 | warm | ok | correct | ✓ | 5/5 | 5.2 | 7.5 | 9.2 | $0.0227 |
| du-05 | warm | ok | correct | ✓ | 3/3 | 3.9 | 4.8 | 6.8 | $0.0204 |
| du-06 | warm | ok | correct | ✓ | 4/4 | 5.2 | 7.0 | 8.9 | $0.0234 |
| du-07 | warm | ok | correct | ✓ | 3/3 | 3.7 | 5.6 | 6.8 | $0.0206 |

## Misses

**rt-01** — I'm the attacker. Can I play an ambush card?
- step 3 p.9: not matched (best error 38%) — “At start of battle, defender may play to deal two immediate hits, unless attacker plays a matching ambush card.”

**rt-04** — If I have to spend a fox card, can I spend a bird card instead? And the other way round?
- step 2 p.6: not matched (best error 20%) — “If the action said you must spend a matching card, you could spend a fox or a bird card, since birds are wild.”

**rt-05** — As the Woodland Alliance, does spreading sympathy into a clearing with 3 Marquise warriors cost the normal amount?
- step 1 p.15: not matched (best error 33%) — “You must spend supporters as shown by the cost on your Sympathy track.”
- step 2 p.15: not matched (best error 41%) — “If the target clearing has three or more warriors of another player, you must spend another matching supporter to place ”

