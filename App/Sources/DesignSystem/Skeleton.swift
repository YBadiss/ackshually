import SwiftUI

/// Pulsing placeholder line: "something is coming" while the answer streams (S4).
/// Width is a fraction of the available width.
struct SkeletonLine: View {
    var widthFraction: CGFloat = 1
    var isTitle = false
    @Environment(\.theme) private var theme
    @State private var on = false

    var body: some View {
        GeometryReader { g in
            RoundedRectangle(cornerRadius: theme.radius.label)
                .fill(theme.colors.line.opacity(on ? 0.9 : 0.5))
                .frame(width: g.size.width * widthFraction)
        }
        .frame(height: isTitle ? theme.size.skeletonTitle : theme.size.skeletonLine)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { on = true } }
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading) {
        SkeletonLine(widthFraction: 0.8, isTitle: true)
        SkeletonLine(widthFraction: 0.45)
    }
    .padding()
    .themed()
}
