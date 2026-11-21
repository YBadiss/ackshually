import SwiftUI

/// First launch (before S1 exists in M3): open a rulebook PDF or try the sample.
struct EmptyLibraryView: View {
    var error: String?
    var onOpen: () -> Void
    var onSample: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                Text("ackshually").font(.largeTitle.weight(.bold)).tracking(-0.8).foregroundStyle(theme.colors.ink)
                Text("Well, according to p.14…").font(theme.font.body).foregroundStyle(theme.colors.muted)
                PrimaryButton(title: "Open a rulebook PDF", action: onOpen)
                    .padding(.top, theme.spacing.xl)
                    .accessibilityIdentifier("openPDF")
                OutlineButton(title: "Try the sample rulebook", action: onSample)
                    .accessibilityIdentifier("openSample")
                if let error {
                    Text(error).font(theme.font.meta).foregroundStyle(theme.colors.warning)
                }
            }
            .padding(theme.spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .themeBackground(\.background)
    }
}

#Preview { EmptyLibraryView(onOpen: {}, onSample: {}).themed() }
#Preview("Error, AX5") {
    EmptyLibraryView(error: "Couldn't open notes.txt as a PDF.", onOpen: {}, onSample: {})
        .themed()
        .dynamicTypeSize(.accessibility5)
}
