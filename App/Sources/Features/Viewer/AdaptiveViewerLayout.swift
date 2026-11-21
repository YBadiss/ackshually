import SwiftUI
import PDFKit

/// The one place that decides the viewer's layout:
/// - compact / portrait: PDF full-bleed, the answer in a system sheet with detents (S4–S9)
/// - wide (iPad, Mac): the answer in the standard inspector column beside the PDF; phone landscape
///   (compact width) gets the same content as a trailing column
/// Also owns the floating chrome over the PDF (ask field, "Back to Step N") and tells the PDF
/// how much of it the sheet / field covers, once the sheet has settled.
struct AdaptiveViewerLayout: View {
    @Bindable var model: ViewerModel
    var voice: AskController
    var document: PDFDocument
    var presentation: ViewerPresentation
    /// The whole window (measured outside the inspector, so opening it can't flip the layout).
    var windowSize: CGSize
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.displayScale) private var displayScale
    @State private var container = Container()
    @State private var sheetTop: CGFloat?
    @State private var askHeight: CGFloat = 0
    @State private var covered: CGFloat = 0

    struct Container: Equatable {
        var size: CGSize = .zero
        /// Global y of the window's bottom edge (below the home indicator).
        var bottom: CGFloat = 0
        var safeBottom: CGFloat = 0
    }

    private struct Settle: Equatable {
        var covered: CGFloat
        var size: CGSize
    }

    private var wide: Bool {
        let s = windowSize
        return s.width >= theme.layout.sideBySideMinWidth && (s.width > s.height || sizeClass == .regular)
    }

    /// Nothing is presented until the first layout pass says which layout this is.
    private var measured: Bool { windowSize != .zero && container.size != .zero }
    private var sheetPresented: Bool { measured && model.sheetVisible && !wide }
    private var showsAskField: Bool { !model.sheetVisible }

    /// What covers the bottom of the PDF right now (may move while the sheet is dragged).
    private var liveCovered: CGFloat {
        if sheetPresented, let top = sheetTop { return max(container.bottom - top, 0) }
        if showsAskField { return askHeight + container.safeBottom }
        return 0
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                pdf
                    .ignoresSafeArea(.container, edges: .bottom)
                    .ignoresSafeArea(.keyboard)
                floatingControls
            }
            .onGeometryChange(for: Container.self) {
                Container(size: $0.size, bottom: $0.frame(in: .global).maxY + $0.safeAreaInsets.bottom, safeBottom: $0.safeAreaInsets.bottom)
            } action: { container = $0 }
            if columnPresented {
                Rectangle().fill(theme.colors.separator).frame(width: 1 / displayScale).ignoresSafeArea()
                AnswerInspector(model: model, voice: voice, idealWidth: inspectorIdealWidth)
                    .frame(width: inspectorIdealWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(theme.sheetAnimation, value: columnPresented)
        // Re-center only once the sheet (or the inspector, a rotation) stops moving.
        .task(id: Settle(covered: liveCovered, size: container.size)) {
            try? await Task.sleep(for: theme.layout.sheetSettleDelay)
            guard !Task.isCancelled else { return }
            covered = liveCovered
            model.visibleAreaChanged()
        }
        .onChange(of: sheetPresented, initial: true) { _, p in
            presentation.answerSheetPresented = p
            if !p { sheetTop = nil }
        }
        .sheet(isPresented: sheetBinding) {
            AnswerSheet(model: model, voice: voice, presentation: presentation,
                        containerHeight: container.size.height + container.safeBottom) { sheetTop = $0 }
                .themed()
        }
        .inspector(isPresented: inspectorBinding) {
            AnswerInspector(model: model, voice: voice, idealWidth: inspectorIdealWidth)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(model.sheetVisible ? "Hide Answer" : "Show Answer", systemImage: "sidebar.trailing", action: toggleAnswer)
                    .accessibilityIdentifier("toggleAnswer")
            }
            .hidden(!(wide && model.answer != nil))
        }
    }

    private func toggleAnswer() {
        withAnimation(theme.sheetAnimation) { model.sheetVisible ? model.dismissSheet() : model.showSheet() }
    }

    private var inspectorIdealWidth: CGFloat {
        let r = theme.layout.inspectorWidthRange
        return min(max(windowSize.width * theme.layout.inspectorFraction, r.lowerBound), r.upperBound)
    }

    // Read-only: neither can be dismissed by a gesture (the header's Close button closes the
    // answer), so SwiftUI only writes `false` when a rotation moves the answer from one to the other.
    private var sheetBinding: Binding<Bool> {
        Binding { sheetPresented } set: { _ in }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding { measured && model.sheetVisible && wide && sizeClass == .regular } set: { _ in }
    }

    /// Phone landscape: wide enough for a column, but compact width, where `.inspector` would
    /// become a sheet. Same content, laid out as a trailing column.
    private var columnPresented: Bool { measured && model.sheetVisible && wide && sizeClass != .regular }

    // MARK: PDF

    private var pdf: some View {
        PDFViewer(document: document, focus: model.focus, bottomObscured: covered,
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

    // MARK: Floating chrome

    private var floatingControls: some View {
        VStack(spacing: theme.spacing.m) {
            if model.userMovedPDF, model.sheetVisible, let n = model.focusedStepNumber {
                BackToStepPill(step: n) { model.backToStep() }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            if showsAskField {
                askArea
                    .frame(maxWidth: theme.layout.askFieldMaxWidth)
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.bottom, theme.spacing.s)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { askHeight = $0 + theme.spacing.s }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Above the sheet's top edge (the sheet is a separate presentation, not in this stack).
        .padding(.bottom, sheetPresented ? max(covered - container.safeBottom, 0) + theme.spacing.m : 0)
        .animation(theme.sheetAnimation, value: showsAskField)
        .animation(.snappy, value: model.userMovedPDF)
    }

    @ViewBuilder private var askArea: some View {
        if model.phase == .waiting, let q = model.answer?.question {
            WaitingBar(question: q) { model.stop() }
        } else {
            AskField(text: $model.draft, voice: voice) { model.ask($0) }
        }
    }
}

#Preview("iPhone 18 Pro") { ViewerPreview().themed() }
#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) { ViewerPreview().themed() }
#Preview("Pro Max", traits: .fixedLayout(width: 440, height: 956)) { ViewerPreview().themed() }
#Preview("Landscape", traits: .landscapeLeft) { ViewerPreview().themed() }
#Preview("iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    ViewerPreview().themed().environment(\.horizontalSizeClass, .regular)
}
#Preview("AX5") { ViewerPreview().themed().dynamicTypeSize(.accessibility5) }
#Preview("Dark") { ViewerPreview().themed().preferredColorScheme(.dark) }
#Preview("Streaming") { ViewerPreview(state: .streaming).themed() }
#Preview("Branch") { ViewerPreview(state: .branch).themed() }
#Preview("Collapsed") { ViewerPreview(detent: .collapsed).themed() }
#Preview("Expanded") { ViewerPreview(detent: .expanded).themed() }
#Preview("Idle") { ViewerPreview(state: .idle).themed() }

