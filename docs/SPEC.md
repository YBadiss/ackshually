# ackshually — Product & Build Spec (v0)

Settles a board-game rules dispute mid-game: ask a question about the rulebook PDF, get a ruling immediately, and step through the highlighted evidence on the page when someone pushes back.

Source docs: [App concept](original/app-concept.md) · [Technical test plan](original/technical-test-plan.md). This spec records the decisions made on top of them (2026-11-21).

---

## 1. Product decisions

| # | Topic | Decision |
|---|---|---|
| 1 | Primary moment | **Mid-game dispute.** The table is waiting; speed and trust beat depth. |
| 2 | Answer presentation | **Verdict first, proof on demand.** Ruling + step 1 evidence shown immediately; Continue walks remaining steps. |
| 3 | Rulebook source | **User uploads own PDF** for the prototype. Curated, pre-indexed library later once indexing exists. |
| 4 | Not settled by rulebook | Rulebook first; **web fallback (BGG / Reddit)**, always labeled as external. |
| 5a | When to search the web | **Fallback only** — when the rulebook answer is *Inferred* or *Not covered*. Designed so "always in parallel" is a config switch later. |
| 5b | Sources disagree | **Rulebook verdict always leads.** Web finding shown as a flagged "⚠️ Community/designer disagrees" card; never silently overrides. Designer/official sources flagged more strongly than random comments. |
| 6 | Input / output | **Text always** (private questions) **+ push-to-talk** on top. Output **always on screen + optional read-aloud**. Navigation by tap. |
| 7 | Missing info | **Answer with branches** ("Discard all. Unless you have a storage item: keep up to 2"). Asking clarifying questions deferred. Conversation context carries across questions in a session (normal agent behaviour). |
| 8 | Documents | **1 PDF per game in the UI**, but data model is `Game → [Document]` so expansions/FAQs are UI work later. |
| 9 | Definition of "proven" | **(a) Benchmark passes**, then **(b) it gets used at your own table**. Strangers / business signal not goals now. |
| 10–11 | Platform | **iOS-first SwiftUI**, runs on Mac via "Designed for iPad" / Simulator. Owner's iPhone is the only target device. Owner directs, Claude writes the code. |
| 12 | Benchmark games | **Power Grid, Root (Law of Root), Azul, Dune Imperium.** Questions from BGG/forums + our own; built together. Plus a deliberately scanned/photographed variant of some pages (e.g. Azul). |
| 13 | Answer screen | **Layout B: full-screen PDF + bottom sheet** (verdict, step text, Back/Continue). May evolve. |
| 14 | Persistence | **Games + sessions saved per game, on-device only** (SwiftData). No sync. |
| 15 | Model | **Provider-agnostic interface, Claude first.** App calls the API directly with the owner's key in Keychain. Backend later. Cost is measured, no hard ceiling yet. |
| 16 | Visual evidence | **B: model returns an approximate box** for figures; fallback = whole page + pointer text. Upgrade path **B+**: Vision-detected candidate boxes, model picks one. |
| — | Scans / outlined text | Per-page check for a usable text layer; if missing, **on-device OCR (Apple Vision)** gives word boxes. Fuzzy quote matching. |
| 17 | Waiting | **Progressive streaming**: restated question → verdict → step 1 jumps to page → later steps fill in. **Background preparation**: PDF usable and askable immediately; OCR improves highlights when done. |
| 18 | Feedback | **👍/👎 per answer** + optional note (can name a step). **Export a whole game** (all sessions, full outputs, timings, ratings) as JSON. |
| 19 | Tone | **Neutral referee in verdicts**; personality lives in name, icon, empty states. |

### Experience principles (from concept, still binding)
- Source and surrounding qualifications easy to inspect.
- As many steps as the answer needs.
- External sources always identified.
- Navigation easy to pause or interrupt.

---

## 2. Screens & interactions

Wireframes use the energy/Battery example. `[ ]` = button, `▔▔` = sheet grab handle, `▓▓` = highlight. Milestone tags show when each screen lands.

### 2.1 My Games (home) — M3 (M2: opens straight to the last PDF)

