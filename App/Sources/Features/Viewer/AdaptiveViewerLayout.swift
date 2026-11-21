import SwiftUI
import PDFKit

/// The one place that decides the viewer's layout:
/// - compact / portrait: PDF full-bleed with the answer as a bottom sheet (S4–S9)
/// - wide (iPad, Mac, phone landscape): answer panel beside the PDF, no detents
struct AdaptiveViewerLayout: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    var document: PDFDocument
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var sheetHeight: CGFloat = 0
    @State private var barHeight: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            if isWide(g.size) {
                wide(g)
            } else {
                compact(g)
            }
        }
    }

    private func isWide(_ size: CGSize) -> Bool {
        let wideEnough = size.width >= theme.layout.sideBySideMinWidth
        return wideEnough && (size.width > size.height || sizeClass == .regular)
    }

    // MARK: Compact: bottom sheet

    private func compact(_ g: GeometryProxy) -> some View {
        let covered = (model.sheetVisible ? sheetHeight : barHeight) + g.safeAreaInsets.bottom
        return ZStack(alignment: .bottom) {
            pdf(bottomObscured: covered)
                .ignoresSafeArea(.container, edges: .bottom)
                .ignoresSafeArea(.keyboard)
            VStack(spacing: theme.spacing.m) {
                pdfChrome
                bottomControls(g)
            }
            .frame(maxWidth: theme.layout.sheetMaxWidth)
        }
        .onChange(of: covered) { _, _ in model.visibleAreaChanged() }
    }

    @ViewBuilder private func bottomControls(_ g: GeometryProxy) -> some View {
        if model.sheetVisible {
            BottomSheet(detent: $model.detent, availableHeight: g.size.height,
                        onDismiss: { model.dismissSheet() }, onRestingHeight: { sheetHeight = $0 }) {
                AnswerCollapsedContent(model: model)
            } medium: {
                AnswerMediumContent(model: model, voice: voice)
            } expanded: {
                AnswerExpandedContent(model: model, voice: voice)
            }
            .transition(.move(edge: .bottom))
        } else {
            askArea
                .padding(.horizontal, theme.spacing.m)
                .padding(.bottom, theme.spacing.s)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 + theme.spacing.s }
        }
    }

    // MARK: Wide: side panel

    private func wide(_ g: GeometryProxy) -> some View {
        let r = theme.layout.sidePanelWidthRange
        let panelWidth = min(max(g.size.width * theme.layout.sidePanelFraction, r.lowerBound), r.upperBound)
        let showPanel = model.sheetVisible
        return HStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                pdf(bottomObscured: showPanel ? 0 : barHeight + g.safeAreaInsets.bottom)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .ignoresSafeArea(.keyboard)
                VStack(spacing: theme.spacing.m) {
                    pdfChrome
                    if !showPanel {
                        askArea
                            .frame(maxWidth: theme.layout.sheetMaxWidth)
                            .padding(.horizontal, theme.spacing.l).padding(.bottom, theme.spacing.s)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 + theme.spacing.s }
                    }
                }
            }
            if showPanel {
                Rectangle().fill(theme.colors.line).frame(width: theme.size.hairline).ignoresSafeArea()
                AnswerSidePanel(model: model, voice: voice)
                    .frame(width: panelWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(theme.sheetAnimation, value: showPanel)
    }

    // MARK: Shared pieces

    private func pdf(bottomObscured: CGFloat) -> some View {
        PDFViewer(document: document, focus: model.focus, bottomObscured: bottomObscured,
                  onUserMove: { model.userMovedPDF = true },
                  onDoubleTap: { model.toggleZoom() })
            .overlay(alignment: .top) {
                if model.focus != nil, model.sheetVisible {
                    HighlightOverlay(evidenceIndex: model.evidenceIndex, evidenceCount: model.currentStep?.evidence.count ?? 0,
                                     note: model.currentHighlight?.note ?? (model.currentHighlight?.kind == .wholePage ? "Showing the whole page" : nil),
                                     onNext: { model.nextEvidence() })
                        .padding(.top, theme.spacing.s)
                }
            }
    }

    /// Floating PDF chrome just above the sheet / ask bar.
    @ViewBuilder private var pdfChrome: some View {
        if model.userMovedPDF, model.sheetVisible, let n = model.focusedStepNumber {
            BackToStepPill(step: n) { model.backToStep() }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    @ViewBuilder private var askArea: some View {
        if model.phase == .waiting, let q = model.answer?.question {
            WaitingBar(question: q) { model.stop() }
        } else {
            AskBar(text: $model.draft, voice: voice) { model.ask($0) }
        }
    }
}

#Preview("iPhone 16 Pro") { ViewerPreview().themed() }
#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) { ViewerPreview().themed() }
#Preview("Pro Max", traits: .fixedLayout(width: 440, height: 956)) { ViewerPreview().themed() }
#Preview("Landscape", traits: .landscapeLeft) { ViewerPreview().themed() }
#Preview("iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    ViewerPreview().themed().environment(\.horizontalSizeClass, .regular)
}
#Preview("AX5") { ViewerPreview().themed().dynamicTypeSize(.accessibility5) }
#Preview("Dark") { ViewerPreview().themed().preferredColorScheme(.dark) }
#Preview("Streaming") { ViewerPreview(state: .streaming).themed() }
#Preview("Idle") { ViewerPreview(state: .idle).themed() }

/// Previews the whole viewer from fixtures (no API key).
struct ViewerPreview: View {
    var state: Fixtures.ModelState = .answered
    @State private var model: ViewerModel?
    @State private var voice = AskController()

    var body: some View {
        NavigationStack {
            if let model, let rb = model.rulebook {
                AdaptiveViewerLayout(model: model, voice: voice, document: rb.pdf)
                    .navigationTitle(rb.title).navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear { model = Fixtures.model(state) }
    }
}
