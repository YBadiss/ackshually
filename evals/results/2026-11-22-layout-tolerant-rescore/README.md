# Layout-tolerant matching: offline re-score

**Date:** 2026-11-22 · **What:** every recorded bench run re-matched with the new matcher (`bench rescore`), no API calls (no `ANTHROPIC_API_KEY` in this environment, so no new answers). Same answers, same PDFs; **before** = today's matcher with layout tolerance off (`--continuous-only`: continuous matching, single-mapping geometry), **after** = fragments + partial + piecewise geometry. The files here are the re-scored [answer-polish-sonnet](../2026-11-22-answer-polish-sonnet/report.md) run (the default config); `rescore.md` lists its quotes whose match changed against the recorded results.

Quote counts are per run (the same quote cited in several runs counts each time). "Spotlit" = the app draws a spotlight (matched or partial, with located rects); everything else shows the whole page with a note.

| Run | Quotes | Matched on claimed page (before → after) | of which fragments | Partial | Spotlit: matched + located (before → after) | Whole page (before → after) |
|---|---|---|---|---|---|---|
| 2026-11-21-m1-haiku-json | 80 | 78 → **78** | 0 | 0 | 62 (78%) → **71** (89%) | 18 → 9 |
| 2026-11-21-m1-opus-citations | 159 | 151 → **152** | 1 | 6 | 118 (74%) → **141** (89%) | 41 → 18 |
| 2026-11-21-m1-opus-json | 96 | 94 → **96** | 2 | 0 | 72 (75%) → **86** (90%) | 24 → 10 |
| 2026-11-21-m1-opus-json-oldjudge | 95 | 93 → **94** | 1 | 0 | 72 (76%) → **84** (88%) | 23 → 11 |
| 2026-11-21-m1-sonnet-json | 78 | 78 → **78** | 0 | 0 | 58 (74%) → **69** (88%) | 20 → 9 |
| 2026-11-21-restyle-sonnet-1h | 86 | 83 → **84** | 1 | 1 | 65 (76%) → **76** (88%) | 21 → 10 |
| 2026-11-21-speed-full-control | 78 | 78 → **78** | 0 | 0 | 63 (81%) → **72** (92%) | 15 → 6 |
| 2026-11-21-speed-k3 | 78 | 77 → **78** | 1 | 0 | 61 (78%) → **71** (91%) | 17 → 7 |
| 2026-11-21-speed-k4-headings | 82 | 74 → **74** | 0 | 0 | 60 (73%) → **73** (89%) | 22 → 9 |
| 2026-11-21-speed-k6 | 79 | 77 → **79** | 2 | 0 | 59 (75%) → **74** (94%) | 20 → 5 |
| 2026-11-22-answer-polish-sonnet | 86 | 84 → **85** | 1 | 1 | 71 (83%) → **78** (91%) | 15 → 8 |
| **All runs** | 997 | 967 → **976** | 9 | 8 | 761 (76%) → **895** (90%) | 236 → 102 |

Most of the spotlight gain is geometry: quotes that already matched as text but couldn't be located (whole page + "couldn't mark it") now get rects from the piecewise locator. Text matches: +9 through fragments, +8 partial.

## Hand-check of every newly placed quote

