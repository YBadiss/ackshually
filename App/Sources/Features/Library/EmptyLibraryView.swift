import SwiftUI

/// My Games with no games (first launch, or everything deleted): add a rulebook PDF or try the sample.
struct EmptyLibraryView: View {
    var error: String?
    var onAdd: () -> Void
    var onSample: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        ContentUnavailableView {
            Label("No Games Yet", systemImage: "book.pages")
        } description: {
            VStack(spacing: theme.spacing.s) {
                Text("Add the rulebook PDF for your game, then ask. Well, according to p.14…")
                if let error {
                    Text(error).foregroundStyle(theme.colors.warning)
                }
            }
        } actions: {
            Button("Add a Rulebook", action: onAdd)
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("emptyAddRulebook")
            Button("Try the Sample", action: onSample)
                .accessibilityIdentifier("trySample")
        }
    }
}

#Preview { EmptyLibraryView(onAdd: {}, onSample: {}).themed().themeBackground(\.groupedBackground) }
#Preview("Error, AX5") {
    EmptyLibraryView(error: "Couldn't open notes.txt as a PDF.", onAdd: {}, onSample: {})
        .themed()
        .dynamicTypeSize(.accessibility5)
}
#Preview("Dark") { EmptyLibraryView(onAdd: {}, onSample: {}).themed().preferredColorScheme(.dark) }
