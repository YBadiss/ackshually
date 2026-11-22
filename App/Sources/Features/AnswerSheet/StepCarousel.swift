import SwiftUI

/// Horizontal step cards (S5/S6), a system shelf: `.viewAligned` paging, next card peeking from the edge,
/// `.scrollPosition(id:)` bound to the current card (which drives the PDF). Card width is
/// relative to the carousel: each side keeps `layout.cardPeekFraction` for the neighbours.
/// All cards share one height, the tallest card's content (each card caps its text at
/// `layout.cardMaxLines` and offers "More"), so text never runs outside a card. A plain `HStack`
/// (an answer has a handful of cards) so every card is measured, not just the visible ones.
/// The shelf never gets shorter while it shows the same answer: while streaming, the loading card
/// reserves a full card, and when it goes away the shelf keeps that height so nothing below moves
/// (the owner's "panel jumps while the answer arrives"). The parent resets it per answer / branch
/// with `.id`.
struct StepCarousel: View {
    var items: [CardItem]
    @Binding var selection: CardID?
    var onMore: (CardID) -> Void = { _ in }
    @Environment(\.theme) private var theme
    @State private var width: CGFloat = 0
    @State private var contentHeights: [CardID: CGFloat] = [:]
    /// Tallest card content seen so far (the shelf only grows).
    @State private var tallestSeen: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    private var shelfHeight: CGFloat? {
        guard let tallest = items.compactMap({ contentHeights[$0.id] }).max() else { return nil }
        return max(tallest, tallestSeen)
    }

    private var current: CardID? { selection ?? items.first?.id }

    var body: some View {
        ScrollViewReader { proxy in
            carousel
                // `.scrollPosition(id:)` ignores the initial value; honour it on appear.
                .onAppear { if let s = selection { proxy.scrollTo(s, anchor: .center) } }
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.m) {
                ForEach(items) { item in
                    StepCard(content: item.content, height: shelfHeight, onMore: { onMore(item.id) }) { h in
                        contentHeights[item.id] = h
                        tallestSeen = max(tallestSeen, h)
                    }
                        .containerRelativeFrame(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Tap a peek = go there. Taps on the current card do nothing.
                            if item.id != current { withAnimation(.snappy) { selection = item.id } }
                        }
                        .accessibilityAction(named: "Show") { selection = item.id }
                        .accessibilityLabel(Self.accessibilityLabel(item, of: items.count))
                        .accessibilityIdentifier("stepCard")
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max(width * theme.layout.cardPeekFraction, theme.spacing.sheetMargin), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selection, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // A new text size re-measures from scratch. Not on width: the floating sheet narrows and
        // widens a little as its detent height changes, and that must not shrink the shelf.
        .onChange(of: typeSize) { tallestSeen = 0 }
        .accessibilityIdentifier("carousel")
    }
}

extension StepCarousel {
    static func accessibilityLabel(_ item: CardItem, of count: Int) -> String {
        switch item.content {
        case let .step(n, title, pages, text, _):
            "Step \(n), \(title)\(pages.isEmpty ? "" : ", page \(pages.map(String.init).joined(separator: ", "))"). \(text)"
        case .loading: "Next step loading"
        case let .branch(c, v): "If \(c): \(v)"
        case let .web(_, w): "\(w.site), \(w.role): \(w.quote)"
        }
    }
}

private struct CarouselPreview: View {
    @State var selection: CardID? = .step(0)
    var body: some View {
        VStack {
            StepCarousel(items: Fixtures.cardItems, selection: $selection)
            CardDots(count: Fixtures.cardItems.count, index: Fixtures.cardItems.firstIndex { $0.id == selection } ?? 0)
        }
        .padding(.vertical)
        .frame(maxHeight: .infinity)
        .themeBackground(\.sheet)
    }
}

#Preview("iPhone") { CarouselPreview().themed() }
#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 300)) { CarouselPreview().themed() }
#Preview("AX5") { CarouselPreview().themed().dynamicTypeSize(.accessibility5) }
#Preview("Dark") { CarouselPreview().themed().preferredColorScheme(.dark) }
