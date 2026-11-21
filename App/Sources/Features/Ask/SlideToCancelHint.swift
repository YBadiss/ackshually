import SwiftUI

/// "‹ Slide to cancel" / "Release to cancel".
struct SlideToCancelHint: View {
    var cancelArmed: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Label(cancelArmed ? "Release to cancel" : "Slide to cancel", systemImage: cancelArmed ? "xmark.circle.fill" : "chevron.backward")
            .font(theme.font.rowValue)
            .foregroundStyle(cancelArmed ? theme.colors.tint : theme.colors.secondaryLabel)
    }
}
