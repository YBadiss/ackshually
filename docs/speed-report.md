# Speed experiment: page selection

**Date:** 2026-11-21 · **Status:** done · **Verdict:** page selection reaches the step 1 median target when retrieval hits, but the full-PDF fallback makes the tail and the cost worse. **Not adopted as the default yet.** It needs a parallel ("hedged") fallback first; see *Recommendation*.

Runs and per-question tables: [evals/results/](../evals/results/README.md) (`speed-*` rows). Baseline: [m1-sonnet-json](../evals/results/2026-11-21-m1-sonnet-json/report.md).

## Problem

M1 answers are accurate (Sonnet 27/28) but slow: step 1 (verdict + first evidence step) has a **6.0 s median** and only 43% land within 5 s. First token alone takes ~4 s on a ~34–40k-token rulebook, against ~1.5 s on a 4-page fixture. Hypothesis: sending only the relevant pages cuts latency enough for step 1 median ≤ 5 s, without losing accuracy.

## What was built

All opt-in. `AnswerRequest.pageSelection` defaults to `.fullDocument`, so the M1 path and the app are unchanged.

- **Retriever** (`Core/.../Retrieval/`). Per-page text comes from PDFKit (the same text layer as `QuoteMatcher`). Pages are ranked with BM25 over light-stemmed terms plus adjacent-term bigrams. A small game-agnostic table-talk synonym list ("fight" → combat, "walk" → move) counts at half weight. Heading terms are boosted: text in a font ≥ 1.25× the body size counts 3× extra. Earlier questions in the conversation count at half weight, and pages the conversation already cited are always sent.
- **Selection.** Top-k pages, optional ±n neighbours. The full PDF is sent instead when the selection covers ≥ 75% of the book (Azul at k=6), when there are no keyword hits, or (optionally) when scores are flat.
- **Excerpt.** A sub-PDF of the selected pages (PDFKit, so page images and diagrams stay), or text only (implemented, not measured). The prompt lists which rulebook page each excerpt page is and asks for rulebook page numbers. Evidence pages are mapped back before anything sees them: an excerpt position becomes the original page, and since the last commit each quote is checked against the selected pages' text (see *Failure cases*).
- **Fallback.** If the excerpt answer's `confidence` is `not_covered`, the request is dropped as soon as that field streams, and the question is re-asked with the full PDF. The restated question and verdict are held until `confidence` arrives, so the UI never sees the discarded attempt.
- **Bench.** `--pages auto --k N --neighbors N --excerpt pdf|text …` records per question the pages sent, retrieval recall, fallback and its timing, discarded tokens, and excerpt size. `bench retrieve` measures recall offline, with no API calls.

## Setup

`claude-sonnet-5-5`, `json` mode, effort `low`, `questions/m1.json` (28 questions, 4 rulebooks of 6–24 pages), LLM judge with the cited pages. Every judge "partial" or "incorrect" in the speed runs was checked by hand against the PDF text (below). Runs went one after another to keep upload bandwidth comparable. A same-day full-PDF control was run because latency drifts with time of day. Total API spend was ≈ $5.

## Results

| Run | Pages sent | Correct (judge) | Wrong after hand check | Step 1 median / p90 | Step 1 ≤ 5 s | Fallbacks | First token (median) | Input tokens (median) | 20 q / PDF |
|---|---|---|---|---|---|---|---|---|---|
| Baseline M1 (full PDF) | all | 27/28 +1 partial | 0 | 6.0 / 8.8 s | 43% | – | 3.9 s | 34k (cached) | $0.28 |
| Control, same day (full PDF) | all | 27/28 +1 partial | 0 | 5.9 / 9.2 s | 29% | – | 4.0 s | 34k (cached) | $0.25 |
| k=3 | 3 | 26/28 +1 partial | 1 (rt-03) | **4.7** / 10.9 s | **64%** | 4/28 | 2.9 s | 10k | $0.51 |
| k=6 | 6 (Azul: all) | 26/28 | 2 (rt-03, rt-06) | 4.9 / 8.1 s | 54% | 3/28 | 2.5 s | 19k | $0.78 |
| **k=4 + headings + strict note** | 4 | 23/28 +5 partial | **0** | 4.9 / 12.2 s | 57% | 5/28 | 3.0 s | 13k | $0.80 |

