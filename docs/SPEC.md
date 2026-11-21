# ackshually — Product Spec

> Settle a board-game rules dispute mid-game. Ask about the rulebook PDF, get the ruling at once, and swipe through the highlighted evidence when someone pushes back.

**Visual reference:** [design/screens.html](design/screens.html) (open in a browser). Each screen below links to its mockup as `S1`–`S12`. When this text and the mockups disagree, update whichever is wrong; don't leave them out of sync.

| | |
|---|---|
| Status | Pre-M1 run. M1 code is on branch `m1-tech-validation`, waiting on PDFs + API key. |
| Platform | iOS (SwiftUI), also runs on Mac. Owner's iPhone is the only target device. |
| Model | Claude, behind a provider interface. |
| Origins | [App concept](original/app-concept.md) · [Technical test plan](original/technical-test-plan.md) |

---

## 1. Product

### The moment
Mid-game, someone asks "wait, can I do that?" and the table is waiting. **Speed and trust beat depth.** The person asking may be anyone at the table, and the phone often gets handed to the skeptic.

### Principles
1. **Ruling first, proof on demand.** The verdict shows immediately; the evidence is one swipe away.
2. **The source is the star.** The rulebook page stays on screen; the app never hides what the rule actually says.
3. **Never confidently wrong.** Every answer is labeled *Stated*, *Inferred* or *Not covered*. External sources are always labeled.
4. **Never block the table.** No waiting to upload, prepare, or confirm before asking.
5. **Neutral referee.** Verdicts are plain and fair; the personality lives in the name, labels and empty states.

### In scope now
- One PDF per game, uploaded by the user.
- Ask by typing or push-to-talk. Answers on screen, optional read-aloud.
- Answers with branches when the outcome depends on something unstated.
- Conversation context within a session; sessions saved per game, on device.
- Web fallback (BGG / Reddit) when the rulebook doesn't settle it.
- 👍/👎 per answer, export a game's data as JSON.

### Not now (later, maybe)
Multiple PDFs per game (expansions, FAQs; the data model already allows it) · asking clarifying questions · curated rulebook library · remembering past rulings as house rules · server / other users / Android · iCloud sync.

---

## 2. Screens

Milestone in brackets. Gestures in **bold**.

### S1 · My Games [M3] — [mockup](design/screens.html#s1)
List of games (cover, name, sessions or preparation progress) + "Add a rulebook PDF" field.
- **Tap a game** → viewer, resumes the last session.
- **＋** → iOS file picker / share-sheet import → S2.
- **Swipe left** → Export · Delete.
- Before M3, the app opens straight into the last PDF.

### S2 · New game, preparing [M2 / M3] — [mockup](design/screens.html#s2)
- The PDF is **readable and askable immediately**.
- A thin progress line appears only if pages need OCR (scans, outlined text), and disappears when done.
- Until a page is prepared, highlights on it fall back to showing the whole page.

### S3 · Asking [M2] — [mockup](design/screens.html#s3)
- **Type** and send: always available, for private questions.
- **Hold 🎙**: live transcript, **release** to send, **slide left** to cancel.
- **Tap 🎙**: dictation; review and edit before sending.
- The PDF can be browsed freely (pinch, scroll) at any time.

### S4 · Answer arriving [M2] — [mockup](design/screens.html#s4)
The sheet rises as soon as the first words arrive, filling in this order:
1. **Restated question** ("3 energy + a Battery, at end of turn"). If it's wrong, **Stop** and rephrase without waiting.
2. **Verdict + confidence label.**
3. **Step 1** → the PDF jumps to the page, zooms, highlights. Later steps keep loading.

### S5 · The answer sheet [M2] — [mockup](design/screens.html#s5)
Two layers, no Back/Continue buttons:
- **Answer header** (fixed while stepping): restated question · verdict · confidence label with pages (`✓ Stated · p.12, p.14`) · branch pills (`No Battery? Discard 3 ›`).
- **Step cards**: a horizontal carousel; the next card peeks from the edge. Each card: number, title, page, one or two sentences.

### S6 · Stepping [M2] — [mockup](design/screens.html#s6)
- **Swipe left / tap the right peek** → next step. The PDF follows the card (page turn, zoom, highlight).
- **Swipe right / tap the left peek** → previous step.
- **Last card**: the result + 👍/👎, with the follow-up field under it.
- A step can cite several passages (pager "1 of 2 ›" on the PDF) or a figure (box outline; if no usable box, the whole page + "see the diagram, lower half").

