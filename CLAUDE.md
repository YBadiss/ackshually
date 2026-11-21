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
- Toolchain: Xcode 27.2 / Swift 6.4 on macOS 27. Target the current iOS SDK.
