import SwiftUI

/// Position dots under the carousel; the active one is a wider accent capsule.
struct CardDots: View {
    var count: Int
    var index: Int
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(0..<count, id: \.self) { i in
                Capsule().fill(i == index ? theme.colors.accent : theme.colors.line)
                    .frame(width: i == index ? theme.size.activeDot : theme.size.dot, height: theme.size.dot)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: index)
        .accessibilityElement()
        .accessibilityLabel("Card \(index + 1) of \(count)")
    }
}

#Preview {
    VStack(spacing: 12) {
        CardDots(count: 4, index: 0)
        CardDots(count: 4, index: 2)
    }
    .padding()
    .themed()
}
