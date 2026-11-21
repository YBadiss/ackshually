# Bench report — claude-opus-5-5 / citations / effort low

- Date: 2026-11-21 18:51:37 +0000
- Questions: `m1.json`
- Model: `claude-opus-5-5` · effort `low` · evidence mode `citations`
- Verdict correctness is graded by an **LLM judge** (`claude-sonnet-5-5`), not by a human.

## Summary

| Metric | Value |
|---|---|
| Questions run | 28 (skipped: 0) |
| Failures (timeout / invalid output / API error) | 0 / 0 / 0 |
| Verdict correct — **LLM judge** | 24/28 (86%) (+4 partial; 0 not judged) |
| Evidence page correct (where expected pages known) | 27/27 (100%) |
| Quotes matched on claimed page | 148/159 (93%) (+0 found on another page) |
| Answers with every quote matched | 19/28 (68%) |
| Figure boxes sane (inside page, not degenerate/whole page) | – |
| Verdict time median / p90 (s) | 5.7 / 8.7 |
| Step 1 ready median / p90 (s) | 7.1 / 10.4 |
| Step 1 within 5 s | 7/28 (25%) |
| Total answer cost | $1.559 (judge extra: 103742 in / 3746 out tokens) |

## Latency by position (seconds, median / p90)

cold = first question on a PDF (cache write) · warm = later new question on the same PDF (cache read) · followup = same session, with conversation context

| Position | n | First token | Restated | Verdict | Step 1 evidence | Step 1 | Full answer |
|---|---|---|---|---|---|---|---|
| cold | 4 | 4.8 / 6.2 | 5.1 / 6.6 | 5.7 / 7.2 | 6.5 / 8.6 | 6.5 / 8.6 | 9.7 / 11.1 |
| warm | 23 | 4.5 / 7.9 | 4.9 / 8.3 | 5.3 / 9.0 | 7.4 / 10.9 | 7.4 / 10.9 | 9.9 / 14.0 |
| followup | 1 | 5.3 / 5.3 | 5.5 / 5.5 | 6.1 / 6.1 | 7.1 / 7.1 | 7.1 / 7.1 | 9.6 / 9.6 |

## Tokens & cost by position (mean per question)

| Position | n | Input (uncached) | Cache write | Cache read | Output | Cost |
|---|---|---|---|---|---|---|
| cold | 4 | 4 | 47858 | 0 | 609 | $0.2515 |
| warm | 23 | 4 | 27 | 46734 | 683 | $0.0232 |
| followup | 1 | 4 | 460 | 40797 | 500 | $0.0205 |

Projected cost per PDF (mean cold + n−1 × mean warm/follow-up, cache kept warm): 1 q → $0.25 · 5 q → $0.34 · 20 q → $0.69

## Per question

