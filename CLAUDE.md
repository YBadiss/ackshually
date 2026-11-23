# Working in this repo

- The product spec is `docs/spec.html` (HTML, not Markdown). Screen mockups come from `docs/design/screens.js`; insert one with `<div class="shot" data-screen="sN"></div>`. When a decision changes, add a row to the spec's decision log (§7) and update the sections it affects, so text and mockups never disagree.
- The answer engine lives in `Core/`; the app and the evals use the same code path. Keep `Core` UI-free and building for both macOS and iOS.
- Evals: `evals/` (`bench` CLI). Every run writes to git-ignored `evals/out/`. Copy runs that inform a decision to `evals/results/<date>-<label>/` and add a row to `evals/results/README.md`. Expected answers in question sets must be verified against the actual PDFs (`assets/rulebooks/`), with the page and an exact quote.
- The API key comes from `ANTHROPIC_API_KEY`; never write it to a file in the repo.
- Rulebook PDFs are copyrighted and git-ignored. Don't commit them or long excerpts.
- Default answer config (from M1): `claude-sonnet-5-5`, `json` evidence mode, effort `low`.
- iOS app (`App/`): small, modular SwiftUI components, one concept per file, grouped by feature. Leaf views take plain values + action closures (no network, Keychain or global state); orchestration lives in a few injected `@Observable` models. All colors, radii, spacing and type styles come from one Theme file (spec §3). Every component has `#Preview`s covering its states, built from shared fixtures so screens can be iterated on without an API key.
- No static layout in the app: theme injected via the SwiftUI Environment with semantic tokens; Dynamic Type text styles and `@ScaledMetric` for sizes that should scale; sizes relative to the container (`containerRelativeFrame`, sheet detents), never fixed frames; adapt to size classes/orientation in one container view (`ViewThatFits`/`AnyLayout`). Preview on small and large iPhones, landscape, iPad, largest text size and dark mode.
- SwiftUI skills are vendored in `.claude/skills/`: use `swiftui-expert-skill` when writing or refactoring app code, and run `swiftui-pro` as a review pass before opening an app PR. Project rules here win where they differ (e.g. we do want Liquid Glass/system materials, per spec §3).
- Toolchain: Xcode 27.2 / Swift 6.4 on macOS 27, XcodeGen 2.48+ (`brew install xcodegen`). Target the current iOS SDK.
- The Xcode project is generated and git-ignored: `App/project.yml` is the source of truth (targets, scheme, test plans). Run `App/bootstrap.sh` after cloning, after pulling and after changing `project.yml`; never edit `Ackshually.xcodeproj` by hand.
- App dependencies: models get `AppDependencies` (credentials, settings, library storage, answer providers) by initialiser; glue views read it from the environment. Only the live implementations (`App/Sources/Services/Dependencies/`) and `LaunchOptions` touch the Keychain, `UserDefaults`, `Library` or `ServerConfig`. Previews and unit tests use the in-memory ones (`Preview Content/InMemoryDependencies.swift`).
- App testing: answer, card, highlight, sheet-rule and library logic is unit-tested in `App/Tests` against a scripted provider (no simulator UI, milliseconds); `App/UITests` keeps what only the real screen shows (layout and margins, detents, gestures, PDF zoom and spotlight, navigation, the file importer, Settings, the server stub route). Every bug found by hand gets an automated test before the fix is merged: a unit test when the logic is wrong, a UI test when only the screen shows it. Launch arguments for UI tests are in `App/Sources/App/LaunchOptions.swift` (`-noKey YES` ignores every credential, `-demoPace 0` streams the demo answer instantly). Several agents may test at once: create your own simulator (`xcrun simctl create "iPhone 18 Pro (<task>)" com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2`), pass `-destination 'id=<udid>'`, and delete it when done.

  Which tests when (test plans in `App/TestPlans`, wired into the scheme by `project.yml`):

  | When | Run | Time |
  |---|---|---|
  | Logic change (models, Core) | `-testPlan Unit` (and `cd Core && swift test`) | seconds |
  | Iterating on a screen | `-testPlan Smoke` plus the area plan: `Viewer`, `AnswerSheet`, `Library` or `Server` | ~1 min + the area |
  | Before a PR | `-testPlan Full`, in parallel | see `docs/m2-notes.md` |

  ```sh
  xcodebuild test -project App/Ackshually.xcodeproj -scheme Ackshually -destination 'id=<udid>' -testPlan Smoke
  xcodebuild test -project App/Ackshually.xcodeproj -scheme Ackshually -destination 'id=<udid>' -testPlan Full \
    -parallel-testing-enabled YES -parallel-testing-worker-count 3   # clones the simulator per worker
  ```
- Architecture diagram: the Claude whiteboard at https://claude.ai/artifact/Wv4rbfpuJmvZqPFjT8nyA1 (linked from spec §5). When a change adds, removes or renames a module, model or service, or changes who depends on what, update the board in the same PR: edit only the boxes and arrows affected, never redraw it. If you can't write to it, say what changed in the PR so the lead updates it.
