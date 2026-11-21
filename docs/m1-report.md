# M1 report — assumption check

**Status: built and unit-tested; live run pending.** Two things are missing: the four rulebook
PDFs (`assets/rulebooks/`) and `ANTHROPIC_API_KEY`. Nothing has been sent to the API yet, so there
are **no real numbers yet**. Everything below that is not marked *pending* was checked offline
against a generated test rulebook and a mock SSE server.

How to finish: put the PDFs in place, `export ANTHROPIC_API_KEY=…`, then from `bench/` run
`swift run bench run --questions questions/fixture.json` (smoke test), then `./compare.sh`.
Fill in `expected_pages` in `bench/questions/m1.json` to turn on the page metric. See
[bench/README.md](../bench/README.md).

## What was built

| Piece | Where | Notes |
|---|---|---|
| Models | `Core/Sources/AckshuallyCore/Model` | Game → [Document], Session/Turn, Answer/Step/Evidence (SPEC §3, field order = streaming order) |
| `AnswerProvider` + `ClaudeProvider` | `Core/.../Providers` | One streamed request: full PDF + question + prior turns. Cache breakpoint on the PDF block plus automatic caching for the conversation tail. Model, effort and evidence mode are configurable. Uses API version `2026-10-21` and the server-side refusal fallback (on by default, `--no-fallbacks` turns it off) |
| Progressive parsing | `Core/.../Streaming` | Incremental JSON scanner emits `restatedQuestion → verdict → confidence → branch → evidence → step` events as each value closes. Verified char-by-char |
| Quote matcher | `Core/.../Matching` | PDFKit text layer, normalized (NFKD ligatures, case/diacritics, letters+digits only, so whitespace, line breaks, hyphenation and punctuation are ignored). Exact match first, then fuzzy Sellers edit distance ≤ 12%. Searches claimed page → neighbours → whole book and reports *matched on another page*. Box sanity check |
| `bench` CLI | `bench/` | Report + JSONL, cold/warm/follow-up split, LLM judge (labelled), timeouts/invalid JSON count as failures, resumable |
| Question set | `bench/questions/m1.json` | 23 questions: Power Grid 7, Root 5, Azul 6, Dune 5. Includes exceptions, sloppy wording, one follow-up chain (pg-05→pg-06), one unanswerable (pg-07) and 3 figure/scoring questions (az-04..06). **All expected pages/boxes are TODO** until the PDFs exist |

Core builds for macOS and the iOS Simulator. 13 unit tests pass (`cd Core && swift test`).

## The 5 assumptions

| # | Assumption | Status | Evidence so far |
|---|---|---|---|
| 1 | One call with the full PDF answers correctly with usable evidence | ⏳ pending | Needs PDFs + key. Metrics are wired up: judge-graded verdict, page correct, every-quote-matched rate |
| 2 | Verdict + step 1 within ~5 s when streamed | ⏳ pending | The streaming path is proven: verdict and step 1 surface while the rest is still generating, so the UI won't wait for the full answer. The real latency risk is model thinking time before the first token; that is why effort defaults to `low` and the report breaks out time-to-first-token separately |
| 3 | Quotes match PDF word coordinates reliably | 🟡 matcher ✅, model quotes pending | On the generated PDF: exact matches, quotes spanning line breaks with different punctuation/case/dashes, small wording differences (e.g. "two" for "2"), wrong-page detection and not-in-book rejection all behave correctly. Unknown: how often the model's quotes are verbatim on real books, and whether real PDFs have usable text layers (`bench pages` checks this; outlined-text/scanned pages report "no text layer" → OCR in M3) |
| 4 | Model-proposed figure boxes land roughly right (Azul) | ⏳ pending | Box sanity + IoU/center-in-expected scoring are built. az-04..06 need `expected_box` filled from the real PDF. Citations mode can't give boxes, so this only applies to json mode |
| 5 | Cost tolerable; caching makes follow-ups cheap | ⏳ pending (estimate below) | Request bodies are byte-deterministic (order-preserving JSON, tested), so the cached prefix stays stable. The report gives cold/warm/follow-up token splits and 1/5/20-questions-per-PDF projections |

