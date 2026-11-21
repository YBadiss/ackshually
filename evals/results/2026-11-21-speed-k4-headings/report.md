# Bench report — claude-sonnet-5-5 / json / effort low

- Date: 2026-11-21 20:40:23 +0000
- Questions: `m1.json`
- Model: `claude-sonnet-5-5` · effort `low` · evidence mode `json` (structured outputs)
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.
- Pages sent: **page selection** — top 4 BM25 pages + 0 neighbour(s), as pdf, full PDF if ≥75% of pages, re-ask with full PDF on not_covered

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 23/28 (82%) (+5 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 24/27 (89%) |
| Quotes matched on claimed page | 74/82 (90%) (+7 found on another page) |
| Answers with every quote matched | 24/28 (86%) |
| Figure boxes sane (inside page, not degenerate/whole page) | 1/1 (100%) |
| Verdict time median / p90 (s) | 4.0 / 10.9 |
| Step 1 ready median / p90 (s) | 4.9 / 12.2 |
| Step 1 within 5 s | 16/28 (57%) |
| Total answer cost | $1.102 (judge extra: 90500 in / 3795 out tokens) |

## Page selection

| Metric | Value |
|---|---|
| Retrieval recall: every expected page sent | 23/27 (85%) (at least one: 25/27 (93%)) |
| Pages sent (first attempt) | 112/422 (27%); mean excerpt 4.0 pages |
| Full PDF chosen up front | 0/28 (0%)  |
| Excerpt size (attached bytes, median) | 2797 KB |
| Fallback to full PDF (excerpt said not_covered) | 5/28 (18%): pg-06, pg-07, rt-02, rt-03, rt-06; fallback started at median 3.0 s; discarded attempts cost $0.152 |
| Evidence pages remapped (model cited an excerpt position) | 0 |
| Local prepare time (rank + build excerpt), median / max | 92 / 342 ms |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 3.4 / 3.6 | 4.2 / 4.5 | 4.2 / 4.5 | 5.0 / 5.2 | 5.0 / 5.2 | 5.9 / 6.6 |
| warm | 23 | 3.0 / 3.6 | 3.9 / 10.6 | 3.9 / 10.9 | 4.7 / 12.2 | 4.7 / 12.2 | 5.5 / 13.6 |
| followup | 1 | 3.7 / 3.7 | 14.6 / 14.6 | 14.8 / 14.8 | 15.6 / 15.6 | 15.6 / 15.6 | 16.8 / 16.8 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 12412 | 0 | 472 | $0.0358 |
| warm | 23 | 4 | 12149 | 9874 | 494 | $0.0363 |
| followup | 1 | 8 | 47921 | 0 | 411 | $0.1239 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.04 · 5 q → $0.20 · 20 q → $0.80

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost | Sent | Recall |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 3/3 | 4.5 | 5.2 | 6.6 | $0.0414 | 3,5,7,9 | ✓ |
| pg-02 | warm | ok | correct | ✓ | 4/4 | 4.7 | 5.6 | 6.8 | $0.0412 | 3,5,7,8 | ✓ |
| pg-03 | warm | ok | correct | ✓ | 3/3 | 4.2 | 4.5 | 5.3 | $0.0391 | 4,5,7,12 | ✓ |
| pg-04 | warm | ok | partially_correct | ✗ | 3/3 | 4.4 | 6.3 | 7.2 | $0.0377 | 5,8,10,12 | ✗ |
| pg-05 | warm | ok | correct | ✓ | 2/2 | 4.1 | 5.1 | 5.7 | $0.0364 | 3,7,8,10 | ✓ |
| pg-06 | followup | ok | correct | ✓ | 2/2 | 14.8 | 15.6 | 16.8 | $0.1239 | 2,3,8,9 → full | ✓ |
| pg-07 | warm | ok | correct | TODO | 3/3 | 10.9 | 12.1 | 13.3 | $0.0439 | 4,5,6,12 → full | – |
| pg-08 | warm | ok | correct | ✓ | 2/2 | 3.9 | 5.3 | 5.3 | $0.0048 | 4,5,6,12 | ✓ |
| rt-01 | cold | ok | partially_correct | ✓ | 2/2 | 2.8 | 4.3 | 4.8 | $0.0311 | 9,14,20,21 | ✓ |
| rt-02 | warm | ok | partially_correct | ✓ | 3/4 | 12.2 | 14.1 | 15.1 | $0.1870 | 2,10,11,12 → full | ✗ |
| rt-03 | warm | ok | partially_correct | ✓ | 4/4 | 9.9 | 12.2 | 13.6 | $0.0414 | 2,10,11,15 → full | ✗ |
| rt-04 | warm | ok | correct | ✓ | 4/4 | 3.7 | 4.7 | 5.9 | $0.0353 | 3,6,11,14 | ✓ |
| rt-05 | warm | ok | correct | ✓ | 3/3 | 2.7 | 3.9 | 4.9 | $0.0331 | 2,11,14,15 | ✓ |
| rt-06 | warm | ok | partially_correct | ✓ | 3/3 | 11.8 | 12.9 | 14.1 | $0.0385 | 8,11,12,13 → full | ✗ |
| az-01 | cold | ok | correct | ✓ | 3/3 | 4.2 | 5.0 | 5.9 | $0.0327 | 2,3,4,5 | ✓ |
| az-02 | warm | ok | correct | ✓ | 3/3 | 4.2 | 4.9 | 5.9 | $0.0053 | 2,3,4,5 | ✓ |
| az-03 | warm | ok | correct | ✗ | 0/3 | 3.7 | 4.4 | 5.4 | $0.0055 | 2,3,4,5 | ✓ |
| az-04 | warm | ok | correct | ✓ | 3/3 | 4.1 | 5.6 | 6.9 | $0.0345 | 3,4,5,6 | ✓ |
| az-05 | warm | ok | correct | ✓ | 3/3 | 3.6 | 4.4 | 5.4 | $0.0057 | 3,4,5,6 | ✓ |
| az-06 | warm | ok | correct | ✓ | 3/3 +box | 4.0 | 5.6 | 6.8 | $0.0076 | 2,3,4,5 | ✓ |
| az-07 | warm | ok | correct | ✓ | 3/3 | 3.9 | 4.6 | 5.5 | $0.0053 | 2,3,4,5 | ✓ |
| du-01 | cold | ok | correct | ✓ | 3/3 | 3.0 | 4.0 | 4.7 | $0.0378 | 8,11,13,20 | ✓ |
| du-02 | warm | ok | correct | ✓ | 2/2 | 2.6 | 4.3 | 4.7 | $0.0388 | 11,12,13,20 | ✓ |
| du-03 | warm | ok | correct | ✗ | 0/3 | 2.5 | 3.5 | 4.3 | $0.0398 | 10,11,16,19 | ✓ |
| du-04 | warm | ok | correct | ✓ | 2/3 | 2.1 | 3.6 | 4.6 | $0.0396 | 10,16,17,19 | ✓ |
| du-05 | warm | ok | correct | ✓ | 3/3 | 2.4 | 3.2 | 4.4 | $0.0386 | 6,13,16,20 | ✓ |
| du-06 | warm | ok | correct | ✓ | 3/3 | 2.5 | 4.2 | 4.9 | $0.0374 | 9,13,18,20 | ✓ |
| du-07 | warm | ok | correct | ✓ | 2/2 | 2.2 | 3.9 | 4.5 | $0.0389 | 12,13,19,20 | ✓ |

## Misses

**pg-04** — Early game: can I build a house in Berlin if my friend already has one there?
- judge **partially_correct**: The assistant gets the main outcome right: no in Step 1, and in Steps 2 and 3 a second or third player can join, at 15 and 20 Elektro. It omits the rule that a player may never connect to the same city twice, which the expected ruling includes. It also implies that building is possible in Step 2 with a friend's house already there, but does not say that the asker could not add a second house of their own. The asker already has no house there, so this is minor. The missing same-city restriction is a small omission, so the answer is mostly correct.
  - expected: Not in Step 1: each city can only be connected by one player. In Step 2 two players can connect to a city, in Step 3 three (spaces cost 10, 15, 20 Elektro). A player may never connect to the same city twice.
  - got: It depends on the Step: in Step 1 no, since each city holds only one player's network. Once Step 2 starts, yes, as a second house for 15 Elektro, if that space is open. (stated)
- cited pages [8, 12] don't include an expected page

**rt-01** — I'm the attacker. Can I play an ambush card?
- judge **partially_correct**: The assistant's substance matches the rulebook: the attacker can only play a matching ambush card to foil the defender's ambush, and cannot ambush to deal hits. But it opens with "Yes" to "Can I play an ambush card?" where the expected answer is "No" (only the defender may ambush; the attacker may only cancel). The "Yes, but only to foil" framing is a conditional answer that contradicts the expected headline, though the details are right.
  - expected: No. Only the defender may play an ambush card (matching the battle clearing, or a bird). The attacker may only play a matching ambush card to cancel the defender's ambush.
  - got: Yes, but only to foil a defender's ambush: the attacker may play a matching ambush card to cancel it. The attacker cannot play an ambush card to deal hits. (inferred)

**rt-02** — The cats and I both have 2 pieces in a clearing. Who rules it?
- judge **partially_correct**: The assistant gets the core rule right: a tie means nobody rules, except the Eyrie, who rule tied clearings (Lords of the Forest). But the verdict says the Eyrie 'win ties', which is loose. Per the rulebook, the Eyrie rule a clearing where they are tied only if they have pieces there. In the user's scenario, the user and the cats are tied 2-2, so this holds only if the user is the Eyrie. The assistant also never says that the Eyrie rule only if they are among the tied players. Its extra points about tokens and the Vagabond pawn are supported by the glossary. Overall the outcome matches, but the verdict is hedged and the exception is imprecise, so it is mostly correct but not fully precise.
  - expected: Nobody rules it when tied — except the Eyrie, who rule tied clearings where they have pieces (Lords of the Forest).
  - got: If the pieces are warriors and buildings, it's a tie and nobody rules it, unless you are the Eyrie, who win ties. Tokens and the Vagabond pawn don't count toward rule. (stated)
- step 3 p.24: not matched (best error 15%) — “It is not a warrior and does not add to rule.”

**rt-03** — can my guys walk from a spot the cats own to another spot the cats also own?
- judge **partially_correct**: The core ruling for the situation asked is right: if the Marquise rules both clearings, another faction rules neither and cannot move between them. The verdict is muddled, though. It opens with "Yes, if you are not the Marquise..." and then concludes "so you cannot", which contradicts itself. The question says "my guys" and "the cats own", which implies a non-cat player, so the Marquise branch is irrelevant. The Eyrie tie branch and the Vagabond branch are supported by the pages. The confidence is also labelled inferred rather than stated, although the rule is stated on page 5. The correct answer is present, but the opening "Yes" and the branching blur it.
  - expected: No. To move you must rule the clearing you move from or the clearing you move to.
  - got: Yes, if you are not the Marquise and the move is between connected clearings, you can move only if you rule the origin or the destination, and the Marquise ruling both means you rule neither, so you cannot (barring a tie or special ability). (inferred)

**rt-06** — wait can my cats leave a spot where we're tied with the birds
- judge **partially_correct**: The assistant gets the core rule right: to move, the Marquise must rule the destination, because on a tie no one rules the origin. It also correctly notes that the Eyrie rule tied clearings. But it assumes the Eyrie are one of the tied parties, and the question only says birds are tied with the cats. It states that the Eyrie rule this clearing as the verdict. The expected ruling treats the Eyrie case only as a branch for when the player is the Eyrie. Here the player is the cats, so the Eyrie ruling is plausible. The assistant's branches still cover the key condition. The mismatch is minor: it does not say that an ordinary tie leaves nobody ruling the origin, and it presents the Eyrie rule as definite. Overall it is mostly right but slightly off.
  - expected: Only if you rule the clearing you move to: on a tie no one rules your starting clearing (for you), so it can't be the one that lets you move. Branch: if you are the Eyrie, you rule tied clearings (Lords of the Forest).
  - got: Only if the Marquise rules the destination clearing. A tie normally means nobody rules, but the Eyrie rule any clearing where they are tied, so the Marquise does not rule this one. (inferred)

**az-03** — Can I dump my tiles straight onto the floor line even though a pattern line could take them?
- cited pages [2, 3] don't include an expected page
- step 1 p.2: matched on p.3 (claimed p.2) — “If you have picked up more tiles than you can place in your chosen pattern line, you must place the excess tiles in the ”
- step 2 p.3: matched on p.4 (claimed p.3) — “Any tiles you have picked that you cannot or do not want to place according to the rules, you must place in your floor l”
- step 3 p.3: matched on p.4 (claimed p.3) — “She may even choose to place both tiles in the floor line (C).”

**du-03** — I have 6 swords in my reveal but no troops in the conflict. Do the swords count?
- cited pages [10] don't include an expected page
- step 1 p.10: matched on p.11 (claimed p.10) — “Each sword you revealed during your Reveal turn is worth 1 strength.”
- step 2 p.10: matched on p.11 (claimed p.10) — “You must have at least one troop in the Conflict to have any strength.”
- step 2 p.10: matched on p.11 (claimed p.10) — “your strength becomes 0, and can’t be increased by any means, including swords on cards you revealed.”

**du-04** — I send an agent to a combat space. How many troops can I put into the conflict?
- step 2 p.16: matched on p.17 (claimed p.16) — “you may deploy to the Conflict any number of troops you recruit this turn (including troops recruited by the card you pl”