```
┌──────────────────────────────┐
│ ackshually              [＋] │
│                              │
│ ┌──────────────────────────┐ │
│ │ ▣  Power Grid            │ │
│ │    3 sessions · Nov 14   │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ ▣  Root — Law of Root    │ │
│ │    Preparing… 62%        │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ ▣  Azul                  │ │
│ │    1 session · Nov 2     │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

| Action | Result |
|---|---|
| Tap a game | Opens **Game viewer** (2.3), resuming the latest session. |
| Tap **＋** | iOS file picker / share sheet import → **Add game** (2.2). |
| Swipe left on a game | Delete · Export game (JSON, see 2.9). |
| Empty state | Light personality allowed here: "Nobody's argued yet. Add a rulebook." |

### 2.2 Add game / preparation — M2 (basic), M3 (background OCR)

```
┌──────────────────────────────┐
│ ‹ Games      Azul            │
│ ┌──────────────────────────┐ │
│ │                          │ │
│ │   (rulebook page 1,      │ │
│ │    readable immediately) │ │
│ │                          │ │
│ └──────────────────────────┘ │
│ ◔ Preparing scanned pages 3/8│
│ ┌──────────────────────────┐ │
│ │ Ask about the rules…   🎙│ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

- PDF opens immediately; title taken from PDF metadata, editable.
- A thin status line appears only if some pages need OCR; it disappears when done. Asking is never blocked.
- Until a page is prepared, highlights on it fall back to whole-page view.

### 2.3 Game viewer — idle — M2

```
┌──────────────────────────────┐
│ ‹ Games   Power Grid    ⋯    │
│ ┌──────────────────────────┐ │
│ │                          │ │
│ │     PDF, free browsing   │ │
│ │     (pinch, scroll,      │ │
│ │      page thumbnails)    │ │
│ │                          │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ Ask about the rules…   🎙│ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

| Action | Result |
|---|---|
| Type + return | Sends question → 2.4. Keyboard dismisses. |
| **Hold 🎙** | Push-to-talk: live transcript fills the field; release sends. Slide away to cancel. |
| Tap 🎙 (no hold) | Toggles dictation; tap again to stop, then review/edit before sending. |
| ⋯ menu | Session history (2.8) · New session · Export game · Read-aloud on/off. |
| Pinch / scroll PDF | Normal free browsing; never interrupted by the app. |

### 2.4 Answer streaming — M2

Content appears progressively, in contract order. The sheet rises as soon as the first token arrives.

```
 t≈1s                          t≈3s                          t≈5s
┌────────────────────────┐    ┌────────────────────────┐    ┌────────────────────────┐
│  (PDF, unchanged)      │    │  (PDF, unchanged)      │    │ p.12                   │
│                        │    │                        │    │ ▓▓ End of turn: discard│
│                        │    │                        │    │ ▓▓ all unused energy.  │
│                        │    │                        │    │                        │
│ ▔▔                     │    │ ▔▔                     │    │ ▔▔                     │
│ You have 3 energy and  │    │ You have 3 energy and  │    │ ✓ Stated in rules      │
│ a Battery, end of turn.│    │ a Battery, end of turn.│    │ Keep 2 energy, discard │
│ ···                    │    │ ✓ Stated in rules      │    │ 1.                     │
│                        │    │ Keep 2 energy, disca▍  │    │ ↳ No Battery: discard 3│
│ [■ Stop]               │    │ [■ Stop]               │    │ 1/3 General rule…      │
└────────────────────────┘    └────────────────────────┘    │ [‹]  [Continue ›]  👍👎│
                                                            └────────────────────────┘
```

- **Restated question** first: if it's wrong, the user taps **Stop** and rephrases without waiting.
- **Verdict + confidence chip** (`✓ Stated` · `≈ Inferred` · `? Not covered`) next.
- **Step 1** arrives → PDF animates to the page, zooms to the evidence, highlight fades in.
- Later steps keep loading; Continue shows a small spinner if pressed before its step has arrived.

### 2.5 Stepping through evidence (layout B) — M2

```
 Sheet: medium (default)        Sheet: collapsed             Sheet: expanded
