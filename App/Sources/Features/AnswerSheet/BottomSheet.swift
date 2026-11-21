import SwiftUI

/// Draggable bottom sheet with three detents (S5/S7/S9). Custom rather than `.sheet` so the PDF
/// above stays interactive and we know how much of it is covered.
/// - collapsed: content-sized (one line)
/// - medium: content-sized, capped at `layout.sheetMediumMaxFraction` of the height (scrolls past that)
/// - expanded: `layout.sheetExpandedFraction` of the height
/// Flick down from collapsed calls `onDismiss`.
struct BottomSheet<Collapsed: View, Medium: View, Expanded: View>: View {
    @Binding var detent: SheetDetent
    /// Height available to the sheet (the viewer's height, safe areas excluded).
    var availableHeight: CGFloat
    var onDismiss: () -> Void
    /// Resting height (not while dragging), so the PDF can center evidence above the sheet.
    var onRestingHeight: (CGFloat) -> Void
    @ViewBuilder var collapsed: () -> Collapsed
    @ViewBuilder var medium: () -> Medium
    @ViewBuilder var expanded: () -> Expanded

    @Environment(\.theme) private var theme
    @State private var drag: CGFloat = 0
    @State private var dragging = false
    @State private var collapsedNatural: CGFloat = 0
    @State private var mediumNatural: CGFloat = 0

    private var grabberHeight: CGFloat { theme.size.grabber.height + theme.spacing.m * 2 }
    private var mediumCap: CGFloat { availableHeight * theme.layout.sheetMediumMaxFraction }
    private var expandedHeight: CGFloat { availableHeight * theme.layout.sheetExpandedFraction }

    private func height(_ d: SheetDetent) -> CGFloat {
        switch d {
        case .collapsed: grabberHeight + collapsedNatural
        case .medium: min(grabberHeight + (mediumNatural > 0 ? mediumNatural : mediumCap), mediumCap)
        case .expanded: max(expandedHeight, height(.medium))
        }
    }

    /// Layout for the current (possibly dragged) height.
    private var shown: SheetDetent {
        guard dragging else { return detent }
        let h = height(detent) - drag
        if h < (height(.collapsed) + height(.medium)) / 2 { return .collapsed }
        if h > (height(.medium) + height(.expanded)) / 2 { return .expanded }
        return .medium
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            Group {
                switch shown {
                case .collapsed:
                    collapsed()
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { collapsedNatural = $0 }
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(theme.sheetAnimation) { detent = .medium } }
                case .medium:
                    mediumBody
                case .expanded:
                    expanded()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: dragging ? clampedDragHeight : height(detent), alignment: .top)
        .background {
            // Extends under the home indicator; the frame (and reported height) stays in the safe area.
            UnevenRoundedRectangle(topLeadingRadius: theme.radius.sheet, topTrailingRadius: theme.radius.sheet)
                .fill(theme.colors.sheet)
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: theme.radius.sheet, topTrailingRadius: theme.radius.sheet)
                        .stroke(theme.colors.line, lineWidth: theme.size.hairline)
                        .mask(alignment: .top) { Rectangle().frame(height: theme.radius.sheet) }
                }
                .shadow(color: theme.colors.shadow, radius: theme.spacing.l, y: -theme.spacing.xs)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .simultaneousGesture(sheetDrag, including: shown == .expanded ? .subviews : .all)
        .onChange(of: dragging ? -1 : height(detent), initial: true) { _, h in if h > 0 { onRestingHeight(h) } }
        .animation(theme.sheetAnimation, value: detent)
    }

    @ViewBuilder private var mediumBody: some View {
        let content = medium()
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mediumNatural = $0 }
        if grabberHeight + mediumNatural > mediumCap {
            ScrollView { content }.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }

    private var clampedDragHeight: CGFloat {
        min(max(height(detent) - drag, height(.collapsed) * 0.6), availableHeight)
    }

    private var grabber: some View {
        Capsule().fill(theme.colors.line)
            .frame(width: theme.size.grabber.width, height: theme.size.grabber.height)
            .padding(.vertical, theme.spacing.m)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(sheetDrag)
            .accessibilityElement()
            .accessibilityLabel("Answer sheet")
            .accessibilityHint("Swipe up or down to resize")
            .accessibilityAdjustableAction { dir in
                withAnimation(theme.sheetAnimation) { detent = step(detent, up: dir == .increment) }
            }
    }

    private func step(_ d: SheetDetent, up: Bool) -> SheetDetent {
        let all = SheetDetent.allCases
        let i = all.firstIndex(of: d) ?? 1
        return all[min(max(i + (up ? 1 : -1), 0), all.count - 1)]
    }

    /// Vertical drags only (horizontal ones belong to the carousel).
    private var sheetDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { v in
                guard dragging || abs(v.translation.height) > abs(v.translation.width) * 1.3 else { return }
                dragging = true
                drag = v.translation.height
            }
            .onEnded { v in
                guard dragging else { return }
                let predicted = height(detent) - v.predictedEndTranslation.height
                if detent == .collapsed, v.predictedEndTranslation.height > theme.spacing.xxl * 3 {
                    dragging = false; drag = 0
                    withAnimation(theme.sheetAnimation) { onDismiss() }
                    return
                }
                var next = SheetDetent.allCases.min { abs(height($0) - predicted) < abs(height($1) - predicted) } ?? .medium
                if next == detent, abs(v.translation.height) > theme.spacing.xxl * 1.5 {
                    next = step(detent, up: v.translation.height < 0)  // a deliberate drag always moves one detent
                }
                withAnimation(theme.sheetAnimation) {
                    dragging = false
                    drag = 0
                    detent = next
                }
            }
    }
}

private struct SheetPreview: View {
    @State var detent: SheetDetent
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.2)
                BottomSheet(detent: $detent, availableHeight: g.size.height, onDismiss: {}, onRestingHeight: { _ in }) {
                    CollapsedVerdictBar(verdict: Fixtures.answer.verdict, confidence: .stated, pages: [4])
                } medium: {
                    VStack {
                        AnswerHeader(content: Fixtures.headerStated)
                        StepCarousel(items: Fixtures.cardItems, selection: .constant(.step(0)))
                    }
                    .padding(.bottom)
                } expanded: {
                    ScrollView {
                        AnswerHeader(content: Fixtures.headerStated)
                        FullAnswerList(rows: Fixtures.stepRows, current: 0, assumptions: Fixtures.answer.assumptions,
                                       branches: Fixtures.answer.branches) { _ in }
                    }
                }
            }
        }
    }
}

#Preview("Medium") { SheetPreview(detent: .medium).themed() }
#Preview("Collapsed") { SheetPreview(detent: .collapsed).themed() }
#Preview("Expanded") { SheetPreview(detent: .expanded).themed() }
#Preview("Medium AX5") { SheetPreview(detent: .medium).themed().dynamicTypeSize(.accessibility5) }
