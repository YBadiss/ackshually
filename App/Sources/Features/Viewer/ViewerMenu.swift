import SwiftUI

/// The ⋯ menu: the system toolbar overflow menu, so its actions join the system's own overflow
/// instead of nesting a custom ellipsis menu inside it.
struct ViewerMenu: ToolbarContent {
    var hasAnswer: Bool
    var answerShown: Bool
    var isDemo: Bool
    var onOpen: () -> Void
    var onSample: () -> Void
    var onShowAnswer: () -> Void
    var onDetails: () -> Void
    var onSettings: () -> Void

    var body: some ToolbarContent {
        ToolbarOverflowMenu {
            Section {
                Button("Open a Rulebook PDF…", systemImage: "doc.badge.plus", action: onOpen)
                Button("Sample Rulebook", systemImage: "book.closed", action: onSample)
            }
            if hasAnswer {
                Section {
                    if !answerShown {
                        Button("Show Answer", systemImage: "text.below.photo", action: onShowAnswer)
                    }
                    Button("Answer Details", systemImage: "list.bullet.rectangle", action: onDetails)
                }
            }
            Section {
                Button("Settings", systemImage: "gearshape", action: onSettings)
            } header: {
                if isDemo { Text("Demo answers: no API key set") }
            }
        }
    }
}