┌────────────────────────┐    ┌────────────────────────┐    ┌────────────────────────┐
│ p.14                   │    │ p.14                   │    │ ▔▔                     │
│ ▓▓ Battery: at end of  │    │ ▓▓ Battery: at end of  │    │ ✓ Keep 2, discard 1.   │
│ ▓▓ turn, keep up to 2  │    │ ▓▓ turn, keep up to 2  │    │ ↳ No Battery: discard 3│
│ ▓▓ unused energy.      │    │ ▓▓ unused energy.      │    │                        │
│                        │    │                        │    │ 1 General rule  p.12   │
│ ▔▔                     │    │                        │    │ 2 Battery exc.  p.14 ● │
│ ✓ Keep 2, discard 1.   │    │                        │    │ 3 Conclusion           │
│ 2/3 The Battery is an  │    │                        │    │                        │
│ exception to discard.  │    │                        │    │ Assumes the Battery is │
│ [‹]  [Continue ›]  👍👎│    │ ▔▔ Keep 2, discard 1.  │    │ already in play.       │
└────────────────────────┘    └────────────────────────┘    └────────────────────────┘
```

| Action | Result |
|---|---|
| **Continue ›** / swipe left on sheet | Next step: PDF animates (page turn if needed) → zoom → highlight. |
| **‹** / swipe right on sheet | Previous step. |
| Drag sheet down → collapsed | "Show the skeptic": PDF near full-screen, one-line verdict pinned at bottom. |
| Drag sheet up → expanded | Full answer: verdict, branches, assumptions, step list. Tap any step to jump to it. |
| Pinch / pan PDF during a step | Free inspection. A **⤺ Back to step** pill appears; tap to re-center the highlight. |
| Double-tap PDF | Toggle zoomed-to-evidence ↔ full page. |
| Step with several passages | Each passage highlighted; small "1 of 2 ›" pager on the PDF if they don't fit one view. |
| Step with a figure box | Box outline instead of text highlight. If no usable box → whole page + "see the diagram, lower half". |
| Last step | Continue becomes **Done** → sheet returns to medium, ask field focused for a follow-up. |

### 2.6 Branches — M2

- Branches show under the verdict as `↳ condition: verdict` rows.
- Tapping a branch replaces the step path with that branch's steps (the main path stays one tap away via a `Main answer` chip).
- If the user answers the branch in a follow-up ("I don't have a Battery"), the app treats it as normal conversation context.

### 2.7 Not covered + web fallback — M4

```
┌──────────────────────────────┐
│ p.21                         │
│ ▓▓ closest passage           │
│ ▔▔                           │
│ ? Not covered by the rulebook│
│ Closest rules: p.21, p.8     │
│ ┌──────────────────────────┐ │
│ │ 🌐 BoardGameGeek · 2021  │ │
│ │ Designer reply: "Yes,    │ │
│ │ you may…"   ↗ open thread│ │
│ └──────────────────────────┘ │
│ [‹]  [Continue ›]      👍👎  │
└──────────────────────────────┘
```

- Triggered automatically when confidence is `inferred` or `not_covered`. A "Searching BGG & Reddit…" line shows while it runs; the rulebook part is already on screen.
- Web results are cards, never PDF highlights; always show site, date, author role (designer / publisher / community) and a link.
- Conflict case: rulebook verdict stays on top; card turns into **⚠️ Designer disagrees** (strong) or **⚠️ Community disagrees** (soft).

### 2.8 Session history — M3

- From ⋯ → Sessions: list per game, by date, each showing its first question.
- Inside a session: scrolling list of Q → verdict rows; tap one to reopen it in the viewer at step 1.
- **New session** clears conversation context (new game night).

### 2.9 Feedback & export — M3

| Action | Result |
|---|---|
| Tap 👍 | Saved silently, brief checkmark. |
| Tap 👎 | Small sheet: chips *Wrong verdict · Missed exception · Wrong highlight · Wrong page · Too slow · Other*, optional step selector, optional note. One tap to send. |
| ⋯ → Export game | Share sheet with one JSON: game, documents, all sessions, questions, full model outputs, timings, tokens, ratings, notes. |

### 2.10 Read-aloud — M4

- Off by default; toggle in ⋯. When on, the **restated question + verdict** are spoken once they're complete. Steps are not read.
- Any tap on the sheet stops speech.

---

## 3. Answer contract (model output)

Field order matters: it is the streaming order.

```jsonc
{
  "restated_question": "You have 3 energy and a Battery at end of turn.",
  "verdict": "Keep 2 energy, discard 1.",
  "confidence": "stated | inferred | not_covered",
  "branches": [                       // optional; alternatives that depend on unstated facts
    { "condition": "Without a Battery", "verdict": "Discard all 3." }
  ],
  "assumptions": ["..."],             // optional
  "steps": [
    {
      "text": "General rule: unused energy is discarded at end of turn.",
      "evidence": [
        {
          "page": 12,
          "quote": "discard all unused energy",      // exact text → matched to word coordinates
          "box": null                                 // or {x,y,w,h} normalized 0–1, for figures
        }
      ]
    }
  ],
  "needs_web": false                  // true when confidence != stated → triggers fallback
}
```

A step may reference several pages. Steps follow the logic of the question, not page order.

Highlight resolution, in order:
1. `quote` → fuzzy match against the page's words (PDFKit text layer, or Vision OCR words) → word-level highlight.
2. `box` → draw the region (sanity-checked: inside page, not degenerate).
3. Fallback → show the whole page, step text points at the area; **log a miss**.

---

## 4. Architecture

```
ackshually/
├─ Core/            Swift package — no UI
│  ├─ Model         Game, Document, Session, Answer, Step, Evidence, Rating
│  ├─ Providers     AnswerProvider protocol; ClaudeProvider (first impl)
│  ├─ Prep          per-page text-layer check, Vision OCR, word boxes cache
│  ├─ Matching      quote → word boxes (fuzzy), box sanity checks
│  └─ Web           fallback search (later, M4)
├─ App/             SwiftUI iOS app (runs on Mac) — PDFKit viewer, layout B
└─ bench/           Swift CLI on Core — runs question sets, writes report
```

- Same `Core` code path for app and bench, so benchmark numbers reflect the app.
- API key: Keychain in app, env var in bench.
- Prompt caching on the PDF so follow-up questions are cheaper and faster.

---

## 5. Milestones

### M1 — Assumption check (short)
Goal: verify quickly that the approach works, then move on. Not the full benchmark.
- `Core` with Claude provider, answer contract, quote matcher.
- `bench` CLI, ~20 questions across the 4 rulebooks (BGG/forum + ours), each with expected verdict + evidence pages/quotes.
- Report: answer correct?, evidence correct?, highlight matched?, time to verdict / first step / full answer, tokens & cost, first vs follow-up question.
- **Exit:** numbers look roughly viable (or we learn which assumption broke). Then go straight to M2.

Assumptions to test:
1. One call with the full PDF answers correctly with usable evidence.
2. Verdict + step 1 arrive within ~5 s when streamed.
3. Returned quotes match PDF word coordinates reliably.
4. Model-proposed boxes for figures land roughly right (Azul).
5. Cost per question is tolerable, and caching makes follow-ups cheap.

### M2 — iOS viewer (the priority)
- Open a PDF, ask by text or push-to-talk.
- Layout B: PDF full-screen, bottom sheet with restated question, verdict, confidence chip, branches.
- Streaming; Continue / Back across steps; page jump + zoom + highlight; inspect full page.
- Follow-up questions with conversation context.

### M3 — Real tool for game night
- My Games list, sessions saved per game (SwiftData, on-device).
- 👍/👎 per answer + note; export a game as JSON.
- Background preparation + OCR for scanned/outlined pages.
- Expand bench to the full ~60 questions incl. the scanned variant.

### M4 — Fallbacks & upgrades
- Web fallback (BGG/Reddit) with external-source labeling and "⚠️ disagrees" card.
- Read-aloud of verdict.
- B+ figure candidates if diagram highlights score badly.

### Later
Multiple PDFs per game (expansions, FAQ), clarifying questions, curated library, table precedent / house rules memory, server proxy, sharing beyond owner's phone.

---

## 6. Open items
- Get the 4 rulebook PDFs into `assets/rulebooks/` (owner) — Root: *The Law of Root*.
- Create a scanned/photographed variant of a few Azul pages.
- Draft the first ~20 benchmark questions together.
- Cost ceiling per question: none set; revisit after M1 numbers.
