import SwiftUI
import PDFKit
import AckshuallyCore

/// PDFKit viewer that follows the current step (S5/S6) and lets the user inspect freely (S8).
/// - `focus` changes → go to page, zoom to the evidence inside the visible area, draw highlights.
/// - Pinch/pan by the user → `onUserMove` (the "⤺ Back to step N" pill). Taps never change steps.
/// - Double-tap → `onDoubleTap` (evidence zoom ↔ full page).
struct PDFViewer: UIViewRepresentable {
    let document: PDFDocument
    var focus: PDFFocus?
    /// Height covered by the answer sheet / ask bar at the bottom, in points.
    var bottomObscured: CGFloat
    /// Height of the chrome over the top of the page (quote pager, highlight note), below the
    /// safe area: evidence is centered beneath it so a note never covers the spotlit lines.
    var topObscured: CGFloat = 0
    var onUserMove: () -> Void
    var onDoubleTap: () -> Void
    @Environment(\.theme) private var theme

    func makeCoordinator() -> Coordinator { Coordinator() }

    private var style: Coordinator.Style {
        Coordinator.Style(
            spotlight: SpotlightOverlayView.Style(dim: UIColor(theme.colors.spotlightDim), outline: UIColor(theme.colors.highlightOutline),
                                                  wordOutline: theme.size.wordOutline, figureOutline: theme.size.figureOutline,
                                                  padding: theme.size.highlightPadding),
            moveDuration: theme.layout.pdfMoveDuration, maxZoom: theme.layout.maxEvidenceZoom, margin: theme.spacing.m)
    }

    func makeUIView(context: Context) -> PDFView {
        let v = FitPagePDFView()
        // Before the document: PDFKit asks for page overlays as it creates the page views.
        v.pageOverlayViewProvider = context.coordinator
        v.document = document
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.displaysPageBreaks = true
        v.pageShadowsEnabled = true
        v.backgroundColor = UIColor(theme.colors.canvas)
        v.autoScales = true
        v.maxScaleFactor = 8
        context.coordinator.attach(to: v)
        return v
    }

