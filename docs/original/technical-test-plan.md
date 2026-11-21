Test whether one model call can answer a question and produce a usable guided explanation within a few seconds. Add indexing as the measurements justify it. [App Concept](https://chatgpt.com/space/page_bfa7d0fd9e348191a03625d914479867)

# Start with the full PDF

Build a small web viewer with page navigation, zoom, highlights, and a Continue button.

Send the PDF, question, and conversation context in one request. Ask for the answer, ordered steps, and supporting page references with quotes or figure regions.

Match quotes to PDF word coordinates for precise highlights. If placement fails, show the page and record the miss. Direct PDF input can supply text and page images. [OpenAI documentation](https://developers.openai.com/api/docs/guides/file-inputs)

# Measure the baseline

Use six rulebooks and about 60 questions with known answers and evidence. Include long books, scans, diagrams, approximate wording, exceptions, follow-ups, and unanswerable questions.

| Measure | Proposed pilot target |
| - | - |
| First correct step displayed | Median ≤5 seconds, 90% within 10 seconds |
| Correct answer with sufficient evidence | ≥90% of questions |
| Correct highlight placement | ≥90% of required highlights |

Also log preparation time, full answer time, model calls, retries, and cost. Compare first and later questions, and total cost at one, five, and twenty questions per PDF.

Repeat runs on the same questions and report results by document size and question type. Count timeouts and invalid outputs as failures. Rerun failures with the known evidence pages to check whether retrieval is the bottleneck.

# Add indexing in stages

| Problem | Next experiment |
| - | - |
| Full PDF is too slow or costly | Extract page text, use keyword search, and send the best pages plus neighbors |
| Approximate wording misses evidence | Combine keyword search with text embeddings |
| Highlights land in the wrong area | Compare quadrants with detected paragraphs, tables, and figures |
| Visual evidence is missed | Test image-based page retrieval, then region captions or concept tags |

For each stage, reuse the benchmark and check that all required evidence is retrieved, including exceptions.

Existing tools to test include [PyMuPDF](https://pymupdf.readthedocs.io/en/latest/app1.html) for text coordinates, [Docling](https://docling.ai/) for layout and regions, and [ColPali](https://proceedings.iclr.cc/paper_files/paper/2025/hash/99e9e141aafc314f76b0ca3dd66898b3-Abstract-Conference.html) for visual page retrieval.

# Deliverable

A working baseline and a short report showing speed, quality, cost, supported document sizes, and which indexing step is justified.
