import SwiftUI

/// My Games' toolbar: Settings, Edit / Done, adding rulebooks, and in Edit mode Delete for the selected games.
struct LibraryToolbar: ToolbarContent {
    var isEditing: Bool
    /// Games selected in Edit mode.
    var selectedCount: Int
    /// No games: no Edit.
    var canEdit: Bool
    var onAdd: () -> Void
    var onSettings: () -> Void
    var onToggleEditing: () -> Void
    var onDeleteSelected: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape", action: onSettings)
                .accessibilityIdentifier("settings")
                .disabled(isEditing)
        }
        if canEdit || isEditing {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit", role: isEditing ? .confirm : nil, action: onToggleEditing)
                    .accessibilityIdentifier("editGames")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Add Rulebooks", systemImage: "plus", action: onAdd)
                .accessibilityIdentifier("addRulebook")
                .disabled(isEditing)
        }
        if isEditing {
            ToolbarItem(placement: .bottomBar) {
                Button(selectedCount == 0 ? "Delete" : "Delete (\(selectedCount))", role: .destructive, action: onDeleteSelected)
                    .disabled(selectedCount == 0)
                    .accessibilityIdentifier("deleteSelected")
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {}.navigationTitle("My Games").toolbar {
            LibraryToolbar(isEditing: false, selectedCount: 0, canEdit: true, onAdd: {}, onSettings: {}, onToggleEditing: {}, onDeleteSelected: {})
        }
    }.themed()
}
#Preview("Editing, AX5, dark") {
    NavigationStack {
        List {}.navigationTitle("My Games").toolbar {
            LibraryToolbar(isEditing: true, selectedCount: 2, canEdit: true, onAdd: {}, onSettings: {}, onToggleEditing: {}, onDeleteSelected: {})
        }
    }
    .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