    func updateUIView(_ v: PDFView, context: Context) {
        let c = context.coordinator
        c.onUserMove = onUserMove
        c.onDoubleTap = onDoubleTap
        c.style = style
        v.backgroundColor = UIColor(theme.colors.canvas)
        if v.document !== document {
            v.document = document
            c.applied = nil
            (v as? FitPagePDFView)?.fitWholePage = true
        }
        let obscuredChanged = abs(c.bottomObscured - bottomObscured) > 1 || abs(c.topObscured - topObscured) > 1
        c.bottomObscured = bottomObscured
        c.topObscured = topObscured
        if focus == nil, c.applied != nil {
            c.clearHighlights()
            c.applied = nil
            (v as? FitPagePDFView)?.fitWholePage = true
        }
        guard let focus else { return }
        if focus != c.applied {
            (v as? FitPagePDFView)?.fitWholePage = false
            c.apply(focus, animated: c.applied != nil)
        } else if obscuredChanged {
            c.apply(focus, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate, @MainActor PDFPageOverlayViewProvider {
        struct Style {
            var spotlight = SpotlightOverlayView.Style()
            var moveDuration: TimeInterval = 0.35
            var maxZoom: CGFloat = 3, margin: CGFloat = 8
        }
        weak var view: PDFView?
        var style = Style() {
            didSet { for o in overlays.values { o.style = style.spotlight } }
        }
        var applied: PDFFocus?
        var bottomObscured: CGFloat = 0
        var topObscured: CGFloat = 0
        var onUserMove: () -> Void = {}
        var onDoubleTap: () -> Void = {}
        /// What is spotlit, and the overlay views PDFKit currently shows (one per visible page).
        private var spotlit: (page: PDFPage, spotlight: Spotlight)?
        private var overlays: [ObjectIdentifier: SpotlightOverlayView] = [:]

        func attach(to v: PDFView) {
            view = v
            // Watch (don't replace) PDFKit's own gestures to tell user moves from ours.
            let pan = UIPanGestureRecognizer(target: self, action: #selector(userGesture(_:)))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(userGesture(_:)))
            for g in [pan, pinch] as [UIGestureRecognizer] {
                g.delegate = self
                g.cancelsTouchesInView = false
                v.addGestureRecognizer(g)
            }
            let dbl = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
            dbl.numberOfTapsRequired = 2
            dbl.delegate = self
            dbl.cancelsTouchesInView = true
            v.addGestureRecognizer(dbl)
        }

        private weak var observedScroll: UIScrollView?

        /// Also listen to PDFKit's own scroll-view gestures (created lazily by PDFView).
        func observeScrollGestures() {
            guard let v = view, let sv = Self.scrollView(in: v), sv !== observedScroll else { return }
            observedScroll = sv
            sv.panGestureRecognizer.addTarget(self, action: #selector(userGesture(_:)))
            sv.pinchGestureRecognizer?.addTarget(self, action: #selector(userGesture(_:)))
        }

        @objc func userGesture(_ g: UIGestureRecognizer) {
            if g.state == .began {
                (view as? FitPagePDFView)?.fitWholePage = false
                onUserMove()
            }
        }

        @objc func doubleTap(_ g: UITapGestureRecognizer) {
            if g.state == .ended { onDoubleTap() }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        // MARK: Spotlight

        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            let o = overlays[ObjectIdentifier(page)] ?? SpotlightOverlayView()
            configure(o, for: page)
            overlays[ObjectIdentifier(page)] = o
            return o
        }

        func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
            overlays[ObjectIdentifier(page)] = nil
        }

        private func configure(_ o: SpotlightOverlayView, for page: PDFPage) {
            o.style = style.spotlight
            o.pageSize = page.bounds(for: .cropBox).size
            o.spotlight = spotlit?.page === page ? spotlit?.spotlight : nil
        }

        func clearHighlights() {
            spotlit = nil
            for o in overlays.values { o.spotlight = nil }
            (view as? FitPagePDFView)?.spotlightRegions = 0
        }

        private func drawHighlights(_ h: Highlight, on page: PDFPage) {
            switch h.kind {
            case .words(let rects): spotlit = (page, Spotlight(regions: rects, shape: .lines))
            case .box(let b): spotlit = (page, Spotlight(regions: [b], shape: .figure))
            case .wholePage: spotlit = nil
            }
            for (id, o) in overlays {
                o.spotlight = spotlit.flatMap { ObjectIdentifier($0.page) == id ? $0.spotlight : nil }
            }
            (view as? FitPagePDFView)?.spotlightRegions = spotlit?.spotlight.regions.count ?? 0
        }

        // MARK: Zoom

        /// Target rect in page space (unpadded) for the highlight.
        private func targetRect(_ h: Highlight, page: PDFPage, zoom: ZoomMode) -> CGRect {
            let pb = page.bounds(for: .cropBox)
            guard zoom == .evidence else { return pb }
            func toPage(_ b: NormalizedBox) -> CGRect {
                CGRect(x: pb.minX + b.x * pb.width, y: pb.minY + (1 - b.y - b.h) * pb.height,
                       width: b.w * pb.width, height: b.h * pb.height)
            }
            switch h.kind {
            case .words(let rects):
                let u = rects.map(toPage).reduce(CGRect.null) { $0.union($1) }
                return u.isNull ? pb : u
            case .box(let b):
                return toPage(b)
            case .wholePage:
                return pb
            }
        }

        func apply(_ focus: PDFFocus, animated: Bool, retries: Int = 20) {
            guard let v = view, let doc = v.document,
                  let page = doc.page(at: min(max(focus.highlight.page, 1), doc.pageCount) - 1) else { return }
            v.layoutIfNeeded()
            let bounds = v.bounds
            guard bounds.width > 0, bounds.height > 0 else {
                // Not laid out yet (first appearance): try again on the next run loop.
                guard retries > 0 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self, self.applied != focus else { return }
                    self.apply(focus, animated: false, retries: retries - 1)
                }
                return
            }
            applied = focus
            observeScrollGestures()
            drawHighlights(focus.highlight, on: page)
            let m = style.margin
            let top = v.safeAreaInsets.top + max(m, topObscured + m / 2)
            let visible = CGRect(x: 0, y: top, width: bounds.width,
                                 height: max(bounds.height - top - bottomObscured - m, bounds.height * 0.2))
            let pageRect = page.bounds(for: .cropBox)
            let target = targetRect(focus.highlight, page: page, zoom: focus.zoom)
            let isPage = target == pageRect

            // Fit the target (with context around it) into the visible area.
            let fitWidth = bounds.width / pageRect.width
            let scale: CGFloat
            if isPage {
                scale = min(visible.width / pageRect.width, visible.height / pageRect.height) * 0.98
            } else {
                let padded = target.insetBy(dx: -max(pageRect.width * 0.04, target.width * 0.12),
                                            dy: -max(pageRect.height * 0.045, target.height * 0.6))
                let s = min(visible.width / padded.width, visible.height / padded.height)
                // Never smaller than page width (keeps the paragraph's context), never absurdly large.
                scale = min(max(s, fitWidth), fitWidth * style.maxZoom)
            }
            v.autoScales = false
            v.minScaleFactor = min(v.scaleFactorForSizeToFit, scale) * 0.5
            let changeScale = abs(v.scaleFactor - scale) > 0.001
            let move = {
                if changeScale { v.scaleFactor = scale }
                v.go(to: target, on: page)
                v.layoutIfNeeded()
                guard let scroll = Self.scrollView(in: v) else { return }
                let r = v.convert(target, from: page)
                var off = scroll.contentOffset
                off.x += r.midX - visible.midX
                off.y += r.midY - visible.midY
                let inset = scroll.adjustedContentInset
                off.x = min(max(off.x, -inset.left), max(scroll.contentSize.width - scroll.bounds.width + inset.right, -inset.left))
                off.y = min(max(off.y, -inset.top), max(scroll.contentSize.height - scroll.bounds.height + inset.bottom + self.bottomObscured, -inset.top))
                scroll.setContentOffset(off, animated: false)
            }
            if animated {
                UIView.animate(withDuration: style.moveDuration, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: move)
            } else {
                move()
            }
        }

        static func scrollView(in v: UIView) -> UIScrollView? {
            for s in v.subviews {
                if let sv = s as? UIScrollView { return sv }
                if let sv = scrollView(in: s) { return sv }
            }
            return nil
        }
    }
}

#Preview("Evidence zoom") {
    PDFViewer(document: Fixtures.pdf, focus: Fixtures.focus(.evidence), bottomObscured: 0, onUserMove: {}, onDoubleTap: {})
        .ignoresSafeArea()
        .themed()
}

#Preview("Whole page") {
    PDFViewer(document: Fixtures.pdf, focus: Fixtures.focus(.page), bottomObscured: 0, onUserMove: {}, onDoubleTap: {})
        .ignoresSafeArea()
        .themed()
}


/// Shows the whole current page (fit width *and* height) while nothing is focused, so a rulebook
/// opens fully visible. Stops refitting once an answer focuses evidence or the user zooms/pans.
final class FitPagePDFView: PDFView {
    var fitWholePage = true {
        didSet {
            if fitWholePage { setNeedsLayout() }
            updateAccessibilityValue()
        }
    }

    /// Number of spotlit regions on the evidence page (0 = nothing spotlit). PDFKit's page overlays
    /// aren't in the accessibility tree, so UI tests read it from the value ("Zoomed, spotlight 1").
    var spotlightRegions = 0 {
        didSet { updateAccessibilityValue() }
    }

    private func updateAccessibilityValue() {
        let zoom = fitWholePage ? "Whole page" : "Zoomed"
        accessibilityValue = spotlightRegions > 0 ? "\(zoom), spotlight \(spotlightRegions)" : zoom
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "pdfView"
        accessibilityValue = "Whole page"
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard fitWholePage, let page = currentPage ?? document?.page(at: 0) else { return }
        let pageRect = page.bounds(for: displayBox)
        let height = bounds.height - safeAreaInsets.top - safeAreaInsets.bottom
        guard pageRect.width > 0, pageRect.height > 0, bounds.width > 0, height > 0 else { return }
        let scale = min(bounds.width / pageRect.width, height / pageRect.height)
        guard abs(scaleFactor - scale) > 0.001 else { return }
        autoScales = false
        minScaleFactor = min(minScaleFactor, scale * 0.5)
        scaleFactor = scale
        go(to: page)
    }
}
