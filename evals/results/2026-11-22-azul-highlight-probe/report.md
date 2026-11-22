# Azul highlight probe (2026-11-21/22)

Owner's question on Azul ("If every color available to pick (in factories or center) is one I can't legally place in any pattern line, what do I do on my turn?"), three follow-ups in the same session, and one Root question. Sonnet 5.5, json, effort low, no judge. Same Core path as the app. Raw answers: `old-prompt-results.jsonl` (prompt before this PR, reproduces the owner's run) and `new-prompt-results.jsonl` (this PR's prompt). Text match = `QuoteMatcher`; geometry = `GlyphLocator` (`bench match`), r = width correlation of the chosen index mapping.


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

## Why the owner saw no highlight

1. **Every Azul quote matched the text exactly** (error 0). The model quoted correctly.
2. **Nothing was drawn**: Azul's PDF is encrypted with permissions that forbid annotation changes (`allowsCommenting == false`); `PDFPage.addAnnotation` silently did nothing. Fixed: highlights are a page overlay view (`PDFPageOverlayViewProvider`), not annotations.
3. **The rects were in the wrong place anyway**: PDFKit's `characterBounds(at:)` (and `selection(for: NSRange)` bounds) are indexed without the line breaks in `PDFPage.string`, plus a few characters of drift on some PDFs. On Azul p.3 the box for "On your turn, you must pick tiles…" started 14 characters late and wrapped over three lines. Seen on all four rulebooks and the generated fixture, macOS and iOS. Fixed in Core (`GlyphLocator`).
4. The 42% yellow would have been hard to see on Azul's cream pages anyway: now a spotlight (dimmed page + brick outline).

## Root miss

"They do rule this clearing, so they can move here." / "They don’t rule this clearing either, so they cannot move here." (p.5) are captions laid over the map art. The text layer interleaves them with the sidebar ("ey do rule this / slots on the map. / clearing, so they / … / can move here.") and drops the decorative "Th". This is the spec §4 layout-tolerant case (word-position clustering / OCR), not fixed here; the app now says *Passage not found · showing the whole page*.
