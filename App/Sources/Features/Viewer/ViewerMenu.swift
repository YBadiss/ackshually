import SwiftUI

/// The viewer's ⋯ menu: the system toolbar overflow menu, so its actions join the system's own
/// overflow instead of nesting a custom ellipsis menu inside it. Only this game's answer items
/// live here; app-wide items (Settings, adding a rulebook) are on My Games.
struct ViewerMenu: ToolbarContent {
    var hasAnswer: Bool
    var answerShown: Bool
    var isDemo: Bool
    var onShowAnswer: () -> Void
    var onDetails: () -> Void

    var body: some ToolbarContent {
        if hasAnswer {
            ToolbarOverflowMenu {
                Section {
                    if !answerShown {
                        Button("Show Answer", systemImage: "text.below.photo", action: onShowAnswer)
                    }
                    Button("Answer Details", systemImage: "list.bullet.rectangle", action: onDetails)
                } header: {
                    if isDemo { Text("Demo answers: no access token set") }
                }
            }
        }
    }
}
