# M2 notes: iOS viewer

**Date:** 2026-11-21 · **Scope:** S3–S9 plus a minimal S2 (open a PDF, reopen it on relaunch). Built on `Core/`.
**Update (same day): native iOS restyle**, see [Restyle](#restyle-native-ios) below. **Then: answer polish** after the owner's Azul test, see [Answer polish](#answer-polish-owners-azul-test). The first-build notes further down still describe behaviour; their screenshots show the old look.

## Run it

```sh
cd App && xcodegen            # optional: regenerate from project.yml (XcodeGen 2.48); the .xcodeproj is checked in
open App/Ackshually.xcodeproj  # scheme "Ackshually", iOS 27+, iPhone first; runs on iPad and on Mac ("Designed for iPad")
```

- **API key.** Use ⋯ (the toolbar overflow menu) → Settings → paste the key; it's stored in the Keychain. On the simulator you can also pass it at launch: `SIMCTL_CHILD_ANTHROPIC_API_KEY=sk-ant-… xcrun simctl launch booted app.ackshually.viewer`. Without a key, the app streams a scripted **demo answer**; the ⋯ menu says "Demo answers: no API key set" and the expanded answer ends with a "Demo answer" footnote.
- **Rulebook.** ⋯ → Open a rulebook PDF… (file importer; the PDF is copied into Application Support and reopened on the next launch), or ⋯ → Sample rulebook (Core's fake "Power Plant Rush").
- **Device.** Pick your team under Signing & Capabilities, then run on the iPhone. Push-to-talk needs a real device; the simulator has no live mic input in automation.
- **Launch arguments** (simulator and screenshots): `-sample YES`, `-pdfPath /abs/file.pdf`, `-demo YES`, `-demoAnswer /abs/answer.json` (a spec §4 JSON), `-ask "…"`, `-present YES`, `-card N`, `-branch N`, `-detent collapsed|medium|expanded`. Details are in `App/Sources/App/LaunchOptions.swift`.
- **UI tests:** `xcodebuild test -project App/Ackshually.xcodeproj -scheme Ackshually -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2'`. 13 tests run on the sample (or PDFs/answers they generate) with demo answers; the original five: streaming → stepping (swipe and peek tap), inspect (pan the PDF under the sheet) → Back to Step → tap PDF → double-tap, branch row + its own steps + dragging the system sheet between all three detents + tapping a step row, a follow-up, and close → ⋯ Show Answer → rotate to landscape (column); the rest are listed under [Answer polish](#answer-polish-owners-azul-test). Add `TEST_RUNNER_SCREENSHOT_DIR=/some/dir` to save screenshots.


## Answer polish (owner's Azul test)

**Date:** 2026-11-21/22. The owner tried the app on Azul ("If every color available to pick (in factories or center) is one I can't legally place in any pattern line, what do I do on my turn?"). Five problems, all fixed:

| # | Problem (owner's screenshot) | Before | After |
|---|---|---|---|
| 1 | Landscape: bar and answer panel the same beige, one block | `bar` #f3ece1 ≈ `sheet` #f6efe4 | New `navigationBar` token (#e2d3bd / dark #0e0c0a), `chromeSeparator` hairlines under the bar and beside the column; PDF canvas keeps its own `canvas` token |
| 2 | No visible highlight; Azul's red frames looked like ours | 42% yellow PDF annotations | **Nothing was drawn at all** on Azul: its PDF forbids annotations, and PDFKit's character boxes were misplaced (see below). Now a **spotlight** drawn by a page overlay view: the page is dimmed except the cited lines / figure box, outlined in brick. A quote that doesn't match says *Passage not found · showing the whole page* |
| 3 | Verdict: 5 bold lines | "one or two short sentences" | Prompt: one sentence, ≤12 words (bench: median 10, max 12). UI: 3 lines max on the sheet, full text expanded / VoiceOver |
| 4 | Step card text overflowed the card | Text `fixedSize` in a `LazyHStack` card of unmeasured height | All cards share one height = tallest content, text ≤5 lines, **More** opens the expanded answer at that step (plain `HStack`, measured) |
| 5 | Last card repeated the verdict | Closing "Result" card with thumbs + follow-up | No Result card; prompt: last step applies the rule ("Your 3 energy"), never restates; follow-up + thumbs in their own row under the shelf |

Plus, at the owner's request, **⋯ → Answer Details**: every cited passage with page, quote and match status (matched / matched on p.N / matched, not located / not matched (why) / figure box), and **Copy JSON** (raw answer, the model's raw text when it came from Claude, and the match results). Debug builds log the answer JSON and each match with `os.Logger` (subsystem `app.ackshually.viewer`, category `answer`).

### Why the Azul highlights were missing

Reproduced with the real Azul PDF and the owner's question through Core (`bench run` with a one-game question set; raw answers in [evals/results/2026-11-22-azul-highlight-probe](../evals/results/2026-11-22-azul-highlight-probe/report.md)):

1. **The quotes matched**: every Azul quote matched the page text exactly (error 0). The model was right.
2. **The app drew nothing**: Azul's PDF is encrypted with permissions that forbid annotations (`allowsCommenting == false`), so `PDFPage.addAnnotation` silently did nothing. Highlights are now a `PDFPageOverlayViewProvider` view.
3. **The rects were wrong anyway**: PDFKit's `characterBounds(at:)` and `selection(for: NSRange)` bounds are indexed **without the line breaks** in `PDFPage.string` (plus a few characters of drift on some PDFs). On Azul p.3 the box for "On your turn, you must pick tiles…" started 14 characters late and wrapped over 3 lines. This affects all four rulebooks and the generated fixture (macOS and iOS). Core's new `GlyphLocator` picks the index mapping whose box widths correlate with the characters' widths (r ≈ 0.85–0.97 when right, ≈ 0 when wrong), per line of the quote, and returns no rects (→ whole page + note) when nothing fits. Unit tests: `GlyphLocatorTests`, `MatcherTests.testRectsSitOnTheQuote`.
4. The Root miss is different: captions over map art are interleaved with the sidebar in the text layer and lose the decorative "Th" (spec §4 layout-tolerant matching; not done here, the app says so on the PDF).

Owner's question + 3 follow-ups on Azul, 1 question on Root:

**old prompt (2026-11-21, owner question reproduced)**

| Q | Step | Page | Quote | Text match | Geometry (this PR) |
|---|---|---|---|---|---|
| az-owner | 1 | 3 | “On your turn, you must pick tiles in one of the following ways:” | matched | located, r=0.95, 1 rect(s) |
| az-owner | 2 | 4 | “Any tiles you have picked that you cannot or do not want to place a…” | matched | located, r=0.93, 2 rect(s) |
| az-owner | 2 | 4 | “If all spaces of your floor line are occupied, return any further f…” | matched | located, r=0.90, 2 rect(s) |
| az-owner | 3 | 3 | “If you are the first player in this round to pick tiles from the ce…” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f1 | 1 | 3 | “If you are the first player in this round to pick tiles from the ce…” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f1 | 2 | 5 | “If you have the starting player marker in your floor line, it count…” | matched | located, r=0.93, 2 rect(s) |
| az-owner-f1 | 3 | 5 | “The player with the starting player marker refills each of the Fact…” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f1 | 3 | 4 | “filling its spaces from left to right.” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f2 | 1 | 4 | “If all spaces of your floor line are occupied, return any further f…” | matched | located, r=0.91, 2 rect(s) |
| az-owner-f2 | 1 | 3 | “On your turn, you must pick tiles in one of the following ways:” | matched | located, r=0.95, 1 rect(s) |
| az-owner-f2 | 2 | 3 | “also take the starting player marker and place it onto the leftmost…” | matched | located, r=0.93, 2 rect(s) |
| az-owner-f3 | 1 | 5 | “For each tile in your floor line, you lose the number of points ind…” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f3 | 1 | 5 | (figure box) | box ok | box outline |
| az-owner-f3 | 2 | 5 | “however, you can never drop below 0 points” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f3 | 2 | 4 | “If all spaces of your floor line are occupied, return any further f…” | matched | located, r=0.90, 2 rect(s) |
| rt-probe | 1 | 5 | “To move, you must rule the clearing you are moving from or moving to.” | matched | located, r=0.90, 2 rect(s) |
| rt-probe | 2 | 5 | “They do rule this clearing, so they can move here.” | not matched (best error 44%) | — (no text match) |
| rt-probe | 3 | 17 | “but he is Nimble, so he can move regardless of who rules his cleari…” | matched | located, r=0.88, 1 rect(s) |

**new prompt (this PR)**

| Q | Step | Page | Quote | Text match | Geometry (this PR) |
|---|---|---|---|---|---|
| az-owner | 1 | 3 | “On your turn, you must pick tiles in one of the following ways:” | matched | located, r=0.95, 1 rect(s) |
| az-owner | 2 | 4 | “Any tiles you have picked that you cannot or do not want to place a…” | matched | located, r=0.92, 2 rect(s) |
| az-owner | 3 | 4 | “She may even choose to place both tiles in the floor line (C).” | matched | located, r=0.87, 1 rect(s) |
| az-owner-f1 | 1 | 3 | “If you are the first player in this round to pick tiles from the ce…” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f1 | 2 | 5 | “If you have the starting player marker in your floor line, it count…” | matched | located, r=0.93, 2 rect(s) |
| az-owner-f1 | 3 | 5 | “But instead of placing it in the lid, place it in front of you.” | matched | located, r=0.94, 2 rect(s) |
| az-owner-f2 | 1 | 4 | “If all spaces of your floor line are occupied, return any further f…” | matched | located, r=0.91, 2 rect(s) |
| az-owner-f2 | 2 | 3 | “If you are the first player in this round to pick tiles from the ce…” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f2 | 3 | 5 | “But instead of placing it in the lid, place it in front of you.” | matched | located, r=0.94, 2 rect(s) |
| az-owner-f3 | 1 | 5 | “For each tile in your floor line, you lose the number of points ind…” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f3 | 1 | 5 | (figure box) | box ok | box outline |
| az-owner-f3 | 2 | 5 | “however, you can never drop below 0 points” | matched | located, r=0.92, 2 rect(s) |
| az-owner-f3 | 3 | 5 | “Peter loses a total of 8 points as he has 4 tiles and the starting …” | matched | located, r=0.85, 2 rect(s) |
| rt-probe | 1 | 5 | “To move, you must rule the clearing you are moving from or moving to.” | matched | located, r=0.90, 2 rect(s) |
| rt-probe | 2 | 5 | “You rule a clearing if you have the most combined warriors and buil…” | matched | located, r=0.89, 2 rect(s) |
| rt-probe | 3 | 5 | “They don’t rule this clearing either, so they cannot move here.” | not matched (best error 24%) | — (no text match) |


### Screenshots (sample rulebook, demo answers; `m2-screenshots/polish/`)

Spotlight · miss note · equal-height cards · AX L · More → expanded · follow-up row · Answer Details · expanded
<p>
<img src="m2-screenshots/polish/01-spotlight-step1.png" width="140"> <img src="m2-screenshots/polish/02-spotlight-miss-note.png" width="140"> <img src="m2-screenshots/polish/03-cards-equal-height-default.png" width="140"> <img src="m2-screenshots/polish/04-cards-equal-height-axl.png" width="140"> <img src="m2-screenshots/polish/05-card-more-expanded.png" width="140"> <img src="m2-screenshots/polish/06-s6-last-card.png" width="140"> <img src="m2-screenshots/polish/07-answer-details.png" width="140"> <img src="m2-screenshots/polish/09-s9-expanded.png" width="140">
</p>

Landscape: darker bar, hairlines, spotlight
<p><img src="m2-screenshots/polish/08-landscape-bar-darker.png" width="420"></p>

The real-Azul checks (owner's question with the API key, the spotlight on p.3 / p.4) were done by hand and are not committed (copyrighted pages).

### New components

| Component | Preview states |
|---|---|
| `Viewer/SpotlightOverlayView` + `Spotlight` (UIKit overlay inside PDFKit) | via `PDFViewer` previews |
| `AnswerSheet/TruncatingText` (line cap + measured More) | short, long, AX5 |
| `AnswerSheet/AnswerFooterRow` (follow-up + thumbs) | unrated, rated, AX5 dark |
| `AnswerDetails/AnswerDetailsView`, `EvidenceStatusRow` | statuses, dark AX3, AX5 |
| Model: `MatchInfo`, `EvidenceReport`, `AnswerDetailsExport`, `ViewerModel+Details` (reports, JSON, logging) | `Fixtures.evidenceReports` |

### Tests

Core: `GlyphLocatorTests` (3), `MatcherTests.testRectsSitOnTheQuote`, `testPromptLimitsVerdictAndForbidsRepeatingIt`, 38 total. UI (13, iPhone 18 Pro, iOS 27.2): the 8 existing (updated for a shelf without the Result card) plus `testCardTextStaysInsideCard` (default + AX L, equal heights, More → expanded), `testLongVerdictIsCappedUntilExpanded`, `testSpotlightAndExplicitMiss`, `testAnswerDetailsListsMatchStatus`, `testNavigationBarIsDarkerThanAnswerColumn` (pixel luminance in landscape). The PDF view's accessibility value now reads "Zoomed, spotlight N" so tests can see the overlay.

### swiftui-pro review

Fixed: one type per file (`Spotlight`, `AnswerDetailsExport` split out), section grouping moved from `AnswerDetailsView` to `EvidenceReport.sections`. Kept: the PDF overlay is UIKit (PDFKit's overlay provider needs a `UIView`); `StepCard`'s small `body(_:)` text helper.

## Restyle (native iOS)

The owner's verdict on the first build: "it looks like a typical Claude/web chat app, not an iOS app, with lots of pills, text etc." The restyle follows spec §3 ("native iOS, warm") and [design/native-ios.html](design/native-ios.html). Behaviour and the S2–S9 interactions are unchanged.

| | Before (first build) | After |
|---|---|---|
| Answer sheet | Custom overlay (`BottomSheet`): own drag gesture, grabber, shadow, 1 px top border | System `.sheet`: detents measured from the content (collapsed = verdict + proof line, medium = + cards and branch rows, large), `presentationBackgroundInteraction(.enabled(upThrough: medium))` so the PDF stays pinchable/pannable, no swipe-to-dismiss (Close button) |
| Header | "You asked" + restated question, verdict, `FlowRow` of chips: `✓ Stated · p.3, p.4`, branch pills, "Demo answer" flag | Bold verdict (title3) + **one** proof line: `checkmark.seal.fill Stated in the rules · p.3, p.4`. Restated question only while waiting and when expanded. Close / Stop as glass circle buttons |
| While waiting / arriving | Outlined "■ Stop" button, custom pulsing skeleton bars | Glass ask field turns into "Reading the rulebook…" + `stop.circle.fill`; native `.redacted(.placeholder)` for the verdict and the loading card |
| Step cards | Card with 1 px shadow, dimmed when not current, caption "1 · Rule" | Borderless shelf cards (App Store / Music), caption = **step title** + page ("Battery exception · p.4"), page dots like `UIPageControl` |
| Branches | Outlined pills in the header, "‹ Main answer" pill; one branch card with "The rulebook steps are on the main answer" | Inset-grouped rows under the cards ("Without a Battery … Discard all 3. ›"); tapping one swaps the header to the branch verdict and the cards to the **branch's own steps**; a "Main Answer" row returns |
| Expanded | Custom bordered step rows, uppercase labels, plain text | Grouped sections like Settings: Steps (number, title, text, page; current in tint), If…, Assumes, Was this right? (thumbs), Follow-up |
| Feedback | 👍/👎 emoji in outlined boxes | `hand.thumbsup` / `hand.thumbsdown` (filled when chosen), 44 pt targets |
| Ask field | Card-colored rounded field, filled brick mic circle | Liquid Glass bottom field (`magnifyingglass` + text field + `mic`), placed like the iOS 26 bottom search field; inline filled field on the sheet for follow-ups |
| PDF chrome | "⤺ Back to step 2" ink capsule, "1 of 2 ›" ink capsule, outlined note | Glass button "Back to Step 2" (`arrow.uturn.backward`), glass pager "1 of 2 ›", glass note |
| Nav bar | Opaque beige bar, `ellipsis.circle` custom `Menu` | Warm-tinted bar, system `ToolbarOverflowMenu` (⋯); on wide screens a `sidebar.trailing` toggle |
| Wide screens | Custom side panel with a hairline and an xmark | iPad/Mac: standard `.inspector` column. Phone landscape: same content as a trailing column (see below) |
| Empty state | Large title + custom buttons | `ContentUnavailableView` with a glass prominent button |
| Palette | Beige everywhere (`#efe4d0` chrome, `#f4e9d5` sheet, brown ink), provisional dark | Restrained: brick tint, warm bars / sheet / grouped backgrounds, system label colors, white cards; every token has a dark variant |

### Screenshots (sample rulebook, demo answers; `m2-screenshots/restyle/`)

Idle · waiting · arriving · streaming · verdict + step 1 · step 2 · two passages · last card + follow-up
<p>
<img src="m2-screenshots/restyle/01-idle.png" width="140"> <img src="m2-screenshots/restyle/02-waiting.png" width="140"> <img src="m2-screenshots/restyle/03-arriving.png" width="140"> <img src="m2-screenshots/restyle/04-streaming.png" width="140"> <img src="m2-screenshots/restyle/05-verdict-step1.png" width="140"> <img src="m2-screenshots/restyle/06-step2.png" width="140"> <img src="m2-screenshots/restyle/07-step3-two-passages.png" width="140"> <img src="m2-screenshots/restyle/08-last-card-follow-up.png" width="140">
</p>

Collapsed · expanded · branch · Back to Step · double-tap → page
<p>
<img src="m2-screenshots/restyle/09-collapsed.png" width="140"> <img src="m2-screenshots/restyle/10-expanded.png" width="140"> <img src="m2-screenshots/restyle/11-branch.png" width="140"> <img src="m2-screenshots/restyle/19-inspect-back-to-step.png" width="140"> <img src="m2-screenshots/restyle/20-double-tap-full-page.png" width="140">
</p>

iPad inspector · phone landscape column
<p>
<img src="m2-screenshots/restyle/12-ipad-inspector.png" width="260"> <img src="m2-screenshots/restyle/18-landscape-column.png" width="320">
</p>

Dark (medium, expanded, idle) · AX5 Dynamic Type (medium, expanded)
<p>
<img src="m2-screenshots/restyle/13-dark-medium.png" width="140"> <img src="m2-screenshots/restyle/14-dark-expanded.png" width="140"> <img src="m2-screenshots/restyle/15-dark-idle.png" width="140"> <img src="m2-screenshots/restyle/16-ax5-medium.png" width="140"> <img src="m2-screenshots/restyle/17-ax5-expanded.png" width="140">
</p>

### What isn't a stock component, and why

1. **The ask field is not `.searchable`.** A search field can't host hold-to-talk (press-and-hold for a live transcript, slide to cancel). It's a `TextField` + mic in a `.glassEffect` capsule placed where the iOS 26+ bottom search field sits.
2. **Phone landscape uses a trailing column, not `.inspector`.** iPhone landscape is compact width, where `.inspector` turns into a sheet (and fought the outgoing answer sheet on rotation, closing the answer). iPad and Mac use the real inspector. Both show the same `AnswerInspector` content.
3. **Grouped rows are `GroupedSection` in a `ScrollView`, not a `List`.** The sheet sizes its collapsed and medium detents from where the header and the branch rows end, which needs one coordinate space; and the shelf's peeking cards must span the sheet's full width, which inset-grouped `List` rows can't. `GroupedSection` mimics inset-grouped styling (rounded group, inset hairline separators, uppercase footnote headers).
4. **Detent heights are measured.** `.height(_)` detents come from the content (capped at 30% / 70% of the window), so the medium detent covers no more of the page than the cards need.
5. **Sheet presentation bindings are read-only.** Nothing can dismiss the sheet or inspector except Close, so the bindings ignore SwiftUI's writes (which only happen when a rotation moves the answer from sheet to column).
6. **The PDF is still PDFKit in a `UIViewRepresentable`** (no SwiftUI PDF view), and the theme's dynamic colors use `UIColor` providers so the same token also works inside PDFKit.

### Contract changes (proposals 1 and 2 below, done)

`Step.title` and `Branch.steps` were added to Core's model, schema, prompt and streaming assembler (both required in the schema, optional when decoding; excerpt-mode page remapping keeps titles and remaps branch evidence). Old answers decode: no title → "Step N", no branch steps → one branch card. **To check in the next bench run:** branch steps stream before the main steps, a few dozen tokens per branch before step 1.

### swiftui-pro review (fixed before the PR)

- Toolbar: the custom ellipsis `Menu` → `ToolbarOverflowMenu` (needs iOS 27, hence the target); the conditional inspector toggle → `.hidden()`.
- One type per file: split `ValueRow`, `StepListRows`, `AssumptionRows`, `CardCaption`, `TrailingIconLabelStyle`, `ViewerMenu`, `ViewerChrome`, `AskFieldBackground`, `SettingsSheet`, `ViewerPresentation`, `AnswerMetrics`, `AnswerPlacement`, `ViewerPreview`, `SlideToCancelHint`, `Confidence+Display`.
- `AnswerContent`'s `some View` helper properties → `AnswerShelf`, `FullAnswerSections`, `FollowUpSection`, `DemoNote`; button actions moved out of `body`.
- 44 pt minimum tap areas for the mic, send, stop, thumbs; close/stop glass buttons at `.large` control size.
- Redundant `.continuous` corner styles removed.
- Kept on purpose: `Binding(get:set:)` for the detent selection (maps the model's detent to measured detents) and the read-only presentation bindings; the peek tap on cards is an `onTapGesture` with an accessibility action (a `Button` would nest the result card's thumbs buttons); the floating field is an overlay rather than `safeAreaBar()` because the PDF must extend under the glass and gets the covered height explicitly.

## What was verified (first build)

| | How | Result |
|---|---|---|
| Build: app (iOS sim, iPad sim), Core (`swift build`) | xcodebuild / swift | ✅ |
| S3 waiting, S4 restated question → verdict → step 1, Stop | UI test + timed simctl screenshots | ✅ |
| S5/S6 carousel: swipe, tap on the peek, PDF follows (page, zoom, highlight), "1 of 2 ›" pager, last card 👍/👎 + follow-up field | UI test | ✅ |
| S7 collapse / S9 expand by dragging, branch pill → branch card → "‹ Main answer" | UI test | ✅ (tapping a step row in S9 is built but not automated) |
| S8 pan → "⤺ Back to step 2" → re-center; tapping the PDF doesn't change the step; double-tap → whole page | UI test | ✅ |
| Follow-up sends the previous turns (Core `history`) | UI test (demo provider) | ✅ the flow works; the context replay is Core code that the evals already exercise |
| Real rulebook: Power Grid PDF + a scripted answer with real quotes | simctl | ✅ quotes matched and highlighted on a two-column page; the page fills the width |
| Real API call | — | ⚠️ **not run**: no `ANTHROPIC_API_KEY` was available in this environment. The app calls `ClaudeProvider` exactly as `bench` does (Sonnet 5.5, json, effort low) |
| Push-to-talk / dictation | — | ⚠️ builds, but not exercised (needs a device mic). Hold ≥0.28 s = live transcript, release sends, slide left past ~18% of the bar's width cancels, tap = dictation |
| iPad side panel, dark (provisional), AX5 Dynamic Type | simctl | ✅ see the screenshots |

## Screenshots of the first build (old look)

S3 waiting · S4 arriving · S5 verdict + step 1 · S6 step 2 · S6 step with two passages · S6 last card
<p>
<img src="m2-screenshots/s3-waiting.png" width="150"> <img src="m2-screenshots/s4-arriving.png" width="150"> <img src="m2-screenshots/s5-verdict-step1.png" width="150"> <img src="m2-screenshots/s6-step2.png" width="150"> <img src="m2-screenshots/s6-step3-two-passages.png" width="150"> <img src="m2-screenshots/s6-last-card-follow-up.png" width="150">
</p>

S7 collapsed · S8 Back to step · S8 double-tap → page · S9 expanded · S9 branch
<p>
<img src="m2-screenshots/s7-collapsed.png" width="150"> <img src="m2-screenshots/s8-back-to-step.png" width="150"> <img src="m2-screenshots/s8-double-tap-full-page.png" width="150"> <img src="m2-screenshots/s9-expanded.png" width="150"> <img src="m2-screenshots/s9-branch.png" width="150">
</p>

Wide (iPad side panel) · dark (provisional) · AX5 Dynamic Type
<p>
<img src="m2-screenshots/wide-ipad-side-panel.png" width="230"> <img src="m2-screenshots/dark-provisional.png" width="150"> <img src="m2-screenshots/ax5-dynamic-type.png" width="150">
</p>

The real-rulebook check (Power Grid) is not in these screenshots because the PDFs are copyrighted.

## Calls I made (where the spec was silent or impractical)

1. **Before the first token** (~4–5 s on a real rulebook), the ask bar turns into "Reading the rulebook… ■ Stop". The sheet still rises on the first token, as S4 says, so the table sees progress straight away.
2. ~~**Custom sheet, not `.sheet`.**~~ *Superseded by the restyle: the system sheet now does this.* It keeps the PDF interactive and tells the viewer exactly how much page is covered, so evidence centers in the visible part. Detents: collapsed is content-sized; medium is content-sized up to 62% of the height (it scrolls beyond that, e.g. at AX sizes); expanded is 94%. A flick down from collapsed dismisses the answer and brings back the ask bar. *Decision-log row added.*
3. **Wide screens get a side panel.** On iPad, on Mac, and in phone landscape at ≥640 pt wide, the answer sits in a column beside the PDF (38% of the width, 320–460 pt) with the header, cards, follow-up and step list. `AdaptiveViewerLayout` is the one place that decides this. *Decision-log row added.*
4. **Highlight fallback** (spec §4, M2 subset): quote → word rects from `QuoteMatcher`; otherwise a sane box gets an outline; otherwise the whole page, with a note ("Showing the whole page" / "See the diagram, lower half"). No layout-tolerant matching or repair call, as instructed.
5. **Evidence zoom** fits the passage (with context) in the visible area. It never zooms below page width or above 3.2× page width. On a big, dense page (Power Grid) the passage's lines are as wide as the page, so "zoom to evidence" stays at page width and the print is small. Pinch is the workaround for now (see proposal 4).
6. **Feedback** is in memory only (S11 storage is M3). **Sessions** last until the app quits or another PDF opens (S12 is M3).
7. **The answer header caps Dynamic Type at AX2** so the verdict and cards stay on screen. Everything else scales fully, and spacing and control sizes scale with text through the theme.

## Proposed spec changes

1. ✅ *Done in the restyle.* **Give each step a `title`** in the answer contract (§4 already shows one in its example, but `Core`'s schema and `Step` don't have it). The mockups' "1 · General rule / 2 · Exception" needs it; the app labels cards "1 · Rule", "2 · Step" for now. This is a small schema + `Step` change in Core, best done after the page-selection experiment lands, so that agent's work isn't disturbed.
2. ✅ *Done in the restyle.* **Branches need their own steps** (or at least one evidence item each). S9 says "the step cards switch to that branch", but a branch is only `{condition, verdict}`, so today the branch view is one card plus Result. Proposal: `branches[].steps` (optional, usually 1 step).
3. **Spell out S4 timing:** "between send and the first token the ask bar shows *Reading the rulebook… / Stop*; the sheet rises on the first token" (what's built).
4. **Minimum-legibility zoom:** on large pages, zoom until body text reaches ~15 pt on screen even if the passage's lines overflow horizontally, centered on the passage start. Needs a quick check on the owner's phone first.
5. Add **wide-screen layout** (side panel) to §2 next to S5/S9 (decision rows added in §7).

## Component map (App/Sources)

Leaf views take plain values (`HeaderContent`, `StepCardContent`, `CardItem`, `StepRow`, `BranchRow`, Core models) and closures. State lives in injected `@Observable` models: `ViewerModel` (document, streaming, current card, detent, branch, PDF focus, feedback), `AskController` (push-to-talk over `SpeechInput`) and `ViewerPresentation` (importer / settings, attached to whichever view is frontmost). Design tokens live in `Theme` (dynamic light/dark colors, Dynamic Type-scaled spacing and sizes), injected as `@Environment(\.theme)` by `.themed()`, which also sets the app tint. Previews use `Preview Content/Fixtures.swift`, built on Core's `FixtureRulebook`, so no API key is needed.

| Component | Screen | Preview states |
|---|---|---|
| **DesignSystem/** `Theme`, `ThemeEnvironment` (`.themed()`, `.themeBackground`) | all | — |
| `GroupedSection`, `ValueRow` (inset-grouped rows), `TrailingIconLabelStyle`, `String+LowercasedFirst` | S5, S9 | rows, checkmark, footer, AX5 dark |
| **Features/Ask/** `AskField` (+ `AskFieldBackground`: glass / inline) | S3, follow-up | floating empty/typed, inline, AX5, dark |
| `PushToTalkButton` | S3 | idle, dictating, holding |
| `HoldToTalkPanel`, `SlideToCancelHint`, `Waveform` | S3 | listening, transcript, cancel armed; levels |
| `WaitingBar` (glass) | S3→S4 | default, AX5 dark |
| **Features/AnswerSheet/** `AnswerHeader` (+ `FailureHeader`) | S4, S5, S9 | arriving (redacted), streaming, stated, with question, inferred, not covered, branch, failed, AX5, dark |
| `ProofLine` (+ `Confidence+Display`) | S5, S7 | stated, inferred, not covered, AX5 dark |
| `StepCard`, `CardCaption` | S5, S6, S10 | step, figure, loading, long (More), branch without steps, web, AX5, dark |
| `StepCarousel`, `CardDots` | S5, S6 | iPhone, SE width, AX5, dark |
| `FeedbackButtons` | S6, S9 | none, up, down |
| `BranchRows`, `StepListRows`, `AssumptionRows` | S5, S9 | none active, active, AX5, dark |
| `AnswerShelf`, `FullAnswerSections`, `FollowUpSection`, `DemoNote` (model-bound pieces) | S5–S9 | step 1, AX5 dark |
| `AnswerContent` (+ `AnswerPlacement`, `AnswerMetrics`): the whole answer column | S4–S9, wide | medium, streaming, expanded, branch, inspector AX5, expanded dark |
| `AnswerSheet` (system sheet, measured detents, background interaction) | S5, S7, S9 | via `ViewerPreview` |
| `AnswerInspector` (inspector column / landscape column) | wide | iPad landscape |
| **Features/Viewer/** `PDFViewer` (PDFKit, highlights, zoom, gestures) | S5, S6, S8 | evidence zoom, whole page |
| `HighlightOverlay` (glass pager, notes), `BackToStepPill` (glass) | S6, S8 | 2 passages, figure note, whole page, AX3/AX5, dark |
| `AdaptiveViewerLayout` (sheet vs inspector vs landscape column; covered height for the PDF) | S3–S9 | iPhone 18 Pro, SE, Pro Max, landscape, iPad, AX5, dark, streaming, branch, collapsed, expanded, idle |
| `ViewerScreen`, `ViewerMenu` (`ToolbarOverflowMenu`), `ViewerChrome`, `ViewerDialogs`, `EmptyLibraryView` (`ContentUnavailableView`), `ViewerPreview` | S2 | answered, empty, empty dark, error AX5 |
| **Features/Settings/** `SettingsView`, `SettingsSheet` | dev | default, dark AX5 |
| **Model/** `ViewerModel` (+`Content`), `AnswerState`, `ViewContent`, `ViewerPresentation`, `HighlightPlacer`, `AskController` | — | — |
| **Services/** `DemoProvider` (now with step titles and a branch step), `Keychain`/`APIKeyStore`, `Library`, `SpeechInput` | — | — |

## Known gaps / next

- Run a real question on the owner's iPhone with a key (time to first token, verdict and step 1, against the M1 numbers).
- Push-to-talk on a device: check the hold threshold and the slide-to-cancel distance at the table.
- Restyle: check the sheet's detent heights and the glass field on the owner's iPhone (simulator only so far), and the step-1 latency with the v2 contract on a real rulebook.
- `scrollPosition(id:)` ignores its initial value, so the carousel scrolls to it on appear (`ScrollViewReader`). It works, but watch for it on iOS 18 changes.
- Evidence on a page that `QuoteMatcher` scrambles (Root multi-column) falls back to the whole page until the layout-tolerant matcher lands in Core.
