import SwiftUI

/// "Deleted Root · Undo" at the bottom of My Games after a delete, like Mail's: a glass capsule that goes
/// with the next action or after `theme.layout.undoBarDuration` (shake still undoes until the app goes to
/// the background). VoiceOver announces it.
struct UndoBar: View {
    var message: String
    var onUndo: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.l) {
            Text(message)
                .font(theme.font.undoBar)
                .foregroundStyle(theme.colors.label)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onUndo) {
                Text("Undo")
                    .font(theme.font.undoBar.weight(.semibold))
                    .frame(minWidth: theme.size.minTapTarget, minHeight: theme.size.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("undoDelete")
        }
        .padding(.horizontal, theme.spacing.xl)
        .padding(.vertical, theme.spacing.xs)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("undoBar")
        .onAppear { AccessibilityNotification.Announcement("\(message). Undo available.").post() }
    }
}

#Preview {
    UndoBar(message: "Deleted Power Plant Rush") {}
        .padding()
        .frame(maxHeight: .infinity, alignment: .bottom)
        .themeBackground(\.groupedBackground)
        .themed()
}

#Preview("AX5, dark") {
    UndoBar(message: "Deleted Root and its 7 rulebooks") {}
        .padding()
        .frame(maxHeight: .infinity, alignment: .bottom)
        .themeBackground(\.groupedBackground)
        .themed()
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}
