import SwiftUI

/// A rulebook's first page as a small printed cover; a book symbol until it has rendered.
struct GameCover: View {
    var image: UIImage?
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale
    static let pageAspect: CGFloat = 0.75

    var body: some View {
        ZStack {
            theme.colors.card
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            } else {
                Image(systemName: "book.closed")
                    .font(theme.font.gameDetail)
                    .foregroundStyle(theme.colors.tertiaryLabel)
            }
        }
        // A page is taller than wide (US Letter / A4 both ≈ 0.75); the width scales with Dynamic Type.
        .frame(width: theme.size.coverWidth, height: theme.size.coverWidth / Self.pageAspect)
        .clipShape(.rect(cornerRadius: theme.radius.cover))
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.cover)
                .strokeBorder(theme.colors.separator, lineWidth: 1 / displayScale)
        }
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .accessibilityHidden(true)
    }
}

#Preview("States") {
    HStack(spacing: 16) {
        GameCover(image: nil)
        GameCover(image: LibraryFixtures.cover)
    }
    .padding()
    .themed()
}
#Preview("AX5, dark") {
    HStack(spacing: 16) {
        GameCover(image: nil)
        GameCover(image: LibraryFixtures.cover)
    }
    .padding()
    .themed()
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