**Split by fallback** (step 1, median / p90):

| Run | No fallback | Fallback questions (median) |
|---|---|---|
| Control | 5.9 / 9.2 s (28) | – |
| k=3 | **4.6 / 5.7 s** (24) | 11.5 s (4) |
| k=6 | 4.6 / 7.2 s (25) | 12.9 s (3) |
| k=4 + headings | **4.5 / 5.6 s** (23) | 12.9 s (5) |

When retrieval is right, the speed-up is large and consistent: step 1 ≈ 4.5 s median, under 6 s at p90, ~1.4 s less than the full PDF. Root gains most (9.8 → ~5 s median), then Power Grid (6.3 → 5.4 s at k=3) and Dune (5.3 → 3.3 s). Azul (6 pages) barely changes. Power Grid excerpts stay heavier per page (large page images, 1.4–3 MB for 3–4 pages).

### The p90 problem

The tail is entirely fallbacks. A fallback pays for the excerpt attempt (dropped after ~3 s, when `confidence` streams) and then a **full-PDF call with a cold cache**: excerpt runs never warm the full-PDF cache. That's 11–13 s to step 1, and with 4–5 of 28 questions falling back, the p90 ends up worse than sending the full PDF every time (12.2 vs 9.2 s). Two kinds of question fall back:

- **Genuinely not covered** (pg-06 "and if we also have the same money?", pg-07 lending money): no page set can avoid this, and these fell back in every run. The full PDF also says `not_covered`, so the retry only confirms it.
- **Retrieval missed the rule page** (rt-02, rt-03, rt-06 at k=4): the stricter note made the model say `not_covered` instead of guessing, so the fallback caught these.

### Cost

A different page subset per question means no prompt-cache reuse. Each question pays a cache write on 10–19k tokens, against a cache read on 34k for the cached full PDF. The first question on a PDF gets cheaper ($0.03–0.05 against $0.09–0.11), but every later one costs 3–4× more ($0.025–0.036 against $0.009), and fallbacks add a full uncached PDF. At 20 questions per PDF: **$0.51–0.80 with page selection, $0.25 with the full PDF.** That's still small in absolute terms.

## Retrieval recall

Recall = every expected page was in the first-attempt selection (27 questions with known pages). Offline (`bench retrieve`, no API):

| Retriever | k=3 | k=4 | k=6 | k=3 ±1 | k=4 ±1 |
|---|---|---|---|---|---|
| BM25 unigrams | 19 | 21 | – | 22 | 24 |
| + bigrams | 21 | 23 | 23 | 22 | 24 |
| + heading boost (current) | 21 | 23 | **24** | 22 | 24 |

Neighbour pages cost a lot of pages (±1 roughly doubles them) for +1 hit. BM25 k1/b settings and dropping bare numbers made no difference. Pages already cited earlier in the conversation are always sent, so the follow-up pg-06 got p.8 every time.

**Misses, and why:**

| Question | Expected | Why BM25 missed |
|---|---|---|
| rt-02 "The **cats** and I both have 2 pieces… Who **rules** it?" | 5, 12 | "cats" (Marquise de Cat) is all over the faction pages; the ruling rule on p.5 says neither cats nor pieces. Got p.12 (Eyrie) but not p.5. |
| rt-03 "can **my guys walk** from a **spot** the cats own…" | 5 | Every content word is slang. Move/rule/clearing come only from half-weight synonyms, and "mov" is on almost every page. |
| rt-06 "can my **cats leave** a spot where we're **tied** with the **birds**" | 5, 12 | Same rule page; "cats"/"birds" pull toward the faction pages. |
| pg-04 "build a house in **Berlin**…" | 6 | "Berlin" exists only on the map; p.6 is the generic building rule. Fixed by k=6, and the model answered correctly from the other pages anyway. |
| az-01, du-05 (k ≤ 3 only) | two pages | Multi-page evidence; the second page ranks 4th–5th. Fixed by k=4. |

