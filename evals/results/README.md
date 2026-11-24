# Eval results

One row per kept run. All runs: 28 questions (`questions/m1.json`) over Power Grid Recharged, Root (Learning to Play), Azul, Dune: Imperium; effort `low`; judge `claude-sonnet-5-5` with the cited rulebook pages (except where noted).
"Step 1" = verdict + first evidence step ready, the moment the table sees proof. Target: median ≤ 5 s.

| Run | Correct (judge) | Every quote matched | Verdict median / p90 | Step 1 median / p90 | Step 1 ≤ 5 s | 1st q / 20 q per PDF | Notes |
|---|---|---|---|---|---|---|---|
| [m1-sonnet-json](2026-11-21-m1-sonnet-json/report.md) | **27/28** +1 partial | **27/28** | **4.8 / 7.7 s** | **6.0 / 8.8 s** | **43%** | $0.11 / $0.28 | **Chosen default.** Fastest and most reliable highlights |
| [m1-opus-json](2026-11-21-m1-opus-json/report.md) | **28/28** | 25/28 | 5.8 / 7.9 s | 7.1 / 10.1 s | 14% | $0.21 / $0.59 | Most accurate; slower, 2× cost |
| [m1-opus-citations](2026-11-21-m1-opus-citations/report.md) | 24/28 +4 partial | 19/28 | 5.7 / 8.7 s | 7.1 / 10.4 s | 25% | $0.25 / $0.69 | Native citations: no accuracy or highlight gain, no figure boxes |
| [m1-haiku-json](2026-11-21-m1-haiku-json/report.md) | 25/28 +3 partial | 24/28 | 5.5 / 7.8 s | 6.6 / 9.1 s | 29% | $0.01 / $0.02 | Cheapest; not faster than Sonnet; less accurate |
| [m1-opus-json-oldjudge](2026-11-21-m1-opus-json-oldjudge/report.md) | 25/28 +1 partial | 25/28 | 6.1 / 8.2 s | 7.6 / 9.9 s | 18% | $0.21 / $0.57 | Judge without rulebook pages: all 3 "wrong" were judge errors (model right) |
| [smoke-fixture-opus](2026-11-21-smoke-fixture-opus/report.md) | 4/5 | 5/5 | 2.2 / 4.1 s | 4.3 / 5.0 s | 100% | — | 4-page fake rulebook; shows how much PDF size drives latency |
| [speed-full-control](2026-11-21-speed-full-control/report.md) | 27/28 +1 partial | 27/28 | 4.8 / 7.3 s | 5.9 / 9.2 s | 29% | $0.09 / $0.25 | Same-day re-run of the default (full PDF) as the control for the speed experiment |
| [speed-k3](2026-11-21-speed-k3/report.md) | 26/28 +1 partial (1 wrong) | 27/28 | 3.8 / 9.1 s | **4.7** / 10.9 s | **64%** | $0.03 / $0.51 | Page selection, top 3 pages. Fast when retrieval hits (4.6 / 5.7 s); 4 not_covered fallbacks set the p90; rt-03 wrong (Root p.5 not sent) |
| [speed-k6](2026-11-21-speed-k6/report.md) | 26/28 (2 wrong) | 27/28 | 3.3 / 6.9 s | 4.9 / 8.1 s | 54% | $0.05 / $0.78 | Top 6 pages; Azul sent whole (≥75% of pages). rt-03 and rt-06 wrong: rule page missed, model answered "inferred" instead of falling back |
| [speed-k4-headings](2026-11-21-speed-k4-headings/report.md) | 23/28 +5 partial (0 wrong) | 24/28 → **27/28** after fix | 4.0 / 10.9 s | **4.9** / 12.2 s | 57% | $0.04 / $0.80 | Top 4 + heading boost + stricter excerpt note: rule-page misses now fall back (5/28). Off-by-one page citations fixed afterwards (quote-checked pages; re-scored from recorded matches). Partials checked by hand: no wrong rulings |
| [restyle-sonnet-1h](2026-11-21-restyle-sonnet-1h/report.md) | 26/28 +2 partial (0 wrong, hand-checked) | 25/28 | 5.1 / 8.4 s | 5.9 / 8.8 s | 39% | $0.17 / $0.36 | Contract v2 (step titles, branch steps, steps before branches) + 1-hour cache TTL. Step 1 unchanged vs baseline (6.0 / 8.8 s). Cold question costs more (1h write = 2× input) but the cache now survives 5–60 min gaps |
| [answer-polish-sonnet](2026-11-22-answer-polish-sonnet/report.md) | 25/28 +2 partial → **27/28 +1 partial (0 wrong)** after hand-check | 26/28 | 5.0 / 8.4 s | 5.6 / 9.2 s | 43% | $0.17 / $0.35 | Prompt: verdict ≤12 words (median 10, max 12), last step applies instead of restating (0 "Result" steps). Judge's rt-03 / rt-06 "partial/incorrect" were judge errors (Root p.12: the Eyrie rule tied clearings); pg-08 partial is fair (imprecise detail in the last step). Step 1 vs restyle-sonnet-1h: 5.6 vs 5.9 s median, 9.2 vs 8.8 s p90 |
| [root-sets-sonnet](2026-11-24-root-sets-sonnet/report.md) | 10/12 +2 partial → **12/12** after hand-check | 12/12 | 24.0 / 27.1 s | 24.7 / 27.9 s | 0% | $0.34 / $0.75 | **Several rulebooks (S13)**, `root-sets.json` (12 questions, Root's 2 core books + one add-on ticked or none). Whole joined PDF (Law + Learning = 20.5 MB, ~163k tokens); sets over 22 MB went as an excerpt. Both partials: the "not in play" flag was in the assumptions, which the judge didn't count. Joined PDFs are far too slow whole: step 1 ≈ 25 s even with a warm cache |
| [root-sets-sonnet-pages-auto](2026-11-24-root-sets-sonnet-pages-auto/report.md) | 8/12 +4 partial → **12/12** after hand-check (1 imprecise step) | 12/12 | **4.3 / 5.3 s** | **4.9 / 5.9 s** | **67%** | $0.06 / q | Same set, page selection (top 4, no neighbours): recall 12/12, 4 pages sent per question, one full-PDF fallback (rs-06-off, not covered: 30 s). 3 partials are the assumption flag again; rs-02-on says the learning guide "says the same" (it omits "rounded up"), ruling right |

Offline re-scores (no new answers): [layout-tolerant-rescore](2026-11-22-layout-tolerant-rescore/README.md), every recorded run re-matched with fragment / partial matching and piecewise geometry: quotes spotlit **76% → 90%** (761 → 895 of 997 across runs; answer-polish-sonnet 71 → 78 of 86), matched as text 967 → 976 (+8 partial). All 48 new placements hand-checked: 0 wrong.

Probe runs (not scored): [azul-highlight-probe](2026-11-22-azul-highlight-probe/report.md), the owner's Azul question + follow-ups + one Root question, with per-quote text match and geometry.

Costs come from the per-model price table in `Core/.../Providers/Pricing.swift`.

## What we learned (2026-11-21)
- **Accuracy and evidence are solved** for these four rulebooks: every model found the right pages (27/27), and Opus/Sonnet were right on ≥27/28.
- **Speed is the open problem.** Even the fastest config reaches step 1 within 5 s only 43% of the time. First token alone takes ~4–5 s on a 40k-token rulebook, for every model, versus ~1.5 s on the 4-page fixture: **the size of the PDF in the prompt, not the model, sets the floor.**
- **Highlight misses were our matcher, not the model**: scrambled multi-column text layers (Root p.6, p.15). Fix planned: layout-tolerant matching, then a repair call.
- **Native citations are not worth it**: same speed, lower accuracy, fewer clean highlights, no figure boxes.

## What we learned (2026-11-21, speed experiment — [docs/speed-report.md](../../docs/speed-report.md))
- **Sending fewer pages works when retrieval hits**: with 3–4 pages (10–13k input tokens instead of ~34k), first token drops from ~4.0 s to ~3.0 s and step 1 to **4.5–4.6 s median, 5.6–5.7 s p90** on the questions that don't fall back.
- **The tail is the fallback**: when the excerpt can't settle it (genuinely not_covered questions, or keyword retrieval missed the rule page), the full-PDF retry costs another ~7–9 s (excerpt attempt + a full PDF whose cache is cold). 4–5 of 28 questions → p90 step 1 11–12 s, worse than full PDF (9.2 s).
- **Keyword retrieval misses table-talk nicknames** ("cats", "birds", "my guys walk") for rules on generic pages (Root p.5 movement/rule). Without a fallback that is a wrong answer; the model says "inferred" unless told to say not_covered.
- **Cost goes up, not down**: a different page subset per question gets no cache reuse, so warm questions cost ~$0.025–0.036 vs $0.009 with the cached full PDF (20 questions/PDF: $0.51–0.80 vs $0.25).
- **Don't trust model page numbers on excerpts**: with a longer excerpt note the model cited the previous page several times; quotes are now checked against the selected pages' text.

## What we learned (2026-11-22, layout-tolerant matching)
- **Most "whole page" highlights were geometry, not text**: the quote matched but PDFKit's character boxes didn't fit one index mapping (ligatures like "ﬃ", glyphs stored after an interleaved sidebar). Locating word chunks piecewise placed about 115 of them; fragments (+9) and partial matches (+8) added the rest.
- **Guard rails earned their keep**: two wrong placements in the first pass (invisible 2 pt card text, a fragment ending on a coincidental letter). Every new placement is now checked against `fixtures/match-set.json` (`bench match-set`).
- What stays unmatched is mostly captions over artwork with decorative initials (Root p.5): Vision OCR (M3).

## What we learned (2026-11-24, several rulebooks: [root-sets-sonnet](2026-11-24-root-sets-sonnet/report.md), [pages-auto](2026-11-24-root-sets-sonnet-pages-auto/report.md))
- **Joining works for accuracy and evidence**: every ruling right after hand-check, every evidence page right, every quote spotlit (35/35, 32/32), cited as "Law of Root p.12, Riverfolk p.5". With an add-on ticked, answers cite the Law first and the booklet second (order of authority).
- **"Not in play" works as designed**: with the add-on unticked, the five questions the Law of Root covers keep the ruling and say "assumes it is in play (not ticked tonight)"; the Rootbotics question, which only its own Law covers, is `not_covered` and names it. The LLM judge counts the assumption as not flagging it (6 of the 6 partials); the app only shows assumptions in the expanded sheet, so the flag is easy to miss at the table.
- **Whole joined PDFs are too slow**: Law + Learning to Play is 56 pages, 20.5 MB, ~163k tokens; first token ≈ 24 s cold *and* warm. Every Root night with an add-on but Riverfolk is over 22 MB anyway (excerpt). Page selection brings step 1 to 4.9 s median at a third of the cost, with recall 12/12 on this set.

