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

Costs come from the per-model price table in `Core/.../Providers/Pricing.swift`.

## What we learned (2026-11-21)
- **Accuracy and evidence are solved** for these four rulebooks: every model found the right pages (27/27), and Opus/Sonnet were right on ≥27/28.
- **Speed is the open problem.** Even the fastest config reaches step 1 within 5 s only 43% of the time. First token alone takes ~4–5 s on a 40k-token rulebook, for every model, versus ~1.5 s on the 4-page fixture: **the size of the PDF in the prompt, not the model, sets the floor.**
- **Highlight misses were our matcher, not the model**: scrambled multi-column text layers (Root p.6, p.15). Fix planned: layout-tolerant matching, then a repair call.
- **Native citations are not worth it**: same speed, lower accuracy, fewer clean highlights, no figure boxes.
