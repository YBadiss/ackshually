import SwiftUI

/// Page-control dots under the carousel (like `UIPageControl`).
struct CardDots: View {
    var count: Int
    var index: Int
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? theme.colors.dotActive : theme.colors.dot)
                    .frame(width: theme.size.dot, height: theme.size.dot)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: index)
        .accessibilityElement()
        .accessibilityLabel("Card \(index + 1) of \(count)")
        .accessibilityIdentifier("cardDots")
    }
}

#Preview {
    VStack(spacing: 12) {
        CardDots(count: 4, index: 0)
        CardDots(count: 4, index: 2)
    }
    .padding()
    .themeBackground(\.sheet)
    .themed()
}
