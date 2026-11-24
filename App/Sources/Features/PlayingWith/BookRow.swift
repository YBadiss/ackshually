import SwiftUI

/// One rulebook in "Playing with" (S13): the title and a trailing checkmark when it is in play (a standard
/// selection list). Core books are checked (dimmed: they can't be unticked); tapping an add-on ticks it.
struct BookRow: View {
    var book: PlayingWithContent.Book
    var onToggle: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        if book.role == .core {
            label.accessibilityValue("Always in play")
        } else {
            Button(action: onToggle) { label }
                .buttonStyle(.plain)
                .accessibilityAddTraits(book.inPlay ? .isSelected : [])
                .accessibilityValue(book.inPlay ? "Playing with" : "Not tonight")
                .accessibilityHint("Ticks or unticks this add-on for tonight")
        }
    }

    private var label: some View {
        HStack(spacing: theme.spacing.l) {
            Text(book.title)
                .font(theme.font.row)
                .foregroundStyle(theme.colors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark")
                .font(theme.font.row.weight(.semibold))
                .foregroundStyle(book.role == .core ? theme.colors.tertiaryLabel : theme.colors.tint)
                .opacity(book.inPlay ? 1 : 0)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("book-\(book.fileName)")
    }
}

#Preview("States") {
    List {
        BookRow(book: PlayingWithFixtures.content.core[0]) {}
        ForEach(PlayingWithFixtures.content.addOns) { BookRow(book: $0) {} }
    }
    .themed()
}
#Preview("AX5, dark") {
    List { ForEach(PlayingWithFixtures.content.addOns) { BookRow(book: $0) {} } }
        .themed().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}