**Cost estimate (to check against real numbers, not measured).** This assumes a 20–30 page
rulebook at about 1.5–3K tokens per page (text plus page image), so roughly 40–60K PDF tokens.
At Opus 5.5 list prices ($4 in, $20 out, $5 cache write, $0.20 cache read per MTok):

- cold question: about $0.20–0.30, mostly the one-off cache write
- warm or follow-up question: about $0.02–0.04, which is ~1K output tokens plus a cheap cache read

A 20-question game night would come to about $0.80–1.00. Sonnet 5.5 is about half that and
Haiku 5.5 about 1/40. The cache lasts 5 minutes. A gap longer than that between questions pays
the cold price again: it can be bridged with a keep-alive or the 1-hour TTL, decided after M1.

## Evidence mode comparison: model-written JSON quotes vs native citations

Both modes are implemented behind the same `AnswerProvider` and produce the same `Answer`, so the
bench compares them directly (`--mode json` vs `--mode citations`).

| | json (default) | citations |
|---|---|---|
| Quote fidelity | Model retypes the quote: risk of paraphrase and of wrong page numbers (printed vs physical page) | `cited_text` is extracted by the API from the PDF, so it should match the text layer near-perfectly. Page comes from the API, not the model |
| Answer contract | Structured outputs guarantee valid JSON in field order | Line format parsed into the contract; less strict (the model could skip a line), and invalid lines show up as failures |
| Streaming | Fields surface as they close | Lines surface as they close, with the same events |
| Figure boxes | ✅ | ❌ (whole-page fallback only) |
| Cost | Baseline | Slightly more input (chunking); `cited_text` doesn't count as output |

**Expectation (to confirm):** citations should win on highlight match rate and page correctness.
JSON stays necessary for figure boxes. If the numbers confirm this, the likely M2 design is
citations for text evidence plus a JSON `box` only on figure steps. Two ways to get there:
- a hybrid prompt: citations mode with a `FIGURE: page; x,y,w,h` line
- falling back to JSON mode only when a step is a figure

This becomes a decision once the run's highlight rates are in.

## Risks found while building (unverified until the live run)

- **API shape risks.** These were written from current docs but have not been exercised live:
  - structured outputs together with a streamed PDF request
  - `fallbacks: "default"` together with streaming, structured outputs or citations. If the
    API rejects it, rerun with `--no-fallbacks`.

  The fixture smoke run surfaces any of these within one question.
- **Page numbering.** The prompt says to use the physical PDF page and ignore printed numbers.
  Books whose printed numbers are offset from the file pages are the main source of wrong pages
  in json mode. The matcher detects "found on another page", so the report will show how often
  this happens.
- **Thinking latency.** Opus 5.5 always thinks, and `effort` is the only control. If time to
  first token blows the 5 s budget, the next things to try are:
  - Sonnet 5.5 or Haiku 5.5
  - Opus with fast mode (`speed: "fast"`), which is not wired yet
- **Follow-up context in json mode.** The prior answer is replayed as its raw JSON, which works
  but costs output-sized input tokens per turn. That is negligible at M1 scale.

## Recommendation

**Do the live run before starting M2. It takes about an hour once the PDFs and key exist.** None
of the five assumptions can be called yet. Then:

- If assumptions 1–3 come back roughly green (≥ ~80% correct, step 1 ≤ ~5 s median, ≥ ~85% of
  quotes matched), **go straight to M2 as built**. Core and the provider are designed to be the
  app's code path.
- If highlights in json mode are poor but good in citations mode, **switch the default to
  citations first**, with boxes only for figures. That is a small change in `Prompts` and
  `ClaudeProvider`.
- If step-1 latency is bad on Opus at low effort, **pick the model from the matrix** (Sonnet 5.5
  is the likely default) before M2. Indexing isn't needed yet.
- If cost is the problem, caching numbers will show whether that is cold-only (fine) or every
  question (a cache bug to fix first).
