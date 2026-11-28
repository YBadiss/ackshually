import SwiftUI

/// My Games' toolbar, like Files and Photos. Browsing: Settings, Select, ＋. Selecting: Select All / Deselect
/// All and Done at the top (Settings and ＋ are gone, not dimmed), "N Selected" and a trash button at the bottom.
struct LibraryToolbar: ToolbarContent {
    var isSelecting: Bool
    var selectedCount: Int
    /// Every game is selected: the leading button reads Deselect All.
    var allSelected: Bool
    /// No games: no Select.
    var canSelect: Bool
    var onAdd: () -> Void
    var onSettings: () -> Void
    var onToggleSelecting: () -> Void
    var onSelectAll: (Bool) -> Void
    var onDeleteSelected: () -> Void

    var body: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button(allSelected ? "Deselect All" : "Select All") { onSelectAll(!allSelected) }
                    .accessibilityIdentifier("selectAll")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: onToggleSelecting)
                    .accessibilityIdentifier("selectGames")
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .status) {
                Text(selectedCount == 0 ? "Select Games" : selectedCount == 1 ? "1 Selected" : "\(selectedCount) Selected")
                    .accessibilityIdentifier("selectedCount")
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button("Delete", systemImage: "trash", role: .destructive, action: onDeleteSelected)
                    .disabled(selectedCount == 0)
                    .accessibilityIdentifier("deleteSelected")
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape", action: onSettings)
                    .accessibilityIdentifier("settings")
            }
            if canSelect {
                ToolbarItem(placement: .primaryAction) {
                    Button("Select", action: onToggleSelecting)
                        .accessibilityIdentifier("selectGames")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Rulebooks", systemImage: "plus", action: onAdd)
                    .accessibilityIdentifier("addRulebook")
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {}.navigationTitle("My Games").toolbar {
            LibraryToolbar(isSelecting: false, selectedCount: 0, allSelected: false, canSelect: true,
                           onAdd: {}, onSettings: {}, onToggleSelecting: {}, onSelectAll: { _ in }, onDeleteSelected: {})
        }
    }.themed()
}
#Preview("Selecting, none") {
    NavigationStack {
        List {}.navigationTitle("My Games").toolbar {
            LibraryToolbar(isSelecting: true, selectedCount: 0, allSelected: false, canSelect: true,
                           onAdd: {}, onSettings: {}, onToggleSelecting: {}, onSelectAll: { _ in }, onDeleteSelected: {})
        }
    }.themed()
}
#Preview("Selecting, AX5, dark") {
    NavigationStack {
        List {}.navigationTitle("My Games").toolbar {
            LibraryToolbar(isSelecting: true, selectedCount: 2, allSelected: false, canSelect: true,
                           onAdd: {}, onSettings: {}, onToggleSelecting: {}, onSelectAll: { _ in }, onDeleteSelected: {})
        }
    }
    .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