| Id | Pos | Status | Judge | Pages | Quotes matched | Verdict s | Step 1 s | Total s | Cost |
|---|---|---|---|---|---|---|---|---|---|
| pg-01 | cold | ok | correct | ✓ | 5/5 | 5.7 | 6.5 | 9.7 | $0.2174 |
| pg-02 | warm | ok | correct | ✓ | 8/8 | 9.0 | 10.4 | 14.0 | $0.0244 |
| pg-03 | warm | ok | correct | ✓ | 6/6 | 7.3 | 7.9 | 10.1 | $0.0177 |
| pg-04 | warm | ok | correct | ✓ | 6/6 | 5.1 | 7.4 | 10.3 | $0.0243 |
| pg-05 | warm | ok | correct | ✓ | 5/5 | 5.8 | 7.9 | 9.9 | $0.0192 |
| pg-06 | followup | ok | correct | ✓ | 4/4 | 6.1 | 7.1 | 9.6 | $0.0205 |
| pg-07 | warm | ok | correct | TODO | 6/6 | 4.8 | 6.2 | 9.0 | $0.0196 |
| pg-08 | warm | ok | correct | ✓ | 5/5 | 7.5 | 8.6 | 11.3 | $0.0195 |
| rt-01 | cold | ok | correct | ✓ | 5/6 | 7.2 | 8.6 | 11.1 | $0.3770 |
| rt-02 | warm | ok | partially_correct | ✓ | 4/4 | 13.5 | 15.7 | 17.5 | $0.0300 |
| rt-03 | warm | ok | partially_correct | ✓ | 6/7 | 8.7 | 10.9 | 13.8 | $0.0342 |
| rt-04 | warm | ok | correct | ✓ | 3/4 | 7.4 | 8.0 | 9.8 | $0.0242 |
| rt-05 | warm | ok | correct | ✓ | 3/5 | 9.4 | 12.1 | 14.5 | $0.0295 |
| rt-06 | warm | ok | correct | ✓ | 4/5 | 7.8 | 9.4 | 11.7 | $0.0295 |
| az-01 | cold | ok | correct | ✓ | 8/8 | 3.6 | 5.1 | 8.2 | $0.0969 |
| az-02 | warm | ok | correct | ✓ | 3/4 | 3.0 | 3.8 | 5.6 | $0.0130 |
| az-03 | warm | ok | correct | ✓ | 6/6 | 3.0 | 4.0 | 6.5 | $0.0153 |
| az-04 | warm | ok | correct | ✓ | 7/7 | 3.1 | 6.2 | 9.1 | $0.0202 |
| az-05 | warm | ok | correct | ✓ | 3/5 | 2.4 | 3.4 | 5.9 | $0.0148 |
| az-06 | warm | ok | correct | ✓ | 6/6 | 6.1 | 10.0 | 12.6 | $0.0267 |
| az-07 | warm | ok | correct | ✓ | 4/5 | 1.9 | 4.0 | 5.9 | $0.0148 |
| du-01 | cold | ok | correct | ✓ | 4/4 | 3.1 | 3.8 | 5.8 | $0.3147 |
| du-02 | warm | ok | partially_correct | ✓ | 6/6 | 3.6 | 5.1 | 8.2 | $0.0261 |
| du-03 | warm | ok | partially_correct | ✓ | 6/6 | 5.7 | 7.1 | 9.4 | $0.0234 |
| du-04 | warm | ok | correct | ✓ | 8/8 | 2.7 | 3.3 | 7.4 | $0.0277 |
| du-05 | warm | ok | correct | ✓ | 6/7 | 3.1 | 3.9 | 7.3 | $0.0254 |
| du-06 | warm | ok | correct | ✓ | 7/7 | 5.3 | 7.1 | 10.5 | $0.0283 |
| du-07 | warm | ok | correct | ✓ | 4/4 | 5.1 | 7.7 | 10.1 | $0.0250 |

## Misses

**rt-01** — I'm the attacker. Can I play an ambush card?
- step 2 p.9: not matched (best error 38%) — “At start of battle, defender may play to 
deal two immediate hits, unless attacker 
plays a matching ambush card.”

**rt-02** — The cats and I both have 2 pieces in a clearing. Who rules it?
- judge **partially_correct**: The core ruling matches: a 2 v 2 tie means no one rules, except the Eyrie (Lords of the Forest). But the assistant's answer is inconsistent on two points. First, it says the Eyrie rule on ties without the expected condition that they must have pieces in the clearing. Second, the Vagabond branch says "The cats rule", which is not supported. The Vagabond does not count toward rule, so a 2 v 2 tie between the Vagabond's pieces and the cats would be impossible, and the claim that the cats rule contradicts the user's stated tie. The token branch is supported by the rulebook. The main verdict is right, but the added branches introduce errors and omit the "where they have pieces" condition.
  - expected: Nobody rules it when tied — except the Eyrie, who rule tied clearings where they have pieces (Lords of the Forest).
  - got: If those pieces are warriors or buildings, it's a tie and no one rules the clearing, unless you are the Eyrie, who rule on ties. (stated)

**rt-03** — can my guys walk from a spot the cats own to another spot the cats also own?
- judge **partially_correct**: The core ruling is right (No; you must rule the origin or destination, and the cats ruling both means you rule neither). The Vagabond exception is supported by p. 17. But the Eyrie branch is wrong or confusing. The Eyrie ruling tied clearings does not make the cats' own clearing yours unless tied, and the case where the cats own both clearings is not a tie, so it is a muddled branch. Also, Eyrie being tied is only relevant if cats are not ruler. The answer hedges with branches that add questionable conditions, though the main verdict matches.
  - expected: No. To move you must rule the clearing you move from or the clearing you move to.
  - got: No. To move, you must rule the clearing you leave or the one you enter. If the cats rule both, your warriors cannot make that move, unless you are the Vagabond. (stated)
