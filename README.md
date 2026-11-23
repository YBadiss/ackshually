<img src="assets/icon.svg" width="64" height="64" alt="">

# ackshually

Settle a board-game rules dispute mid-game: ask about the rulebook PDF, get the ruling at once, and swipe through the highlighted evidence. iOS app (SwiftUI) powered by Claude.

**Start here:** open [docs/spec.html](docs/spec.html) in a browser (product spec with live screen mockups).

## Repo map

| Path | What |
|---|---|
| `docs/spec.html` | Product spec: decisions, screens S1–S12, style, answer contract, architecture, milestones, decision log |
| [Architecture whiteboard](https://claude.ai/artifact/Wv4rbfpuJmvZqPFjT8nyA1) | Living diagram of modules and dependencies (private Claude whiteboard) |
| `docs/design/` | `screens.js` + `screens.css` = the single source for screen mockups (used by the spec and `screens.html`); `explorations/` = superseded design work |
| `docs/m1-report.md` | M1 assumption check: results and recommendation |
| `docs/m2-notes.md` | M2 iOS viewer: how to run, what was verified, component map, proposed spec changes |
| `docs/original/` | The original concept and test-plan notes |
| `App/` | M2 SwiftUI app on Core; the Xcode project is generated from `project.yml` (`App/bootstrap.sh`, XcodeGen); see [docs/m2-notes.md](docs/m2-notes.md) |
| `Core/` | Swift package, no UI: answer contract, Claude provider (streaming), quote → highlight matcher |
| `Server/` | Node 24 service that holds the API key and forwards the app's answer requests; see [Server/README.md](Server/README.md) |
| `evals/` | `bench` CLI + question sets for the answer engine; `results/` = kept runs with an index |
| `assets/rulebooks/` | Rulebook PDFs (git-ignored, bring your own) |

## Common commands

```sh
cd Core && swift test                                  # unit tests
cd evals && swift run bench run                        # run the eval set (needs ANTHROPIC_API_KEY)
cd evals && swift run bench run --model claude-opus-5-5 --game azul
cd Server && npm test                                  # server tests (fake upstream, no key)
cd evals && ./compare.sh                               # model / evidence-mode comparison
App/bootstrap.sh                                       # generate the Xcode project (brew install xcodegen); again after pulls
open App/Ackshually.xcodeproj                          # iOS app (no key → demo answers; My Games → Try the Sample)
xcodebuild test -project App/Ackshually.xcodeproj -scheme Ackshually -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -testPlan Smoke
                                                       # test plans: Unit, Smoke, Viewer, AnswerSheet, Library, Server, Full (see CLAUDE.md)
```
