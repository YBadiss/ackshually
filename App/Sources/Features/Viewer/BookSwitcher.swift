import SwiftUI
import AckshuallyCore

/// The book switcher (S13): with several books in play the viewer shows them one after another; this menu jumps
/// to the first page of one of them.
struct BookSwitcher: ToolbarContent {
    var parts: [BookPart]
    var onSelect: (Int) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Go to Book") {
                    ForEach(Array(parts.enumerated()), id: \.element.firstPage) { i, part in
                        Button { onSelect(i) } label: {
                            Text(part.title)
                            Text(part.pageCount == 1 ? "1 page" : "\(part.pageCount) pages")
                        }
                    }
                }
            } label: {
                Label("Books", systemImage: "books.vertical")
            }
            .accessibilityIdentifier("bookSwitcher")
        }
    }
}

#Preview {
    NavigationStack {
        Fixtures.pageBackdrop.navigationTitle("Power Plant Rush").navigationBarTitleDisplayMode(.inline)
            .toolbar { BookSwitcher(parts: Fixtures.setRulebook().contents.parts) { _ in } }
            .viewerChrome()
    }
    .themed()
}
#Preview("Dark") {
    NavigationStack {
        Fixtures.pageBackdrop.navigationTitle("Power Plant Rush").navigationBarTitleDisplayMode(.inline)
            .toolbar { BookSwitcher(parts: Fixtures.setRulebook().contents.parts) { _ in } }
            .viewerChrome()
    }
    .themed().preferredColorScheme(.dark)
}