### S7 · Show the skeptic [M2] — [mockup](design/screens.html#s7)
- **Drag the sheet down** → page near full-screen, one-line verdict + page pinned at the bottom. **Drag up** to restore.

### S8 · Inspect freely [M2] — [mockup](design/screens.html#s8)
- **Pinch / pan** the PDF at any time to read surrounding qualifications. Tapping the PDF never changes steps.
- A **⤺ Back to step N** pill re-centers on the highlight.
- **Double-tap**: evidence zoom ↔ full page.

### S9 · Full answer [M2] — [mockup](design/screens.html#s9)
- **Drag the sheet up** → header, list of all steps (**tap** to jump), assumptions.
- **Tap a branch pill** → the step cards switch to that branch; a "Main answer" pill returns.

### S10 · Not covered → web [M4] — [mockup](design/screens.html#s10)
- Triggered when the rulebook answer is *Inferred* or *Not covered*. The rulebook part shows first; a "Searching BGG & Reddit…" card fills in after.
- Web findings are **bordered step cards**, never PDF highlights: site, date, author role (designer / publisher / community), quote, link.
- If a source disagrees, the rulebook verdict stays in the header and the card says **⚠ Designer disagrees** (strong) or **⚠ Community disagrees** (soft).

### S11 · Feedback [M3] — [mockup](design/screens.html#s11)
- **👍** saved silently. **👎** → one-tap reason (wrong verdict, missed exception, wrong highlight, wrong page, too slow, other), optional step, optional note.
- **⋯ → Export game**: one JSON with all sessions, questions, full model outputs, timings, tokens, ratings.

### S12 · Sessions [M3] — [mockup](design/screens.html#s12)
- **⋯ → Sessions**: past questions per game, grouped by night. **Tap** → reopens that answer.
- **New** = new game night; clears conversation context.

### Read-aloud [M4] (no mockup)
Off by default, toggled in ⋯. Speaks the restated question + verdict only. Any tap stops it.

---

## 3. Visual style

| Token | Value | Use |
|---|---|---|
| background | `#efe4d0` | app chrome, nav |
| sheet | `#f4e9d5` + 1px `#d8c6a8` top border | answer sheet, a shade darker than the page so app and rulebook never blend |
| card | `#fffaf0` | step cards, list rows |
| ink / muted | `#33261b` / `#8a735c` | text |
| line | `#d8c6a8` | borders, dividers, inactive dots |
| accent | `#a2412b` | primary actions, active dot, warnings |
| highlight | `#f2b134` at ~40% fill, `#d39320` outline | evidence on the PDF |
| stated | `#3f6b2a` on `#e3efd9` | "✓ Stated" label |

- **One font:** SF (system) everywhere. The rulebook keeps its own fonts.
- **Corners:** sheet 16, cards 11–12, buttons 9, labels 6.
- **Voice:** short, precise, a little nerdy, never smug. Examples: "Well, according to p.14…", "✓ Stated · p.12, p.14", "? Not covered", "⚠ Designer disagrees", "Reading the rulebook…".
- **Dark mode:** not designed yet.

---

## 4. Answer contract

What the model returns. **Field order is streaming order.**

```jsonc
{
  "restated_question": "You have 3 energy and a Battery at end of turn.",
  "verdict": "Keep 2 energy, discard 1.",
  "confidence": "stated | inferred | not_covered",
  "branches": [{ "condition": "Without a Battery", "verdict": "Discard all 3." }],
  "assumptions": ["The Battery is already in play."],
  "steps": [
    {
      "title": "General rule",
      "text": "Unused energy is discarded at end of turn.",
      "evidence": [
        { "page": 12, "quote": "discard all unused energy", "box": null }   // box: {x,y,w,h} normalized 0–1, for figures
      ]
    }
  ],
  "needs_web": false
}
```

**Placing a highlight**, in order:
1. Match `quote` to the page's words (PDF text layer, or OCR words for scanned/outlined pages) → word-level highlight.
2. Else draw `box` if it passes sanity checks.
3. Else show the whole page; log a miss.

