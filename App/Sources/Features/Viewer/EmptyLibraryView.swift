import SwiftUI

/// First launch (before S1 exists in M3): open a rulebook PDF or try the sample.
struct EmptyLibraryView: View {
    var error: String?
    var onOpen: () -> Void
    var onSample: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        ContentUnavailableView {
            Label("No Rulebook Yet", systemImage: "book.pages")
        } description: {
            VStack(spacing: theme.spacing.s) {
                Text("Open the rulebook PDF for your game, then ask. Well, according to p.14…")
                if let error {
                    Text(error).foregroundStyle(theme.colors.warning)
                }
            }
        } actions: {
            Button("Open a Rulebook PDF", action: onOpen)
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("openPDF")
            Button("Try the Sample Rulebook", action: onSample)
                .accessibilityIdentifier("openSample")
        }
        .themeBackground(\.groupedBackground)
    }
}

#Preview { EmptyLibraryView(onOpen: {}, onSample: {}).themed() }
#Preview("Error, AX5") {
    EmptyLibraryView(error: "Couldn't open notes.txt as a PDF.", onOpen: {}, onSample: {})
        .themed()
        .dynamicTypeSize(.accessibility5)
}
#Preview("Dark") { EmptyLibraryView(onOpen: {}, onSample: {}).themed().preferredColorScheme(.dark) }
