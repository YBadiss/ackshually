import SwiftUI

/// Small outlined pill button (branch pills, "‹ Main answer"). Filled when active.
struct OutlinePill: View {
    var text: String
    var active = false
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(theme.font.chip)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, theme.spacing.m).padding(.vertical, theme.spacing.xs)
                .foregroundStyle(active ? theme.colors.accentInk : theme.colors.muted)
                .background(active ? theme.colors.ink : .clear, in: RoundedRectangle(cornerRadius: theme.radius.label))
                .overlay(RoundedRectangle(cornerRadius: theme.radius.label).strokeBorder(active ? .clear : theme.colors.line))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

#Preview {
    VStack {
        OutlinePill(text: "No Battery? Discard all 3. ›") {}
        OutlinePill(text: "‹ Main answer", active: true) {}
    }
    .padding()
    .themed()
}
