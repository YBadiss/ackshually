import SwiftUI
import AckshuallyCore

/// A picked rulebook in "Add N Rulebooks" (S14): its first page, its title (tap to rename), why it was put here,
/// and a Core / Add-on menu (hidden for skipped files).
struct ReviewBookRow: View {
    var book: ImportBatch.Book
    var cover: UIImage?
    /// nil: no role menu (skipped).
    var role: BookRole?
    /// The only core book of a new game: Add-on is off.
    var isLastCore = false
    var onRename: () -> Void
    var onSetRole: (BookRole) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Cover, text and menu in a row; stacked at accessibility sizes so no word breaks (#27).
    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.m))
            : AnyLayout(HStackLayout(spacing: theme.spacing.l))
    }

    var body: some View {
        layout {
            GameCover(image: cover)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Button(action: onRename) {
                    Text(book.title)
                        .font(theme.font.row)
                        .foregroundStyle(theme.colors.label)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Renames this rulebook")
                .accessibilityIdentifier("reviewTitle")
                if let reason = book.reason {
                    Text(reason)
                        .font(theme.font.gameDetail)
                        .foregroundStyle(theme.colors.secondaryLabel)
                        .accessibilityIdentifier("reviewReason")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let role {
                Menu {
                    Picker("Kind", selection: Binding(get: { role }, set: onSetRole)) {
                        Text("Core").tag(BookRole.core)
                        Text("Add-on").tag(BookRole.addOn).selectionDisabled(isLastCore)
                    }
                } label: {
                    Label(role == .core ? "Core" : "Add-on", systemImage: "chevron.up.chevron.down")
                        .labelStyle(TrailingIconLabelStyle())
                        .font(theme.font.rowValue)
                }
                .accessibilityIdentifier("role-\(book.fileName)")
            }
        }
        .padding(.vertical, theme.spacing.xxs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review-\(book.fileName)")
    }
}

#Preview("States") {
    List {
        ReviewBookRow(book: AddRulebooksFixtures.book("power-plant-rush.pdf", "Power Plant Rush", reason: "base rules"),
                      cover: LibraryFixtures.cover, role: .core, isLastCore: true, onRename: {}, onSetRole: { _ in })
        ReviewBookRow(book: AddRulebooksFixtures.book("storms.pdf", "Storms", reason: "expansion"),
                      cover: nil, role: .addOn, onRename: {}, onSetRole: { _ in })
        ReviewBookRow(book: AddRulebooksFixtures.book("score.pdf", "Score Pad", reason: "score sheet, not a rulebook"),
                      cover: nil, role: nil, onRename: {}, onSetRole: { _ in })
    }
    .themed()
}
#Preview("AX5, dark") {
    List {
        ReviewBookRow(book: AddRulebooksFixtures.book("storms.pdf", "Storms: The Weather Expansion", reason: "expansion booklet"),
                      cover: nil, role: .addOn, onRename: {}, onSetRole: { _ in })
    }
    .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
