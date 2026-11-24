import SwiftUI
import AckshuallyCore

/// S14 · Add N Rulebooks: the picked PDFs grouped into games, for review. Files wait under "Sorting…" until the
/// suggestion arrives. Each game shows its name (a new one can be renamed) and whether it is new; each book its
/// cover, title (tap to rename) and a Core / Add-on menu. Drag a book onto another game, or long-press → Move to…
/// Nothing is saved until Add; Cancel discards the copies.
struct AddRulebooksSheet: View {
    var content: AddRulebooksContent
    var covers: [String: UIImage]
    var loadCover: (_ fileName: String, _ pixelWidth: Int, _ scale: CGFloat) async -> Void
    var actions: AddRulebooksActions
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale
    @State private var renaming: Renaming?
    @State private var newName = ""

    private enum Renaming: Identifiable, Equatable {
        case group(String)
        case book(String)
        var id: String {
            switch self {
            case .group(let id): "group:\(id)"
            case .book(let f): "book:\(f)"
            }
        }
    }

    private var batch: ImportBatch { content.batch }

    var body: some View {
        NavigationStack {
            List {
                ForEach(batch.groups) { group in
                    Section {
                        ForEach(group.books) { book in
                            row(book, in: group)
                        }
                    } header: {
                        ReviewGroupHeader(name: group.name, badge: AddRulebooksContent.badge(group),
                                          onRename: group.isNew ? { startRenaming(.group(group.id), current: group.name) } : nil)
                            .dropDestination(for: String.self) { items, _ in actions.move(items, group.id, nil) }
                    }
                    .listRowBackground(theme.colors.card)
                }
                if batch.isSorting {
                    Section("Sorting…") {
                        ForEach(batch.sorting) { SortingRow(title: $0.title) }
                    }
                    .listRowBackground(theme.colors.card)
                }
                if !batch.skipped.isEmpty {
                    Section {
                        ForEach(batch.skipped) { book in
                            ReviewBookRow(book: book, cover: covers[book.fileName], role: nil,
                                          onRename: { startRenaming(.book(book.fileName), current: book.title) }, onSetRole: { _ in })
                                .draggable(book.fileName)
                                .contextMenu { moveMenu(book) }
                                .task(id: pixelWidth) { await loadCover(book.fileName, pixelWidth, displayScale) }
                        }
                    } header: {
                        Text("Skipped")
                    } footer: {
                        Text("Not added. Long-press one to add it to a game.")
                    }
                    .dropDestination(for: String.self) { items, _ in actions.skip(items) }
                    .listRowBackground(theme.colors.card)
                }
                if let note = content.note {
                    Section { } footer: { Text(note).accessibilityIdentifier("reviewNote") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.groupedBackground)
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: actions.cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", role: .confirm, action: actions.add)
                        .disabled(!content.canAdd)
                        .accessibilityIdentifier("addRulebooksConfirm")
                }
            }
            .alert(renaming.map(renameTitle) ?? "", item: $renaming) { target in
                TextField("Name", text: $newName)
                Button("Rename") { rename(target) }
                Button("Cancel", role: .cancel) {}
            }
        }
        .accessibilityIdentifier("addRulebooksSheet")
    }

    private func row(_ book: ImportBatch.Book, in group: ImportBatch.Group) -> some View {
        ReviewBookRow(book: book, cover: covers[book.fileName], role: book.role, isLastCore: batch.isLastCore(book.fileName),
                      onRename: { startRenaming(.book(book.fileName), current: book.title) },
                      onSetRole: { actions.setRole(book.fileName, $0) })
            .draggable(book.fileName)
            .dropDestination(for: String.self) { items, _ in actions.move(items, group.id, book.fileName) }
            .contextMenu { moveMenu(book) }
            .task(id: pixelWidth) { await loadCover(book.fileName, pixelWidth, displayScale) }
    }

    @ViewBuilder private func moveMenu(_ book: ImportBatch.Book) -> some View {
        Menu("Move to…", systemImage: "arrow.right.square") {
            ForEach(content.moveTargets(for: book.fileName)) { target in
                Button(target.title) { actions.moveTo(book.fileName, target.kind) }
            }
            Divider()
            Button("New Game", systemImage: "plus") { actions.moveToNewGame(book.fileName) }
        }
        Button("Rename", systemImage: "pencil") { startRenaming(.book(book.fileName), current: book.title) }
        if batch.group(containing: book.fileName) != nil {
            Button("Skip", systemImage: "nosign", role: .destructive) { actions.skip([book.fileName]) }
        }
    }

    /// Thumbnails rendered a bit wider than shown so small text-size changes reuse them (as in My Games).
    private var pixelWidth: Int {
        let px = theme.size.coverWidth * displayScale
        return Int((px / 64).rounded(.up) * 64)
    }

    private func renameTitle(_ r: Renaming) -> String {
        if case .group = r { "Rename Game" } else { "Rename Rulebook" }
    }

    private func startRenaming(_ target: Renaming, current: String) {
        newName = current
        renaming = target
    }

    private func rename(_ target: Renaming) {
        switch target {
        case .group(let id): actions.renameGroup(id, newName)
        case .book(let file): actions.renameBook(file, newName)
        }
    }
}

#Preview("Suggested") { AddRulebooksFixtures.sheet(AddRulebooksFixtures.suggested).themed() }
#Preview("Sorting") { AddRulebooksFixtures.sheet(AddRulebooksFixtures.sorting).themed() }
#Preview("Unsorted") { AddRulebooksFixtures.sheet(AddRulebooksFixtures.unsorted).themed() }
#Preview("AX5") { AddRulebooksFixtures.sheet(AddRulebooksFixtures.suggested).themed().dynamicTypeSize(.accessibility5) }
#Preview("Dark") { AddRulebooksFixtures.sheet(AddRulebooksFixtures.suggested).themed().preferredColorScheme(.dark) }
#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    AddRulebooksFixtures.sheet(AddRulebooksFixtures.suggested).themed()
}
#Preview("Landscape", traits: .landscapeLeft) { AddRulebooksFixtures.sheet(AddRulebooksFixtures.suggested).themed() }
#Preview("iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    AddRulebooksFixtures.sheet(AddRulebooksFixtures.suggested).themed().environment(\.horizontalSizeClass, .regular)
}
