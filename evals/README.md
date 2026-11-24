# evals — answer-engine evals

The `bench` CLI runs question sets against rulebook PDFs and scores correctness, evidence, highlights, latency and cost. Same `Core` code path as the app.

Runs a question set against rulebook PDFs through the same `AckshuallyCore` code the app will use
(`ClaudeProvider` → streaming → `QuoteMatcher`) and writes a markdown report plus raw JSONL.

## Prerequisites

1. **Rulebook PDFs** in `assets/rulebooks/` (repo root). Expected names — anything containing the
   keyword also works:

   | Game | Expected file | Fallback match |
   |---|---|---|
   | Power Grid | `powergrid.pdf` | name contains `power` |
   | Root — Learning to Play | `root-learning.pdf` | contains `root` |
   | Azul | `azul.pdf` | contains `azul` |
   | Dune: Imperium | `dune-imperium.pdf` | contains `dune` |
   | Root, several books (`root-sets.json`) | `root-law.pdf`, `root-learning.pdf`, `root-riverfolk-learning.pdf`, `root-underworld-learning.pdf`, `root-marauder-learning.pdf`, `root-homeland-learning.pdf`, `root-clockwork-law.pdf` (Leder Games' resources page) | – |

   Missing PDFs are skipped (reported as *skipped*, not failures). PDFs are git-ignored.
2. **API key**: `export ANTHROPIC_API_KEY=sk-ant-...`. Without it `bench run` exits with code 2 and
   sends nothing.
3. Xcode 16.2 / Swift 6.0.3, macOS 14+.

## Run

```sh
cd evals

# 0. smoke test on the generated fake rulebook (~5 cheap questions, ~1 minute)
swift run bench run --questions questions/fixture.json

# 1. the M1 set (28 questions), default: claude-sonnet-5-5, json evidence mode, effort low
swift run bench run

# 2. the comparison matrix (opus json / opus citations / sonnet json / haiku json)
./compare.sh
```

Each run prints progress to stderr and writes `evals/out/<stamp>-<model>-<mode>-<effort>/`:
`report.md`, `results.jsonl` (one record per question: timings, usage, cost, full answer, raw
model text, judge verdict, per-quote highlight outcome), `config.txt`.

### Useful options

| Option | Default | |
|---|---|---|
| `--model ID` | `claude-opus-5-5` | e.g. `claude-sonnet-5-5`, `claude-haiku-5-5` |
| `--mode json\|citations` | `json` | see *Evidence modes* below |
| `--effort low\|medium\|high\|xhigh\|max` | `low` | thinking depth; trades latency for accuracy |
| `--game powergrid,azul` / `--id az-04` / `--limit N` | all | subsets |
| `--judge-model ID` / `--no-judge` | `claude-sonnet-5-5` | LLM judge for verdict correctness |
| `--timeout SEC` | `120` | per question; a timeout is a failure |
| `--resume DIR` | | continue an interrupted run in `DIR` (skips questions already answered, rebuilds follow-up context) |
| `--no-schema` | | json mode without structured outputs (prompt-only JSON) |
| `--no-fallbacks` | | drop the server-side refusal fallback (`fallbacks: "default"`) if the API rejects it |
| `--base-url URL` | api.anthropic.com | proxy / mock server |
| `--pages all\|auto` | `all` | `auto` = page selection: rank pages locally (BM25) and send only the best ones (see [docs/speed-report.md](../docs/speed-report.md)) |
| `--k N` / `--neighbors N` / `--max-pages N` | `3` / `1` / none | page selection: top-ranked pages, pages either side of each, cap |
| `--excerpt pdf\|text` | `pdf` | send a sub-PDF (text + page images) or only the extracted page text |
| `--full-if-coverage X` / `--min-confidence X` | `0.75` / `0` | send the full PDF when the selection covers ≥ X of the book / scores are flat |
| `--no-page-fallback` | | don't re-ask with the full PDF when the excerpt answers `not_covered` |

Other subcommands:

```sh
swift run bench report out/<dir>                          # rebuild report.md from results.jsonl
swift run bench pages ../assets/rulebooks/azul.pdf         # which pages have a text layer (scans need OCR)
swift run bench retrieve --k 3 --neighbors 0               # offline: pages page selection would send + recall (no API)
swift run bench match ../assets/rulebooks/azul.pdf 6 "..."  # debug one quote → highlight (fragments, coverage; --render out/x.png)
swift run bench match-set                                  # matcher regression set (fixtures/match-set.json, real PDFs; skips missing ones)
swift run bench match-set --render out/handcheck           # … plus a crop of each placement, to check by eye (git-ignored)
swift run bench rescore results/<dir> [--continuous-only]  # re-match a recorded run's quotes offline → out/rescore-<dir>/
swift run bench fixture                                    # regenerate fixtures/fake-rulebook.pdf
```

## What is measured

Per question (and split **cold** = first question on a PDF / **warm** = later new question, cache
read / **followup** = same session with conversation context):

- time to first token, restated question, verdict, first step-1 evidence, step 1 complete, full answer
- input / cache-write / cache-read / output tokens and USD cost (list prices in `Core/.../Pricing.swift`)
- **verdict correct** — graded by an LLM judge (marked as such everywhere; spot-check `Misses`)
- **evidence page correct** — any cited page ∈ `expected_pages` (shown as TODO while those are empty)
- **highlight matched** — each quote fuzzy-matched to the PDF text layer on the cited page
  (also reports "found on another page" and "no text layer")
- figure **boxes** — sanity (inside page, not degenerate, not whole page) and IoU vs `expected_box`
- failures: timeouts, invalid/truncated output, API errors

## Evidence modes

- `json` — the model writes the SPEC §3 JSON itself (quotes + optional figure `box`), enforced with
  structured outputs; fields stream in contract order and are surfaced as soon as each closes.
- `citations` — Claude's native PDF citations: the model writes `QUESTION:/VERDICT:/STEP:` lines
  and the API attaches page-located `cited_text` to each step. Quotes are extracted by the API
  rather than typed by the model; no figure boxes (citations can't be combined with structured outputs).

## Question set format (`questions/*.json`)

```jsonc
{ "games": [ { "id": "azul", "name": "Azul", "pdf": "assets/rulebooks/azul.pdf", "pdf_match": ["azul"],
    "questions": [ {
      "id": "az-04", "question": "...", "expected_verdict": "...", "expected_confidence": "stated",
      "tags": ["figure"], "source": "URL or own",
      "expected_pages": [6],              // physical PDF pages, 1-based; [] = TODO
      "expected_quote": "...",            // optional
      "expected_box": {"x":0.1,"y":0.5,"w":0.4,"h":0.3},  // optional, figures (top-left origin)
      "follows": "az-03"                  // optional: follow-up in the same session
} ] } ] }
```

### Several rulebooks per game (S13)

A game can list its books instead of one `pdf`. Core books are always sent; a question ticks add-ons by id.
The books in play are joined into one PDF (`RulebookJoiner`, same code as the app), with the table of contents,
order of authority and not-in-play note in the prompt. A joined PDF over 22 MB is sent as an excerpt of selected
pages (`PageSelectingProvider.oversizeOptions`), as in the app.

```jsonc
{ "id": "root-sets", "name": "Root",
  "books": [
    { "id": "law", "title": "Law of Root", "role": "core", "pdf": "assets/rulebooks/root-law.pdf" },
    { "id": "riverfolk", "title": "Riverfolk", "role": "add_on", "pdf": "assets/rulebooks/root-riverfolk-learning.pdf" }
  ],
  "questions": [ {
    "id": "rs-01-on", "question": "...", "expected_verdict": "...",
    "add_ons": ["riverfolk"],                                   // ticked add-ons; none = core books only
    "expected_book_pages": [{ "book": "law", "page": 11 }]      // pages of each book's own PDF
} ] }
```

The report adds a *Rulebooks sent* table (books, PDF size, excerpt or not, cited pages as "Riverfolk p.4").
Set: `questions/root-sets.json` (6 questions that need an add-on, each asked with it ticked and unticked).

Once the PDFs are in, fill `expected_pages` (and boxes for `az-04..06`) in `questions/m1.json`,
then re-run; until then the page metric shows TODO.

## Results: what gets committed

- `out/` is scratch and git-ignored: every run lands there.
- Runs worth keeping are copied to `results/<date>-<label>/` (`report.md` + `results.jsonl`) and listed in
  [results/README.md](results/README.md) with one line of key numbers and what was learned.
- A run is worth keeping when it informs a decision (model choice, evidence mode, a fix) or is a new baseline.