The cheap fixes are done: bigrams, headings, a small synonym list, session-cited pages. Neighbours were tried and don't pay off. What's left is one game-specific vocabulary gap: faction nicknames and slang for a rule that lives on a generic page. A per-game glossary ("cats" = Marquise, "birds" = Eyrie) would close it, but it has to be written per game. A cheap model picking pages from a table of contents would too, at the price of an extra call.

## Failure cases (hand-checked against the PDFs)

- **rt-03 (k=3, k=6) and rt-06 (k=6): wrong.** Root p.5 says *"To move, you must rule the clearing you are moving from or moving to"*. It wasn't sent, and the model answered "Yes… (inferred)" from the faction pages. Fixed in the k=4 run by the stricter excerpt note ("use not_covered, not inferred, when the rule isn't on these pages"): all three Root misses then fell back and got the rule right.
- **k=4 "partials" (5):** pg-04 is correct (matches p.6, *"In Step 1 of the game, each city can only be connected by one player"*). rt-01 has the substance right per p.9 (only the defender ambushes; the attacker can foil), but the headline "Yes, but only to foil" is misleading. rt-02, rt-03 and rt-06 are full-PDF fallback answers with hedged or muddled verdicts, which is model and judge variance, not retrieval. The same questions swing between correct and partial across the full-PDF runs too. **No wrong rulings.**
- **du-05 (k=3, partial):** the outcome is right ("No, at the end of the round", p.6), but it misses the Endgame Intrigue step on p.13, which wasn't sent.
- **Mis-numbered evidence pages (k=4 run):** with the longer note, the model several times cited the page *before* the right one (az-03: 2/3 for 3/4; du-03: 10 for 11; du-04: 16 for 17). Those numbers are inside the selection, so the number-only mapping couldn't catch them: 7 quotes "found on another page", and the answers with every quote matched fell to 24/28. **Fixed** in the last commit: each excerpt quote is located in the text of the named page, then the other selected pages (`RulebookIndex.resolvePage`). Re-scoring the recorded answers with the matches the bench already logged gives **81/82 quotes on the claimed page, 27/28 answers fully matched, evidence page correct 26/27**, on par with the control. ⚠️ This commit could not be compiled or unit-tested: the machine's Xcode was updated to 27.2 mid-task and its license is not accepted yet. Run `cd Core && swift test` after `sudo xcodebuild -license`.

## Recommendation

**Needs Y before it becomes the default.** Keep `.fullDocument` as the Core default and `--pages all` as the bench default for now.

- Page selection **meets the median target** (4.7–4.9 s against 5.9–6.0 s), and on the ~85% of questions where retrieval hits it is clearly better (4.5 / 5.6 s). But it **regresses p90** (12.2 against 9.2 s), costs ~3× more per question, and needs the fallback to stay accurate.
- **Y = hedged fallback, the next experiment:** start the full-PDF request alongside the excerpt request and use whichever settles first. Show the excerpt answer when its `confidence` isn't `not_covered`, otherwise keep streaming the full-PDF answer already in flight. Expected: median ≈ 4.5 s, p90 ≈ today's full-PDF p90 (no sequential retry), cost ≈ excerpt + cached full (~$0.045/question, ~$0.9 per 20). A cheaper variant only hedges when retrieval confidence is low or the question has a follow-up/negation shape.
- **Config to carry forward:** k=4, no neighbours, heading boost, strict excerpt note, sub-PDF (`PageSelectionOptions()` defaults now). Text-only excerpts are implemented but unmeasured. They would cut Power Grid's heavy page images but lose diagrams; worth one run if Power Grid stays slow.
- **App (M2):** safe to wire behind a setting now (`pageSelection: .automatic(PageSelectionOptions())`). Pass a prebuilt `RulebookIndex` (built once per PDF; otherwise the provider builds and caches it on the first question). Ranking + building the excerpt then takes ~0.1 s (max 0.4 s) per question. `AnswerResult.retrieval` carries the diagnostics.