- step 2 p.5: not matched (best error 36%) — “Move Example
ey don’t rule this 
clearing either, so they 
cannot move here.”

**rt-04** — If I have to spend a fox card, can I spend a bird card instead? And the other way round?
- step 2 p.6: not matched (best error 30%) — “OR
Matching Example
If the action said you must spend a 
matching card, you could spend a 
fox or a bird card, since bir”

**rt-05** — As the Woodland Alliance, does spreading sympathy into a clearing with 3 Marquise warriors cost the normal amount?
- step 1 p.15: not matched (best error 46%) — “Spread Sympathy: Place a sympathy token in an unsympathetic clearing, adjacent to a sympathetic clearing if 
possible. ”
- step 2 p.15: not matched (best error 41%) — “If the target clearing has 
three or more warriors of another player, you must spend 
another matching supporter to plac”

**rt-06** — wait can my cats leave a spot where we're tied with the birds
- step 4 p.5: not matched (best error 37%) — “Buildings
ey do rule this 
clearing, so they 
can move here.
”

**az-02** — Can I put blue tiles in my third pattern line if there's already a blue tile in the third row of my wall?
- step 2 p.4: not matched (best error 14%) — “Incomplete
Incomplete
Complete
• In all later rounds, you must also comply with the following 
rule: You are not allowed”

**az-05** — End of game: what's a completed column worth compared to a completed row and all five of one color?
- step 1 p.6: not matched (best error 13%) — “CREDITS
End of the game
The game ends right after the Wall-tiling phase in which at least 
one player has completed at l”
- step 2 p.6: not matched (best error 36%) — “Once the game has ended, score additional points if you have 
achieved the following goals:
• Gain 2 points for each com”

**az-07** — can i throw red on the line that's already got blue on it
- step 3 p.4: not matched (best error 14%) — “Incomplete
Incomplete
Complete
• In all later rounds, you must also comply with the following 
rule: You are not allowed”

**du-02** — Two of us tie for the highest strength in combat. Who gets the first-place reward?
- judge **partially_correct**: The core ruling matches the rulebook: with a tie for first, no one wins and each tied player gets the second reward. However, the answer misses the tie-for-second rule, which the expected ruling includes: players tied for second get the third reward. It also adds a 3-player branch saying the third player gets nothing, which is supported only indirectly because the third reward is not available in 3-player games. The 0-strength claim is supported by the rulebook. The answer is right on the main point but omits the second-place tie condition.
  - expected: Nobody: tied players for first each get the second-place reward instead (and if tied for second, they get third-place reward).
  - got: Nobody. Neither of you wins the Conflict, the first-place reward is not given, and each of you receives the second-place reward. (stated)

**du-03** — I have 6 swords in my reveal but no troops in the conflict. Do the swords count?
- judge **partially_correct**: The main ruling is right and supported by the rulebook: with no troops in the Conflict your strength is 0 and swords add nothing. However, the branches are flawed. The first suggests an Agent turn to a Combat space before setting strength could put troops in the Conflict, which is plausible but irrelevant here, since the question says there are none. The second claims a Combat Intrigue card could add troops, but the rulebook says only players with at least one troop in the Conflict may play Combat Intrigue cards. So a player with no troops cannot play one, and that branch contradicts the pages. The swords also would not count in that case if the troop is added after Set Strength, since strength is 0 and only 'adjusts' by the card. This invented, contradicted branch means the answer is not fully correct.
  - expected: No. If you have no units in the Conflict your strength is 0, regardless of swords.
  - got: No. With no troops in the Conflict your strength is 0, and the swords add nothing. (stated)

**du-05** — Someone just hit 10 points mid-round. Does the game end right now?
- step 4 p.13: not matched (best error 21%) — “Phase 4: Makers
Phase 5: Recall
Endgame
First, you may play and resolve any 
Endgame Intrigue cards you have.”

