# Bench report — claude-opus-5-5 / json / effort low

- Date: 2026-11-21 18:36:39 +0000
- Questions: `fixture.json`
- Model: `claude-opus-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.

## Summary

| Metric | Value |
|---|---|
| Questions run | 5 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 4/5 (80%) (+0 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 4/4 (100%) |
| Quotes matched on claimed page | 13/13 (100%) (+0 found on another page) |
| Answers with every quote matched | 5/5 (100%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Figure boxes IoU ≥ 0.3 vs expected | 1/1 (100%) (center inside expected: 1) |
| Verdict time median / p90 (s) | 2.2 / 4.1 |
| Step 1 ready median / p90 (s) | 4.3 / 5.0 |
| Step 1 within 5 s | 5/5 (100%) |
| Total answer cost | $0.100 (judge extra: 3705 in / 572 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 1 | 3.2 / 3.2 | 3.6 / 3.6 | 4.1 / 4.1 | 5.0 / 5.0 | 5.0 / 5.0 | 6.7 / 6.7 |
| warm | 3 | 1.4 / 1.7 | 1.7 / 2.1 | 2.2 / 2.4 | 4.3 / 4.4 | 4.3 / 4.4 | 5.6 / 5.9 |
| followup | 1 | 1.5 / 1.5 | 1.8 / 1.8 | 1.9 / 1.9 | 3.0 / 3.0 | 3.0 / 3.0 | 4.6 / 4.6 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 1 | 4 | 8227 | 0 | 478 | $0.0507 |
| warm | 3 | 4 | 15 | 8197 | 523 | $0.0122 |
| followup | 1 | 4 | 488 | 8227 | 448 | $0.0131 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.05 · 5 q → $0.10 · 20 q → $0.29

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| fx-01 | cold | ok | correct | ✓ | 3/3 | 4.1 | 5.0 | 6.7 | $0.0507 |
| fx-02 | followup | ok | correct | ✓ | 3/3 | 1.9 | 3.0 | 4.6 | $0.0131 |
| fx-03 | warm | ok | correct | ✓ | 3/3 | 1.8 | 3.2 | 4.9 | $0.0111 |
| fx-04 | warm | ok | incorrect | ✓ | 2/2 +box | 2.2 | 4.3 | 5.9 | $0.0134 |
| fx-05 | warm | ok | correct | TODO | 2/2 | 2.4 | 4.4 | 5.6 | $0.0121 |

## Misses

**fx-04** — Where is the scoring track shown?
- judge **incorrect**: The expected ruling says the scoring track is shown in Figure 1 on the Special plants page, lower half, and the rulebook states this. The assistant claims the rulebook never identifies it, answers not_covered, and says the track might not be shown anywhere. That contradicts the stated answer. Its hedged branch pointing to the figure under Special plants does not rescue it, because it denies that the rulebook labels the figure as the track and never mentions Figure 1.
  - expected: In Figure 1 on the Special plants page (lower half of the page).
  - got: The rulebook never labels any illustration as the scoring track. It only lists '1 scoring track' in the contents. The only figure is an unlabeled row of 10 colored squares on page 4, which may be the track but is not identified as such. (not_covered)

