<img src="assets/icon.svg" width="64" height="64" alt="">

# ackshually

Settle a board-game rules dispute mid-game: ask about the rulebook PDF, get the ruling at once, and swipe through the highlighted evidence. iOS app (SwiftUI) powered by Claude.

**Start here:** open [docs/spec.html](docs/spec.html) in a browser (product spec with live screen mockups).

## Repo map

| Path | What |
|---|---|
| `docs/spec.html` | Product spec: decisions, screens S1–S12, style, answer contract, architecture, milestones, decision log |
| `docs/design/` | `screens.js` + `screens.css` = the single source for screen mockups (used by the spec and `screens.html`); `explorations/` = superseded design work |
| `docs/m1-report.md` | M1 assumption check: results and recommendation |
| `docs/original/` | The original concept and test-plan notes |
| `Core/` | Swift package, no UI: answer contract, Claude provider (streaming), quote → highlight matcher |
| `evals/` | `bench` CLI + question sets for the answer engine; `results/` = kept runs with an index |
| `assets/rulebooks/` | Rulebook PDFs (git-ignored, bring your own) |

## Common commands

```sh
cd Core && swift test                                  # unit tests
cd evals && swift run bench run                        # run the eval set (needs ANTHROPIC_API_KEY)
cd evals && swift run bench run --model claude-opus-5-5 --game azul
cd evals && ./compare.sh                               # model / evidence-mode comparison
```