Each distinct quote whose outcome or geometry changed was rendered with its rects (`bench match-set --render`, crops kept in git-ignored `evals/out/handcheck/`, not committed) and checked by eye. **48 placements, 48 on the right words, 0 wrong.** "Part of the quote" = the boxes cover only some of the quoted words (the rest of the line couldn't be located), never other text.

Two wrong placements found during the check were fixed before these numbers: Root p.9 (an ambush card's text layer, ~2 pt tall under artwork, got slivers → piecewise lines under 4 pt are rejected; it's back to "not located") and Root p.10 (a fragment ending on the "b" of "by" matched the "B" of "» Battle" and boxed it → fragments are trimmed to whole words).

| # | Page | Outcome | Quote | Location | Boxed | Note |
|---|---|---|---|---|---|---|
| 1 | root p.15 | matched (2 fragments, 100% of the quote) | “Spend two supporters matching a sympathetic clearing. Re…” | ✓ correct | whole quote |  |
| 2 | root p.15 | matched (2 fragments, 100% of the quote) | “you’ll have to remove half your officers and discard all…” | ✓ correct | part of the quote | misses “half your officers and discard” (glyphs out of order after the ﬃ ligature) |
| 3 | powergrid p.5 | matched | “If the player does not want to offer a power plant for a…” | ✓ correct | part of the quote |  |
| 4 | powergrid p.4 | matched | “During the first round of the game each player must buy …” | ✓ correct | part of the quote |  |
| 5 | powergrid p.5 | matched on p.4 (claimed p.5) | “The player pays their highest bid to the bank and takes …” | ✓ correct | whole quote |  |
| 6 | powergrid p.6 | matched | “Earning cash: Starting with the first player, every play…” | ✓ correct | part of the quote |  |
| 7 | root p.12 | matched | “The Eyrie are the Lords of the Forest. They rule a clear…” | ✓ correct | part of the quote |  |
| 8 | root p.12 | matched | “They rule a clearing even when tied for presence.” | ✓ correct | part of the quote |  |
| 9 | root p.6 | matched | “Birds Are Wild: The birds live in the treetops across th…” | ✓ correct | part of the quote |  |
| 10 | dune p.16 | matched on p.17 (claimed p.16) | “you may deploy up to two more troops from your garrison.” | ✓ correct | whole quote |  |
| 11 | dune p.6 | matched | “At the end of a round, if any player has reached 10 or m…” | ✓ correct | whole quote |  |
| 12 | powergrid p.5 | matched | “Pass the auction  If the player does not want to offer a…” | ✓ correct | part of the quote |  |
| 13 | powergrid p.7 | matched | “In Step 2, every city can be part of the networks of two…” | ✓ correct | part of the quote |  |
| 14 | powergrid p.10 | matched | “The Trust cannot win – it only   offers many possibiliti…” | ✓ correct | part of the quote |  |
| 15 | root p.6 | matched | “Mouse Bird  Birds Are Wild: The birds live in the treeto…” | ✓ correct | part of the quote | native citation incl. a “Mouse Bird” label |
| 16 | root p.5 | partial match (58% of the quote) | “Move Example  ey don’t rule this   clearing either, so …” | ✓ correct | part of the quote | partial 58%: italic caption over art, first line not found |
| 17 | root p.10 | matched (2 fragments, 100% of the quote) | “Hawks for Hire: After taking three actions,   you may ta…” | ✓ correct | part of the quote | 98%: “by” dropped at a fragment edge |
| 19 | azul p.6 | partial match (87% of the quote) | “CREDITS  End of the game  The game ends right after the …” | ✓ correct | whole quote | partial 87%: the citation included the heading “CREDITS End of the game” |
| 20 | dune p.12 | matched | “The player with the highest strength wins the Conflict  …” | ✓ correct | part of the quote |  |
| 21 | dune p.6 | matched | “At the end of a   round, if any player has reached 10 or…” | ✓ correct | whole quote |  |
| 22 | dune p.13 | partial match (72% of the quote) | “Phase 4: Makers  Phase 5: Recall  Endgame  First, you ma…” | ✓ correct | whole quote | partial 72%: the citation included phase headings |
| 23 | dune p.9 | matched | “Player Turn – Agent Turn  In an Agent turn, you play one…” | ✓ correct | part of the quote |  |
| 24 | powergrid p.7 | matched | “In Step 2, every city can be part of the networks of two…” | ✓ correct | part of the quote |  |
| 25 | root p.10 | matched (2 fragments, 100% of the quote) | “you may take any number of extra actions by spending one…” | ✓ correct | whole quote |  |
| 26 | root p.11 | matched (2 fragments, 100% of the quote) | “She moves two warriors from a mouse clearing, which she …” | ✓ correct | whole quote |  |
| 27 | dune p.12 | matched | “The player with the highest strength wins the Conflict a…” | ✓ correct | part of the quote |  |
| 28 | dune p.11 | matched | “Each troop you have in the Conflict is worth 2 strength.…” | ✓ correct | part of the quote |  |
| 29 | dune p.11 | matched | “You must have at least one troop in the Conflict to have…” | ✓ correct | part of the quote |  |
| 31 | root p.10 | matched (2 fragments, 100% of the quote) | “you may take any number of extra actions by spending one…” | ✓ correct | whole quote |  |
| 32 | dune p.17 | matched | “you may deploy to the Conflict any number of troops you …” | ✓ correct | part of the quote |  |
| 33 | powergrid p.7 | matched | “In Step 2, every city can be part of the networks of two…” | ✓ correct | part of the quote |  |
| 34 | powergrid p.4 | matched | “If two or more players are tied for the most cities, the…” | ✓ correct | part of the quote |  |
| 35 | powergrid p.6 | matched | “The players do not have to choose their starting cities …” | ✓ correct | part of the quote |  |
| 36 | root p.5 | partial match (68% of the quote) | “They don’t rule this clearing either, so they cannot mov…” | ✓ correct | part of the quote |  |
| 38 | azul p.4 | matched (3 fragments, 91% of the quote) | “Move the rightmost tile of each complete line to the spa…” | ✓ correct | whole quote | 3 fragments around the Incomplete/Complete labels of a figure |
| 39 | dune p.17 | matched | “you may deploy to the Conflict any number of troops you …” | ✓ correct | part of the quote |  |
| 40 | powergrid p.4 | matched | “During the frst round of the game each player must buy 1…” | ✓ correct | part of the quote |  |
| 41 | powergrid p.12 | matched | “Every city can only be part of the network of a single p…” | ✓ correct | part of the quote |  |
| 42 | root p.11 | matched (2 fragments, 100% of the quote) | “She moves two warriors from a mouse clearing, which she …” | ✓ correct | whole quote |  |
| 43 | powergrid p.8 | matched | “In Step 3, every city can be part of the networks of thr…” | ✓ correct | part of the quote |  |
| 44 | azul p.2 | matched on p.3 (claimed p.2) | “If you have picked up more tiles than you can place in y…” | ✓ correct | whole quote |  |
| 45 | azul p.3 | matched on p.4 (claimed p.3) | “Any tiles you have picked that you cannot or do not want…” | ✓ correct | whole quote |  |
| 46 | azul p.3 | matched on p.4 (claimed p.3) | “She may even choose to place both tiles in the floor lin…” | ✓ correct | whole quote |  |
| 47 | dune p.10 | matched on p.11 (claimed p.10) | “Each sword you revealed during your Reveal turn is worth…” | ✓ correct | whole quote |  |
| 49 | dune p.10 | matched on p.11 (claimed p.10) | “your strength becomes 0, and can’t be increased by any m…” | ✓ correct | part of the quote |  |
| 50 | dune p.16 | matched on p.17 (claimed p.16) | “you may deploy to the Conflict any number of troops you …” | ✓ correct | part of the quote |  |
| 51 | powergrid p.5 | matched | “If the player does not want to ofer a power plant for au…” | ✓ correct | part of the quote |  |
| 52 | dune p.10 | matched | “plus up to two more troops from your garrison. (Any troo…” | ✓ correct | whole quote |  |

The numbers refer to `evals/fixtures/match-set.json` (`bench match-set` prints the same table).
