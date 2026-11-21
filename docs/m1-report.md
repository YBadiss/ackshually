# M1 report — assumption check

**Date:** 2026-11-21 · **Status:** done · **Verdict:** go to M2 with **Sonnet 5.5 + model-written quotes**; run one speed experiment (page selection) alongside M2.

Run details and per-question tables: [evals/results/](../evals/results/README.md). Question set: 28 questions across Power Grid Recharged, Root (Learning to Play), Azul and Dune: Imperium, every expected answer, page and quote verified against the PDFs by hand, including 5 deliberately sloppy "table talk" questions.

## The five assumptions

| # | Assumption | Result | |
|---|---|---|---|
| 1 | One call with the full PDF answers correctly with usable evidence (≥90%) | Opus 28/28, Sonnet 27/28 (+1 partial). Evidence page right 27/27 for every model | ✅ |
| 2 | Verdict + step 1 fast (median ≤5 s) | Best: Sonnet, verdict **4.8 s**, step 1 **6.0 s** median; only 43% of step 1s within 5 s. First question on a new PDF ~6–11 s | ❌ |
| 3 | Quotes land on the right words (≥90%) | 94–97% of quotes matched. Every miss was our text extraction scrambling multi-column pages, not a model misquote | ✅ |
| 4 | Model boxes land on figures | Only 1 box returned across runs (sane). Models answered Azul diagram questions from text instead | ⚠️ not really tested |
| 5 | Cost tolerable, caching works | Sonnet: $0.11 first question, ~$0.01 after (20 questions ≈ $0.28). Cache hit on every warm question | ✅ |

## Findings

1. **Model:** Sonnet 5.5 is the best trade-off: nearly Opus accuracy, the fastest, the cleanest highlights, half the cost. Haiku is cheaper but not faster and less accurate. Opus stays available for a "think harder" retry.
2. **Evidence mode:** model-written quotes (`json`) beat Claude's native citations: native citations gave lower accuracy (24/28), fewer fully highlighted answers (19/28 vs 25–27/28), no figure boxes, same speed.
3. **The latency floor is the PDF size.** First token takes ~4–5 s on a ~40k-token rulebook for every model, versus ~1.5 s on a 4-page fixture. Swapping models won't reach 5 s; sending less will.
4. **The grader needed the rulebook.** Without the cited pages, the LLM judge marked 3 correct answers wrong (real exceptions it didn't know about). Fixed: the judge now gets the cited and expected page text.
5. **Highlight misses come from layout.** Root's multi-column pages produce an interleaved text layer, so an exact-sequence match fails even when the quote is right. Fix: layout-tolerant matching (word positions), then Vision OCR, then a repair call (spec §4).

## Recommendation

- **Start M2 now** with Sonnet 5.5, `json` evidence mode, effort low.
- **In parallel, one speed experiment** (test plan stage 1): extract page text locally, pick the best pages + neighbours by keyword match, and send only those (as text + images) instead of the whole PDF. Re-run this question set; success = step 1 median ≤5 s with no loss of accuracy. Fall back to the full PDF when retrieval is unsure.
- **Cheap UX mitigation regardless:** S4 already shows the restated question within ~4–5 s, so the table sees progress before the verdict.
- **Before M3:** draw expected boxes for Azul az-04/az-06 and add a question whose answer exists *only* in a diagram, so assumption 4 is really tested.
