import SwiftUI

/// My Games' toolbar: app-wide items (Settings) and adding a rulebook.
struct LibraryToolbar: ToolbarContent {
    var onAdd: () -> Void
    var onSettings: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape", action: onSettings)
                .accessibilityIdentifier("settings")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Add a Rulebook", systemImage: "plus", action: onAdd)
                .accessibilityIdentifier("addRulebook")
        }
    }
}