Two evidence modes are being compared in M1: quotes written by the model (`json`, supports figure boxes) vs. Claude's native PDF citations (`citations`, no boxes). The winner becomes the default.

---

## 5. Architecture

```
Core/    Swift package, no UI (macOS + iOS)
         models · AnswerProvider protocol + ClaudeProvider · streaming field parser
         quote matcher (fuzzy) · box checks · [M3] Vision OCR prep · [M4] web fallback
bench/   Swift CLI on Core: runs question sets, writes report + JSONL
App/     [M2] SwiftUI app: PDFKit viewer, answer sheet, SwiftData storage
```

- The app and the bench share `Core`, so benchmark numbers reflect the app.
- Whole PDF + question + conversation in one streamed request; PDF prompt-cached so follow-ups are cheap.
- Data model: `Game → [Document]`, `Game → [Session] → [Answer]`. Everything on device.
- API key: Keychain in the app, `ANTHROPIC_API_KEY` env var for the bench. App calls the API directly (no server yet).
- Step carousel: horizontal `ScrollView` + `.scrollTargetBehavior(.viewAligned)`, side margins for the peek, `.scrollPosition(id:)` drives the PDF. Fallback: `TabView(.page)`.
- Figures: v1 = model-proposed box. If boxes score badly → Vision-detected candidate regions, model picks one.

---

## 6. Milestones

| | Goal | Contents | Exit |
|---|---|---|---|
| **M1** Assumption check | Prove the approach, quickly | `Core` + `bench`, 23 questions over Power Grid, Root (Law of Root), Azul, Dune Imperium | Numbers look viable, or we know what broke. Keep it short. |
| **M2** iOS viewer | Something to use at the table | S3–S9: ask (text + push-to-talk), streaming, answer sheet, stepping, collapse/expand, inspect, follow-ups | Usable on the owner's iPhone |
| **M3** Real tool | Game-night ready | S1, S2 (background OCR), S11, S12; full ~60-question bench incl. a scanned variant | Used unprompted at game night |
| **M4** Fallbacks | Cover the gaps | S10 web fallback, read-aloud, better figure boxes if needed | — |

**M1 tests five assumptions:**
1. One call with the full PDF answers correctly with usable evidence (target ≥90%).
2. Verdict + step 1 arrive fast when streamed (target median ≤5 s, 90% ≤10 s).
3. Quotes land on the right words (target ≥90% of highlights).
4. Model-proposed boxes land roughly right on figures (Azul).
5. Cost per question is tolerable, and caching makes follow-ups cheap.

Results go in [m1-report.md](m1-report.md).

---

## 7. Decisions log

Append new decisions here; change the sections above to match.

| Date | Decision | Why |
|---|---|---|
| 2026-11-21 | Mid-game dispute is the primary use | Drives speed, verdict-first, voice input |
| 2026-11-21 | Verdict first, proof on demand | Tables want the ruling; proof is for the skeptic |
| 2026-11-21 | User-uploaded PDFs; curated library later | No rights issues; validates on own games |
| 2026-11-21 | Web fallback only when rulebook isn't enough; rulebook always leads | Fast path stays fast; never silently overridden |
| 2026-11-21 | Branches instead of clarifying questions | Simpler agent; no round-trip while the table waits |
| 2026-11-21 | iOS-first SwiftUI, Claude behind an interface, direct API calls | Owner's iPhone; native PDFKit; no server yet |
| 2026-11-21 | Figures: model box first, Vision candidates if needed | Cheapest thing that produces a measurement |
| 2026-11-21 | Layout B: full PDF + bottom sheet | Keeps the source central |
| 2026-11-21 | Sheet v2: fixed header + peeking step cards, no buttons | Buttons + swipe were redundant; old sheet mixed answer and step |
| 2026-11-21 | Warm palette, one font (SF), precise nerdy wording | Owner's pick from three directions |

---

## 8. Open items
- [ ] Owner: add the 4 rulebook PDFs to `assets/rulebooks/` (Root: *The Law of Root*).
- [ ] Owner: provide the API key for the M1 run.
- [ ] Fill in expected pages / Azul boxes in `bench/questions/m1.json` once PDFs are in.
- [ ] Photograph a few Azul pages for the scanned variant (M3).
- [ ] Design dark mode and app icon.
- [ ] Set a cost ceiling per question after M1 numbers.
