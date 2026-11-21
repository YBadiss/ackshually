import SwiftUI

/// Tiny live level meter (S3 mockup waveform).
struct Waveform: View {
    var level: Float
    @Environment(\.theme) private var theme
    private let shape: [CGFloat] = [0.3, 0.7, 1, 0.5, 0.8, 0.35]

    var body: some View {
        HStack(spacing: theme.spacing.xxs) {
            ForEach(shape.indices, id: \.self) { i in
                Capsule().fill(theme.colors.tint)
                    .frame(width: theme.size.waveBar,
                           height: max(theme.size.waveBar, theme.size.waveHeight * shape[i] * CGFloat(max(level, 0.12))))
            }
        }
        .frame(height: theme.size.waveHeight)
        .animation(.easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack { Waveform(level: 0.1); Waveform(level: 0.6); Waveform(level: 1) }
        .padding()
        .themed()
}
