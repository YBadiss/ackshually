import UIKit
import AckshuallyCore

/// Per-page overlay (PDFKit's `PDFPageOverlayViewProvider`) that draws the spotlight: the page is
/// dimmed except for the cited regions, which get a solid outline in the app tint. A view, not
/// PDF annotations: annotations can't be added to PDFs whose permissions forbid it (Azul), and a
/// yellow fill vanished on cream, decorated pages. Sized by PDFKit to the page; zooms with it.
final class SpotlightOverlayView: UIView {
    struct Style: Equatable {
        var dim: UIColor = .black.withAlphaComponent(0.3)
        var outline: UIColor = .systemRed
        /// In page points (the view's coordinate space maps to the page's crop box).
        var wordOutline: CGFloat = 1.6
        var figureOutline: CGFloat = 2.4
        var padding: CGFloat = 2.5
    }

    /// Page size in PDF points, to convert page-point widths into this view's points.
    var pageSize: CGSize = .zero { didSet { if pageSize != oldValue { setNeedsDisplay() } } }
    var style = Style() { didSet { if style != oldValue { setNeedsDisplay() } } }
    var spotlight: Spotlight? {
        didSet {
            guard spotlight != oldValue else { return }
            accessibilityValue = spotlight.map { "\($0.regions.count) region(s)" }
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
        accessibilityIdentifier = "spotlight"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ rect: CGRect) {
        guard let spotlight, !spotlight.regions.isEmpty, let ctx = UIGraphicsGetCurrentContext() else { return }
        let b = bounds
        let unit = pageSize.width > 0 ? b.width / pageSize.width : 1
        let pad = style.padding * unit
        let holes = spotlight.regions.map { r in
            CGRect(x: r.x * b.width, y: r.y * b.height, width: r.w * b.width, height: r.h * b.height)
                .insetBy(dx: -pad, dy: -pad)
        }
        let radius = spotlight.shape == .lines ? pad * 1.5 : pad
        // Lines of one quote touch once padded: union them into one shape (an even-odd fill would
        // re-dim where they overlap), outlined once.
        let cutout = holes.reduce(CGMutablePath() as CGPath) { path, h in
            let r = min(radius, h.width / 2, h.height / 2)
            return path.union(CGPath(roundedRect: h, cornerWidth: r, cornerHeight: r, transform: nil))
        }

        ctx.addPath(CGPath(rect: b, transform: nil).subtracting(cutout))
        ctx.setFillColor(style.dim.cgColor)
        ctx.fillPath()

        ctx.addPath(cutout)
        ctx.setLineWidth((spotlight.shape == .lines ? style.wordOutline : style.figureOutline) * unit)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(style.outline.cgColor)
        ctx.strokePath()
    }
}
